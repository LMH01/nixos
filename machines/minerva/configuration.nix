# nix run .\#lollypops -- pi4b
{ self, ... }:
{ pkgs, lib, config, modulesPath, flake-self, home-manager, nixos-hardware, nixpkgs, ... }: {

  imports = [
    ./hardware-configuration.nix
    home-manager.nixosModules.home-manager

    # this machine is a server
    self.nixosModules.server

    self.nixosModules.services
  ];

  lmh01 = {
    services = {
      nginx.enable = true;
      nginx.enable_acme = true;
      nginx.open_ports = false;
      syncthing.enable = lib.mkForce false; # syncthing is not required on this machine
    };
    domain = "home.skl2.de";
    options = {
      type = "server";
    };
  };

  # secrets
  sops.secrets = { };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "server";
  };

  # nginx reverse proxy settings
  services.nginx = {
    virtualHosts = {
      "${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://127.0.0.1:11800";
        };
      };
      "audiobookshelf.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "https://audiobookshelf.home.skl2.de";
          extraConfig = ''
            proxy_set_header    Upgrade     $http_upgrade;
            proxy_set_header    Connection  "upgrade";
          '';
        };
      };
      "jellyfin.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "https://jellyfin.home.skl2.de";
          extraConfig = ''
            proxy_set_header    Upgrade           $http_upgrade;
            proxy_set_header    Connection        "upgrade";
            proxy_set_header    X-Real-IP         $remote_addr;
            proxy_set_header    X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header    X-Forwarded-Proto $scheme; 
          '';
        };
      };
      "jellyseer.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "https://jellyseer.home.skl2.de";
        };
      };
      "music.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "https://music.home.skl2.de";
        };
      };
      "music-server.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "https://music-server.home.skl2.de";
        };
      };
      "status.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://10.0.10.9:80";
        };
      };
    };
  };

  # Home Manager configuration
  home-manager = {
    # DON'T set useGlobalPackages! It's not necessary in newer
    # home-manager versions and does not work with configs using
    # nixpkgs.config
    useUserPackages = true;
    extraSpecialArgs = {
      inherit flake-self;
      # Pass system configuration (top-level "config") to home-manager modules,
      # so we can access it's values for conditional statement
      system-config = config;
    };
    users.louis = flake-self.homeConfigurations.server;
  };

  networking.hostName = "minerva";

  networking.networkmanager.enable = true;

  system.stateVersion = "23.05";
}
