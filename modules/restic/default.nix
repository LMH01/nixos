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

    # if enabled, home assistant directory (/home/louis/HomeAssistant) will be backed up to sn
    backup-home_assistant-sn = mkEnableOption "enable home assistant backup to sn";
    backup-gitea-sn = mkEnableOption "enable gitea backup to sn";
    backup-home_assistant-lb = mkEnableOption "enable home assistant backup to lb";
    backup-gitea-lb = mkEnableOption "enable gitea backup to lb";

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
        # commented out until server is available again
        #home_assistant-sn = mkIf cfg.backup-home_assistant-sn {
        #  paths = [ "/home/louis/HomeAssistant" ];
        #  repositoryFile = "${config.lmh01.secrets}/restic/sn/repository";
        #  passwordFile = "${config.lmh01.secrets}/restic/sn/password";
        #  # stop home assistant before backup
        #  backupPrepareCommand = ''
        #    echo "Shutting down Home Assistant to perform backup"
        #    ${pkgs.docker}/bin/docker stop homeassistant
        #  '';
        #  # start home assistant after backup is complete
        #  backupCleanupCommand = ''
        #    echo "Starting Home Assistant"
        #    ${pkgs.docker}/bin/docker start homeassistant
        #  '';
        #  pruneOpts = [
        #    "--keep-daily 7"
        #    "--keep-weekly 5"
        #    "--keep-monthly 12"
        #    "--keep-yearly 75"
        #  ];
        #  timerConfig = cfg.backup-timer;
        #  # retry-lock is disabled for this backup, so that home assistant isn't down for too long
        #  extraBackupArgs = [
        #    "--exclude-file=${restic-ignore-file}"
        #    "--one-file-system"
        #    "-v"
        #  ];
        #  initialize = true;
        #};
        #gitea-sn = mkIf cfg.backup-gitea-sn {
        #  paths = [ "/var/lib/storage/gitea" ];
        #  repositoryFile = "${config.lmh01.secrets}/restic/sn/repository";
        #  passwordFile = "${config.lmh01.secrets}/restic/sn/password";
        #  # stop home assistant before backup
        #  backupPrepareCommand = ''
        #    echo "Shutting down gitea to perform backup"
        #    systemctl stop gitea
        #  '';
        #  # start home assistant after backup is complete
        #  backupCleanupCommand = ''
        #    echo "Starting gitea"
        #    systemctl start gitea
        #  '';
        #  pruneOpts = [
        #    "--keep-daily 7"
        #    "--keep-weekly 5"
        #    "--keep-monthly 12"
        #    "--keep-yearly 75"
        #  ];
        #  timerConfig = cfg.backup-timer;
        #  # retry-lock is disabled for this backup, so that home assistant isn't down for too long
        #  extraBackupArgs = [
        #    "--exclude-file=${restic-ignore-file}"
        #    "--one-file-system"
        #    "-v"
        #  ];
        #  initialize = true;
        #};
        home_assistant-lb = mkIf cfg.backup-home_assistant-sn {
          paths = [ "/home/louis/HomeAssistant" ];
          repositoryFile = "${config.lmh01.secrets}/restic/lb/repository";
          passwordFile = "${config.lmh01.secrets}/restic/lb/password";
          # stop home assistant before backup
          backupPrepareCommand = ''
            echo "Shutting down Home Assistant to perform backup"
            ${pkgs.docker}/bin/docker stop homeassistant
          '';
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
          timerConfig = cfg.backup-timer;
          # retry-lock is disabled for this backup, so that home assistant isn't down for too long
          extraBackupArgs = [
            "--exclude-file=${restic-ignore-file}"
            "--one-file-system"
            "-v"
          ];
          initialize = true;
        };
        gitea-lb = mkIf cfg.backup-gitea-sn {
          paths = [ "/var/lib/storage/gitea" ];
          repositoryFile = "${config.lmh01.secrets}/restic/lb/repository";
          passwordFile = "${config.lmh01.secrets}/restic/lb/password";
          # stop home assistant before backup
          backupPrepareCommand = ''
            echo "Shutting down gitea to perform backup"
            systemctl stop gitea
          '';
          # start home assistant after backup is complete
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
          timerConfig = cfg.backup-timer;
          # retry-lock is disabled for this backup, so that home assistant isn't down for too long
          extraBackupArgs = [
            "--exclude-file=${restic-ignore-file}"
            "--one-file-system"
            "-v"
          ];
          initialize = true;
        };
      };
  };
}
