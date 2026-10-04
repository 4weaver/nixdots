{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.modules.sketchybar;
  palette = config.colorScheme.palette;
in
{
  options.my.modules.sketchybar.enable = lib.mkEnableOption "sketchybar status bar";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      sbar-inogai
      sketchybar-app-font
    ];

    xdg.configFile."sbar-inogai/config.lua".text = "return ${
      lib.generators.toLua { } (builtins.mapAttrs (key: value: "0xff${value}") palette)
    }";

    # launchd owns the bar daemon: start at login, restart if it dies. The
    # sbar-inogai wrapper execs sketchybar, which loads the lua config shipped
    # in the package; nothing else may start it, only send it events.
    #
    # Stale block: sbar-inogai's spaces and window-title components shell out to
    # `aerospace`, and the workspace block was refreshed by AeroSpace's
    # `exec-on-workspace-change`. AeroSpace is now dormant on the mba
    # (docs/adr/0005) and paneru has no equivalent hook, so those blocks no
    # longer update. Left enabled rather than silently removed; paneru's menu
    # bar indicator covers the need meanwhile.
    launchd.agents.sbar-inogai = {
      enable = true;
      config = {
        ProgramArguments = [ "${pkgs.sbar-inogai}/bin/sbar-inogai" ];
        RunAtLoad = true;
        KeepAlive = true;
        # spaces.lua/window_title.lua shell out to `aerospace`; keep the PATH
        # that finds it (and the rest of the profile's binaries).
        EnvironmentVariables.PATH =
          "${config.home.homeDirectory}/.nix-profile/bin:/usr/bin:/usr/sbin:/bin:/sbin";
      };
    };
  };
}
