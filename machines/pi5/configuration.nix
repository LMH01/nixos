# nix run .\#lollypops -- pi4b
{ self, ... }:
{ pkgs, lib, config, modulesPath, flake-self, home-manager, nixos-hardware, nixpkgs, raspberry-pi-nix, ... }: {

  imports = [

    home-manager.nixosModules.home-manager

    self.nixosModules.gitea
    self.nixosModules.server
    self.nixosModules.restic
    self.nixosModules.webdav
    self.nixosModules.wireguard
    self.nixosModules.woodpecker

    raspberry-pi-nix.nixosModules.raspberry-pi
    raspberry-pi-nix.nixosModules.sd-image
  ];

  raspberry-pi-nix.board = "bcm2712";

  # nix build .\#nixosConfigurations.pi4b.config.system.build.sdImage
  # add boot.binfmt.emulatedSystems = [ "aarch64-linux" ]; to your x86 system
  # to build ARM stuff through qemu
  sdImage.compressImage = false;
  sdImage.imageBaseName = "pi5-image";

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
      domain = "pi5-louis.fritz.box";
    };
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
      # these service backups are not tested (and not yet working!)
      # TODO when these are enabled: Update systemd units to create backup chain (like below for the current way)
      # In this case a start backup needs to be set, where the timerConfig is not null.
      #service-backups =
      #  let
      #    sn_repo_file = "${config.lmh01.secrets}/restic/sn/repository";
      #    sn_password_file = "${config.lmh01.secrets}/restic/sn/password";
      #    sn_env_file = "${config.lmh01.secrets}/restic/sn/environment";
      #    lb_repo_file = "${config.lmh01.secrets}/restic/lb/repository";
      #    lb_password_file = "${config.lmh01.secrets}/restic/lb/password";
      #    sn = {
      #      repositoryFile = sn_repo_file;
      #      passwordFile = sn_password_file;
      #      environmentFile = sn_env_file;
      #    };
      #    lb = {
      #      repositoryFile = lb_repo_file;
      #      passwordFile = lb_password_file;
      #    };
      #    targets = {
      #      sn = sn;
      #      lb = lb;
      #    };
      #  in
      #  {
      #    audiobookshelf = {
      #      backupPrepareCommand = ''
      #        ${pkgs.docker}/bin/docker stop audiobookshelf
      #      '';
      #      backupCleanupCommand = ''
      #        ${pkgs.docker}/bin/docker start audiobookshelf
      #      '';
      #      targets = {
      #        sn = {
      #          paths = [
      #            "/home/louis/Documents/audiobookshelf"
      #          ];
      #          repositoryFile = sn_repo_file;
      #          passwordFile = sn_password_file;
      #          environmentFile = sn_env_file;
      #        };
      #        lb = {
      #          paths = [
      #            "/home/louis/Documents/immich"
      #            "/home/louis/Documents/audiobookshelf/config"
      #          ];
      #          repositoryFile = lb_repo_file;
      #          passwordFile = lb_password_file;
      #        };
      #      };
      #    };
      #    gitea = {
      #      paths = [ "/var/lib/storage/gitea" ];
      #      backupPrepareCommand = ''
      #        echo "Stopping gitea"
      #        systemctl stop gitea
      #      '';
      #      backupCleanupCommand = ''
      #        echo "Starting gitea"
      #        systemctl start gitea
      #      '';
      #      targets = targets;
      #    };
      #    home-assistant = {
      #      paths = [ "/home/louis/HomeAssistant" ];
      #      backupPrepareCommand = ''
      #        ${pkgs.docker}/bin/docker stop homeassistant
      #      '';
      #      backupCleanupCommand = ''
      #        ${pkgs.docker}/bin/docker start homeassistant
      #      '';
      #      targets = targets;
      #    };
      #    immich = {
      #      paths = [ "/home/louis/Documents/immich" ];
      #      backupPrepareCommand = ''
      #        ${pkgs.docker}/bin/docker stop immich_server
      #        ${pkgs.docker}/bin/docker stop immich_machine_learning
      #        ${pkgs.docker}/bin/docker stop immich_redis
      #        ${pkgs.docker}/bin/docker stop immich_postgres
      #      '';
      #      backupCleanupCommand = ''
      #        ${pkgs.docker}/bin/docker start immich_server
      #        ${pkgs.docker}/bin/docker start immich_machine_learning
      #        ${pkgs.docker}/bin/docker start immich_redis
      #        ${pkgs.docker}/bin/docker start immich_postgres
      #      '';
      #      targets = targets;
      #    };
      #    paplerless-ngx = {
      #      paths = [ "/home/louis/Documents/paperless-ngx" ];
      #      backupPrepareCommand = ''
      #        echo "Stopping webdav"
      #        systemctl stop webdav
      #      '';
      #      backupCleanupCommand = ''
      #        echo "Starting webdav"
      #        systemctl start webdav
      #      '';
      #      targets = targets;
      #    };
      #    webdav = {
      #      paths = [ "/var/lib/webdav" ];
      #      backupPrepareCommand = ''
      #        echo "Stopping webdav"
      #        systemctl stop webdav
      #      '';
      #      backupCleanupCommand = ''
      #        echo "Starting webdav"
      #        systemctl start webdav
      #      '';
      #      targets = targets;
      #    };
      #  };
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
        "/home/louis/Documents/paperless-ngx"
        "/var/lib/storage/gitea"
        "/var/lib/webdav"
      ];
      serviceBackupPathsSn = [
        "/home/louis/Documents/immich"
        "/home/louis/Documents/audiobookshelf"
        "/home/louis/Documents/paperless-ngx"
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
        ${pkgs.docker}/bin/docker stop paperless-ngx-webserver-1
        ${pkgs.docker}/bin/docker stop paperless-ngx-db-1
        ${pkgs.docker}/bin/docker stop paperless-ngx-broker-1
      '';
      # commands to run when service backups are complete
      serviceBackupCleanupCommand = ''
        ${pkgs.docker}/bin/docker start immich_server
        ${pkgs.docker}/bin/docker start immich_machine_learning
        ${pkgs.docker}/bin/docker start immich_redis
        ${pkgs.docker}/bin/docker start immich_postgres
        ${pkgs.docker}/bin/docker start audiobookshelf
        ${pkgs.docker}/bin/docker start paperless-ngx-webserver-1
        ${pkgs.docker}/bin/docker start paperless-ngx-db-1
        ${pkgs.docker}/bin/docker start paperless-ngx-broker-1
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
        # disable auto start because this backup is automatically started by systemd when backup chain starts
        timerConfig = null;
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
        # disable auto start because this backup is automatically started by systemd when backup chain starts
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
        # disable auto start because this backup is automatically started by systemd when backup chain starts
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
        # The current way the systemd services are configured requires that this last backup is triggered.
        # The service configuration below is responsible for triggering all other backups before this one.
        timerConfig = backupTimer;
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
    after = [ "restic-backups-home_assistant-sn.service" ];
  };
  systemd.services.restic-backups-services-sn = {
    wants = [ "restic-backups-home_assistant-lb.service" ];
    after = [ "restic-backups-home_assistant-lb.service" ];
  };
  systemd.services.restic-backups-services-lb = {
    wants = [ "restic-backups-services-sn.service" ];
    after = [ "restic-backups-services-sn.service" ];
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

  networking.hostName = "pi5-louis";

  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = lib.mkForce [];

  networking.firewall.allowedTCPPorts = [
    53 # used by pihole
    2283 # used by immich
    2287 # used by paperless-ngx
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
}# nix run .\#lollypops -- pi5b
