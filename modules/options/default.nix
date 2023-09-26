{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.options;
in
{

  options.lmh01.options = {

    CISkip = mkOption {
      type = types.bool;
      default = false;
      example = true;
      description = "Wheter this host should be skipped by the CI pipeline";
    };
  };

}
