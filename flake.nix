{
  description = "My NixOS infrastructure";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = github:nix-community/home-manager;
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # https://github.com/numtide/flake-utils
    # flake-utils provides a set of utility functions for creating multi-output flakes
    # -> lets us easily define a output for different system types
    # -> could be replaced by a more manual approach
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, ... }@inputs:
    let
      system = "x86_64-linux";
    in
    with inputs;
    # this function is used to repeat the same definitions for multible architectures
    (flake-utils.lib.eachSystem (flake-utils.lib.defaultSystems))
      (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = {
              allowUnfree = true;
              allowUnsupportedSystem = true;
            };
          };
        in
        rec {
          # nix fmt .
          formatter = pkgs.nixpkgs-fmt;
        }
      )
    //
    {
      nixosConfigurations = {
        nixos_portable = nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [
            ./machines/nixos_portable/configuration.nix
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
