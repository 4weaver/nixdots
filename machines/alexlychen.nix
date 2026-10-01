{ pkgs, ... }:
{
  home.username = "alexlychen";
  home.homeDirectory = "/home/alexlychen";
  home.packages = [
    pkgs.nodejs
    pkgs.nix-ai-tools.pi
    pkgs.nix-ai-tools.omp
  ];

  my.modules = {
    # Mac-only modules are intentionally disabled here.

    wsl.enable = true;
    zellij.keyLayout = "windows";

    gpg.pinentry = "curses";

    # herdr panes run nushell: WSL has no zsh and `sh` is all /bin carries.
    # hint/find mirror the agent home. WSL has no clipboard bridge the plugin
    # reads (it looks for pbpaste/wl-paste/xclip), so the clipboard-driven entry
    # points are inert here; the pane-text scan that hint is built on works.
    herdr = {
      enable = true;
      quicklook.enable = true;
      settings.keys.command = [
        {
          key = "prefix+a";
          type = "plugin_action";
          command = "herdr-quicklook.hint";
          description = "hint-pick any openable token on screen";
        }
        {
          key = "prefix+f";
          type = "plugin_action";
          command = "herdr-quicklook.find";
          description = "fuzzy-find a file to open";
        }
      ];
    };

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
