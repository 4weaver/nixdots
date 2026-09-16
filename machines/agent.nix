{ ... }:
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
  # no direnv). No yazi/lazygit/cli-utils/gpg/zellij, which are already on
  # the system or in the agent nix profile, and no nodejs either: the
  # machine has nodejs_22.
  my.modules = {
    shell.enable = true;
  };
}
