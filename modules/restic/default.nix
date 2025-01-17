{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.restic-client;
in
{
  options.lmh01.restic-client = {
    enable = mkEnableOption "restic backups";
    backup-timer = mkOption {
      type = types.attrs;
      default = {
        OnCalendar = "01:00";
        Persistent = true;
        RandomizedDelaySec = "6h";
      };
      example = {
        OnCalendar = "01:00";
        Persistent = true;
        RandomizedDelaySec = "6h";
      };
      description = lib.mdDoc ''
        When to perform the backup to the backup locations.

        If the computer is turned off when the timer was supposed to fire,
        it is fired, when the computer is turned on the next time.
      ''; # TODO check if this is true
    };
    backup-paths-sn = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "/var/lib/gitea" ];
      description = "Paths to backup to sn";
    };
    backup-paths-lb = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "/var/lib/gitea" ];
      description = "Paths to backup to lb";
    };
    backup-paths-home_nas = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "/var/lib/gitea" ];
      description = "Paths to backup to home_nas, does only work in home net";
    };

    backup-paths-exclude = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "/home/louis/.cache" ];
      description = "Paths to exclude from backup";
    };

    service-backups = lib.mkOption {
      description = ''
        Backups for services.
      '';
      type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
        backup-timer = mkOption {
          type = types.attrs;
          default = {
            OnCalendar = "01:00";
            Persistent = true;
            RandomizedDelaySec = "6h";
          };
          example = {
            OnCalendar = "01:00";
            Persistent = true;
            RandomizedDelaySec = "6h";
          };
          description = lib.mdDoc ''
            When to perform the backup of this service.
          '';
        };

        paths = lib.mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "/var/lib/gitea" ];
          description = "Paths to backup.";
        };

        paths-exclude = lib.mkOption {
          type = types.listOf types.str;
          default = [ ];
          example = [ "/home/user/.cache" ];
          description = "Paths to exclude from backup.";
        };

        extraBackupArgs = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            Extra arguments passed to restic backup.
          '';
          example = [
            "--exclude-file=/etc/nixos/restic-ignore"
          ];
        };

        initialize = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = ''
            Create the repository if it doesn't exist.
          '';
        };

        pruneOpts = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            A list of options (--keep-\* et al.) for 'restic forget
            --prune', to automatically prune old snapshots.  The
            'forget' command is run *after* the 'backup' command, so
            keep that in mind when constructing the --keep-\* options.
          '';
          example = [
            "--keep-daily 7"
            "--keep-weekly 5"
            "--keep-monthly 12"
            "--keep-yearly 75"
          ];
        };

        checkOpts = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          description = ''
            A list of options for 'restic check'.
          '';
          example = [
            "--with-cache"
          ];
        };

        backupPrepareCommand = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = ''
            A script that must run before starting the backup process.
            Is run before backups to the locations are started.
          '';
        };

        backupCleanupCommand = lib.mkOption {
          type = with lib.types; nullOr str;
          default = null;
          description = ''
            A script that must run after finishing the backup process.
            Is run after backups to the locations are completed.
          '';
        };

        targets = lib.mkOption {
          description = ''
            To what locations the service should be backed up to.
          '';
          type = lib.types.attrsOf (lib.types.submodule ({ name, ... }: {
            repositoryFile = lib.mkOption {
              type = with lib.types; nullOr path;
              default = null;
              description = ''
                Path to the file containing the repository location to backup to.
              '';
            };

            passwordFile = lib.mkOption {
              type = lib.types.str;
              description = ''
                Read the repository password from a file.
              '';
              example = "/etc/nixos/restic-password";
            };

            environmentFile = lib.mkOption {
              type = with lib.types; nullOr str;
              default = null;
              description = ''
                file containing the credentials to access the repository, in the
                format of an EnvironmentFile as described by systemd.exec(5)
              '';
            };
          }));
        };
      }));
    };
    # TODO option to perform a specific script before the backup is started
    # TODO option to perform a specific script when the backup is completed
  };
  # IMPORTANT
  # Services are executed as root so make sure that the root user has access to the sftp server!
  config = mkIf cfg.enable {
    services.restic.backups =
      let
        restic-ignore-file = pkgs.writeTextFile {
          name = "restic-ignore-file";
          text = builtins.concatStringsSep "\n" cfg.backup-paths-exclude;
        };
      in
      (lib.attrsets.mergeAttrsList [
        # base backups
        (lib.optionalAttrs true {
          #sn = {
          #  paths = cfg.backup-paths-sn;
          #  repositoryFile = "${config.lmh01.secrets}/restic/sn/repository";
          #  passwordFile = "${config.lmh01.secrets}/restic/sn/password";
          #  environmentFile = "${config.lmh01.secrets}/restic/sn/environment";

          #  pruneOpts = [
          #    "--keep-daily 7"
          #    "--keep-weekly 5"
          #    "--keep-monthly 12"
          #    "--keep-yearly 75"
          #  ];
          #  timerConfig = cfg.backup-timer;
          #  extraBackupArgs = [
          #    "--exclude-file=${restic-ignore-file}"
          #    "--one-file-system"
          #    "--retry-lock 1h" # try to periodically relock the repository for 1 hour
          #    "-v"
          #  ];
          #  initialize = true;
          #};
          lb = {
            paths = cfg.backup-paths-lb;
            repositoryFile = "${config.lmh01.secrets}/restic/lb/repository";
            passwordFile = "${config.lmh01.secrets}/restic/lb/password";
            #environmentFile = "${config.lmh01.secrets}/restic/lb/environment";

            pruneOpts = [
              "--keep-daily 7"
              "--keep-weekly 5"
              "--keep-monthly 12"
              "--keep-yearly 75"
            ];
            timerConfig = cfg.backup-timer;
            extraBackupArgs = [
              "--exclude-file=${restic-ignore-file}"
              "--one-file-system"
              "--retry-lock 1h" # try to periodically relock the repository for 1 hour
              "-v"
            ];
            initialize = true;
          };
          # only works when nas home is manually mounted to /mnt/nas_home
          # (this is a restriction of the nas I have a home)
          home_nas = {
            paths = cfg.backup-paths-home_nas;
            repositoryFile = "${config.lmh01.secrets}/restic/home_nas/repository";
            passwordFile = "${config.lmh01.secrets}/restic/home_nas/password";

            pruneOpts = [
              "--keep-daily 7"
              "--keep-weekly 5"
              "--keep-monthly 12"
              "--keep-yearly 75"
            ];
            timerConfig = cfg.backup-timer;
            extraBackupArgs = [
              "--exclude-file=${restic-ignore-file}"
              "--one-file-system"
              "--retry-lock 1h" # try to periodically relock the repository for 1 hour
              "-v"
            ];
            initialize = true;
          };

        })
        # service backups
        (lib.optionalAttrs true {
          # FILL IN HERE
        })
      ]);
  };
}
