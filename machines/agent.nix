{ pkgs, lib, ... }:
let
  # One shared prefix sequence for tmux and herdr: the keyboard's TMUX layer
  # (zmk-config eyelash_sofle.keymap) sends Ctrl-b then the action key to both.
  # detach is prefix+d because the layer's detach binding is d, matching tmux;
  # herdr's own default is prefix+q.
  #
  # The popup is herdr's "floating pane" — herdr has no built-in float, so it is
  # a `popup` custom command, and the layer sends prefix+t for its float key.
  # Popups are session-modal and eat every key, Esc included, until the shell
  # exits. It runs the same shell as the panes rather than $SHELL, so a scratch
  # terminal here is the environment the rest of the config describes.
  #
  # quicklook's hint picker scans only the focused pane's visible text, so its
  # cost is bounded by screen size — which matters on /var/lib/agent-files, a
  # 15G, ~125k-file tree that is not a git repo. Bound to prefix+a, not the
  # upstream README's prefix+v: herdr's default `keys.split_vertical` already
  # owns prefix+v, and a plugin_action there would silently take the split away.
  shell = lib.getExe pkgs.nushell;

  herdrSettings = {
    onboarding = false;

    keys = {
      detach = "prefix+d";

      command = [
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
        {
          key = "prefix+t";
          type = "popup";
          command = "exec ${shell}";
          description = "scratch popup terminal";
          width = "80%";
          height = "80%";
        }
      ];
    };

    ui = {
      status_indicators = "symbols";
      toast.delivery = "terminal";
    };

    theme = {
      name = "terminal";
      auto_switch = false;
    };
  };
in
{
  home.username = "agent";
  home.homeDirectory = "/home/agent";

  # nvim-inogai defaults every language group to ON, but arachnet already
  # carries the toolchains. The option sits under `wrappers` because
  # nvim-inogai's home module is a getInstallModule wrapper.
  wrappers.neovim.extras.lang = {
    nix.enable = false;
    lua.enable = false;
    java.enable = false;
    json.enable = false;
    c.enable = false;
    csharp.enable = false;
    javascript.enable = false;
    angular.enable = false;
  };

  # Lean agent CLI: shell (nushell/atuin/carapace/starship/zoxide — no zsh,
  # no direnv) plus yazi. yazi is not on the system nor in the agent nix
  # profile, so the home has to provide it. lazygit/cli-utils/gpg/zellij
  # stay off — they already exist; no nodejs either, the machine has
  # nodejs_22.
  my.modules = {
    shell.enable = true;
    yazi.enable = true;

    # herdr owns its own package (the nix-ai-tools pin) and its config.toml;
    # this machine's keybindings are the settings below.
    herdr = {
      enable = true;
      quicklook.enable = true;
      settings = herdrSettings;
    };
  };
}
