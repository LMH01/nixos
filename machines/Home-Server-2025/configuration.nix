# nix run .\#lollypops -- pi4b
{ self, ... }:
{ pkgs, lib, config, modulesPath, flake-self, home-manager, nixos-hardware, nixpkgs, ... }: {

  imports = [
    ./hardware-configuration.nix
    home-manager.nixosModules.home-manager

    # this machine is a server
    self.nixosModules.server

    self.nixosModules.services

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
    services = {
      nginx.enable = true;
      nginx.enable_acme = true;
    };
    gitea = {
      enable = true;
      enable_nginx = true;
      port = 22807;
    };
    # disabled for now because the latest renovate version available here does not work
    #renovate.enable = true;
    domain = "home.skl2.de";
    options = {
      type = "server";
    };
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
    webdav = {
      enable = true;
      enable_nginx = true;
    };
    wireguard.enable = true;
  };

  # secrets
  sops.secrets = {
    "restic/lb/repository" = {
      owner = "louis";
    };
    "restic/lb/password" = {
      owner = "louis";
    };
    "restic/sn/repository" = {
      owner = "louis";
    };
    "restic/sn/password" = {
      owner = "louis";
    };
    "restic/sn/environment" = {
      owner = "louis";
    };
    "restic/truenas/repository" = {
      owner = "louis";
    };
    "restic/truenas/password" = {
      owner = "louis";
    };
    "nginx/evcc_basic_auth_file" = {
      owner = "nginx";
    };
    "nginx/koito_basic_auth_file" = {
      owner = "nginx";
    };
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
          proxyPass = "http://127.0.0.1:22801";
          extraConfig = ''
            proxy_set_header    Upgrade     $http_upgrade;
            proxy_set_header    Connection  "upgrade";
          '';
        };
      };
      "dawarich.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://127.0.0.1:22802";
          extraConfig = ''
            proxy_set_header    Upgrade     $http_upgrade;
            proxy_set_header    Connection  "upgrade";
          '';
        };
      };
      "evcc.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://10.0.10.11:7070";
          extraConfig = ''
            proxy_set_header    Upgrade     $http_upgrade;
            proxy_set_header    Connection  "upgrade";
          '';
          basicAuthFile = config.sops.secrets."nginx/evcc_basic_auth_file".path;
        };
      };
      "files.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://127.0.0.1:11515";
          extraConfig = ''
            proxy_set_header    Upgrade     $http_upgrade;
            proxy_set_header    Connection  "upgrade";
          '';
        };
      };
      "has.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://10.0.10.2:8123";
          extraConfig = ''
            # These configuration options are required for WebSockets to work.
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";

            proxy_redirect off;
          '';
        };
      };
      "immich.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://127.0.0.1:22803";
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
          proxyPass = "https://10.0.10.3:8920";
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
          proxyPass = "http://127.0.0.1:22804";
        };
      };
      "koito.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://127.0.0.1:22817";
          basicAuthFile = config.sops.secrets."nginx/koito_basic_auth_file".path;
        };
      };
      "links.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://127.0.0.1:22811";
        };
      };
      "meals.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://127.0.0.1:22812";
        };
      };
      "minerva-dns.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://192.168.188.157:5380";
        };
      };
      "minerva-home.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://192.168.188.157:11800";
        };
      };
      "music.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://127.0.0.1:22810";
        };
      };
      "music-server.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://127.0.0.1:22809";
        };
      };
      "opnsense.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://10.0.10.1:8080";
        };
      };
      "paperless.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://127.0.0.1:22806";
          extraConfig = ''
            # These configuration options are required for WebSockets to work.
            proxy_http_version 1.1;
            proxy_set_header Upgrade $http_upgrade;
            proxy_set_header Connection "upgrade";

            proxy_redirect off;
          '';
        };
      };
      "pihole.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://127.0.0.1:22813";
        };
      };
      "status.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://10.0.10.9:80";
        };
      };
      "tracearr.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://10.0.10.2:22814";
          extraConfig = ''
            proxy_set_header    Upgrade     $http_upgrade;
            proxy_set_header    Connection  "upgrade";
            proxy_set_header    X-Forwarded-For   $proxy_add_x_forwarded_for;
            proxy_set_header    X-Forwarded-Proto $scheme; 
          '';
        };
      };
      "truenas.${config.lmh01.domain}" = {
        forceSSL = true;
        useACMEHost = "${config.lmh01.domain}";
        locations."/" = {
          proxyPass = "http://10.0.10.4:80";
          extraConfig = ''
            proxy_set_header    Upgrade     $http_upgrade;
            proxy_set_header    Connection  "upgrade";
          '';
        };
      };
    };
  };

  # additional restic backups, used just on this system
  services.restic.backups =
    let
      backupTimer = {
        OnCalendar = "02:00";
        Persistent = true;
        RandomizedDelaySec = "1h";
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
        "/home/louis/Documents/homepage"
        "/home/louis/Documents/immich"
        "/home/louis/Documents/audiobookshelf/config"
        "/home/louis/Documents/audiobookshelf/metadata"
        "/home/louis/Documents/paperless-ngx"
        "/home/louis/Documents/tandoor"
        "/home/louis/services/dawarich"
        "/home/louis/services/linkwarden"
        "/home/louis/services/tracearr"
        "/var/lib/storage/gitea"
        "/var/lib/webdav"
      ];
      serviceBackupPathsSn = [
        "/home/louis/Documents/homepage"
        "/home/louis/Documents/immich"
        "/home/louis/Documents/audiobookshelf"
        "/home/louis/Documents/paperless-ngx"
        "/home/louis/Documents/tandoor"
        "/home/louis/services/dawarich"
        "/home/louis/services/linkwarden"
        "/home/louis/services/tracearr"
        "/home/louis/services/koito"
        "/home/louis/services/navidrome"
        "/var/lib/storage/gitea"
        "/var/lib/webdav"
      ];
      serviceBackupPathsTruenas = [
        "/home/louis/Documents/homepage"
        "/home/louis/Documents/immich"
        "/home/louis/Documents/audiobookshelf"
        "/home/louis/Documents/paperless-ngx"
        "/home/louis/Documents/tandoor"
        "/home/louis/services/dawarich"
        "/home/louis/services/linkwarden"
        "/home/louis/services/tracearr"
        "/home/louis/services/koito"
        "/home/louis/services/navidrome"
        "/var/lib/storage/gitea"
        "/var/lib/webdav"
      ];
      # commands to run when serice backups are started
      serviceBackupPrepareCommand = ''
        ${pkgs.docker}/bin/docker stop homepage
        ${pkgs.docker}/bin/docker stop immich_server
        ${pkgs.docker}/bin/docker stop immich_machine_learning
        ${pkgs.docker}/bin/docker stop immich_redis
        ${pkgs.docker}/bin/docker stop immich_postgres
        ${pkgs.docker}/bin/docker stop audiobookshelf
        ${pkgs.docker}/bin/docker stop paperless-ngx-webserver-1
        ${pkgs.docker}/bin/docker stop paperless-ngx-db-1
        ${pkgs.docker}/bin/docker stop paperless-ngx-broker-1
        ${pkgs.docker}/bin/docker stop tandoor_db_recipes
        ${pkgs.docker}/bin/docker stop tandoor_web_recipes
        ${pkgs.docker}/bin/docker stop tandoor_nginx
        ${pkgs.docker}/bin/docker stop linkwarden-postgres
        ${pkgs.docker}/bin/docker stop linkwarden-server
        ${pkgs.docker}/bin/docker stop linkwarden-meilisearch
        ${pkgs.docker}/bin/docker stop dawarich_sidekiq
        ${pkgs.docker}/bin/docker stop dawarich_app
        ${pkgs.docker}/bin/docker stop dawarich_db
        ${pkgs.docker}/bin/docker stop dawarich_redis
        ${pkgs.docker}/bin/docker stop tracearr
        ${pkgs.docker}/bin/docker stop koito
        ${pkgs.docker}/bin/docker stop koito-psql
        ${pkgs.docker}/bin/docker stop navidrome
      '';
      # commands to run when service backups are complete
      serviceBackupCleanupCommand = ''
        ${pkgs.docker}/bin/docker start homepage
        ${pkgs.docker}/bin/docker start immich_server
        ${pkgs.docker}/bin/docker start immich_machine_learning
        ${pkgs.docker}/bin/docker start immich_redis
        ${pkgs.docker}/bin/docker start immich_postgres
        ${pkgs.docker}/bin/docker start audiobookshelf
        ${pkgs.docker}/bin/docker start paperless-ngx-webserver-1
        ${pkgs.docker}/bin/docker start paperless-ngx-db-1
        ${pkgs.docker}/bin/docker start paperless-ngx-broker-1
        ${pkgs.docker}/bin/docker start tandoor_db_recipes
        ${pkgs.docker}/bin/docker start tandoor_web_recipes
        ${pkgs.docker}/bin/docker start tandoor_nginx
        ${pkgs.docker}/bin/docker start linkwarden-postgres
        ${pkgs.docker}/bin/docker start linkwarden-server
        ${pkgs.docker}/bin/docker start linkwarden-meilisearch
        ${pkgs.docker}/bin/docker start dawarich_sidekiq
        ${pkgs.docker}/bin/docker start dawarich_app
        ${pkgs.docker}/bin/docker start dawarich_db
        ${pkgs.docker}/bin/docker start dawarich_redis
        ${pkgs.docker}/bin/docker start tracearr
        ${pkgs.docker}/bin/docker start koito
        ${pkgs.docker}/bin/docker start koito-psql
        ${pkgs.docker}/bin/docker start navidrome
      '';
    in
    {
      # All Services are backed up to three locations.
      # The backup flow is as follows:
      # Home Assistant shutdown -> Home Assistant backup to sn -> Home Assistant backup to lb -> Home Assistant backup to truenas -> Home Assistant start
      # -> Shutdown all other services -> backup all other services to sn -> backup all other services to lb -> backup all other services to truenas -> start all other services
      home_assistant-sn = {
        paths = [ "/home/louis/HomeAssistant" ];
        repositoryFile = config.sops.secrets."restic/sn/repository".path;
        passwordFile = config.sops.secrets."restic/sn/password".path;
        environmentFile = config.sops.secrets."restic/sn/environment".path;
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
        repositoryFile = config.sops.secrets."restic/lb/repository".path;
        passwordFile = config.sops.secrets."restic/lb/password".path;
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
      home_assistant-truenas = {
        paths = [ "/home/louis/HomeAssistant" ];
        repositoryFile = config.sops.secrets."restic/truenas/repository".path;
        passwordFile = config.sops.secrets."restic/truenas/password".path;
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
        repositoryFile = config.sops.secrets."restic/sn/repository".path;
        passwordFile = config.sops.secrets."restic/sn/password".path;
        environmentFile = config.sops.secrets."restic/sn/environment".path;
        backupPrepareCommand = serviceBackupPrepareCommand;
        pruneOpts = pruneOpts;
        # disable auto start because this backup is automatically started by systemd when backup chain starts
        timerConfig = null;
        extraBackupArgs = extraBackupArgs;
        initialize = true;
      };
      services-lb = {
        paths = serviceBackupPathsLb;
        repositoryFile = config.sops.secrets."restic/lb/repository".path;
        passwordFile = config.sops.secrets."restic/lb/password".path;
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
      services-truenas = {
        paths = serviceBackupPathsTruenas;
        repositoryFile = config.sops.secrets."restic/truenas/repository".path;
        passwordFile = config.sops.secrets."restic/truenas/password".path;
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
  systemd.services.restic-backups-home_assistant-truenas = {
    wants = [ "restic-backups-home_assistant-lb.service" ];
    after = [ "restic-backups-home_assistant-lb.service" ];
  };
  systemd.services.restic-backups-services-sn = {
    wants = [ "restic-backups-home_assistant-truenas.service" ];
    after = [ "restic-backups-home_assistant-truenas.service" ];
  };
  systemd.services.restic-backups-services-lb = {
    wants = [ "restic-backups-services-sn.service" ];
    after = [ "restic-backups-services-sn.service" ];
  };
  systemd.services.restic-backups-services-truenas = {
    wants = [ "restic-backups-services-lb.service" ];
    after = [ "restic-backups-services-lb.service" ];
  };

  # timer and service to start renovate bot automatically (I don't use services.renovate because that is outdated and does not work for my repo as of 15.08.2025)
  # I use the docker container instead
  systemd.services.run-renovate-docker = {
    description = "Run the renovate docker container once";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.docker}/bin/docker compose -f /home/louis/Documents/renovate_bot/docker-compose.yml up";
    };
  };
  systemd.timers.run-renovate-docker = {
    description = "Timer to run the renovate docker container daily at 19:00 Uhr";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "19:00";
      Persistant = true;
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

  # Additional packages
  environment.systemPackages = [
    flake-self.inputs.simple-update-checker.packages.x86_64-linux.default
  ];

  networking.hostName = "Home-Server-2025-NixOS";

  networking.networkmanager.enable = true;
  networking.networkmanager.plugins = lib.mkForce [ ];

  networking.firewall.allowedTCPPorts = [
    53 # used by pihole
    8123 # home assistant
  ];

  networking.firewall.allowedUDPPorts = [
    53 # used by pihole
    8123 # home assistant
  ];

  #lollypops.deployment =
  #  {
  #    local-evaluation = true;
  #    # ssh = { user = "root"; host = "<IP>"; };
  #  };

  system.stateVersion = "23.05";
}# nix run .\#lollypops -- pi5b
