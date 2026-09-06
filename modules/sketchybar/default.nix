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
    # in the package; aerospace only sends it events, it must not start it.
    launchd.agents.sbar-inogai = {
      enable = true;
      config = {
        ProgramArguments = [ "${pkgs.sbar-inogai}/bin/sbar-inogai" ];
        RunAtLoad = true;
        KeepAlive = true;
        # spaces.lua shells out to `aerospace`; same PATH the aerospace module
        # gives its own exec'd commands.
        EnvironmentVariables.PATH =
          "${config.home.homeDirectory}/.nix-profile/bin:/usr/bin:/usr/sbin:/bin:/sbin";
      };
    };
  };
}
