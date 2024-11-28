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
    self.nixosModules.webdav
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
    webdav.enable = true;
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
      backupTimer = {
        OnCalendar = "01:00";
        Persistent = true;
        RandomizedDelaySec = "4h";
      };
      pruneOpts = [
        "--keep-daily 7"
        "--keep-weekly 5"
        "--keep-monthly 12"
        "--keep-yearly 75"
      ];
      extraBackupArgs = [
        "--one-file-system"
        "-v"
      ];
      serviceBackupPaths = [
        "/home/louis/Documents/immich"
        "/var/lib/storage/gitea"
        "/var/lib/webdav"
      ];
      # commands to run when serice backups are started
      serviceBackupPrepareCommand = ''
        docker stop immich_server
        docker stop immich_machine_learning
        docker stop immich_redis
        docker stop immich_postgres
        systemctl stop gitea
        systemctl stop webdav
      '';
      # commands to run when service backups are complete
      serviceBackupCleanupCommand = ''
        docker start immich_server
        docker start immich_machine_learning
        docker start immich_redis
        docker start immich_postgres
        systemctl start gitea
        systemctl start webdav
      '';
    in
    {
      # All Services are backed up to two locations.
      # The home assistant backup is separate from all other backups, in order to be able to start home assistant as quickly as possible again
      # The backup services-sn and services-lb is used to backup all other services running on this system.
      # Before these backups are started all affected services are shutdown until the whole backup is complete.
      home_assistant-sn = {
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
        pruneOpts = pruneOpts;
        # on check phase dont lock repo, to make check not fail if other backup is currenlty running
        # and that backup to other location is executed
        checkOpts = [
          "--no-lock"
        ];
        timerConfig = backupTimer;
        extraBackupArgs = extraBackupArgs;
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
        pruneOpts = pruneOpts;
        # disable auto start because this backup is only started when home_assistant-sn is done
        timerConfig = null;
        extraBackupArgs = extraBackupArgs;
        initialize = true;
      };

      # services are first backed up to lb and then to sn
      services-lb = {
        paths = serviceBackupPaths;
        repositoryFile = "${config.lmh01.secrets}/restic/lb/repository";
        passwordFile = "${config.lmh01.secrets}/restic/lb/password";
        backupPrepareCommand = serviceBackupPrepareCommand;
        backupCleanupCommand = ''
          systemctl start restic-backups-services-sn
        '';
        pruneOpts = pruneOpts;
        # on check phase dont lock repo, to make check not fail if other backup is currenlty running
        # and that backup to other location is executed
        checkOpts = [
          "--no-lock"
        ];
        timerConfig = backupTimer;
        extraBackupArgs = extraBackupArgs;
        initialize = true;
      };
      services-sn = {
        paths = serviceBackupPaths;
        repositoryFile = "${config.lmh01.secrets}/restic/sn/repository";
        passwordFile = "${config.lmh01.secrets}/restic/sn/password";
        environmentFile = "${config.lmh01.secrets}/restic/sn/environment";
        backupCleanupCommand = serviceBackupCleanupCommand;
        pruneOpts = pruneOpts;
        # disable auto start because this backup is only started when services-lb is done
        timerConfig = null;
        extraBackupArgs = extraBackupArgs;
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
    53 # used by pihole
    2283 # used by immich
    8076 # used by webdav
    8123 # used by home assistant
    11500 # pihole admin interface
  ];

  networking.firewall.allowedUDPPorts = [
    53 # used by pihole
    11500 # pihole admin interface
  ];

  lollypops.deployment = {
    local-evaluation = true;
    # ssh = { user = "root"; host = "<IP>"; };
  };

  nixpkgs.hostPlatform = lib.mkDefault "aarch64-linux";

  system.stateVersion = "23.05";
}
