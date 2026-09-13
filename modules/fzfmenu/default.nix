{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.modules.fzfmenu;

  fzfmenu = pkgs.nur.repos.inogai.fzfmenu;

  # Started by aerospace with exec-and-forget, so the name has to resolve on
  # PATH. kitty receives fzfmenu as a positional program, which bypasses
  # programs.kitty's `shell` setting (that would route into zellij) and keeps a
  # multiplexer out of the middle — the prerequisite for kitty-graphics
  # previews.
  #
  # Windowing notes:
  # * `-o` overrides rather than `--config`: the regular kitty.conf still loads,
  #   so the launcher inherits colours, font and hide_window_decorations; only
  #   geometry and lifecycle are overridden.
  # * --single-instance keeps one kitty server alive, so opening the launcher is
  #   a ~0.2s socket round-trip instead of a ~1s cold start. The price: macOS
  #   cascades every window that server creates, so the launcher lands a step
  #   away from last time. Dropping --single-instance pins the position and
  #   costs ~0.8s per open — speed won. Nothing in macOS lets us place the
  #   window ourselves: AeroSpace has no such command and kitty's --position is
  #   ignored here.
  # * remember_window_position covers the cold path: the first window after a
  #   reboot (or a killed server) lands where it was last left. Its own
  #   KITTY_CACHE_DIRECTORY keeps that memory out of the main kitty's cache.
  # * macos_quit_when_last_window_closed stays at its default (no) so the
  #   server survives dismissal and stays warm.
  launcher = pkgs.writeShellScriptBin "fzfmenu-launch" ''
    . /etc/profile.d/nix.sh

    # Toggle: a second press dismisses the launcher. Keyed on fzf, which only
    # lives while the window is up — the kitty server deliberately outlives it,
    # so the process is not a usable "is it open?" signal.
    if pgrep -f 'fzfmenu _controller' > /dev/null 2>&1; then
      pkill -f 'fzfmenu _controller'
      exit 0
    fi

    export KITTY_CACHE_DIRECTORY="$HOME/Library/Caches/fzfmenu"

    exec ${lib.getExe pkgs.kitty} \
      --single-instance --instance-group fzfmenu \
      --title fzfmenu \
      -o remember_window_size=no \
      -o remember_window_position=yes \
      -o initial_window_width=1000 \
      -o initial_window_height=800 \
      ${lib.getExe fzfmenu}
  '';

  # `--max-depth 2` keeps the list to real applications: depth 1 misses
  # ~/Applications/Home Manager Apps/*, and going deeper surfaces the helper
  # bundles nested inside other apps.
  appPicker = pkgs.writeShellScript "fzfmenu-app-picker" ''
    exec ${lib.getExe pkgs.fd} -L --max-depth 2 '\.app$' \
      /Applications "$HOME/Applications" /System/Applications \
      -x ${pkgs.coreutils}/bin/echo '{/}'
  '';

  # Candidates come straight from ~/.ssh/config (written by modules/cli-utils).
  # `Host` may list several names; wildcard/negation patterns are skipped.
  sshPicker = pkgs.writeShellScript "fzfmenu-ssh-picker" ''
    exec ${lib.getExe pkgs.gawk} '
      /^[[:space:]]*[Hh]ost[[:space:]]/ {
        for (i = 2; i <= NF; i++) if ($i !~ /[*?!]/) print $i
      }
    ' "$HOME/.ssh/config"
  '';

  # Runs inside the fzfmenu window. kitty propagates the caller's environment
  # to the window it creates, so exporting the ssh-agent socket here is what
  # makes the forwarded session work — the GUI-launched kitty server never had
  # SSH_AUTH_SOCK to begin with. No --instance-group: the session belongs in a
  # regular kitty window, with the regular config.
  sshRunner = pkgs.writeShellScript "fzfmenu-ssh-runner" ''
    export SSH_AUTH_SOCK="$(getconf DARWIN_USER_TEMP_DIR)/ssh-agent"
    exec ${lib.getExe pkgs.kitty} -1 -T "ssh:$FZFMENU_OUTPUT" \
      ${lib.getExe pkgs.openssh} "$FZFMENU_OUTPUT"
  '';
in
{
  options.my.modules.fzfmenu.enable = lib.mkEnableOption "fzfmenu launcher";

  config = lib.mkIf cfg.enable {
    home.packages = [
      fzfmenu
      launcher
    ];

    xdg.configFile."fzfmenu/config.toml".text = ''
      [[plugins]]
      name = "app_launcher"
      description = "Launch an application"
      prefix = ""
      picker = "${appPicker}"
      runner = '/usr/bin/open -a "$FZFMENU_OUTPUT"'

      [[plugins]]
      name = "ssh"
      description = "SSH into a host from ~/.ssh/config"
      prefix = "ssh "
      picker = "${sshPicker}"
      runner = "${sshRunner}"
      background = true
    '';
  };
}
