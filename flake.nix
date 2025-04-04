{
  description = "My NixOS infrastructure";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixos-hardware.url = "github:NixOS/nixos-hardware/master";

    #link = {
    #  url = "github:alinkbetweennets/nix";
    #  inputs = {
    #    nixpkgs.follows = "nixpkgs";
    #    home-manager.follows = "home-manager";
    #  };
    #};

    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # used for `nix run .#build-outputs`
    mayniklas = {
      url = "github:MayNiklas/nixos";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        nixos-hardware.follows = "nixos-hardware";
      };
    };

    # used to get current mensa meals
    bonn-mensa = {
      url = "github:alexanderwallau/bonn-mensa";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };

    # used to check if programs have updates available
    simple-update-checker = {
      url = "github:lmh01/simple_update_checker";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };

    ### Tools for managing NixOS

    # lollypops deployment tool
    # https://github.com/pinpox/lollypops
    lollypops = {
      url = "github:pinpox/lollypops";
      inputs = { nixpkgs.follows = "nixpkgs"; };
    };

    # Adblocking lists for DNS servers
    # input here, so it will get updated by nix flake update
    adblockStevenBlack = {
      url = "github:StevenBlack/hosts";
      flake = false;
    };

    # Adblocking lists for Unbound DNS servers running on NixOS
    # https://github.com/MayNiklas/nixos-adblock-unbound
    adblock-unbound = {
      url = "github:MayNiklas/nixos-adblock-unbound";
      inputs = {
        adblockStevenBlack.follows = "adblockStevenBlack";
        nixpkgs.follows = "nixpkgs";
      };
    };

    disko = {
      url = "github:nix-community/disko";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    raspberry-pi-nix.url = "github:nix-community/raspberry-pi-nix";

  };

  outputs = { self, sops-nix, ... }@inputs:
    with inputs;
    let
      supportedSystems = [ "aarch64-linux" "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlays.default ]; });
    in
    {

      formatter = forAllSystems
        (system: nixpkgsFor.${system}.nixpkgs-fmt);

      overlays.default = final: prev:
        (import ./pkgs inputs) final prev;

      packages = forAllSystems
        (system:
          let
            pkgs = nixpkgsFor.${system};
          in
          {
            woodpecker-pipeline = pkgs.callPackage ./pkgs/woodpecker-pipeline {
              flake-self = self;
              inputs = inputs;
            };
            build_outputs =
              pkgs.callPackage mayniklas.packages.${system}.build_outputs.override {
                inherit self;
                output_path = "~/.keep-nix-outputs-LMH01";
              };
            inherit (nixpkgsFor.${system}.lmh01)
              candy-icon-theme
              alpha_tui;

          }
          //
          builtins.listToAttrs
            (
              map
                (x: {
                  name = "${x}-image-zip";
                  value = pkgs.stdenv.mkDerivation {
                    name = "${x}-image-zip";
                    src = self.nixosConfigurations.${x}.config.system.build.sdImage;
                    buildCommand = ''
                      name=$(basename $src/sd-image/*)
                      mkdir -p $out
                      ln -s $src/sd-image/$name $out/
                      ${pkgs.zip}/bin/zip $out/$name.zip $src/sd-image/$name
                    '';
                  };
                })
                (builtins.filter (x: x == "pi4b" || x == "pi5") (builtins.attrNames self.nixosConfigurations))
            )
          //
          builtins.listToAttrs
            (
              map
                (x: {
                  name = "${x}-image";
                  value = self.nixosConfigurations.${x}.config.system.build.sdImage;
                })
                (builtins.filter (x: x == "pi4b" || x == "pi5") (builtins.attrNames self.nixosConfigurations))
            )
        );


      apps = forAllSystems (system: {
        lollypops = lollypops.apps.${system}.default {
          configFlake = self;
        };
      });

      # Output all modules in ./modules to flake. Modules should be in
      # individual subdirectories and contain a default.nix file
      nixosModules = builtins.listToAttrs (map
        (x: {
          name = x;
          value = import (./modules + "/${x}");
        })
        (builtins.attrNames (builtins.readDir ./modules)));

      # Each subdirectory in ./machines is a host. Add them all to
      # nixosConfiguratons. Host configurations need a file called
      # configuration.nix that will be read first
      nixosConfigurations = builtins.listToAttrs (
        map
          (
            x:
            let
              name = (builtins.replaceStrings [ ".nix" ] [ "" ] x);
            in
            {
              inherit name;
              value = nixpkgs.lib.nixosSystem {

                # Make inputs and the flake itself accessible as module parameters.
                # Technically, adding the inputs is redundant as they can be also
                # accessed with flake-self.inputs.X, but adding them individually
                # allows to only pass what is needed to each module.
                specialArgs = { flake-self = self; } // inputs;

                modules = [
                  lollypops.nixosModules.lollypops
                  disko.nixosModules.disko
                  (import "${./.}/machines/${x}/configuration.nix" { inherit self; })
                  self.nixosModules.options
                  sops-nix.nixosModules.sops
                  #raspberry-pi-nix.nixosModules.raspberry-pi
                  #raspberry-pi-nix.nixosModules.sd-image
                ];

              };
            }
          )
          (builtins.attrNames (builtins.readDir ./machines)));

      homeConfigurations = {
        portable = { pkgs, lib, ... }: {
          imports = [
            ./home-manager/profiles/common.nix
            ./home-manager/profiles/gui_common.nix
            ./home-manager/profiles/portable.nix
          ];
        };
        CBPC-0123_LMH = { pkgs, lib, ... }: {
          imports = [
            ./home-manager/profiles/common.nix
            ./home-manager/profiles/gui_common.nix
            ./home-manager/profiles/desktop.nix
          ];
        };
        Dell22_LMH = { pkgs, lib, ... }: {
          imports = [
            ./home-manager/profiles/common.nix
            ./home-manager/profiles/gui_common.nix
            ./home-manager/profiles/laptop.nix
          ];
        };
        server = { pkgs, lib, ... }: {
          imports = [
            ./home-manager/profiles/common.nix
            ./home-manager/profiles/server.nix
          ];
        };
      };

      homeManagerModules = builtins.listToAttrs (map
        (name: {
          inherit name;
          value = import (./home-manager/modules + "/${name}");
        })
        (builtins.attrNames (builtins.readDir ./home-manager/modules)));

    };
}
