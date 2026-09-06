{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.my.modules.shell;
in
{
  options.my.modules.shell = {
    enable = lib.mkEnableOption "shell tools (nushell, atuin, carapace, starship, zoxide)";

    zsh = {
      enable = lib.mkEnableOption "zsh (only needed where the OS login shell is zsh)";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = with pkgs; [
      vivid
    ];

    home.sessionVariables = {
      EDITOR = "nvim";
    };

    home.shellAliases = {
      nv = "nvim";
    } // lib.optionalAttrs config.my.modules.zellij.enable {
      zj = "zellij";
    };

    programs.nushell = {
      enable = true;
      settings = {
        show_banner = false;
        completions.algorithm = "fuzzy";
      };
      extraConfig = ''
        $env.LS_COLORS = (vivid generate catppuccin-mocha)
      '';
      environmentVariables = config.home.sessionVariables;
      shellAliases = config.home.shellAliases;
    };

    programs.atuin = {
      enable = true;
      enableNushellIntegration = true;
      settings = {
        enter_accept = false;
      };
    };

    programs.carapace = {
      enable = true;
      enableNushellIntegration = true;
    };

    programs.starship = {
      enable = true;
      enableNushellIntegration = true;
      settings = {
        add_newline = false;
        character = {
          success_symbol = "[➜](bold green)";
          error_symbol = "[➜](bold red)";
        };
        os.disabled = false;
        os.format = "on [$symbol]($style)";
        os.symbols = {
          Macos = " ";
          Debian = " ";
          Windows = " ";
        };
        time.disabled = false;
        format = lib.concatStringsSep "" [
          "$all"
          "$time"
          "$os"
          "$line_break"
          "$jobs"
          "$character"
        ];
      };
    };

    programs.zoxide = {
      enable = true;
      enableNushellIntegration = true;
    };

    programs.zsh = lib.mkIf config.my.modules.shell.zsh.enable {
      enable = true;
    };
  };
}
