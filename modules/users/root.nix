{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.users.root;
in
{

  options.lmh01.users.root = {
    enable = mkEnableOption "activate user root";
  };

  config = mkIf cfg.enable {

    users.users.root = {
      openssh.authorizedKeys.keyFiles = [
        (pkgs.fetchurl {
          url = "https://github.com/LMH01.keys";
          hash = "sha256-tCb8S7xVsIexCr2JlwMA96d90zHSyqOIfcObV8xCmGY=";
        })
      ];

    };
  };

}
