{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.modules.herdr;
in
{
  options.my.modules.herdr = {
    enable = lib.mkEnableOption "herdr terminal workspace manager";

    shell = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.nushell;
      description = ''
        Shell for herdr's interactive panes. Null leaves herdr on its own
        default, which is `$SHELL`, then `/bin/sh`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # herdr comes from the llm-agents.nix pin, not nixpkgs, so every machine
    # runs one version (nixpkgs currently lags it). Same source as the agent
    # home; see machines/agent.nix.
    programs.herdr = {
      enable = true;
      package = pkgs.nix-ai-tools.herdr;

      # The shell is an absolute store path rather than a bare `nu`: herdr
      # spawns panes through its server, whose PATH is not the login shell's.
      # home.packages below keeps that path alive for the GC.
      settings = lib.optionalAttrs (cfg.shell != null) {
        terminal.default_shell = lib.getExe cfg.shell;
      };
    };

    home.packages = lib.optional (cfg.shell != null) cfg.shell;
  };
}
