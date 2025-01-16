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
      serviceBackupPathsLb = [
        "/home/louis/Documents/immich"
        "/home/louis/Documents/audiobookshelf/config"
        "/home/louis/Documents/audiobookshelf/metadata"
        "/var/lib/storage/gitea"
        "/var/lib/webdav"
      ];
      serviceBackupPathsSn = [
        "/home/louis/Documents/immich"
        "/home/louis/Documents/audiobookshelf"
        "/var/lib/storage/gitea"
        "/var/lib/webdav"
      ];
      # commands to run when serice backups are started
      serviceBackupPrepareCommand = ''
        ${pkgs.docker}/bin/docker stop immich_server
        ${pkgs.docker}/bin/docker stop immich_machine_learning
        ${pkgs.docker}/bin/docker stop immich_redis
        ${pkgs.docker}/bin/docker stop immich_postgres
        ${pkgs.docker}/bin/docker stop audiobookshelf
        echo "Stopping gitea"
        systemctl stop gitea
        echo "Stopping webdav"
        systemctl stop webdav
      '';
      # commands to run when service backups are complete
      serviceBackupCleanupCommand = ''
        ${pkgs.docker}/bin/docker start immich_server
        ${pkgs.docker}/bin/docker start immich_machine_learning
        ${pkgs.docker}/bin/docker start immich_redis
        ${pkgs.docker}/bin/docker start immich_postgres
        ${pkgs.docker}/bin/docker start audiobookshelf
        echo "Starting gitea"
        systemctl start gitea
        echo "Starting webdav"
        systemctl start webdav
      '';
    in
    {
      # All Services are backed up to two locations.
      # The backup flow is as follows:
      # Home Assistant shutdown -> Home Assistant backup to sn -> Home Assistant backup to lb -> Home Assistant start
      # -> Shutdown all other services -> backup all other services to sn -> backup all other services to lb -> start all other services
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
      
      services-sn = {
        paths = serviceBackupPathsSn;
        repositoryFile = "${config.lmh01.secrets}/restic/sn/repository";
        passwordFile = "${config.lmh01.secrets}/restic/sn/password";
        environmentFile = "${config.lmh01.secrets}/restic/sn/environment";
        backupPrepareCommand = serviceBackupPrepareCommand;
        pruneOpts = pruneOpts;
        # disable auto start because this backup is only started when services-lb is done
        timerConfig = null;
        extraBackupArgs = extraBackupArgs;
        initialize = true;
      };
      services-lb = {
        paths = serviceBackupPathsLb;
        repositoryFile = "${config.lmh01.secrets}/restic/lb/repository";
        passwordFile = "${config.lmh01.secrets}/restic/lb/password";
        backupCleanupCommand = serviceBackupCleanupCommand;
        pruneOpts = pruneOpts;
        # on check phase dont lock repo, to make check not fail if other backup is currenlty running
        # and that backup to other location is executed
        checkOpts = [
          "--no-lock"
        ];
        # disable auto start because this backup is only started when home_assistant-lb is done
        timerConfig = null;
        extraBackupArgs = extraBackupArgs;
        initialize = true;
      };

      # commented out for now as sn is available again
      # these backups only backup to lb and are not dependent on backups to sn
      #home_assistant-lb-single = {
      #  paths = [ "/home/louis/HomeAssistant" ];
      #  repositoryFile = "${config.lmh01.secrets}/restic/lb/repository";
      #  passwordFile = "${config.lmh01.secrets}/restic/lb/password";
      #  backupPrepareCommand = ''
      #    echo "Shutting down Home Assistant to perform backup"
      #    ${pkgs.docker}/bin/docker stop homeassistant
      #  '';
      #  # start home assistant after backup is complete
      #  backupCleanupCommand = ''
      #    echo "Starting Home Assistant"
      #    ${pkgs.docker}/bin/docker start homeassistant
      #  '';
      #  pruneOpts = pruneOpts;
      #  # disable auto start because this backup is only started when home_assistant-sn is done
      #  timerConfig = backupTimer;
      #  extraBackupArgs = extraBackupArgs;
      #  initialize = true;
      #};

      ## services are first backed up to lb and then to sn
      #services-lb-single = {
      #  paths = serviceBackupPathsLb;
      #  repositoryFile = "${config.lmh01.secrets}/restic/lb/repository";
      #  passwordFile = "${config.lmh01.secrets}/restic/lb/password";
      #  backupPrepareCommand = serviceBackupPrepareCommand;
      #  backupCleanupCommand = serviceBackupCleanupCommand;
      #  pruneOpts = pruneOpts;
      #  # on check phase dont lock repo, to make check not fail if other backup is currenlty running
      #  # and that backup to other location is executed
      #  checkOpts = [
      #    "--no-lock"
      #  ];
      #  timerConfig = backupTimer;
      #  extraBackupArgs = extraBackupArgs;
      #  initialize = true;
      #};

    };

  # ensure that backups start one after another in the correct order
  systemd.services.restic-backups-home_assistant-lb = {
    wants = [ "restic-backups-home_assistant-sn.service" ];
    before = [ "restic-backups-home_assistant-sn.service" ];
  };
  systemd.services.restic-backups-services-sn = {
    wants = [ "restic-backups-home_assistant-lb.service" ];
    before = [ "restic-backups-home_assistant-lb.service" ];
  };
  systemd.services.restic-backups-services-lb = {
    wants = [ "restic-backups-services-sn.service" ];
    before = [ "restic-backups-services-sn.service" ];
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
