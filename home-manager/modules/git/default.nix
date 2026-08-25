{ lib, pkgs, config, ... }: {
  programs.git = {
    enable = true;
    lfs.enable = true;
    settings = {
      pull.rebase = false;
      user.email = "lmh01@skl2.de";
      user.name = "LMH01";
      init.defaultBranch = "main";
    };
  };
}
