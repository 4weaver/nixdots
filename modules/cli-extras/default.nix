{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.modules.cli-extras;
in
{
  options.my.modules.cli-extras.enable = lib.mkEnableOption "Extra CLI utilities (personal, not for work machines)";

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      pandoc
      wakatime-cli

      (writeShellScriptBin "md2pdf" ''
        for f in "$@"; do
          pandoc -s --pdf-engine=xelatex \
            -V CJKmainfont='Noto Serif CJK HK' \
            -V papersize:a4 -V geometry:margin=1in \
            -o "''${f%.md}.pdf" "$f"
        done
      '')
    ];
  };
}