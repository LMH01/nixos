# nix run .\#lollypops -- pi4b
{ self, ... }:
{ pkgs, lib, config, modulesPath, flake-self, home-manager, nixos-hardware, nixpkgs, ... }: {

  imports = [
    ./hardware-configuration.nix
    home-manager.nixosModules.home-manager

    # this machine is a server
    self.nixosModules.server

    self.nixosModules.gitea
    self.nixosModules.restic
    self.nixosModules.webdav
    self.nixosModules.wireguard
    self.nixosModules.woodpecker
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
    gitea = {
      enable = true;
      domain = "Home-Server-2025-NixOS.fritz.box";
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
    };
    webdav.enable = true;
    wireguard.enable = true;
  };

  # to be commented in again, when server is up and running properly with services
  # additional restic backups, used just on this system
  #services.restic.backups =
  #  let
  #    backupTimer = {
  #      OnCalendar = "02:00";
  #      Persistent = true;
  #      RandomizedDelaySec = "1h";
  #    };
  #    pruneOpts = [
  #      "--keep-daily 7"
  #      "--keep-weekly 5"
  #      "--keep-monthly 12"
  #      "--keep-yearly 75"
  #    ];
  #    extraBackupArgs = [
  #      "--one-file-system"
  #      "-v"
  #    ];
  #    serviceBackupPathsLb = [
  #      "/home/louis/Documents/homepage"
  #      "/home/louis/Documents/immich"
  #      "/home/louis/Documents/audiobookshelf/config"
  #      "/home/louis/Documents/audiobookshelf/metadata"
  #      "/home/louis/Documents/paperless-ngx"
  #      "/var/lib/storage/gitea"
  #      "/var/lib/webdav"
  #    ];
  #    serviceBackupPathsSn = [
  #      "/home/louis/Documents/homepage"
  #      "/home/louis/Documents/immich"
  #      "/home/louis/Documents/audiobookshelf"
  #      "/home/louis/Documents/paperless-ngx"
  #      "/var/lib/storage/gitea"
  #      "/var/lib/webdav"
  #    ];
  #    # commands to run when serice backups are started
  #    serviceBackupPrepareCommand = ''
  #      ${pkgs.docker}/bin/docker stop homepage
  #      ${pkgs.docker}/bin/docker stop immich_server
  #      ${pkgs.docker}/bin/docker stop immich_machine_learning
  #      ${pkgs.docker}/bin/docker stop immich_redis
  #      ${pkgs.docker}/bin/docker stop immich_postgres
  #      ${pkgs.docker}/bin/docker stop audiobookshelf
  #      ${pkgs.docker}/bin/docker stop paperless-ngx-webserver-1
  #      ${pkgs.docker}/bin/docker stop paperless-ngx-db-1
  #      ${pkgs.docker}/bin/docker stop paperless-ngx-broker-1
  #    '';
  #    # commands to run when service backups are complete
  #    serviceBackupCleanupCommand = ''
  #      ${pkgs.docker}/bin/docker start homepage
  #      ${pkgs.docker}/bin/docker start immich_server
  #      ${pkgs.docker}/bin/docker start immich_machine_learning
  #      ${pkgs.docker}/bin/docker start immich_redis
  #      ${pkgs.docker}/bin/docker start immich_postgres
  #      ${pkgs.docker}/bin/docker start audiobookshelf
  #      ${pkgs.docker}/bin/docker start paperless-ngx-webserver-1
  #      ${pkgs.docker}/bin/docker start paperless-ngx-db-1
  #      ${pkgs.docker}/bin/docker start paperless-ngx-broker-1
  #    '';
  #  in
  #  {
  #    # All Services are backed up to two locations.
  #    # The backup flow is as follows:
  #    # Home Assistant shutdown -> Home Assistant backup to sn -> Home Assistant backup to lb -> Home Assistant start
  #    # -> Shutdown all other services -> backup all other services to sn -> backup all other services to lb -> start all other services
  #    home_assistant-sn = {
  #      paths = [ "/home/louis/HomeAssistant" ];
  #      repositoryFile = "${config.lmh01.secrets}/restic/sn/repository";
  #      passwordFile = "${config.lmh01.secrets}/restic/sn/password";
  #      environmentFile = "${config.lmh01.secrets}/restic/sn/environment";
  #      # stop home assistant before backup
  #      backupPrepareCommand = ''
  #        echo "Shutting down Home Assistant to perform backup"
  #        ${pkgs.docker}/bin/docker stop homeassistant
  #      '';
  #      pruneOpts = pruneOpts;
  #      # on check phase dont lock repo, to make check not fail if other backup is currenlty running
  #      # and that backup to other location is executed
  #      checkOpts = [
  #        "--no-lock"
  #      ];
  #      # disable auto start because this backup is automatically started by systemd when backup chain starts
  #      timerConfig = null;
  #      extraBackupArgs = extraBackupArgs;
  #      initialize = true;
  #    };
  #    home_assistant-lb = {
  #      paths = [ "/home/louis/HomeAssistant" ];
  #      repositoryFile = "${config.lmh01.secrets}/restic/lb/repository";
  #      passwordFile = "${config.lmh01.secrets}/restic/lb/password";
  #      # start home assistant after backup is complete
  #      backupCleanupCommand = ''
  #        echo "Starting Home Assistant"
  #        ${pkgs.docker}/bin/docker start homeassistant
  #      '';
  #      pruneOpts = pruneOpts;
  #      # disable auto start because this backup is automatically started by systemd when backup chain starts
  #      timerConfig = null;
  #      extraBackupArgs = extraBackupArgs;
  #      initialize = true;
  #    };

  #    services-sn = {
  #      paths = serviceBackupPathsSn;
  #      repositoryFile = "${config.lmh01.secrets}/restic/sn/repository";
  #      passwordFile = "${config.lmh01.secrets}/restic/sn/password";
  #      environmentFile = "${config.lmh01.secrets}/restic/sn/environment";
  #      backupPrepareCommand = serviceBackupPrepareCommand;
  #      pruneOpts = pruneOpts;
  #      # disable auto start because this backup is automatically started by systemd when backup chain starts
  #      timerConfig = null;
  #      extraBackupArgs = extraBackupArgs;
  #      initialize = true;
  #    };
  #    services-lb = {
  #      paths = serviceBackupPathsLb;
  #      repositoryFile = "${config.lmh01.secrets}/restic/lb/repository";
  #      passwordFile = "${config.lmh01.secrets}/restic/lb/password";
  #      backupCleanupCommand = serviceBackupCleanupCommand;
  #      pruneOpts = pruneOpts;
  #      # on check phase dont lock repo, to make check not fail if other backup is currenlty running
  #      # and that backup to other location is executed
  #      checkOpts = [
  #        "--no-lock"
  #      ];
  #      # The current way the systemd services are configured requires that this last backup is triggered.
  #      # The service configuration below is responsible for triggering all other backups before this one.
  #      timerConfig = backupTimer;
  #      extraBackupArgs = extraBackupArgs;
  #      initialize = true;
  #    };

  #    # jellyfin backup (not included in main backup run)
  #    jellyfin-sn = {
  #      paths = [ "/home/louis/Documents/jellyfin" ];
  #      repositoryFile = "${config.lmh01.secrets}/restic/sn/repository";
  #      passwordFile = "${config.lmh01.secrets}/restic/sn/password";
  #      environmentFile = "${config.lmh01.secrets}/restic/sn/environment";
  #      # stop home assistant before backup
  #      backupPrepareCommand = ''
  #        ${pkgs.docker}/bin/docker stop jellyfin
  #      '';
  #      pruneOpts = pruneOpts;
  #      # on check phase dont lock repo, to make check not fail if other backup is currenlty running
  #      # and that backup to other location is executed
  #      checkOpts = [
  #        "--no-lock"
  #      ];
  #      # disable auto start because this backup is automatically started by systemd when trigger for jellyfin-lb is run
  #      timerConfig = null;
  #      extraBackupArgs = extraBackupArgs;
  #      initialize = true;
  #    };
  #    jellyfin-lb = {
  #      paths = [ "/home/louis/Documents/jellyfin" ];
  #      repositoryFile = "${config.lmh01.secrets}/restic/lb/repository";
  #      passwordFile = "${config.lmh01.secrets}/restic/lb/password";
  #      # start home assistant after backup is complete
  #      backupCleanupCommand = ''
  #        ${pkgs.docker}/bin/docker start jellyfin
  #      '';
  #      pruneOpts = pruneOpts;
  #      timerConfig = {
  #        OnCalendar = "Mon *-*-* 04:00";
  #        Persistent = true;
  #        RandomizedDelaySec = "1h";
  #      };
  #      extraBackupArgs = extraBackupArgs;
  #      initialize = true;
  #    };

  #    # commented out for now as sn is available again
  #    # these backups only backup to lb and are not dependent on backups to sn
  #    #home_assistant-lb-single = {
  #    #  paths = [ "/home/louis/HomeAssistant" ];
  #    #  repositoryFile = "${config.lmh01.secrets}/restic/lb/repository";
  #    #  passwordFile = "${config.lmh01.secrets}/restic/lb/password";
  #    #  backupPrepareCommand = ''
  #    #    echo "Shutting down Home Assistant to perform backup"
  #    #    ${pkgs.docker}/bin/docker stop homeassistant
  #    #  '';
  #    #  # start home assistant after backup is complete
  #    #  backupCleanupCommand = ''
  #    #    echo "Starting Home Assistant"
  #    #    ${pkgs.docker}/bin/docker start homeassistant
  #    #  '';
  #    #  pruneOpts = pruneOpts;
  #    #  # disable auto start because this backup is only started when home_assistant-sn is done
  #    #  timerConfig = backupTimer;
  #    #  extraBackupArgs = extraBackupArgs;
  #    #  initialize = true;
  #    #};

  #    ## services are first backed up to lb and then to sn
  #    #services-lb-single = {
  #    #  paths = serviceBackupPathsLb;
  #    #  repositoryFile = "${config.lmh01.secrets}/restic/lb/repository";
  #    #  passwordFile = "${config.lmh01.secrets}/restic/lb/password";
  #    #  backupPrepareCommand = serviceBackupPrepareCommand;
  #    #  backupCleanupCommand = serviceBackupCleanupCommand;
  #    #  pruneOpts = pruneOpts;
  #    #  # on check phase dont lock repo, to make check not fail if other backup is currenlty running
  #    #  # and that backup to other location is executed
  #    #  checkOpts = [
  #    #    "--no-lock"
  #    #  ];
  #    #  timerConfig = backupTimer;
  #    #  extraBackupArgs = extraBackupArgs;
  #    #  initialize = true;
  #    #};

  #  };

  ## ensure that backups start one after another in the correct order
  #systemd.services.restic-backups-home_assistant-lb = {
  #  wants = [ "restic-backups-home_assistant-sn.service" ];
  #  after = [ "restic-backups-home_assistant-sn.service" ];
  #};
  #systemd.services.restic-backups-services-sn = {
  #  wants = [ "restic-backups-home_assistant-lb.service" ];
  #  after = [ "restic-backups-home_assistant-lb.service" ];
  #};
  #systemd.services.restic-backups-services-lb = {
  #  wants = [ "restic-backups-services-sn.service" ];
  #  after = [ "restic-backups-services-sn.service" ];
  #};
  
  #systemd.services.restic-backups-jellyfin-lb = {
  #  wants = [ "restic-backups-jellyfin-sn.service" ];
  #  after = [ "restic-backups-jellyfin-sn.service" ];
  #};

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

  networking.hostName = "Home-Server-2025-NixOS";

  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = lib.mkForce [ ];

  # set static network address so that it does not change
  networking.interfaces.ens18.ipv4.addresses = [{
    address = "10.0.10.2";
    prefixLength = 24;
  }];

  networking.firewall.allowedTCPPorts = [
    53 # used by pihole
    2283 # used by immich
    2287 # used by paperless-ngx
    8076 # used by webdav
    8096 # used by jellyfin
    8920 # used by jellyfin
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

  system.stateVersion = "23.05";
}# nix run .\#lollypops -- pi5b
