{ config, lib, pkgs, ... }:
let
  cfg = config.services.chatmail;
  chatmailConf = ''
    [params]

    # mail domain (MUST be set to fully qualified chat mail domain)
    mail_domain = c-nixos.testrun.org

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
in {
  options.services.chatmail = {
    enable = lib.mkEnableOption "chatmail";
    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = lib.mdDoc "chatmail.ini configuration file";
      apply = v:
        if v != null then v else pkgs.writeText "chatmail.ini" chatmailConf;
    };
    usernameMinLength = lib.mkOption {
      type = lib.types.int;
      default = 9;
      description = lib.mdDoc "Minimum length a username must have";
    };
    usernameMaxLength = lib.mkOption {
      type = lib.types.int;
      default = 9;
      description = lib.mdDoc "Maximum length a username can have";
    };
    passwordMinLength = lib.mkOption {
      type = lib.types.int;
      default = 9;
      description = lib.mdDoc "Minimum length a password must have";
    };
    filtermailSmtpPort = lib.mkOption {
      type = lib.types.port;
      default = 10080;
      description = lib.mdDoc "Where the filtermail SMTP service listens";
    };
    postfixReinjectPort = lib.mkOption {
      type = lib.types.port;
      default = 10025;
      description =
        lib.mdDoc "Postfix accepts on the localhost reinject SMTP port";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.etc."chatmail/chatmail.ini".source = cfg.configFile;

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
            "${pkgs.chatmaild}/bin/doveauth /run/dovecot2/doveauth.socket vmail /var/lib/chatmail/passdb.sqlite ${cfg.configFile}";
          Restart = "always";
          RestartSec = 30;
          StateDirectory = "chatmail";
          StateDirectoryMode = "0750";
        };
      };
    };
  };
}
