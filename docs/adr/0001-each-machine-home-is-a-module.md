# Each machine's home is a module, not a row in a preset table

Per-machine data used to live in two tables keyed by a preset name — one in `flake.nix` pinning the system, one in `home.nix` holding username, packages and module toggles — and `home.nix` both looked the entry up by that name and branched on it (`preset == "mac"`, `preset == "arachnet" || preset == "agent"`). Adding a machine meant editing two tables and remembering every comparison; missing one silently misconfigured the new machine rather than failing.

Each machine is now a module: `flake.nix` generates the arguments that vary only by system and appends `./machines/<name>.nix`, so a machine's settings are ordinary options written in one place. The name lookup and every name comparison are gone.

## Considered Options

- **Keep the tables and branch on declared capability flags** (`gui`, `server`) instead of names. Rejected: the flags still have to be added to each table by hand and kept in step with the machine list, which is the failure being removed.
- **Pass the whole table entry into `home.nix` via `extraSpecialArgs`.** Rejected: same hand-maintained coupling, just a different lookup.

## Consequences

A machine's settings can no longer half-exist: everything for it is in one file, and a setting that is absent falls back to the module system's default rather than to another machine's value. `home.nix` shrinks to what every machine shares.
