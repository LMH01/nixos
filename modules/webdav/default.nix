{ lib, config, ... }:
with lib;
let cfg = config.lmh01.webdav;
in
{

  options.lmh01.webdav = {
    enable = mkEnableOption "activate webdav";
  };

  config = mkIf cfg.enable {

    sops.secrets."webdav/config.yaml" = { owner = "louis"; };


    services.webdav = {
      enable = true;
      configFile = config.sops.secrets."webdav/config.yaml".path;
      user = "louis";
    };

  };
}



