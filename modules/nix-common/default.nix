{ pkgs, nixpkgs, flake-self, ... }: {

  # Allow unfree licenced packages
  nixpkgs = {
    config.allowUnfree = true;
    overlays = [
      # our packages
      flake-self.overlays.default
    ];
  };

  nix = {
    # Set the $NIX_PATH entry for nixpkgs. This is necessary in
    # this setup with flakes, otherwise commands like `nix-shell
    # -p pkgs.htop` will keep using an old version of nixpkgs.
    # With this entry in $NIX_PATH it is possible (and
    # recommended) to remove the `nixos` channel for both users
    # and root e.g. `nix-channel --remove nixos`. `nix-channel
    # --list` should be empty for all users afterwards
    nixPath = [ "nixpkgs=${nixpkgs}" ];

    package = pkgs.nixVersions.stable;

    extraOptions = ''
      # If set to true, Nix will fall back to building from source if a binary substitute fails.
      fallback = true

      # the timeout (in seconds) for establishing connections in the binary cache substituter. 
      connect-timeout = 10

      # these log lines are only shown on a failed build
      log-lines = 25
    '';

    settings = {
      # Enable flakes
      experimental-features = [ "nix-command" "flakes" ];
      # Save space by hardlinking store files
      auto-optimise-store = true;
    };
  };

}
