{
  description = "A simple NixOS flake";

  inputs = {
    # NixOS official package source, here using the nixos-23.11 branch
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-23.11";
  };

  # The `self` parameter is special, it refers to
  # the attribute set returned by the `outputs` function itself.
  outputs = { self, nixpkgs, ... }@inputs: {
    formatter.x86_64-linux = nixpkgs.legacyPackages.x86_64-linux.nixpkgs-fmt;

    # The host with the hostname `my-nixos` will use this configuration
    nixosConfigurations.c-nixos = nixpkgs.lib.nixosSystem {
      system = "aarch64-linux";
      modules = [
        ./configuration.nix
      ];
    };

    nixosModules.default = import ./modules/default.nix;
    overlays.default = import ./overlay.nix;

    packages.x86_64-linux.default =
      let
        pkgs = nixpkgs.legacyPackages.x86_64-linux;
        install-script = pkgs.writeShellScriptBin "install.sh" (builtins.readFile ./install.sh);
      in
      pkgs.symlinkJoin {
        name = "install.sh";
        paths = [ install-script pkgs.nixos-rebuild ];
        buildInputs = [ pkgs.makeWrapper ];
        postBuild = "wrapProgram $out/bin/install.sh --prefix PATH : $out/bin";
      };
  };
}
