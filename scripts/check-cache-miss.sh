#!/usr/bin/env bash
#
# check-cache-miss — before adding a package or switching a home, ask who will
# build it. Prints, per installable, the output path, whether that output is in
# the local store or in each configured binary cache, and how many derivations
# a local build would run here.
#
# An argument containing "(" is read as a Nix expression, anything else as a
# flake installable. Exits 1 when something would have to be built here — a
# whole home always builds its own activation scripts, so for a home read the
# count, not the exit code.
#
#   check-cache-miss '(...).inputs.nix-ai-tools.packages.x86_64-linux.omp'
#   check-cache-miss .#homeConfigurations.alexlychen.activationPackage
#   SUBS="https://cache.numtide.com" check-cache-miss '(...).omp'   # probe one
#   NIX_ARGS="--override-input nixpkgs github:NixOS/nixpkgs/<rev>" check-cache-miss .#…
#
# NIX_ARGS is word-split and appended to every nix invocation (pick-nixpkgs-rev
# uses it to probe a candidate revision without touching the lock).
# Run it from the directory of the flake whose lock you are testing.
set -uo pipefail

if [ $# -eq 0 ]; then
  sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'
  exit 2
fi

subs=${SUBS:-$(nix config show 2>/dev/null | sed -n 's/^substituters = //p' | tr ' ' '\n')}
read -r -a xtra <<<"${NIX_ARGS:-}"
status=0

for inst in "$@"; do
  printf '\n== %s\n' "$inst"
  case $inst in
    *'('*) pref=(--impure --expr) ;;
    *)     pref=() ;;
  esac

  out=$(nix eval --raw "${pref[@]}" "${xtra[@]}" "${inst}.outPath" 2>/dev/null) || out=
  if [ -n "$out" ]; then
    printf '   output   %s\n' "${out#/nix/store/}"
    nix path-info "$out" >/dev/null 2>&1 && printf '   store    present\n' || printf '   store    absent\n'
    for sub in $subs; do
      [ -n "$sub" ] || continue
      if nix path-info --store "$sub" "$out" >/dev/null 2>&1; then
        printf '   cache    HIT   %s\n' "$sub"
      else
        printf '   cache    miss  %s\n' "$sub"
      fi
    done
  else
    printf '   output   (could not evaluate .outPath)\n'
  fi

  if ! dry=$(nix build --dry-run --no-link --no-write-lock-file "${pref[@]}" "${xtra[@]}" "$inst" 2>&1); then
    printf '   error    %s\n' "$(printf '%s' "$dry" | grep -m1 '^error' || echo 'evaluation failed')"
    status=1
    continue
  fi

  built=$(printf '%s' "$dry" | grep -oE '^these [0-9]+ derivations will be built' | grep -oE '[0-9]+')
  fetch=$(printf '%s' "$dry" | grep -oE '^these [0-9]+ paths will be fetched \([^)]*\)')
  printf '   build    %s derivation(s) would be built here\n' "${built:-0}"
  [ -n "$fetch" ] && printf '   fetch    %s\n' "$fetch"
  # Name them while the list is short enough to read; a miss on one pinned
  # package shows up here as its own toolchain, which is the whole point.
  if [ "${built:-0}" -gt 0 ] && [ "${built:-0}" -le 30 ]; then
    printf '%s' "$dry" | grep -E '^  /nix/store/.*\.drv$' | sed 's|.*-[0-9a-z]\{32\}-|              |; s|\.drv$||'
  fi
  [ -n "$built" ] && status=1
done

exit $status
