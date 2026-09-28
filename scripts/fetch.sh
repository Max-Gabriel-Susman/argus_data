#!/usr/bin/env bash
# fetch.sh -- put the raw Indy session files where the Argus stack expects them.
#
#   bash scripts/fetch.sh                 # into ~/argus_data
#   ARGUS_DATA_DIR=/elsewhere bash scripts/fetch.sh
#
# Downloads the 84 MB .mat (doi:10.5281/zenodo.583331) with wget and checks
# its md5 against the one Zenodo publishes. The ~1 GB broadband .nwb
# (doi:10.5281/zenodo.1419774) is only checked for, with instructions if it
# is missing. Idempotent: a file that is already present and verifies is
# left alone, and a download goes to a .part file that is renamed only once
# it verifies, so an interrupted run never leaves a file that looks complete.
set -euo pipefail

DATA_DIR=${ARGUS_DATA_DIR:-$HOME/argus_data}

MAT=indy_20161005_06.mat
MAT_URL="https://zenodo.org/records/583331/files/indy_20161005_06.mat?download=1"
MAT_MD5=5ea300952642e0fc54245144499db9bb

NWB=indy_20161005_06_broadband.nwb
NWB_PAGE="https://zenodo.org/records/1419774"
NWB_MD5=a1a7d31e22f406aaa042bf91b3817a5f

md5_of() {
  md5sum "$1" | cut -d' ' -f1
}

mkdir -p "$DATA_DIR"

if [ -f "$DATA_DIR/$MAT" ]; then
  echo "present: $DATA_DIR/$MAT (not re-downloading)"
else
  echo "fetching $MAT into $DATA_DIR"
  wget -O "$DATA_DIR/$MAT.part" "$MAT_URL"
  got=$(md5_of "$DATA_DIR/$MAT.part")
  if [ "$got" != "$MAT_MD5" ]; then
    echo "md5 mismatch for $MAT: got $got, want $MAT_MD5" >&2
    echo "left as $DATA_DIR/$MAT.part; delete it and re-run" >&2
    exit 1
  fi
  mv "$DATA_DIR/$MAT.part" "$DATA_DIR/$MAT"
  echo "fetched and verified: $DATA_DIR/$MAT"
fi

if [ -f "$DATA_DIR/$NWB" ]; then
  echo "present: $DATA_DIR/$NWB"
else
  cat <<EOF

missing: $DATA_DIR/$NWB
The broadband supplement is 1,026,860,510 bytes (gzip-compressed HDF5) and
is not fetched automatically. Download it by hand:

  1. Open $NWB_PAGE
  2. Download indy_20161005_06.nwb
  3. Save it as $DATA_DIR/$NWB  (note the _broadband suffix)
  4. Check: md5sum $DATA_DIR/$NWB  ->  $NWB_MD5

EOF
fi
