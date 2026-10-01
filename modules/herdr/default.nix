{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.modules.herdr;

  quicklook = pkgs.callPackage ./herdr-quicklook.nix { };

  herdr = pkgs.nix-ai-tools.herdr;
  nu = lib.getExe pkgs.nushell;
in
{
  options.my.modules.herdr = {
    enable = lib.mkEnableOption "herdr terminal workspace manager";
    optionalDeps.enable = lib.mkEnableOption "optional deps for herdr";
  };

  config = lib.mkIf cfg.enable {
    programs.herdr = {
      enable = true;
      package = herdr;

      settings = {
        onboarding = false;

        terminal.default_shell = nu;

        keys = {
          detach = "prefix+d";

          command = [
            {
              key = "prefix+v";
              type = "plugin_action";
              command = "herdr-quicklook.hint";
              description = "hint-pick any openable token on screen";
            }
            {
              key = "prefix+f";
              type = "plugin_action";
              command = "herdr-quicklook.find";
              description = "fuzzy-find a file to open";
            }
            {
              key = "prefix+t";
              type = "popup";
              command = "exec ${nu}";
              description = "scratch popup terminal";
              width = "80%";
              height = "80%";
            }
          ];
        };

        ui = {
          prompt_new_tab_name = false;
          status_indicators = "symbols";
          toast.delivery = "terminal";
        };

        theme = {
          name = "terminal";
          auto_switch = false;
        };
      };
    };

    home.activation.herdrLinkPlugins = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run ${lib.getExe herdr} plugin link ${quicklook} || true
      run ${lib.getExe herdr} server reload-config || true
    '';

    home.packages = lib.mkIf cfg.optionalDeps.enable (with pkgs; [
      nushell
      jq
      bat
      glow
      chafa
      eza
      qsv
      delta
    ]);
  };
}
