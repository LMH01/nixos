{
  description = "My NixOS infrastructure";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = github:nix-community/home-manager;
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self,  ... }@inputs:
  let
    system = "x86_64-linux";
  in
  with inputs;
  {
    nixosConfigurations = {
      nixos_portable = nixpkgs.lib.nixosSystem {
        inherit system;
        modules = [
          ./base_configuration.nix
	  ./machines/nixos_portable/hardware-configuration.nix
          home-manager.nixosModules.home-manager
          {
            home-manager = {
              useUserPackages = true;
              useGlobalPkgs = true;
              users.louis = ./home-manager/profiles/portable.nix;
            };
          }
        ];
      };
    };
  };
}
