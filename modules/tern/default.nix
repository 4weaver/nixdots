{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.modules.tern;

  # Tern ships as a signed, self-updating bundle in /Applications, so there is
  # nothing to package: the CLI *is* the app's binary, the same executable that
  # serves the GUI. Pointing at the bundle rather than a copy means a Tern
  # update is picked up without touching this module.
  ternBin = "/Applications/Tern.app/Contents/MacOS/tern";
in
{
  options.my.modules.tern.enable = lib.mkEnableOption "Tern's command line (`tern`)";

  config = lib.mkIf cfg.enable {
    # A wrapper, not a symlink. On macOS the running image's path comes from
    # _NSGetExecutablePath, which reports a symlink's own location, and Tern
    # loads its fonts and the rest of its assets from `../Resources/assets`
    # relative to it. A profile symlink therefore dies at startup with
    # "cannot load the page fonts"; exec'ing the real binary keeps the bundle
    # layout the binary expects. ./fzfmenu/copyq.nix wraps for the same reason.
    #
    # Tern already puts its own binary on PATH inside its panes, so this is
    # only for the shells outside it: kitty, zellij, ssh, scripts.
    home.packages = [
      (pkgs.writeShellScriptBin "tern" ''
        exec ${ternBin} "$@"
      '')
    ];
  };
}
