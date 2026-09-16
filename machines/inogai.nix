{ pkgs, ... }:
{
  home.username = "inogai";
  home.homeDirectory = "/Users/inogai";
  home.packages = with pkgs; [
    raycast
    shottr
    handy

    nix-ai-tools.pi
    nix-ai-tools.command-code

    nodejs
  ];

  # raycast and shottr are unfree.
  nixpkgs.config.allowUnfreePredicate =
    pkg: builtins.elem (pkgs.lib.getName pkg) [ "raycast" "shottr" ];

  my.modules = {
    aerospace.enable = true;
    fonts.enable = true;
    fzfmenu.enable = true;
    jankyborders.enable = true;
    kitty.enable = true;
    kitty.mapShiftSpaceToCxSpace = true;
    qutebrowser.enable = true;
    sketchybar.enable = true;
    syncthing.enable = true;

    zellij.keyLayout = "mac";

    gpg.pinentry = "touchid";

    # CLI stack.
    cli-utils.enable = true;
    direnv.enable = true;
    gpg.enable = true;
    shell.enable = true;
    shell.zsh.enable = true; # macOS's login shell is zsh
    tui-apps.enable = true;
    yazi.enable = true;
    zellij.enable = true;
  };
}
