{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.openssh;
in
{

  options.lmh01.openssh = {
    enable = mkEnableOption "activate openssh";
  };

  config = mkIf cfg.enable {

    # Enable the OpenSSH daemon.
    services.openssh = {
      enable = true;
      startWhenNeeded = true;
      settings = {
        PasswordAuthentication = false;
        KbdInteractiveAuthentication = false;
      };
    };

  };
}
