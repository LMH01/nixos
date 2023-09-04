{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.rust;
in
{

  options.lmh01.rust = {
    enable = mkEnableOption "activate rust toolchain";
  };

  config = mkIf cfg.enable {

    environment.systemPackages = with pkgs; [ cargo rustc ];

  };
}
