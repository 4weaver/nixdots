# What every machine's home has in common. Per-machine settings live in
# ./machines/<name>.nix.
{
  nix-colors,
  ...
}:
{
  # colorScheme = nix-colors.colorSchemes.gruvbox-dark-medium;
  colorScheme = nix-colors.colorSchemes.catppuccin-mocha;

  home.stateVersion = "26.05";

  news.display = "silent";

  programs.home-manager.enable = true;

  wrappers.neovim.enable = true;
}
