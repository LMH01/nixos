# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ self, ... }:
{ pkgs, lib, config, flake-self, home-manager, ... }:
{
  imports = [
    ./hardware-configuration.nix
    home-manager.nixosModules.home-manager

    # this machine is a desktop,
    # import type specific modules
    self.nixosModules.desktop

    self.nixosModules.services

    # my own modules, specific for this machine
    self.nixosModules.nvidia
    self.nixosModules.openrgb
    self.nixosModules.restic
  ];

  lmh01 = {
    #wayland.enable = true;
    services = {
      protonvpn.enable = true;
    };
    nvidia.enable = true;
    openrgb.enable = true;
    restic-client = {
      enable = true;
      # backups should be performed when the pc is started, but only once per day
      backup-timer = {
        OnBootSec = "1m"; # start time one minute after pc has been started
        # make sure that the timer only starts once per 12 hours
        # (I'm assuming here that this is enough to not fire the timer twice per day)
        OnUnitActiveSec = "12h";
        # randomize startup time that it is less likely that backups collide
        # more time is probably not needed, because changes should be pretty small
        RandomizedDelaySec = "5m";
        Persistent = true;
      };
      backup-paths-sn = [
        "/userdata/Userdata"
        "/home/louis/.ssh"
      ];
      backup-paths-lb = [
        "/userdata/Userdata/Dokumente"
        "/home/louis/.ssh"
      ];
      # unfortunately the nas drive can't be mounted automatically and sftp is not supported
      # thus this backup will mostly not work automated
      #backup-paths-home_nas = [
      #  "/userdata/Userdata"
      #];
      # commented out because drive can't be mounted automatically, I might build a workaround later
    };
  };

  services.tailscale = {
    enable = true;
    useRoutingFeatures = "client";
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
      # so we can access it's values for conditional statements
      system-config = config;
    };
    users.louis = flake-self.homeConfigurations.CBPC-0123_LMH;
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

  networking.hostName = "CBPC-0123_LMH";
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  networking.networkmanager.enable = true;

  # Enable the X11 windowing system.
  services.xserver.enable = true;

  # Enable the KDE Plasma Desktop Environment.
  services.displayManager.sddm.enable = true;
  services.desktopManager.plasma6.enable = true;

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
  #services.teamviewer.enable = true;

  # Enable flatpak (mainly for Handbrake)
  services.flatpak.enable = true;

  # Enable touchpad support (enabled default in most desktopManager).
  # services.xserver.libinput.enable = true;

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = with pkgs; [
    neovim # Do not forget to add an editor to edit configuration.nix! The Nano editor is also installed by default.
    #  wget
    #(pkgs.callPackage ./candy-icon-theme {})
  ];

  # Set hardware clock to local time to prevent time issues with windows
  time.hardwareClockInLocalTime = true;

  # specific display config for this pc
  # because of limitations in scaling the resolution of the left monitor is set to a
  # higher value then what can be displayed. This causes the offset to be 3200.
  services.xserver.displayManager.sessionCommands = ''
    xrandr --output DP-0 --mode 2560x1440 --scale 1.25x1.25 --pos 0x0
    xrandr --output DP-2 --mode 3840x2160 --pos 3200x0
  '';

  # programs that I only need on this machine
  programs.streamdeck-ui = {
    enable = true;
    autoStart = true; # optional
  };

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

  networking.firewall.checkReversePath = lib.mkForce false;

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "23.05"; # Did you read the comment?

}
