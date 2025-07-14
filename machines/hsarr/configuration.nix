# nix run .\#lollypops -- pi4b
{ self, ... }:
{ pkgs, lib, config, modulesPath, flake-self, home-manager, nixos-hardware, nixpkgs, ... }: {

  imports = [
    ./hardware-configuration.nix
    home-manager.nixosModules.home-manager

    # this machine is a server
    self.nixosModules.server

  ];

  # this workaround is currently needed to build the sd-image
  # basically: there currently is an issue that prevents the sd-image to be built successfully
  # remove this once the issue is fixed!
  nixpkgs.overlays = [
    (final: super: {
      makeModulesClosure = x:
        super.makeModulesClosure (x // { allowMissing = true; });
    })
  ];
  ###

  lmh01 = {
    options.type = "server";
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

  # Additional packages
  environment.systemPackages = with pkgs; [
    wireguard-tools
  ];

  networking.hostName = "hsarr";

  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = lib.mkForce [ ];
  networking.interfaces.ens18.ipv4.addresses = [{
    address = "10.0.10.8";
    prefixLength = 24;
  }];
  networking.defaultGateway = "10.0.10.1";
  networking.nameservers = [ "192.168.188.226" "192.168.188.1" ];

  networking.firewall.allowedTCPPorts = [ 19898 19787 ];

  networking.firewall.allowedUDPPorts = [ ];

  sops.secrets."vpn/wireguard" = { };

  networking.wg-quick.interfaces.vpn.configFile = config.sops.secrets."vpn/wireguard".path;

  system.stateVersion = "23.05";
}
