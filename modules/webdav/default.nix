{ lib, config, ... }:
with lib;
let cfg = config.lmh01.webdav;
in
{

  options.lmh01.webdav = {
    enable = mkEnableOption "activate webdav";
  };

  config = mkIf cfg.enable {

    services.webdav = {
      enable = true;
      configFile = "${config.lmh01.secrets}/webdav/config.yaml";
      user = "louis";
    };

  };
}



