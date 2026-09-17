# Nixdots

The flake that builds every machine's home-manager configuration.

## Language

**Machine**:
One home this flake builds, named by the user it belongs to (`inogai`, `alexlychen`, `agent`). Each has its own module under `machines/`.
_Avoid_: preset, host, profile, target

**Home**:
The home-manager configuration built for a machine — what `home-manager switch` or `nix build .#homeConfigurations.<machine>` activates.
_Avoid_: dotfiles, user config

**Machine module**:
`machines/<machine>.nix`. Everything that differs for one machine: username, home directory, packages, module toggles.
_Avoid_: preset, profile, host config

**Shared home**:
`home.nix` — what every machine's home has in common. Contains nothing machine-specific.
_Avoid_: base, common, global config

**Pinned package**:
A package taken from one of the extra nixpkgs inputs because the main one cannot serve it. Each pin records its reason beside it in `flake.nix`.
_Avoid_: override, workaround
