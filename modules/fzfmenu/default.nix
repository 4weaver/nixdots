{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.modules.fzfmenu;

  fzfmenu = pkgs.nur.repos.inogai.fzfmenu;

  # nixpkgs only builds CopyQ for Linux, hence the local derivation. Its server
  # owns the pasteboard, so there is no capture step to arrange here.
  copyq = pkgs.callPackage ./copyq.nix { };

  # The bundle's binary, not $out/bin/copyq: CopyQ finds its plugins — the item
  # plugins that handle images included — relative to the executable's path.
  copyqBin = "${copyq}/Applications/CopyQ.app/Contents/MacOS/CopyQ";

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

  # One line per item, "<row>\t<summary>", newest first (row 0). getItem() hands
  # back every MIME type, so this is a single `copyq eval` run rather than a call
  # per item; the row travels in the item text to reach the runner.
  clipPicker = pkgs.writeShellScript "fzfmenu-clip-picker" ''
    exec ${copyqBin} eval -- '
      var out = [];
      for (var i = 0; i < size(); ++i) {
        var item = getItem(i), formats = Object.keys(item), image = "";
        for (var f = 0; f < formats.length; ++f)
          if (formats[f].indexOf("image/") === 0) image = formats[f];
        var label = item[mimeText] !== undefined ? str(item[mimeText])
          : item[mimeUriList] !== undefined ? str(item[mimeUriList])
          : image !== "" ? "[" + image + " " + item[image].length + "B]"
          : "[" + formats.join(", ") + "]";
        print(i + "\t" + label.replace(/[ \t\r\n]+/g, " ").trim().substring(0, 120) + "\n");
      }
    '
  '';

  # fzf substitutes the highlighted item for `{}`, so field 1 of the whole line
  # is the row; dropping up to the last space strips whatever prefix it carries.
  clipShow = pkgs.writeShellScript "fzfmenu-clip-show" ''
    row="$(printf '%s' "$1" | cut -f1)"
    row="''${row##* }"
    [ -n "$row" ] || exit 0
    case "$row" in *[!0-9]*) exit 0 ;; esac

    # An image item has no text, so the bytes go to a file and kitty draws them
    # into the pane fzf reserved. --clear because images outlive the text drawn
    # around them.
    image="$(${copyqBin} eval -- '
      var item = getItem(parseInt(str(arguments[1]))), formats = Object.keys(item), found = "";
      for (var i = 0; i < formats.length; ++i)
        if (formats[i].indexOf("image/") === 0) found = formats[i];
      print(found);' "$row")"

    if [ -n "$image" ]; then
      tmp="$(/usr/bin/mktemp "''${TMPDIR:-/tmp}/fzfmenu-clip.XXXXXX")"
      ${copyqBin} read "$image" "$row" > "$tmp"
      # PNG is what macOS puts on the pasteboard anyway; anything else goes
      # through sips so kitty can decode it.
      if [ "$image" != "image/png" ]; then
        /usr/bin/sips -s format png "$tmp" --out "$tmp.png" > /dev/null
        tmp="$tmp.png"
      fi
      ${lib.getExe pkgs.kitty} +kitten icat --clear \
        --place "''${FZF_PREVIEW_COLUMNS:-80}x''${FZF_PREVIEW_LINES:-24}@0x0" "$tmp"
      rm -f "$tmp"
      exit 0
    fi

    ${copyqBin} eval -- '
      var item = getItem(parseInt(str(arguments[1])));
      print(item[mimeText] !== undefined ? str(item[mimeText]).substring(0, 4000)
        : Object.keys(item).join(", ") + "\n");' "$row"
  '';

  # `select` copies the row back with every format it holds — which is how an
  # image comes back as an image — and floats it to the top (config move=true).
  clipRunner = pkgs.writeShellScript "fzfmenu-clip-runner" ''
    row="$(printf '%s' "$FZFMENU_OUTPUT" | cut -f1)"
    row="''${row##* }"
    [ -n "$row" ] || exit 1
    case "$row" in *[!0-9]*) exit 1 ;; esac
    exec ${copyqBin} select "$row"
  '';

in
{
  options.my.modules.fzfmenu.enable = lib.mkEnableOption "fzfmenu launcher";

  config = lib.mkIf cfg.enable {
    home.packages = [
      fzfmenu
      launcher
      copyq
    ];

    # CopyQ's server is the whole capture side. With no arguments it stays in the
    # foreground and shows no window, so launchd has something to supervise —
    # --start-server would detach and leave launchd restarting a dead process.
    launchd.agents.copyq = {
      enable = true;
      config = {
        ProgramArguments = [ copyqBin ];
        RunAtLoad = true;
        KeepAlive = true;
      };
    };

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

      [[plugins]]
      name = "clipboard"
      description = "Clipboard history; pick an entry to paste it back"
      prefix = "cl "
      picker = "${clipPicker}"
      preview = "${clipShow} {}"
      runner = "${clipRunner}"
    '';
  };
}
