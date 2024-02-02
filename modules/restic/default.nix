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
          #timerConfig = {
          #  OnCalendar = "03:00";
          #  Persistent = true;
          #  RandomizedDelaySec = "5h";
          #};
          extraBackupArgs = [
            "--exclude-file=${restic-ignore-file}"
            "--one-file-system"
            "--dry-run"
            "-v"
          ];
          initialize = true;
        };
      };
  };
}