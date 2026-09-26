#!/usr/bin/env bash
#
# pick-nixpkgs-rev — the periodic nixpkgs revision survey (nixdots docs/adr/0003,
# nixos-config docs/adr/0008).
#
# Policy: from time to time (roughly monthly, or whenever a bump is wanted),
# survey a few candidate nixpkgs-unstable revisions and keep the one with the
# fewest binary-cache misses across the three consumers the two repos care
# about — nixpkgs (the homes + the arachnet system closure), nur (fzfmenu) and
# llm-agents.nix (pi/omp/command-code) — then pin nixdots AND nixos-config to
# it. The flake URLs stay on the branch; only the lock holds the chosen rev.
#
# A candidate is really a (nixpkgs rev, llm-agents.nix commit) pair: pi/omp/
# command-code sit in cache.numtide.com only for the nixpkgs rev that commit's
# own flake.lock holds, so the default candidate list is the revs paired with
# the last few llm-agents.nix commits, plus the nixpkgs-unstable tip.
#
#   pick-nixpkgs-rev.sh                 survey the default candidates
#   pick-nixpkgs-rev.sh --rev REV ...   survey exactly these revs (unpaired)
#   pick-nixpkgs-rev.sh --count N       llm-agents commits to pair (default 4)
#   pick-nixpkgs-rev.sh --apply REV     pin nixdots + nixos-config to REV
#
# Score per candidate = derivations `nix build --dry-run` would build locally,
# summed over the probes. Lowest wins; ties go to the paired rev. A survey is
# read-only (input overrides + --no-write-lock-file, no lock writes); only
# --apply edits the two flake.locks.
#
# Requires: gh (authenticated), nix, jq. Run from anywhere.
set -uo pipefail

HERE=$(cd "$(dirname "$0")" && pwd)
NIXDOTS=$(dirname "$HERE")
NIXOS_NIX=${NIXOS_CONFIG_DIR:-$NIXDOTS/../nixos-config}/nixos
CHECK="$HERE/check-cache-miss.sh"
SUBS="https://cache.nixos.org https://cache.numtide.com https://inogai.cachix.org"
SYS=x86_64-linux

count=4
apply=
declare -a extra_revs=()
while [ $# -gt 0 ]; do
  case $1 in
    --count) count=$2; shift 2 ;;
    --apply) apply=$2; shift 2 ;;
    --rev) extra_revs+=("$2"); shift 2 ;;
    -h|--help) sed -n '3,28p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "pick-nixpkgs-rev: unknown argument '$1'" >&2; exit 2 ;;
  esac
done

lock_rev() {  # $1=lock file, $2=owner, $3=repo -> first matching locked rev
  jq -r --arg o "$2" --arg r "$3" \
    '[.nodes[] | select((.locked.owner? // "") == $o and (.locked.repo? // "") == $r) | .locked.rev][0] // empty' \
    "$1"
}

# --- candidates: nixpkgs revs paired with recent llm-agents.nix commits -------
declare -A pair_of=()   # nixpkgs rev -> llm-agents.nix commit that holds it
declare -a cand=()
while read -r L; do
  [ -n "$L" ] || continue
  R=$(gh api "repos/numtide/llm-agents.nix/contents/flake.lock?ref=$L" --jq .content 2>/dev/null \
      | base64 -d 2>/dev/null \
      | jq -r '[.nodes[] | select((.locked.owner? // "") == "NixOS" and (.locked.repo? // "") == "nixpkgs") | .locked.rev][0] // empty')
  [ -n "$R" ] || continue
  if [ -z "${pair_of[$R]:-}" ]; then pair_of[$R]=$L; cand+=("$R"); fi
done < <(gh api "repos/numtide/llm-agents.nix/commits?per_page=$count" --jq '.[].sha' 2>/dev/null)

tip=$(gh api repos/NixOS/nixpkgs/commits/nixpkgs-unstable --jq .sha 2>/dev/null)
if [ -n "$tip" ] && [ -z "${pair_of[$tip]:-}" ]; then
  # keep the tip first: it is the freshness floor every other candidate competes with
  cand=("$tip" "${cand[@]}")
fi
# the pin we have is always a candidate — the survey must be able to say "keep it"
cur_R=$(lock_rev "$NIXDOTS/flake.lock" NixOS nixpkgs)
cur_L=$(lock_rev "$NIXDOTS/flake.lock" numtide llm-agents.nix)
if [ -n "$cur_R" ] && [ -z "${pair_of[$cur_R]:-}" ]; then
  pair_of[$cur_R]=$cur_L
  cand+=("$cur_R")
fi
for R in "${extra_revs[@]}"; do
  [ -n "${pair_of[$R]:-}" ] || pair_of[$R]=""
done
if [ ${#extra_revs[@]} -gt 0 ]; then
  cand=("${extra_revs[@]}")   # explicit --rev list replaces the default survey set
fi

if [ -n "$apply" ]; then
  L=${pair_of[$apply]:-}
  if [ -z "$L" ]; then L=$(lock_rev "$NIXDOTS/flake.lock" numtide llm-agents.nix); fi
  echo "pinning nixdots and nixos-config to $apply${L:+ (llm-agents.nix $L)}"
  ( cd "$NIXDOTS" && nix flake lock \
      --override-input nixpkgs "github:NixOS/nixpkgs/$apply" \
      ${L:+--override-input nix-ai-tools "github:numtide/llm-agents.nix/$L"} ) || exit 1
  ( cd "$NIXOS_NIX" && nix flake lock \
      --override-input nixpkgs "github:NixOS/nixpkgs/$apply" ) || exit 1
  # --override-input rewrites "original" to the rev URL; the flakes declare the
  # branch URL, so put it back — lock holds the rev, flake.nix keeps the branch.
  python3 - "$NIXDOTS/flake.lock" "$NIXOS_NIX/flake.lock" "$L" <<'EOF'
import json, sys
def fix(path, name, orig, only_if_rev=None):
    d = json.load(open(path))
    node = d['nodes']['root']['inputs'].get(name)
    if not node: return
    if only_if_rev and d['nodes'][node].get('locked', {}).get('rev') != only_if_rev:
        return
    if d['nodes'][node].get('original') != orig:
        d['nodes'][node]['original'] = orig
        with open(path, 'w') as f:
            json.dump(d, f, indent=2)
            f.write('\n')
        print(f"  original[{name}] restored in {path}")
branch = {"owner": "NixOS", "repo": "nixpkgs", "ref": "nixpkgs-unstable", "type": "github"}
fix(sys.argv[1], "nixpkgs", branch)
fix(sys.argv[2], "nixpkgs", branch)
if len(sys.argv) > 3 and sys.argv[3]:
    fix(sys.argv[1], "nix-ai-tools",
        {"owner": "numtide", "repo": "llm-agents.nix", "type": "github"},
        only_if_rev=sys.argv[3])
EOF
  echo "--- nixdots";        git -C "$NIXDOTS" diff --stat flake.lock
  echo "--- nixos-config";   git -C "$(dirname "$NIXOS_NIX")" diff --stat nixos/flake.lock
  exit 0
fi

if [ ${#cand[@]} -eq 0 ]; then
  echo "pick-nixpkgs-rev: no candidates (gh api failed?)" >&2
  exit 2
fi

cur_L=${cur_L:-$(lock_rev "$NIXDOTS/flake.lock" numtide llm-agents.nix)}
nur_L=$(lock_rev "$NIXDOTS/flake.lock" nix-community NUR)
echo "candidates: ${#cand[@]}  (llm-agents.nix pairing, current lock: ${cur_L:-none}; nur: ${nur_L:0:12})"

# probe <label> <dir> <nix-args> <installable>; adds one row to the report
declare -a rows=()
probe() {
  local label=$1 dir=$2 args=$3 inst=$4 out builds hit names
  out=$(cd "$dir" && NIX_ARGS="$args" SUBS="$SUBS" "$CHECK" "$inst" 2>/dev/null) || true
  builds=$(printf '%s\n' "$out" | sed -n 's/^   build    \([0-9][0-9]*\) derivation.*/\1/p')
  hit=$(printf '%s\n' "$out" | sed -n 's/^   cache    HIT   //p' | paste -sd, -)
  # check-cache-miss names the builds when the list is short; keep them —
  # "a miss on one pinned package shows up here as its own toolchain".
  names=$(printf '%s\n' "$out" | sed -n 's/^              \(\S\)/                \1/p')
  if [ -z "$builds" ]; then
    rows+=("   $(printf '%-24s' "$label") ERROR  $(printf '%s' "$out" | sed -n 's/^   error    //p' | head -1)")
    total=$(( ${total:-0} + 9999 ))
  else
    rows+=("   $(printf '%-24s' "$label") build $(printf '%4s' "$builds")${hit:+   HIT $hit}")
    [ -n "$names" ] && rows+=("$names")
    total=$(( ${total:-0} + builds ))
  fi
}

declare -a summary=()
for R in "${cand[@]}"; do
  L=${pair_of[$R]:-${cur_L:-}}
  total=0
  rows=()
  echo
  echo "== nixpkgs ${R:0:12}${L:+  (llm-agents.nix ${L:0:12}${pair_of[$R]:+ paired})}"
  ov="--accept-flake-config --override-input nixpkgs github:NixOS/nixpkgs/$R"
  [ -n "$L" ] && ov="$ov --override-input nix-ai-tools github:numtide/llm-agents.nix/$L"

  [ -n "$L" ] && probe "llm-agents pi"            "$NIXDOTS" "$ov" "github:numtide/llm-agents.nix/$L#pi"
  [ -n "$L" ] && probe "llm-agents omp"           "$NIXDOTS" "$ov" "github:numtide/llm-agents.nix/$L#omp"
  [ -n "$L" ] && probe "llm-agents command-code"  "$NIXDOTS" "$ov" "github:numtide/llm-agents.nix/$L#command-code"
  if [ -n "$nur_L" ]; then
    probe "nur fzfmenu" "$NIXDOTS" "" \
      "(let np = builtins.getFlake \"github:NixOS/nixpkgs/$R\"; nur = builtins.getFlake \"github:nix-community/NUR/$nur_L\"; in (np.legacyPackages.$SYS.extend nur.overlays.default).nur.repos.inogai.fzfmenu)"
  fi
  probe "home agent"       "$NIXDOTS" "$ov" ".#homeConfigurations.agent.activationPackage"
  probe "home alexlychen"  "$NIXDOTS" "$ov" ".#homeConfigurations.alexlychen.activationPackage"
  # home inogai (mac) is not probed: its eval does not finish on arachnet in any
  # useful time. The mac shares the same nixpkgs axis as the probes above, and
  # its own misses show up at switch time.
  probe "arachnet toplevel" "$NIXOS_NIX" \
    "--accept-flake-config --override-input nixpkgs github:NixOS/nixpkgs/$R" \
    ".#nixosConfigurations.arachnet.config.system.build.toplevel"

  printf '%s\n' "${rows[@]}"
  printf '   %-24s TOTAL %s\n' "" "$total"
  summary+=("$(printf '%-14s %8s %8d  %s' "${R:0:12}" "${L:0:12}" "$total" "${pair_of[$R]:+paired}")")
done

echo
echo "== summary (rev / llm-agents / local builds)"
printf '%s\n' "${summary[@]}"
echo
echo "lowest total wins; ties go to the paired rev (pi/omp/command-code hit cache.numtide.com)."
echo "apply with:  $0 --apply <rev>"
