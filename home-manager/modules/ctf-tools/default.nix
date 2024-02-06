# Initially copied from https://github.com/ALinkbetweenNets/nix/blob/main/home-manager/modules/pentesting/default.nix
{ lib, pkgs, config, ... }:
with lib;
let cfg = config.lmh01.ctf-tools;
in {
  options.lmh01.ctf-tools.enable = mkEnableOption "activate capture the flag tools";
  config = mkIf cfg.enable {
    home.packages = with pkgs; [
      bless # hexeditor

      nmap
      rustscan # rust nmap alternative
      # DNS
      # Network
      metasploit

      # MITM

      # Interaction
      inetutils # Telnet, tracroute

      # Sniffing
      wireshark

      # Web
      wget
      curl
      burpsuite
      zap

      # Cracking
      hashcat

      # Cryptography
      cyberchef

      # Reversing
      ghidra
      pwndbg

      # Static Analysis
      file
      binwalk

      # Android
      android-studio
      androidenv.androidPkgs_9_0.platform-tools # to get adb
      jadx # .apk decompiling
    ];
  };
}