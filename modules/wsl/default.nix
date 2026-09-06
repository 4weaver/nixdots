{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.modules.wsl;
in
{
  options.my.modules.wsl.enable = lib.mkEnableOption "WSL integration: open files and URLs in Windows applications";

  config = lib.mkIf cfg.enable {
    home.packages = [
      # Opens files (pdf, images, ...) and URLs in their Windows default
      # application from inside WSL.
      pkgs.wsl-open

      # Expose the same opener as `xdg-open` so Linux tools (yazi, neovim,
      # mailers, ...) that shell out to xdg-open route through Windows.
      (pkgs.writeShellScriptBin "xdg-open" ''
        exec ${lib.getExe pkgs.wsl-open} "$@"
      '')
    ];

    # BROWSER: tools that look for a browser use the same opener.
    # CLIPBOARD_BACKEND: lets Neovim discover the clipboard backend without
    # re-detecting (replaces the deleted modules/clipboard).
    home.sessionVariables = {
      BROWSER = "xdg-open";
      CLIPBOARD_BACKEND = "win32yank";
    };
  };
}
