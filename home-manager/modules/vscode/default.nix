{ config, system-config, pkgs, ... }: {

  programs.vscode = {
    enable = true;
    package = pkgs.vscode;
    enableUpdateCheck = false;
    enableExtensionUpdateCheck = false;
    extensions = with pkgs.vscode-extensions; [
      #arrterian.nix-env-selector
      b4dm4n.vscode-nixpkgs-fmt
      dracula-theme.theme-dracula
      gruntfuggly.todo-tree
      jnoortheen.nix-ide
      llvm-vs-code-extensions.vscode-clangd # TODO Move into own module or better move into shell.nix
      ms-python.python
      ms-vscode-remote.remote-ssh
      redhat.java
      redhat.vscode-yaml
      streetsidesoftware.code-spell-checker
      tamasfe.even-better-toml
      usernamehw.errorlens
      vadimcn.vscode-lldb
      vscodevim.vim
    ] ++ pkgs.vscode-utils.extensionsFromVscodeMarketplace [
      {
        name = "code-spell-checker-german";
        publisher = "streetsidesoftware";
        version = "2.3.0";
        sha256 = "rAm3pcLn6HoWnhWeoK/0D9r5oY9TIQ23EMh35rurgDg=";
      }
      {
        name = "vscode-openapi";
        publisher = "42crunch";
        version = "4.25.1";
        sha256 = "+hKQUJp9c0oyhePFmQEXAqtqKL3fkQ1nhopUPnhRZc4=";
      }
      #{
      #  name = "vscode-pets";
      #  publisher = "tonybaloney";
      #  version = "1.25.0";
      #  sha256 = "2xzqR4KW1+RFJI0mttou/LSqE51Ozn4eBpbCRwzy5AQ=";
      #}
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
