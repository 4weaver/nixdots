{ pkgs, ... }:
{
  home.username = "alexlychen";
  home.homeDirectory = "/home/alexlychen";
  home.packages = [
    pkgs.nodejs
    pkgs.nix-ai-tools.pi
  ];

  my.modules = {
    # Mac-only modules are intentionally disabled here.

    wsl.enable = true;
    zellij.keyLayout = "windows";

    gpg.pinentry = "curses";

    # CLI stack. shell.zsh stays off — Windows doesn't need zsh.
    cli-utils.enable = true;
    direnv.enable = true;
    gpg.enable = true;
    shell.enable = true;
    tui-apps.enable = true;
    yazi.enable = true;
    zellij.enable = true;
  };
}
