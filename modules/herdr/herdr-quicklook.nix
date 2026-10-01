{
  lib,
  fetchFromGitHub,
  applyPatches,
}:

# Not a build: the plugin is a manifest plus shell scripts, so the pinned checkout
# with the one local patch applied IS the plugin directory herdr links.
applyPatches {
  name = "herdr-quicklook-0.7.0";

  src = fetchFromGitHub {
    owner = "dwarvesf";
    repo = "herdr-quicklook";
    rev = "b6567740aaceeabf8fd31c002c4936bfbf1523e6";
    hash = "sha256-J+Yo0z8ZdqiVgRIdBRQze1QAmSpCPu3atG0vGl1+yfU=";
  };

  patches = [ ./cjk-span-separator.patch ];

  # demo/ is 6.2M of recorded GIFs and tests/ is bats-only; no runtime path,
  # action, pane or link handler references either (release.sh is the sole
  # consumer of tests/, and it is not an entrypoint).
  postPatch = ''
    rm -rf demo tests
  '';
}
