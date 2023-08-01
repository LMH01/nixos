{ config, pkgs, ...}: {

  home-manager.users.louis = {
  	home.stateVersion = "23.05";
  	home.packages = with pkgs; [
  		_1password-gui
  		alacritty
		discord
		firefox
		font-awesome
		gitui
		kate
		neofetch
		signal-desktop
		xclip
  	];

	programs = {
		git.enable = true;
		starship.enable = true;
		zsh.enable = true;
	};

	imports = [
		modules/zsh
		modules/git
	];
  };
}
