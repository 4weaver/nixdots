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
      wakatime-cli
    ];
  };
}