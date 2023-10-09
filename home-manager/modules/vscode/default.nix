{ config, system-config, pkgs, ... }: {

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    extensions = with pkgs.vscode-extensions; [
      arrterian.nix-env-selector
      llvm-vs-code-extensions.vscode-clangd # TODO Move into own module or better move into shell.nix
      b4dm4n.vscode-nixpkgs-fmt
      dracula-theme.theme-dracula
      gruntfuggly.todo-tree
      jnoortheen.nix-ide
      ms-python.python
      redhat.java
      streetsidesoftware.code-spell-checker
      tamasfe.even-better-toml
      usernamehw.errorlens
      vadimcn.vscode-lldb
      vscodevim.vim
    ];

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
