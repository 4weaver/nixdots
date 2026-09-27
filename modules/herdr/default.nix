{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.my.modules.herdr;

  tomlFormat = pkgs.formats.toml { };

  # The shell is an absolute store path rather than a bare `nu`: herdr spawns
  # panes through its server, whose PATH is not the login shell's.
  shellSettings = lib.optionalAttrs (cfg.shell != null) {
    terminal.default_shell = lib.getExe cfg.shell;
  };
in
{
  options.my.modules.herdr = {
    enable = lib.mkEnableOption "herdr terminal workspace manager";

    shell = lib.mkOption {
      type = lib.types.nullOr lib.types.package;
      default = pkgs.nushell;
      description = ''
        Shell for herdr's interactive panes. Owns `terminal.default_shell`;
        null leaves herdr on its own default (`$SHELL`, then `/bin/sh`).
      '';
    };

    settings = lib.mkOption {
      type = tomlFormat.type;
      default = { };
      description = ''
        The rest of herdr's config.toml: keybindings, theme, popups. Written
        to {file}`$XDG_CONFIG_HOME/herdr/config.toml` verbatim; see
        <https://herdr.dev/docs/configuration/>.
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

      settings = lib.recursiveUpdate cfg.settings shellSettings;
    };

    # Keeps the absolute shell path alive for the GC.
    home.packages = lib.optional (cfg.shell != null) cfg.shell;
  };
}
