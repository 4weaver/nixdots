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
    # Toggle: a second press dismisses the launcher. Keyed on fzf, which only
    # lives while the window is up — the kitty server deliberately outlives it,
    # so the process is not a usable "is it open?" signal.
    if /usr/bin/pgrep -f 'fzfmenu _controller' > /dev/null 2>&1; then
      /usr/bin/pkill -f 'fzfmenu _controller'
      exit 0
    fi

    # Nothing is inherited: --single-instance makes this server long-lived, so
    # its start environment is what every window it ever opens sees.
    # SSH_AUTH_SOCK is exported for the ssh plugin's windows.
    exec /usr/bin/env -i \
      HOME="$HOME" \
      USER="$(/usr/bin/id -un)" \
      TERM=xterm-kitty \
      TMPDIR=/tmp \
      PATH="${config.home.profileDirectory}/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
      SSH_AUTH_SOCK="$(/usr/bin/getconf DARWIN_USER_TEMP_DIR)/ssh-agent" \
      KITTY_CACHE_DIRECTORY="$HOME/Library/Caches/fzfmenu" \
      ${lib.getExe pkgs.kitty} \
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
  # kitty.app is excluded: `open -a` only activates a running kitty and never
  # opens a window — the `terminal` plugin below is the way in.
  appPicker = pkgs.writeShellScript "fzfmenu-app-picker" ''
    exec ${lib.getExe pkgs.fd} -L --max-depth 2 -E kitty.app '\.app$' \
      /Applications "$HOME/Applications" /System/Applications \
      -x ${pkgs.coreutils}/bin/echo '{/}'
  '';

  # One prefix for both: the local shell first, then every Host in ~/.ssh/config
  # (written by modules/cli-utils; both mean "give me a terminal somewhere").
  termPicker = pkgs.writeShellScript "fzfmenu-term-picker" ''
    printf '%s\n' "~/"
    exec ${lib.getExe pkgs.gawk} '
      /^[[:space:]]*[Hh]ost[[:space:]]/ {
        for (i = 2; i <= NF; i++) if ($i !~ /[*?!]/) print $i
      }
    ' "$HOME/.ssh/config"
  '';

  # `~/` or any path is a local window in that directory; anything else is an
  # ssh host, which needs the forwarded agent socket. `kitty -1` joins the
  # regular instance group, so these windows get the regular config and shell.
  termRunner = pkgs.writeShellScript "fzfmenu-term-runner" ''
    out="$FZFMENU_OUTPUT"
    [ "$out" = "~/" ] && out="$HOME"
    case "$out" in
      /*)
        exec ${lib.getExe pkgs.kitty} -1 -d "$out"
        ;;
    esac
    export SSH_AUTH_SOCK="$(/usr/bin/getconf DARWIN_USER_TEMP_DIR)/ssh-agent"
    exec ${lib.getExe pkgs.kitty} -1 -T "ssh:$out" \
      ${lib.getExe pkgs.openssh} "$out"
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
      name = "terminal"
      description = "Local terminal, or ssh to a host"
      prefix = "t "
      picker = "${termPicker}"
      runner = "${termRunner}"
      background = true
    '';
  };
}
