{ lib, pkgs, config, ...}: {
    programs.git = {
        enable = true;
        extraConfig = { pull.rebase = false; };
        userEmail = "lmh-01@netcologne.de";
        userName = "LMH01";
    };
}
