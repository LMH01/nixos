{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.users.louis;
in {

  options.lmh01.users.louis = {
    enable = mkEnableOption "activate user louis";
  };

  config = mkIf cfg.enable {

    users.users.louis = {
      isNormalUser = true;
      home = "/home/louis";
      extraGroups = [ "wheel" ]
        ++ lib.optionals config.networking.networkmanager.enable [ "networkmanager" ];
      shell = "${pkgs.zsh}/bin/zsh";
      openssh.authorizedKeys.keyFiles = [
        (pkgs.fetchurl {
          url = "https://github.com/LMH01.keys";
          hash = "sha256-rVZEmUERVQSB7Nm3xZEJU6HxDeCK/iuEyrKz+IeXlf0=";
        })
      ];
    };
    nix.settings.allowed-users = [ "louis" ];
  };

}
