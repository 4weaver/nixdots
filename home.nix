{
  config,
  lib,
  pkgs,
  nix-colors,
  preset,
  ...
}:
let
  # Presets control everything that differs between machines:
  #   username / homeDirectory, mac-only packages, and per-preset module
  #   toggles. Switch machine by building a different configuration:
  #
  #   nix build .#homeConfigurations.inogai.activationPackage     # mac
  #   nix build .#homeConfigurations.alexlychen.activationPackage # windows
  #   nix build .#homeConfigurations.arachnet.activationPackage   # arachnet (server)
  #
  # Or with home-manager's standalone CLI:
  #
  #   home-manager switch --flake .#inogai      # mac
  #   home-manager switch --flake .#alexlychen  # windows (WSL)
  #
  # arachnet is consumed as a NixOS module from the nixos-config repo (see
  # flake.nix `nixosModules.inogai-arachnet`), so its preset only carries the
  # module toggles here; `nixos-rebuild switch` on arachnet activates it.
  presets = {
    mac = {
      username = "inogai";
      homeDirectory = "/Users/inogai";
      # Mac-only GUI packages. Referenced via `pkgs` rather than a bare
      # `with` so this list stays valid outside of `home.packages`.
      packages = with pkgs; [
        raycast
        shottr
        handy

        # pi coding agent; all ~/.pi config is a live git repo it manages
        # itself (nothing under ~/.pi is declared in home-manager).
        nix-ai-tools.pi
      ];
      modules = {
        aerospace.enable = true;
        fonts.enable = true;
        jankyborders.enable = true;
        kitty.enable = true;
        kitty.mapShiftSpaceToCxSpace = true;
        qutebrowser.enable = true;
        sketchybar.enable = true;
        syncthing.enable = true;

        zellij.keyLayout = "mac";

        gpg.pinentry = "touchid";

        # CLI stack (previously in the shared block — now per-preset).
        cli-utils.enable = true;
        direnv.enable = true;
        gpg.enable = true;
        shell.enable = true;
        shell.zsh.enable = true; # macOS's login shell is zsh
        tui-apps.enable = true;
        yazi.enable = true;
        zellij.enable = true;
      };
    };
    windows = {
      username = "alexlychen";
      homeDirectory = "/home/alexlychen";
      packages = [ pkgs.nix-ai-tools.pi ];
      modules = {
        # Mac-only modules are intentionally disabled here.

        wsl.enable = true;
        zellij.keyLayout = "windows";

        gpg.pinentry = "curses";

        # CLI stack (previously in the shared block — now per-preset).
        # shell.zsh stays off — Windows doesn't need zsh.
        cli-utils.enable = true;
        direnv.enable = true;
        gpg.enable = true;
        shell.enable = true;
        tui-apps.enable = true;
        yazi.enable = true;
        zellij.enable = true;
      };
    };
    arachnet = {
      username = "inogai";
      homeDirectory = "/home/inogai";
      packages = [ ];
      modules = {
        # Lean server CLI: shell (nushell/atuin/carapace/starship/zoxide —
        # no zsh, no direnv), lazygit, yazi. No zellij/cli-utils/gpg/pi.
        shell.enable = true;
        tui-apps.enable = true;
        yazi.enable = true;
      };
    };
  };

  cfg = presets.${preset};
in
{

  # colorScheme = nix-colors.colorSchemes.gruvbox-dark-medium;
  colorScheme = nix-colors.colorSchemes.catppuccin-mocha;

  home.username = cfg.username;
  home.homeDirectory = cfg.homeDirectory;
  home.stateVersion = "26.05";

  news.display = "silent";

  programs.home-manager.enable = true;

  home.packages = cfg.packages ++ [
    pkgs.nodejs
  ];

  # Only the mac preset needs unfree GUI apps (raycast/shottr). Guarded by
  # preset so the arachnet NixOS module (useGlobalPkgs = true) doesn't set
  # nixpkgs.config at all — home-manager forbids nixpkgs.* options together
  # with useGlobalPkgs.
  nixpkgs.config.allowUnfreePredicate = lib.mkIf (preset == "mac") (
    pkg:
    builtins.elem (pkgs.lib.getName pkg) [
      "raycast"
      "shottr"
    ]
  );

  wrappers.neovim.enable = true;

  # nvim language extras: the nvim-inogai module defaults every group to ON.
  # arachnet (server) keeps nvim lean — disable all eight explicitly.
  # Mac/windows keep the defaults. The option lives under the wrapper
  # namespace because nvim-inogai's home module is a getInstallModule
  # wrapper (optionLocation = ["wrappers" "neovim"]).
  wrappers.neovim.extras.lang = lib.mkIf (preset == "arachnet") {
    nix.enable = false;
    lua.enable = false;
    java.enable = false;
    json.enable = false;
    c.enable = false;
    csharp.enable = false;
    javascript.enable = false;
    angular.enable = false;
  };

  my.modules = cfg.modules;
}
