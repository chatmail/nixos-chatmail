{ config, lib, pkgs, ... }:
let
  inherit (lib)
    mdDoc
    mkEnableOption
    mkIf
    mkOption;

  chatmailDomain = "c-nixos.testrun.org";
  cfg = config.services.chatmail;
  dovecotAuthConf = pkgs.writeText "auth.conf" ''
    uri = proxy:/run/doveauth.socket:auth
    iterate_disable = yes
    default_pass_scheme = plain
    # %E escapes characters " (double quote), ' (single quote) and \ (backslash) with \ (backslash).
    # See <https://doc.dovecot.org/configuration_manual/config_file/config_variables/#modifiers>
    # for documentation.
    #
    # We escape user-provided input and use double quote as a separator.
    password_key = passdb/%Ew"%Eu
    user_key = userdb/%Eu
  '';

  chatmailConf = ''
    [params]

    # mail domain (MUST be set to fully qualified chat mail domain)
    mail_domain = ${chatmailDomain}

    #
    # Account Restrictions
    #

    # how many mails a user can send out per minute
    max_user_send_per_minute = 60

    # maximum mailbox size of a chatmail account
    max_mailbox_size = 100M

    # days after which mails are unconditionally deleted
    delete_mails_after = 40

    username_min_length = ${toString cfg.usernameMinLength}
    username_max_length = ${toString cfg.usernameMaxLength}
    password_min_length = ${toString cfg.passwordMinLength}

    # list of chatmail accounts which can send outbound un-encrypted mail
    passthrough_senders =

    # list of e-mail recipients for which to accept outbound un-encrypted mails
    passthrough_recipients = privacy@testrun.org xstore@testrun.org groupsbot@hispanilandia.net

    filtermail_smtp_port = ${toString cfg.filtermailSmtpPort}
    postfix_reinject_port = ${toString cfg.postfixReinjectPort}
  '';
in
{
  options.services.chatmail = {
    enable = mkEnableOption "chatmail";
    configFile = mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = mdDoc "chatmail.ini configuration file";
      apply = v:
        if v != null then v else pkgs.writeText "chatmail.ini" chatmailConf;
    };
    usernameMinLength = mkOption {
      type = lib.types.int;
      default = 9;
      description = mdDoc "Minimum length a username must have";
    };
    usernameMaxLength = mkOption {
      type = lib.types.int;
      default = 9;
      description = mdDoc "Maximum length a username can have";
    };
    passwordMinLength = mkOption {
      type = lib.types.int;
      default = 9;
      description = mdDoc "Minimum length a password must have";
    };
    filtermailSmtpPort = mkOption {
      type = lib.types.port;
      default = 10080;
      description = mdDoc "Where the filtermail SMTP service listens";
    };
    postfixReinjectPort = mkOption {
      type = lib.types.port;
      default = 10025;
      description =
        mdDoc "Postfix accepts on the localhost reinject SMTP port";
    };
  };

  config = mkIf cfg.enable {
    environment.etc."chatmail/chatmail.ini".source = cfg.configFile;
    environment.etc."chatmail/dovecot/auth.conf".source = dovecotAuthConf;

    services.dovecot2 = {
      enable = true;
      enablePop3 = false;
      enableImap = true;
      enableLmtp = true;

      mailUser = "vmail";
      mailGroup = "vmail";

      extraConfig = ''
        auth_verbose = yes
        auth_debug = yes
        auth_debug_passwords = yes
        auth_verbose_passwords = plain
        mail_debug = yes

        auth_cache_size = 100M

        mail_server_admin = mailto:root@${chatmailDomain}

        # these are the capabilities Delta Chat cares about actually
        # so let's keep the network overhead per login small
        # https://github.com/deltachat/deltachat-core-rust/blob/master/src/imap/capabilities.rs
        imap_capability = IMAP4rev1 IDLE MOVE QUOTA CONDSTORE NOTIFY METADATA


        # Authentication for system users.
        passdb {
          driver = dict
          args = ${dovecotAuthConf}
        }
        userdb {
          driver = dict
          args = ${dovecotAuthConf}
        }

        ##
        ## Mailbox locations and namespaces
        ##

        # Mailboxes are stored in the "mail" directory of the vmail user home.
        mail_location = maildir:/home/vmail/mail/%d/%u

        namespace inbox {
          inbox = yes

          mailbox Drafts {
            special_use = \Drafts
          }
          mailbox Junk {
            special_use = \Junk
          }
          mailbox Trash {
            special_use = \Trash
          }

          # For \Sent mailboxes there are two widely used names. We'll mark both of
          # them as \Sent. User typically deletes one of them if duplicates are created.
          mailbox Sent {
            special_use = \Sent
          }
          mailbox "Sent Messages" {
            special_use = \Sent
          }
        }

        service lmtp {
          user = ${config.services.dovecot2.mailUser}

          unix_listener dovecot-lmtp {
            group = ${config.services.postfix.group}
            mode = 0600
            user = ${config.services.postfix.user}
          }
        }

        service auth {
          unix_listener auth {
            mode = 0660
            user = ${config.services.postfix.user}
            group = ${config.services.postfix.group}
          }
        }

        service auth-worker {
          # Default is root.
          # Drop privileges we don't need.
          user = ${config.services.dovecot2.mailUser}
        }

        service imap-login {
          # High-security mode.
          # Each process serves a single connection and exits afterwards.
          # This is the default, but we set it explicitly to be sure.
          # See <https://doc.dovecot.org/admin_manual/login_processes/#high-security-mode> for details.
          service_count = 1

          # Inrease the number of simultaneous connections.
          #
          # As of Dovecot 2.3.19.1 the default is 100 processes.
          # Combined with `service_count = 1` it means only 100 connections
          # can be handled simultaneously.
          process_limit = 10000

          # Avoid startup latency for new connections.
          process_min_avail = 10
        }

        ssl = required
        ssl_min_protocol = TLSv1.2
        ssl_prefer_server_ciphers = yes
      '';

      sslServerCert = config.security.acme.certs."${chatmailDomain}".directory
        + "/full.pem";
      sslServerKey = config.security.acme.certs."${chatmailDomain}".directory
        + "/key.pem";

      enablePAM = false;
    };

    services.postfix = {
      enable = true;

      sslCert = config.security.acme.certs."${chatmailDomain}".directory
        + "/full.pem";
      sslKey = config.security.acme.certs."${chatmailDomain}".directory
        + "/key.pem";

      enableSubmission = true;
      enableSubmissions = true;

      config = {
        # maixmum 30MB sized messages
        message_size_limit = "31457280";
      };
    };

    systemd.services = {
      filtermail = {
        description = "Chatmail Postfix BeforeQueue filter";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.chatmaild}/bin/filtermail ${cfg.configFile}";
          Restart = "always";
          RestartSec = 30;
        };
      };

      doveauth = {
        description = "Chatmail dict authentication proxy for Dovecot";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          ExecStart =
            "${pkgs.chatmaild}/bin/doveauth /run/doveauth.socket vmail /var/lib/chatmail/passdb.sqlite ${cfg.configFile}";
          Restart = "always";
          RestartSec = 30;
          StateDirectory = "chatmail";
          StateDirectoryMode = "0750";
        };
      };
    };
  };
}
