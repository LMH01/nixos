{ config, pkgs, lib, ... }: {

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    extensions = with pkgs.vscode-extensions; [
        dracula-theme.theme-dracula
        rust-lang.rust-analyzer
        usernamehw.errorlens
        vscodevim.vim
    ];
  };

}
