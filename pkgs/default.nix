inputs:
self: super: {

  # our packages are accessible via lmh01.<name>
  lmh01 = {
    candy-icon-theme = super.pkgs.callPackage ./candy-icon-theme { };
    alpha_tui = super.pkgs.callPackage ./alpha_tui {};
  };

}
