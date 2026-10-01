{ pkgs, ... }:
{
  home.username = "agent";
  home.homeDirectory = "/home/agent";

  # nvim-inogai defaults every language group to ON, but arachnet already
  # carries the toolchains. The option sits under `wrappers` because
  # nvim-inogai's home module is a getInstallModule wrapper.
  wrappers.neovim.extras.lang = {
    nix.enable = false;
    lua.enable = false;
    java.enable = false;
    json.enable = false;
    c.enable = false;
    csharp.enable = false;
    javascript.enable = false;
    angular.enable = false;
  };

  # Lean agent CLI: shell (nushell/atuin/carapace/starship/zoxide — no zsh,
  # no direnv) plus yazi. yazi is not on the system nor in the agent nix
  # profile, so the home has to provide it. lazygit/cli-utils/gpg/zellij
  # stay off — they already exist; no nodejs either, the machine has
  # nodejs_22.
  my.modules = {
    shell.enable = true;
    yazi.enable = true;

    herdr = {
      enable = true;
      optionalDeps.enable = true;
    };
  };
}
