{ config, system-config, pkgs, lib, ... }: {

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    extensions = with pkgs.vscode-extensions; [
      b4dm4n.vscode-nixpkgs-fmt
      dracula-theme.theme-dracula
      james-yu.latex-workshop
      jnoortheen.nix-ide
      redhat.java
      streetsidesoftware.code-spell-checker
      tamasfe.even-better-toml
      usernamehw.errorlens
      vadimcn.vscode-lldb
      vscodevim.vim
    ] ++ lib.optionals system-config.lmh01.rust.enable [rust-lang.rust-analyzer];

    userSettings = {
      "workbench.colorTheme" = "Dracula";
      "nix.enableLanguageServer" = "true";
      "nix.serverPath" = "${pkgs.nil}/bin/nil";
      "[nix]" = {
        "editor.defaultFormatter" = "B4dM4n.nixpkgs-fmt";
      };
      "files.autoSave" = "afterDelay";
    };
  };

}
