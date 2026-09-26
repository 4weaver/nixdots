# The shared nixpkgs rev is picked by a cache-miss survey, not taken from the tip

ADR-0002 put every machine's home on the server's `nixos-26.05` channel. That fixed the second-copy-of-nixpkgs problem but created another: the packages the homes pull from llm-agents.nix (`pi`, `omp`, `command-code`) are built by its CI against nixpkgs-unstable at whatever rev that commit's own flake.lock holds, and `fzfmenu` from NUR is in the same position. A release-channel nixpkgs — or the wrong unstable rev — puts those outputs off every binary cache and they compile here. Pin `d95fc36` did exactly that: hand-syncing the rev to the server's moved every llm-agents output off cache.numtide.com.

The main `nixpkgs` input now declares the `nixpkgs-unstable` branch URL, but the rev in the lock is **chosen**, not taken from the branch tip. From time to time (roughly monthly, or whenever a bump is wanted) run `scripts/pick-nixpkgs-rev.sh`: it surveys candidate revisions and reports how many derivations each would build locally across the three consumers this policy covers — nixpkgs (the homes and arachnet's system closure), nur (`fzfmenu`) and llm-agents.nix (`pi`/`omp`/`command-code`) — and the lowest total wins, ties going to the paired rev.

"Paired" because a candidate is really a (nixpkgs rev, llm-agents.nix commit) pair: those three outputs are in cache.numtide.com only when our nixpkgs is the rev that commit's flake.lock holds, so the default candidate list is the revs paired with the last few llm-agents.nix commits plus the unstable tip, and `--apply REV` moves the `nix-ai-tools` input to the paired commit along with the nixpkgs pin.

nixos-config pins the **same** rev (ADR-0008 there); `--apply` writes both checkouts' locks in one command. The two repos stay independent — no `follows` between them; the shared rev is the only coupling.

`nix flake update nixpkgs` is not the mechanism: it jumps to the tip and can silently rebuild the llm-agents outputs. The flake URLs stay on the branch; only the lock holds the chosen rev.

## Consequences

- Rev moves are decisions with a number attached; between surveys the lock does not drift.
- `nix-ai-tools` follows the main `nixpkgs`, so it needs no separate sync — but it moves when the pick pairs with a newer llm-agents.nix commit.
- ADR-0002's channel choice is superseded (unstable + survey pick instead of `nixos-26.05`), and its `handy` pin is void: the main input is nixpkgs-unstable now and serves `handy` from cache.nixos.org (the `nixpkgs-unstable` input is gone). The `qutebrowser` pin from `release-25.11` stands — aarch64-darwin still has no cached QtWebEngine for it.
- The mac home is not in the survey scoring (its eval does not finish on arachnet); it moves with the shared rev and shows any miss at switch time.
