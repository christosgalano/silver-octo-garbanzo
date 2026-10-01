#!/usr/bin/env bash
# Works out what a change touches, so CI tests and plans only what it has to.
#
#   modules/<m> changed                         ->  test <m>, test every stack, plan every environment
#   stacks/<s> changed                          ->  test <s>, plan every environment
#   live/<e>                                    ->  plan <e>
#   policy/, .github/, trivy.yaml, .tflint.hcl  ->  plan every environment (the gates themselves changed)
#
# Usage: changes.sh <base-sha> [head-sha]
# Writes `units` and `environments` (JSON arrays) to $GITHUB_OUTPUT.
set -euo pipefail

base=$1
head=${2:-HEAD}

files=$(git diff --name-only "${base}...${head}")
echo "Changed files:"
sed 's/^/  /' <<<"${files}"

all_envs=$(find terraform/live -mindepth 1 -maxdepth 1 -type d | sort)
all_stacks=$(find terraform/stacks -mindepth 1 -maxdepth 1 -type d | sort)

units=()
envs=()
plan_all=false

while IFS= read -r f; do
  [ -z "$f" ] && continue
  case "$f" in
    terraform/modules/*)
      units+=("$(cut -d/ -f1-3 <<<"$f")")
      while IFS= read -r s; do units+=("$s"); done <<<"${all_stacks}"
      plan_all=true
      ;;
    terraform/stacks/*)
      units+=("$(cut -d/ -f1-3 <<<"$f")")
      plan_all=true
      ;;
    terraform/live/*)
      envs+=("$(cut -d/ -f3 <<<"$f")")
      ;;
    policy/* | .github/* | trivy.yaml | .tflint.hcl)
      plan_all=true
      ;;
  esac
done <<<"${files}"

if [ "${plan_all}" = true ]; then
  while IFS= read -r e; do envs+=("$(basename "$e")"); done <<<"${all_envs}"
fi

# Only units that actually have tests, and only environments that still exist.
tested=()
for u in "${units[@]+"${units[@]}"}"; do
  [ -d "$u/tests" ] && tested+=("$u")
done
existing=()
for e in "${envs[@]+"${envs[@]}"}"; do
  [ -d "terraform/live/$e" ] && existing+=("$e")
done

to_json() { if [ $# -eq 0 ]; then echo '[]'; else printf '%s\n' "$@" | sort -u | jq -Rnc '[inputs]'; fi; }
units_json=$(to_json "${tested[@]+"${tested[@]}"}")
envs_json=$(to_json "${existing[@]+"${existing[@]}"}")

echo "Test units:   ${units_json}"
echo "Environments: ${envs_json}"
{
  echo "units=${units_json}"
  echo "environments=${envs_json}"
} >> "${GITHUB_OUTPUT:-/dev/stdout}"
