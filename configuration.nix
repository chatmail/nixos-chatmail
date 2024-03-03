{ pkgs, config, ... }: {
  imports = [
    ./hardware-configuration.nix
    ./networking.nix # generated at runtime by nixos-infect
    ./chatmail.nix
  ];

  boot.tmp.cleanOnBoot = true;
  zramSwap.enable = true;
  networking.hostName = "c-nixos";
  networking.domain = "";
  services.openssh.enable = true;
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDK/nhFqOwbJxbZ4WNtUkSidovG9av/yQHv7GLIqu6Jbd+ZtDYlCoYhb0lqJgijoJGOK6mwk+1/FCgD0sjuBgs78kzGGa5X6OFB55+re8zFzK81q+uCWW5UOUT5PkGpMzDVfy/Atodo1vYrpB7Vt2pXRqtErpCutLOGLT3VxADVPoGwbd+vN3g+duh/RTbMp5zkpy7B0cqmVLTd0ZTaZlnzsq+RaeQzfuIbdG5VupTmB0smJZa8kVtCjYp6V2aFErHONE2WJydwfr5MV0nbA/4rpoxt0MY0BQ7W8nixuSbjbIxkNJR002bILTOIfXBj7uLmHKw4kc2nerB42mV+Cbdd hpk"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKZYJ91RLXRCQ4ZmdW6ucIltzukQ/k+lDOqlRIYwxNRv missytake"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINm82t7AZ2yOuOM3SezqWz7k8ydiaRoCzEUfWMZPrCTV link2xt"
  ];
  system.stateVersion = "23.11";

  nixpkgs.overlays = [
    (final: prev:

      {
        chatmaild = prev.python3Packages.buildPythonPackage rec {
          name = "chatmaild";
          version = "0-unstable-2024-03-03";
          src = prev.fetchFromGitHub {
            owner = "deltachat";
            repo = "chatmail";
            rev = "14342383cf6294241e49576b404a4606c11c8e34";
            sha256 = "sha256-ceC7J+qEyxsdUKrfb+/D6wz6g+Yw7tYH+KrLJdOZEVw=";
          };
          sourceRoot = "${src.name}/chatmaild";
          format = "pyproject";
          propagatedBuildInputs = [
            prev.python3Packages.setuptools
            prev.python3Packages.aiosmtpd
            prev.python3Packages.iniconfig
            prev.python3Packages.requests
            # Also deltachat-rpc-client and deltachat-rpc-server for echobot
          ];
        };
      })
  ];

  environment.systemPackages = with pkgs; [
    vim
    htop
    chatmaild
  ];

  security.acme.acceptTerms = true;
  security.acme.defaults.email = "root@c-nixos.testrun.org";

  services.nginx = {
    enable = true;
    virtualHosts = {
      "c-nixos.testrun.org" = {
        forceSSL = true;
        enableACME = true;
      };
    };
  };

  networking.firewall.allowedTCPPorts = [
    25 # SMTP
    80 # HTTP
    443 # HTTPS
    587 # submission
    465 # submissions
    143 # IMAP
    993 # IMAPS
  ];

  services.chatmail = {
    enable = true;
    passwordMinLength = 10;
  };

  services.postfix = {
    enable = true;

    sslCert = config.security.acme.certs."c-nixos.testrun.org".directory
      + "/full.pem";
    sslKey = config.security.acme.certs."c-nixos.testrun.org".directory
      + "/key.pem";

    enableSubmission = true;
    enableSubmissions = true;

    config = {
      # maixmum 30MB sized messages
      message_size_limit = "31457280";
    };
  };

  services.dovecot2 = {
    enable = true;
    enableImap = true;
    enablePop3 = false;

    mailUser = "vmail";
    mailGroup = "vmail";
  };
}
