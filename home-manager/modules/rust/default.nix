{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.programs.rust;
in
{

  options.lmh01.programs.rust.enable = mkEnableOption "activate rust toolchain";

  config = mkIf cfg.enable {

    # Certain Rust tools won't work without this
    home.sessionVariables.RUST_SRC_PATH = "${pkgs.rust.packages.stable.rustPlatform.rustLibSrc}";

    # install rust toolchain
    home.packages = with pkgs; [
      cargo
      clang
      clippy
      gcc
      rust-analyzer
      rustc
      rustfmt
    ];

    programs.vscode.extensions = with pkgs.vscode-extensions; [
      rust-lang.rust-analyzer
      serayuzgur.crates
    ];

  };
}
