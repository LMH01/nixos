{ config, pkgs, lib, ... }: {

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    extensions = with pkgs.vscode-extensions; [
        dracula-theme.theme-dracula
        redhat.java
        rust-lang.rust-analyzer
        streetsidesoftware.code-spell-checker
        tamasfe.even-better-toml
        usernamehw.errorlens
        vadimcn.vscode-lldb
        vscodevim.vim
    ];
  };

}
