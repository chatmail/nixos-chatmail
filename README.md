# Building

1. Install [nixos-rebuild](https://nixos.wiki/wiki/Nixos-rebuild): `nix profile install nixpkgs#nixos-rebuild`
2. Run `./install.sh`

# Files

- `hardware-configuration.nix`: hardware configuration generated by `nixos-infect`
- `networking.nix`: network configuration generated by `nixos-infect`
- `configuration.nix`: NixOS system configuration
- `modules/default.nix`: NixOS chatmail module
