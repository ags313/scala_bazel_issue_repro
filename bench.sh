#!/usr/bin/env bash
# Times the Scalac action of //:lib_<n> for each toolchain config, on stock rules_scala and with
# patches/rules_scala_analyze_once_per_run.patch applied.
#
#   ./bench.sh                                  # everything (~12 min on a fast machine)
#   SIZES="25 50 100" CONFIGS="off ast" ./bench.sh
#   VARIANTS=patched ./bench.sh
#
# Results: bench-results/results.tsv (one row per build) and one Bazel profile per build.
set -euo pipefail
cd "$(dirname "$0")"

SIZES=${SIZES:-"10 25 50 100 200 400"}
CONFIGS=${CONFIGS:-"off ast high_level"}
VARIANTS=${VARIANTS:-"stock patched"}
BAZEL=${BAZEL:-bazelisk}
OUT=bench-results
mkdir -p "$OUT"

# The patched variant appends this to MODULE.bazel for the duration of the run.
FIX='
single_version_override(
    module_name = "rules_scala",
    patch_strip = 1,
    patches = ["//patches:rules_scala_analyze_once_per_run.patch"],
)'

cp MODULE.bazel "$OUT/MODULE.bazel.orig"
trap 'cp "$OUT/MODULE.bazel.orig" MODULE.bazel' EXIT

# Seconds spent in the Scalac action for one target, from a Bazel JSON profile.
scalac_seconds() {
  jq -r --arg t "$2" \
    '[.traceEvents[] | select(.ph == "X" and .args.mnemonic == "Scalac" and (.name | endswith($t))) | .dur]
     | add / 1e6 | . * 10 | round / 10' "$1"
}

[[ -f $OUT/results.tsv ]] || printf 'variant\tconfig\tfiles\tscalac_s\n' > "$OUT/results.tsv"

for variant in $VARIANTS; do
  cp "$OUT/MODULE.bazel.orig" MODULE.bazel
  [[ $variant == patched ]] && printf '%s\n' "$FIX" >> MODULE.bazel

  for config in $CONFIGS; do
    # Builds the toolchain and warms up the Scalac worker; not measured.
    "$BAZEL" build --config="$config" --//:salt="warmup-$RANDOM" //:lib_25 > "$OUT/warmup.log" 2>&1

    for n in $SIZES; do
      profile="$OUT/$variant-$config-$n.json"
      "$BAZEL" build --config="$config" --//:salt="$(date +%s%N)" --profile="$profile" //:lib_"$n" \
        > "$OUT/$variant-$config-$n.log" 2>&1
      s=$(scalac_seconds "$profile" "//:lib_$n")
      printf '%s\t%s\t%s\t%s\n' "$variant" "$config" "$n" "$s" | tee -a "$OUT/results.tsv"
    done
  done
done

column -t -s$'\t' "$OUT/results.tsv"
