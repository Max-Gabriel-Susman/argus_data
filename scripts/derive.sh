#!/usr/bin/env bash
# derive.sh -- rebuild every derived file the Argus stack reads, from the raw
# broadband .nwb. Needs scripts/fetch.sh to have run and the .nwb in place.
#
#   bash scripts/derive.sh
#   ARGUS_DATA_DIR=/elsewhere ARGUS_WS=/path/to/argus_ws \
#     ARGUS_CODEC=/path/to/argus-neural-codec bash scripts/derive.sh
#
# Makes, in order:
#   indy_20161005_06_s120_10s.bin      10 s from t=120 s, resampled to
#                                      30012 Hz: the relay's replay segment
#   indy_20161005_06_s10_374s_24k.bin  374 s from t=10 s at the native
#                                      24,414 Hz: decode_test.py's input
#   argus-neural-codec/sim/data/feature_ci.dat and feature_ci_golden.txt,
#                                      the CI pair tb_argus_feature checks
#
# The flags are the ones those files were made with; see nwb_to_replay.py
# --help and spike_features.py --help, and the comment above FEATURE_BIN in
# argus-neural-codec/sim/Makefile.
set -euo pipefail

DATA_DIR=${ARGUS_DATA_DIR:-$HOME/argus_data}
WS=${ARGUS_WS:-$HOME/Documents/argus_ws}
CODEC=${ARGUS_CODEC:-$HOME/Documents/argus-neural-codec}
TOOLS=$WS/src/argus_sim/tools
NWB=$DATA_DIR/indy_20161005_06_broadband.nwb

if [ ! -f "$NWB" ]; then
  echo "missing $NWB -- run scripts/fetch.sh and follow its instructions" >&2
  exit 1
fi

# Replay segment for dataset_relay_node: 10 s, resampled to the fabric's
# 30012 Hz sweep rate (the default --target-hz).
python3 "$TOOLS/nwb_to_replay.py" "$NWB" \
  --start 120 --seconds 10 \
  --out "$DATA_DIR/indy_20161005_06_s120_10s.bin"

# Long segment at the recording's own rate for decode_test.py; it covers the
# .mat's behaviour window. --no-resample is what enables chunked processing.
python3 "$TOOLS/nwb_to_replay.py" "$NWB" \
  --start 10 --seconds 374 --no-resample \
  --out "$DATA_DIR/indy_20161005_06_s10_374s_24k.bin"

# CI pair for tb_argus_feature: the first 6000 sweeps of the replay segment
# and the model's golden for them, at a 2048-sweep warm-up and 100-sweep bins.
mkdir -p "$CODEC/sim/data"
head -c $((6000 * 96 * 2)) "$DATA_DIR/indy_20161005_06_s120_10s.bin" \
  > "$CODEC/sim/data/feature_ci.dat"
python3 "$TOOLS/spike_features.py" "$CODEC/sim/data/feature_ci.dat" \
  --mult 3.5 --ms-shift 11 --warmup 2048 --bin 100 \
  --golden "$CODEC/sim/data/feature_ci_golden.txt"
