{ pkgs, ... }:
let
  vars = import ../../vars.nix;
in
{

  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;
    # autocd = true;
    dotDir = ".config/zsh";

    # Commented out because it causes the error "The option `home-manager.users.louis.programs.zsh.promptInit' does not exist. "
    # enable starship
    #promptInit = ''
    #  eval "$(starship init zsh)"
    #'';

    history = {
      expireDuplicatesFirst = true;
      ignoreSpace = true;
      save = 15000;
      share = true;
    };

    plugins = [
      {
        name = "fast-syntax-highlighting";
        file = "fast-syntax-highlighting.plugin.zsh";
        src = "${pkgs.zsh-fast-syntax-highlighting}/share/zsh/site-functions";
      }
      {
        name = "zsh-nix-shell";
        file = "nix-shell.plugin.zsh";
        src = "${pkgs.zsh-nix-shell}/share/zsh-nix-shell";
      }
    ];

    shellAliases = {
      sudo = "sudo ";

      # always copy with progress
      cp = "${pkgs.rsync}/bin/rsync --info=progress2";
      c = "cp";

      # switching within a flake repository
      frb = "${pkgs.nixos-rebuild}/bin/nixos-rebuild --use-remote-sudo switch --flake";

      # always execute nixos-rebuild with sudo for switching
      nixos-rebuild = "${pkgs.nixos-rebuild}/bin/nixos-rebuild --use-remote-sudo";

      # quick nix develop -c zsh
      nd = "${pkgs.nix}/bin/nix develop -c ${pkgs.zsh}/bin/zsh";

      nsh = "nix-shell";
      nsp = "nix-shell -p";
    };
  };

  programs.zsh.oh-my-zsh = {
    enable = true;
    theme = "agnoster";
  };

  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
    defaultOptions = [
      "--height 40%"
      "--layout=reverse"
      "--border"
      "--inline-info"
      "--color 'fg:#${vars.colors.base05}'" # Text
      "--color 'bg:#${vars.colors.base00}'" # Background
      "--color 'preview-fg:#${vars.colors.base05}'" # Preview window text
      "--color 'preview-bg:#${vars.colors.base00}'" # Preview window background
      "--color 'hl:#${vars.colors.base0A}'" # Highlighted substrings
      "--color 'fg+:#${vars.colors.base0D}'" # Text (current line)
      "--color 'bg+:#${vars.colors.base02}'" # Background (current line)
      "--color 'gutter:#${vars.colors.base02}'" # Gutter on the left (defaults to bg+)
      "--color 'hl+:#${vars.colors.base0E}'" # Highlighted substrings (current line)
      "--color 'info:#${vars.colors.base0E}'" # Info line (match counters)
      "--color 'border:#${vars.colors.base0D}'" # Border around the window (--border and --preview)
      "--color 'prompt:#${vars.colors.base05}'" # Prompt
      "--color 'pointer:#${vars.colors.base0E}'" # Pointer to the current line
      "--color 'marker:#${vars.colors.base0E}'" # Multi-select marker
      "--color 'spinner:#${vars.colors.base0E}'" # Streaming input indicator
      "--color 'header:#${vars.colors.base05}'" # Header
    ];
  };

  programs.dircolors = {
    enable = true;
    enableZshIntegration = true;
  };

  programs.htop = {
    enable = true;
    settings = {
      show_cpu_frequency = true;
      show_cpu_temperature = true;
      show_cpu_usage = true;
      show_program_path = true;
      tree_view = false;
    };
  };

  programs.jq.enable = true;

  programs.bat = {
    enable = true;
    # This should pick up the correct colors for the generated theme. Otherwise
    # it is possible to generate a custom bat theme to ~/.config/bat/config
    config = { theme = "base16"; };
  };
}
