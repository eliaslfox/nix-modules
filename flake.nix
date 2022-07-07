{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }: {
    nixosModules = rec {
      nix-modules = import ./default.nix;
      default = nix-modules;
    };

    home-manager = import ./home-manager;
  };
}
