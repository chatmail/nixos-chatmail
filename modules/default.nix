{ config, lib, pkgs, ... }:
let
  inherit (lib)
    mdDoc
    mkEnableOption
    mkIf
    mkOption;

  chatmailDomain = config.networking.fqdn;
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

  submissionHeaderCleanup = pkgs.writeText "submission_header_cleanup" ''
    /^Received:/            IGNORE
    /^X-Originating-IP:/    IGNORE
    /^X-Mailer:/            IGNORE
    /^User-Agent:/          IGNORE
  '';

  mtaStsDaemonConf = pkgs.writeText "mta-sts-daemon.yml" ''
    host: 127.0.0.1
    port: ${toString cfg.mtaStsPort}
    reuse_port: true
    shutdown_timeout: 20
    cache:
      type: internal
      options:
        cache_size: 10000
    proactive_policy_fetching:
      enabled: true
    default_zone:
      strict_testing: false
      timeout: 4
  '';

  postfixLoginMap = pkgs.writeText "login_map" ''
    /^(.*)$/        ''${1}
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
    mtaStsPort = mkOption {
      type = lib.types.port;
      default = 8461;
      description =
        mdDoc "MTA-STS daemon port";
    };
  };

  config = mkIf cfg.enable {
    environment.etc."chatmail/chatmail.ini".source = cfg.configFile;
    environment.etc."chatmail/dovecot/auth.conf".source = dovecotAuthConf;
    environment.etc."mta-sts-daemon.yml".source = mtaStsDaemonConf;
    environment.etc."opendkim.conf".source = config.services.opendkim.configFile;

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
          unix_listener /var/lib/postfix/queue/private/auth {
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

      extraConfig = ''
        myorigin = ${chatmailDomain}

        smtpd_banner = $myhostname ESMTP $mail_name (Chatmail)
        biff = no

        # appending .domain is the MUA's job.
        append_dot_mydomain = no

        # Uncomment the next line to generate "delayed mail" warnings
        #delay_warning_time = 4h

        readme_directory = no

        #smtp_tls_CApath=/etc/ssl/certs
        #smtp_tls_session_cache_database = btree:''${data_directory}/smtp_scache
        smtp_tls_policy_maps = socketmap:inet:127.0.0.1:${toString cfg.mtaStsPort}:postfix
        smtpd_tls_protocols = >=TLSv1.2

        # Disable anonymous cipher suites
        # and known insecure algorithms.
        #
        # Disabling anonymous ciphers
        # does not generally improve security
        # because clients that want to verify certificate
        # will not select them anyway,
        # but makes cipher suite list shorter and security scanners happy.
        # See <https://www.postfix.org/TLS_README.html> for discussion.
        #
        # Only ancient insecure ciphers should be disabled here
        # as MTA clients that do not support more secure cipher
        # likely do not support MTA-STS either and will
        # otherwise fall back to using plaintext connection.
        smtpd_tls_exclude_ciphers = aNULL, RC4, MD5, DES

        # Override client's preference order.
        # <https://www.postfix.org/postconf.5.html#tls_preempt_cipherlist>
        #
        # This is mostly to ensure cipher suites with forward secrecy
        # are preferred over non cipher suites without forward secrecy.
        # See <https://www.postfix.org/FORWARD_SECRECY_README.html#server_fs>.
        tls_preempt_cipherlist = yes

        smtpd_relay_restrictions = permit_mynetworks permit_sasl_authenticated defer_unauth_destination
        myhostname = ${chatmailDomain}
        alias_maps = hash:/etc/aliases
        alias_database = hash:/etc/aliases

        # Postfix does not deliver mail for any domain by itself.
        # Primary domain is listed in `virtual_mailbox_domains` instead
        # and handed over to Dovecot.
        mydestination =

        relayhost =
        mynetworks = 127.0.0.0/8 [::ffff:127.0.0.0]/104 [::1]/128
        mailbox_size_limit = 0
        # maximum 30MB sized messages
        message_size_limit = 31457280
        recipient_delimiter = +
        inet_interfaces = all
        inet_protocols = all

        #virtual_transport = lmtp:unix:private/dovecot-lmtp
        virtual_transport = lmtp:unix:/run/dovecot2/dovecot-lmtp
        virtual_mailbox_domains = ${chatmailDomain}

        mua_client_restrictions = permit_sasl_authenticated, reject
        mua_sender_restrictions = reject_sender_login_mismatch, permit_sasl_authenticated, reject
        mua_helo_restrictions = permit_mynetworks, reject_invalid_helo_hostname, reject_non_fqdn_helo_hostname, permit

        # 1:1 map MAIL FROM to SASL login name.
        smtpd_sender_login_maps = regexp:${postfixLoginMap}
      '';

      masterConfig = {
        submission = {
          args = [
            "-o"
            "syslog_name=postfix/submission"
            "-o"
            "smtpd_tls_security_level=encrypt"
            "-o"
            "smtpd_sasl_auth_enable=yes"
            "-o"
            "smtpd_sasl_type=dovecot"
            "-o"
            "smtpd_sasl_path=private/auth"
            "-o"
            "smtpd_reject_unlisted_recipient=no"
            "-o"
            "smtpd_client_restrictions=$mua_client_restrictions"
            "-o"
            "smtpd_helo_restrictions=$mua_helo_restrictions"
            "-o"
            "smtpd_sender_restrictions=$mua_sender_restrictions"
            "-o"
            "smtpd_recipient_restrictions="
            "-o"
            "smtpd_relay_restrictions=permit_sasl_authenticated,reject"
            "-o"
            "milter_macro_daemon_name=ORIGINATING"
            "-o"
            "smtpd_client_connection_limit=1000"
            "-o"
            "smtpd_proxy_filter=127.0.0.1:${toString cfg.filtermailSmtpPort}"
            "-o"
            "cleanup_service_name=authclean"
          ];
        };

        smtps = {
          args = [
            "-o"
            "syslog_name=postfix/smtps"
            "-o"
            "smtpd_tls_wrappermode=yes"
            "-o"
            "smtpd_tls_security_level=encrypt"
            "-o"
            "smtpd_sasl_auth_enable=yes"
            "-o"
            "smtpd_sasl_type=dovecot"
            "-o"
            "smtpd_sasl_path=private/auth"
            "-o"
            "smtpd_reject_unlisted_recipient=no"
            "-o"
            "smtpd_client_restrictions=$mua_client_restrictions"
            "-o"
            "smtpd_helo_restrictions=$mua_helo_restrictions"
            "-o"
            "smtpd_sender_restrictions=$mua_sender_restrictions"
            "-o"
            "smtpd_recipient_restrictions="
            "-o"
            "smtpd_relay_restrictions=permit_sasl_authenticated,reject"
            "-o"
            "milter_macro_daemon_name=ORIGINATING"
            "-o"
            "smtpd_client_connection_limit=1000"
            "-o"
            "smtpd_proxy_filter=127.0.0.1:${toString cfg.filtermailSmtpPort}"
            "-o"
            "cleanup_service_name=authclean"
          ];
        };
      };
      extraMasterConf = ''
        # Local SMTP server for reinjecting filered mail.
        localhost:${toString cfg.postfixReinjectPort} inet  n       -       n       -       10      smtpd
          -o syslog_name=postfix/reinject
          -o smtpd_milters=unix:/run/opendkim/opendkim.sock
          -o cleanup_service_name=authclean

        # Cleanup `Received` headers for authenticated mail
        # to avoid leaking client IP.
        #
        # We do not do this for received mails
        # as this will break DKIM signatures
        # if `Received` header is signed.
        authclean unix  n       -       -       -       0       cleanup
          -o header_checks=regexp:${submissionHeaderCleanup}
      '';
    };

    services.opendkim =
      let
        selector = "dkim";
        screenPolicyScript = pkgs.writeTextFile {
          name = "screen.lua";
          text = builtins.readFile ./screen.lua;
        };
        finalPolicyScript = pkgs.writeTextFile {
          name = "final.lua";
          text = builtins.readFile ./final.lua;
        };
        keyPath = "/var/lib/opendkim/keys";
        keyFile = "${keyPath}/${selector}.private";
        signingTable = pkgs.writeText "SigningTable" ''
          *@${ config.networking.fqdn } ${selector}._domainkey.${ config.networking.fqdn }
        '';
        keyTable = pkgs.writeText "KeyTable" ''
          ${ selector }._domainkey.${config.networking.fqdn} ${config.networking.fqdn}:${selector}:${keyFile}
        '';
      in
      {
        enable = true;
        inherit selector keyPath;
        configFile = pkgs.writeText "opendkim.conf" ''
          Syslog         yes
          SyslogSuccess  yes

          Canonicalization relaxed/simple
          OversignHeaders  From

          On-BadSignature  reject
          On-KeyNotFound   reject
          On-NoSignature   reject

          Domain          ${ config.networking.fqdn }
          Selector        ${ selector }
          KeyFile         ${ keyFile }
          KeyTable        ${ keyTable }
          SigningTable refile:${ signingTable }

          # Sign Autocrypt header in addition to the default specified in RFC 6376
          SignHeaders *,+autocrypt

          # Script to ignore signatures that do not correspond to the From: domain.
          ScreenPolicyScript ${screenPolicyScript}

          # Script to reject mails without a valid DKIM signature.
          FinalPolicyScript ${finalPolicyScript}

          # Set umask so postfix user can access unix socket from opendkim group.
          UMask 0007

          Socket ${ config.services.opendkim.socket }
        '';
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

      mta-sts-daemon = {
        description = "Postfix MTA-STS resolver daemon";
        wantedBy = [ "multi-user.target" ];
        after = [ "network.target" ];
        serviceConfig = {
          ExecStart = "${pkgs.postfix-mta-sts-resolver}/bin/mta-sts-daemon";
          Restart = "always";
          RestartSec = 30;
        };
      };

      opendkim = {
        serviceConfig = {
          # Remove all command line flags except for:
          # -f for running in foregorund instead of daemonizing
          # -l for logging
          # -x for configuration file
          ExecStart = lib.mkForce "${pkgs.opendkim}/bin/opendkim -f -l -x ${config.services.opendkim.configFile}";
        };
      };
    };

    users.users = {
      "vmail" = lib.mkForce {
        name = "vmail";
        isSystemUser = true;
        home = "/home/vmail";
        createHome = true;
        group = "vmail";
      };

      # Add postfix to opendkim group so it can access milter socket.
      postfix.extraGroups = [ config.services.opendkim.group ];
    };

  };
}
