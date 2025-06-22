{ lib, pkgs, config, ... }:
with lib;
{
  options.lmh01 = {
    options = {
      CISkip = mkOption {
        type = types.bool;
        default = false;
        example = true;
        description = "Wheter this host should be skipped by the CI pipeline";
      };

      type = mkOption {
        type = types.enum [ "desktop" "laptop" "server" ];
        default = "desktop";
        example = "server";
      };

    };

    domain = mkOption {
        type = types.str;
        default = "example.com";
        description = "domain name for use with services and nginx";
    };
  };

}
