{
  config,
  lib,
  pkgs,
  ...
}:
let
  colorscheme = import ./colorscheme.nix { inherit config lib; };
  fonts = import ./fonts.nix;

  cfg = config.my.modules.kitty;

  # A fixed environment rather than the caller's: a GUI-launched kitty gets
  # launchd's PATH, and zellij keys its socket directory off TMPDIR. TERMINFO and
  # KITTY_* are passed through because kitty itself owns them. zellij is exec'd,
  # so there is deliberately no fallback shell.
  session = pkgs.writeShellScript "kitty-session" ''
    exec /usr/bin/env -i \
      HOME="$HOME" \
      USER="$(/usr/bin/id -un)" \
      TERM="$TERM" \
      TERMINFO="$TERMINFO" \
      LANG="$LANG" \
      KITTY_INSTALLATION_DIR="$KITTY_INSTALLATION_DIR" \
      KITTY_PID="$KITTY_PID" \
      KITTY_PUBLIC_KEY="$KITTY_PUBLIC_KEY" \
      KITTY_WINDOW_ID="$KITTY_WINDOW_ID" \
      KITTY_LISTEN_ON="$KITTY_LISTEN_ON" \
      TMPDIR=/tmp \
      PATH="${config.home.profileDirectory}/bin:/nix/var/nix/profiles/default/bin:/usr/bin:/bin:/usr/sbin:/sbin" \
      SSH_AUTH_SOCK="$(/usr/bin/getconf DARWIN_USER_TEMP_DIR)/ssh-agent" \
      ${lib.getExe pkgs.zellij} -l welcome
  '';
in
{
  options.my.modules.kitty = {
    enable = lib.mkEnableOption "Kitty Terminal";
    font = lib.mkOption {
      type = lib.types.enum [ "plex" "victor" ];
      default = "plex";
      description = "Font for Kitty";
    };
    mapShiftSpaceToCxSpace = lib.mkEnableOption "mapping shift+space to C-x then space";
  };

  config = lib.mkIf cfg.enable {
    programs.kitty = lib.mkMerge (
      [
        fonts.${cfg.font}
        fonts.nerdFontOverrides
        colorscheme
        {
          enable = true;
          settings = {
            shell = "${session} -l welcome";
            font_size = 20;

            # OS Specific
            confirm_os_window_close = 0;
            hide_window_decorations = "titlebar-only";
            macos_option_as_alt = "yes";
            clear_all_shortcuts = "yes";

            # Remote Control
            allow_remote_control = "yes";
            listen_on = "unix:/tmp/kitty.sock";

            # Cursor Trail
            cursor_trail = 3;
            cursor_trail_decay = "0.3 0.6";
            cursor_trail_start_threshold = 0;

            # Background
            # background_opacity = 0.93;
            # background_blur = 32;
            # transparent_background_colors = "#202020@0.93 #181818@0.93 #333333@0.93";
          };
          extraConfig = ''
            # Underline Adjustments
            modify_font underline_position 130% - 2
            modify_font underline_thickness 2

            # Input Handling
            mouse_map left click ungrabbed mouse_handle_click selection link prompt
            mouse_map cmd+left release grabbed,ungrabbed mouse_handle_click link

            map cmd+c copy_to_clipboard
            map cmd+v paste_from_clipboard
            map cmd+r load_config_file
            map cmd+shift+equal change_font_size current +1.0
            map cmd+shift+minus change_font_size current -1.0
            map shift+page_up scroll_page_up
            map shift+page_down scroll_page_down
          '';
        }
      ]
      ++ lib.optional cfg.mapShiftSpaceToCxSpace {
        extraConfig = ''
          # Map shift+space to C-x then space
          map shift+space send_text all \x18\x20
        '';
      }
    );
  };
}
