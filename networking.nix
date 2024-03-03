{ lib, ... }: {
  # This file was populated at runtime with the networking
  # details gathered from the active system.
  networking = {
    nameservers =
      [ "2a01:4ff:ff00::add:2" "2a01:4ff:ff00::add:1" "185.12.64.2" ];
    defaultGateway = "172.31.1.1";
    defaultGateway6 = {
      address = "fe80::1";
      interface = "eth0";
    };
    dhcpcd.enable = false;
    usePredictableInterfaceNames = lib.mkForce false;
    interfaces = {
      eth0 = {
        ipv4.addresses = [{
          address = "65.109.12.8";
          prefixLength = 32;
        }];
        ipv6.addresses = [
          {
            address = "2a01:4f9:c010:e292::1";
            prefixLength = 64;
          }
          {
            address = "fe80::9400:3ff:fe0f:df38";
            prefixLength = 64;
          }
        ];
        ipv4.routes = [{
          address = "172.31.1.1";
          prefixLength = 32;
        }];
        ipv6.routes = [{
          address = "fe80::1";
          prefixLength = 128;
        }];
      };

    };
  };
  services.udev.extraRules = ''
    ATTR{address}=="96:00:03:0f:df:38", NAME="eth0"

  '';
}
