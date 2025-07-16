{ config, pkgs, lib, ... }:
with lib;
let cfg = config.lmh01.renovate;
in {
  options.lmh01.renovate = {
    enable = mkEnableOption "activate renovate bot";
  };

  config = mkIf cfg.enable {
    # setup sops
    sops.secrets = {
      "renovate-token" = { };
    };

    services.renovate = {
      enable = true;
      schedule = "*-*-* 19:00:00";
      settings = {
        endpoint = "https://git.home.skl2.de/api/v1";
        platform = "gitea";
        onboardingConfig = {
          extends = [ "config:recommended" ];
        };
        autodiscover = true;
      };
      credentials = {
        RENOVATE_TOKEN = config.sops.secrets."renovate-token".path;
      };
    };
  };
}
