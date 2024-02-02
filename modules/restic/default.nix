{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.restic-client;
in
{
  options.lmh01.restic-client = {
    enable = mkEnableOption "restic backups";
    backup-paths-sn = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "/var/lib/gitea" ];
      description = "Paths to backup to sn";
    };
    backup-timer-sn = mkOption {
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
        When to perform the backup to sn.

        If the computer is turned off when the timer was supposed to fire,
        it is fired, when the computer is turned on the next time.
      ''; # TODO check if this is true
    };
    backup-prepare-sn = mkOption {
      type = with types; nullOr str;
      default = null;
      description = lib.mdDoc ''
        A script that must run before starting the backup process to sn.
      '';
    };
    backup-cleanup-sn = mkOption {
      type = with types; nullOr str;
      default = null;
      description = lib.mdDoc ''
        A script that must run after finishing the backup process to sn.
      '';
    };
    backup-paths-exclude = mkOption {
      type = types.listOf types.str;
      default = [ ];
      example = [ "/home/louis/.cache" ];
      description = "Paths to exclude from backup";
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
      {
        sn = {
          paths = cfg.backup-paths-sn;
          repositoryFile = "${config.lmh01.secrets}/restic/sn/repository";
          passwordFile = "${config.lmh01.secrets}/restic/sn/password";
          environmentFile = "${config.lmh01.secrets}/restic/sn/environment";

          # these values are given as example, I'm currently unsure how they work exactly
          # they might be changed when I learn what they do exactly
          pruneOpts = [
            "--keep-daily 7"
            "--keep-weekly 5"
            "--keep-monthly 12"
            "--keep-yearly 75"
          ];
          timerConfig = cfg.backup-timer-sn;
          backupPrepareCommand = cfg.backup-prepare-sn;
          backupCleanupCommand = cfg.backup-cleanup-sn;
          extraBackupArgs = [
            "--exclude-file=${restic-ignore-file}"
            "--one-file-system"
            "--dry-run"
            "--retry-lock 2h" # try to periodically relock the repository for 2 hours
            "-v"
          ];
          initialize = true;
        };
      };
  };
}
