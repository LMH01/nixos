# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ self, ... }:
{ pkgs, lib, config, flake-self, home-manager, ... }:
{
  imports = [
    ./hardware-configuration.nix
    home-manager.nixosModules.home-manager
    
    # this machine is a laptop,
    # import type specific modules
    self.nixosModules.laptop

    # my own modules
    self.nixosModules.locale
    self.nixosModules.nvidia
  ];

  # Home Manager configuration
  home-manager = {
    # DON'T set useGlobalPackages! It's not necessary in newer
    # home-manager versions and does not work with configs using
    # nixpkgs.config
    useUserPackages = true;
    extraSpecialArgs = {
      inherit flake-self;
      # Pass system configuration (top-level "config") to home-manager modules,
      # so we can access it's values for conditional statements
      system-config = config;
    };
    users.louis = flake-self.homeConfigurations.portable;
  };

  # being able to build aarm64 stuff
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];

  # Bootloader.
  boot.loader.systemd-boot = {
    enable = true;
    configurationLimit = 5;
  };
  boot.loader.efi.canTouchEfiVariables = true;

  # Kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Enable ntfs support
  boot.supportedFilesystems = [ "ntfs" ];

  networking.hostName = "nixos_portable";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  services.xserver.videoDrivers = [ "amdgpu" ];

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment. - does not work when booth amd and nvidia drivers are installed on stable branch
  #services.displayManager.sddm.enable = true;
  services.xserver.desktopManager.plasma6.enable = true;

  # Enable the Gnome Desktop Environment - works with booth amd and nvidia drivers installed on stable branch
  services.xserver.displayManager.gdm.enable = true; #is used instead of sddm because sddm is not displayed when nvidia and amd drivers are installed on an nvidia system
  #services.xserver.desktopManager.gnome.enable = true;

  # Enable CUPS to print documents.
  services.printing.enable = true;

  # Enable sound with pipewire.
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    # If you want to use JACK applications, uncomment this
    #jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    #media-session.enable = true;
  };

  # Enable teamviewer service (temporary)
  services.teamviewer.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    neovim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
    #(pkgs.callPackage ./candy-icon-theme {})
  ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  # programs.gnupg.agent = {
  #   enable = true;
  #   enableSSHSupport = true;
  # };

  # List services that you want to enable:

  # Enable the OpenSSH daemon.
  # services.openssh.enable = true;

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  # networking.firewall.enable = false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

}
