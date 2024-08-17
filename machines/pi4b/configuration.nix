# nix run .\#lollypops -- pi4b
{ self, ... }:
{ pkgs, lib, config, modulesPath, flake-self, home-manager, nixos-hardware, nixpkgs, ... }: {

  imports = [
    # being able to build the sd-image
    "${modulesPath}/installer/sd-card/sd-image-aarch64.nix"

    # https://github.com/NixOS/nixos-hardware/tree/master/raspberry-pi/4
    nixos-hardware.nixosModules.raspberry-pi-4

    home-manager.nixosModules.home-manager

    self.nixosModules.gitea
    self.nixosModules.server
    self.nixosModules.jellyfin
    self.nixosModules.restic
    self.nixosModules.wireguard
    self.nixosModules.woodpecker
  ];

  ### build sd-image

  # nix build .\#nixosConfigurations.pi4b.config.system.build.sdImage
  # add boot.binfmt.emulatedSystems = [ "aarch64-linux" ]; to your x86 system
  # to build ARM stuff through qemu
  sdImage.compressImage = false;
  sdImage.imageBaseName = "raspi-image";

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
    gitea = {
      enable = true;
      domain = "pi4b-louis.fritz.box";
    };
    jellyfin.enable = true;
    options.type = "server";
    restic-client = {
      enable = true;
      backup-paths-lb = [
        "/home/louis/.secrets"
        "/home/louis/.ssh"
        "/home/louis/Obsidian"
      ];
      backup-paths-sn = [
        "/home/louis/.secrets"
        "/home/louis/.ssh"
        "/home/louis/Obsidian"
        "/mnt/nas_multimedia/Imagedata/Digital/OwnPics" # will only be backed up, when the drive is mounted manually
      ];
    };
    wireguard.enable = true;
    # disabled until I have time to properly get it running
    # (problems with git clone)
    #woodpecker = {
    #  enable = true;
    #  domain = "192.168.188.124";
    #};
  };

  # additional restic backups, used just on this system
  services.restic.backups =
    let
      backup-timer = {
        OnCalendar = "01:00";
        Persistent = true;
        RandomizedDelaySec = "4h";
      };
    in
    {
      # Home assistant and gitea are backuped to two locations.
      # If either service is backed up, the data will be backuped to booth locations, by starting the backup to 
      # the second location when backup to the first location is done.
      # The check stage is thus disabled for the backup to the first location to not block exection of the second
      # backup when the repo is locked.
      # To make sure that booth repos are checked after a backup run is completed, the check stage for the second
      # backup is executed normally. The second backup target is different in booth backups to make sure that booth
      # locations are checked.
      home_assistant-sn =
        {
          paths = [ "/home/louis/HomeAssistant" ];
          repositoryFile = "${config.lmh01.secrets}/restic/sn/repository";
          passwordFile = "${config.lmh01.secrets}/restic/sn/password";
          environmentFile = "${config.lmh01.secrets}/restic/sn/environment";
          # stop home assistant before backup
          backupPrepareCommand = ''
            echo "Shutting down Home Assistant to perform backup"
            ${pkgs.docker}/bin/docker stop homeassistant
          '';
          # as homeassistant should also be backuped to another location,
          # and it is already down we are staring the other backup now
          backupCleanupCommand = ''
            systemctl start restic-backups-home_assistant-lb
          '';
          pruneOpts = [
            "--keep-daily 7"
            "--keep-weekly 5"
            "--keep-monthly 12"
            "--keep-yearly 75"
          ];
          # on check phase dont lock repo, to make check not fail if other backup is currenlty running
          # and that backup to other location is executed
          checkOpts = [
            "--no-lock"
          ];
          timerConfig = backup-timer;
          # retry-lock is disabled for this backup, so that home assistant isn't down for too long
          extraBackupArgs = [
            "--one-file-system"
            "-v"
          ];
          initialize = true;
        };
      gitea-lb = {
        paths = [ "/var/lib/storage/gitea" ];
        repositoryFile = "${config.lmh01.secrets}/restic/lb/repository";
        passwordFile = "${config.lmh01.secrets}/restic/lb/password";
        # stop gitea before backup
        backupPrepareCommand = ''
          echo "Shutting down gitea to perform backup"
          systemctl stop gitea
        '';
        # as gitea should also be backuped to another location,
        # and it is already down we are staring the other backup now
        backupCleanupCommand = ''
          systemctl start restic-backups-gitea-sn
        '';
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 5"
          "--keep-monthly 12"
          "--keep-yearly 75"
        ];
        # on check phase dont lock repo, to make check not fail if other backup is currenlty running
        # and that backup to other location is executed
        checkOpts = [
          "--no-lock"
        ];
        # disable auto start because this backup is only started when gitea-sn is done
        timerConfig = backup-timer;
        # retry-lock is disabled for this backup, so that home assistant isn't down for too long
        extraBackupArgs = [
          "--one-file-system"
          "-v"
        ];
        initialize = true;
      };
      home_assistant-lb = {
        paths = [ "/home/louis/HomeAssistant" ];
        repositoryFile = "${config.lmh01.secrets}/restic/lb/repository";
        passwordFile = "${config.lmh01.secrets}/restic/lb/password";
        # start home assistant after backup is complete
        backupCleanupCommand = ''
          echo "Starting Home Assistant"
          ${pkgs.docker}/bin/docker start homeassistant
        '';
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 5"
          "--keep-monthly 12"
          "--keep-yearly 75"
        ];
        # disable auto start because this backup is only started when home_assistant-sn is done
        timerConfig = null;
        # retry-lock is disabled for this backup, so that home assistant isn't down for too long
        extraBackupArgs = [
          "--one-file-system"
          "-v"
        ];
        initialize = true;
      };
      gitea-sn = {
        paths = [ "/var/lib/storage/gitea" ];
        repositoryFile = "${config.lmh01.secrets}/restic/sn/repository";
        passwordFile = "${config.lmh01.secrets}/restic/sn/password";
        environmentFile = "${config.lmh01.secrets}/restic/sn/environment";
        # start gitea after backup is complete
        backupCleanupCommand = ''
          echo "Starting gitea"
          systemctl start gitea
        '';
        pruneOpts = [
          "--keep-daily 7"
          "--keep-weekly 5"
          "--keep-monthly 12"
          "--keep-yearly 75"
        ];
        timerConfig = null;
        # retry-lock is disabled for this backup, so that home assistant isn't down for too long
        extraBackupArgs = [
          "--one-file-system"
          "-v"
        ];
        initialize = true;
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
      # so we can access it's values for conditional statements
      system-config = config;
    };
    users.louis = flake-self.homeConfigurations.server;
  };

  hardware.raspberry-pi."4".poe-hat.enable = true;
  networking.hostName = "pi4b-louis";

  networking.networkmanager.enable = true;

  networking.firewall.allowedTCPPorts = [
    8123 # used by home assistant
  ];

  lollypops.deployment = {
    local-evaluation = true;
    # ssh = { user = "root"; host = "<IP>"; };
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  system.stateVersion = "23.05";
}
