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

  # GUI-launched kitty (Dock/Raycast) gets launchd's bare PATH — nix PATH
  # only exists inside shells. So declare the profile paths explicitly here
  # and source the profile env files rather than depending on how kitty was
  # started: nix-daemon.sh for the system profile, hm-session-vars.sh for the
  # Home Manager session vars. zellij's panes then resolve nu (default_shell)
  # regardless of launch context.
  session = pkgs.writeShellScript "kitty-session" ''
    export PATH="${config.home.profileDirectory}/bin:/nix/var/nix/profiles/default/bin:$PATH"
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
    . ${config.home.profileDirectory}/etc/profile.d/hm-session-vars.sh
    export SSH_AUTH_SOCK="$(getconf DARWIN_USER_TEMP_DIR)/ssh-agent"
    exec ${lib.getExe pkgs.zellij} -l welcome
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
