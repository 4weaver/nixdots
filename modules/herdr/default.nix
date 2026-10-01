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

  # The plugin is a directory, not a program, so it is not a home.packages entry:
  # the activation script below names the path, which is what keeps the store path
  # alive for the GC.
  quicklook = pkgs.callPackage ./herdr-quicklook.nix { };

  herdrBin = lib.getExe pkgs.nix-ai-tools.herdr;
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

    quicklook.enable = lib.mkEnableOption "herdr-quicklook plugin (hint/find over openable tokens)";
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

    # Keeps the absolute shell path alive for the GC, plus the optional
    # renderers quicklook calls by name (resolved through the herdr server's
    # PATH, ~/.nix-profile/bin). jq is a hard requirement of the plugin; the
    # rest are what it degrades to plain less / ls -la without.
    home.packages =
      lib.optional (cfg.shell != null) cfg.shell
      ++ lib.optionals cfg.quicklook.enable (with pkgs; [
        jq
        bat
        glow
        chafa
        eza
        qsv
        delta
      ]);

    home.activation.herdrLinkPlugins = lib.mkIf cfg.quicklook.enable (
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        # `run` is Home Manager's activation helper (lib/bash/home-manager.sh):
        # it echoes under --dry-run instead of executing. DRY_RUN_CMD is
        # deprecated upstream and is not used anywhere in this repo.
        run ${herdrBin} plugin link ${quicklook} || true
        run ${herdrBin} server reload-config || true
      ''
    );
  };
}
