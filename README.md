# Argus Data

Argus Data encapsulates dataset acquisition, survey, and conversion tooling for the Argus Cybernetics replay pipeline; provenance and scripts, no data in git.

This repository is where the Argus stack says where every dataset comes from
and how every derived file is made. **No data lives in git** — not here, not
in any Argus repository. Raw and derived files go in `~/argus_data/` and are
referenced by path (`ARGUS_DATASET_PATH` for the decoder, `dataset_path` for
the relay). A fresh clone cannot contain them anyway, so the honest
arrangement is to say where they come from and where they go.

```
bash scripts/fetch.sh    # the .mat, and instructions for the .nwb
bash scripts/derive.sh   # every derived file below, from the .nwb
```

Both honour `ARGUS_DATA_DIR` (default `~/argus_data`); `derive.sh` also takes
`ARGUS_WS` and `ARGUS_CODEC` for the workspace and codec checkouts.

## Source: session `indy_20161005_06`

Both raw files are session `indy_20161005_06` from *Nonhuman Primate Reaching
with Multichannel Sensorimotor Cortex Electrophysiology* (O'Doherty, Cardoso,
Makin & Sabes, UCSF), CC-BY-4.0. A macaque made self-paced reaches to targets
on a grid while a 96-channel Utah array recorded M1. There are no trial
boundaries — reaches are continuous, with no inter-trial gaps or pre-movement
delays.

| File | Zenodo record | Size | md5 |
| --- | --- | --- | --- |
| `indy_20161005_06.mat` | doi:10.5281/zenodo.583331 | 83,957,398 B (84 MB) | `5ea300952642e0fc54245144499db9bb` |
| `indy_20161005_06_broadband.nwb` | doi:10.5281/zenodo.1419774 | 1,026,860,510 B | `a1a7d31e22f406aaa042bf91b3817a5f` |

`fetch.sh` downloads the `.mat` with wget and verifies it. The `.nwb` is
published as `indy_20161005_06.nwb`; download it from the record page and
save it with the `_broadband` suffix. It is gzip-compressed HDF5: about 1 GB
on disk, about 1.9 GB of `int16` samples once read.

**Shared session clock.** The two files share one clock: the broadband starts
at `t = 1278 s`, the behavioural data at `1288 s`. Anything derived from one
can be aligned to the other by timestamp alone.

### `indy_20161005_06.mat` — training source

MATLAB v7.3, i.e. HDF5, read with `h5py`:

| Variable      | Shape   | Meaning                                     |
| ------------- | ------- | ------------------------------------------- |
| `t`           | k × 1   | Timestamps, seconds                         |
| `cursor_pos`  | k × 2   | Cursor position (x, y), mm, 250 Hz          |
| `target_pos`  | k × 2   | Target position (x, y), mm, 250 Hz          |
| `finger_pos`  | k × 3/6 | Fingertip position (z, -x, -y), cm          |
| `spikes`      | n × u   | Spike time vectors per channel per unit     |
| `wf`          | n × u   | Spike waveform snippets, µV                 |

`argus_inference`'s `inference_node` loads this at startup, bins spike times,
derives 4-way intent labels from the cursor-to-target vector, and fits an
LDA-over-StandardScaler pipeline. It never leaves the host — training data,
not pipeline input.

### `indy_20161005_06_broadband.nwb` — acquisition-path source

NWB 1.0.6 (HDF5). `/acquisition/timeseries/broadband/data` is 9,619,237 × 96
`int16` codes with a `conversion` attribute of 3.05185e-07 V/code;
`/acquisition/timeseries/broadband/timestamps` gives per-sample seconds
(1278.0 to 1672.0). 394 s at 24,414 Hz (24.4 kS/s), 96 channels, unfiltered
below the 7.5 kHz anti-alias low-pass, so each channel carries its
electrode's DC offset.

It is the only file here that is actual voltage, and therefore the only one
that can stand in for an electrode array. It is never read at runtime;
`argus_sim/tools/nwb_to_replay.py` converts segments of it into what the relay
serves.

## Derived files

Every file in `~/argus_data/` other than the two above, with the command that
makes it. `$T` is `~/Documents/argus_ws/src/argus_sim/tools`, `$D` is
`~/argus_data`, `$NWB` is `$D/indy_20161005_06_broadband.nwb`. The first three
rows are what `derive.sh` runs; the rest are exploration and cache output,
listed so nothing in the directory is unexplained.

| File | Made by | What it is |
| --- | --- | --- |
| `indy_20161005_06_s120_10s.bin` | `python3 $T/nwb_to_replay.py $NWB --start 120 --seconds 10 --out $D/indy_20161005_06_s120_10s.bin` | 10 s replay segment, resampled to 30,012 Hz; what `dataset_relay_node` serves |
| `indy_20161005_06_s10_374s_24k.bin` | `python3 $T/nwb_to_replay.py $NWB --start 10 --seconds 374 --no-resample --out $D/indy_20161005_06_s10_374s_24k.bin` | 374 s at the native 24,414 Hz, covering the `.mat` window; `decode_test.py` input |
| `argus-neural-codec/sim/data/feature_ci.dat` + `feature_ci_golden.txt` | `head -c $((6000*96*2)) $D/indy_20161005_06_s120_10s.bin > sim/data/feature_ci.dat` then `python3 $T/spike_features.py sim/data/feature_ci.dat --mult 3.5 --ms-shift 11 --warmup 2048 --bin 100 --golden sim/data/feature_ci_golden.txt` | the CI pair `tb_argus_feature` checks bit-exact (60 bins × 96 ch); lives in the codec repo, not here — 1.2 MB of samples, CC-BY-4.0 |
| `indy_20161005_06_s10_200s_24k.bin` | `python3 $T/nwb_to_replay.py $NWB --start 10 --seconds 200 --no-resample --out $D/indy_20161005_06_s10_200s_24k.bin` | earlier, shorter version of the 374 s segment |
| `indy_20161005_06_s120_10s.golden.txt` + `.trace.txt` | `python3 $T/spike_features.py $D/indy_20161005_06_s120_10s.bin --mult 3.5 --golden $D/indy_20161005_06_s120_10s.golden.txt --trace $D/indy_20161005_06_s120_10s.trace.txt` | production-parameter golden (the locked 3.5σ, K=15, 1500-sweep bins) for the local full-length `make tb_argus_feature` run, and the filtered signal of channel 0 (first 4096 samples) for a filter-only test. **The golden now on disk predates the lock:** its header says `NUM=81` (4.5σ) and carries no `ORDER`/`WINSOR` fields, so regenerate it with this command before trusting that run |
| `indy_20161005_06_s120_10s.m{3.5,4.5}.{won,woff}.golden.txt` | `spike_features.py` on the same `.bin` with `--golden`, plus `--mult 3.5` or `--mult 4.5`, and `--no-winsorize` for `woff` | threshold and winsorizing sweep |
| `indy_20161005_06_s120_10s.o{1,2}.{bon,boff}.golden.txt` | the same, at `--mult 4.5`, plus `--hp-order 1` or `--hp-order 2`, and `--bipolar` for `bon` | filter order and polarity sweep |
| `*.bin.features.<sha1>.npz` | `decode_test.py` on the matching `.bin` (automatic; `--no-cache` skips it) | model feature cache; the tag hashes the model parameters. Safe to delete |
| `feature_stim_ci.txt`, `feature_golden_ci.txt` | the since-removed `spike_features.py --stim` path | superseded CI pair, before `tb_argus_feature` read the `.bin` directly; not regenerable and not used |

### `*.bin` format

What `dataset_relay_node` mmaps: headerless little-endian `uint16`,
sample-major, 96 columns, one row per sample. Values are RHD2132 ADC codes —
offset binary, `0x8000` = 0 V at the electrode, 0.195 µV per LSB — so the
simulated Intan chips in the codec return exactly what real silicon would
have returned for that electrode voltage.

The converter AC-couples each channel (mean removal, then a first-order
high-pass, standing in for the chip's analog coupling) and, unless
`--no-resample`, resamples from 24,414 Hz to the fabric's 30,012 Hz sweep
rate so spike widths and filter cutoffs are right in the fabric's time base.
It reports per-channel RMS and the clipped fraction; cortical broadband is
20–150 µV RMS, and a millivolt reading means the conversion attribute was not
what was assumed.

### Not in `~/argus_data/`

`neural_96.csv` lives in `argus_sensors/data/`: binned spike counts derived
from the `.mat`, 96 channels, 50 ms bins (20 Hz), columns `sample,t,ch0..ch95`
with `t` in session-relative seconds. It is small enough to belong in a
repository, and `argus_sensors/neural_telemetry_replay` installs and reads it.

## Roles, and what each file cannot do

The decoder trains on the `.mat`. The hardware path is validated with the
`.nwb`, via the `.bin`. They meet only through the shared session clock.

- **The `.mat` cannot drive the hardware path.** Its `wf` field holds real
  waveforms, but only as snippets around detected threshold crossings; the
  continuous record between spikes is discarded.
- **The `.csv` cannot either.** Counts are not voltages.
- **The `.bin` cannot train the decoder on its own.** It carries no labels.
  Labels come from `cursor_pos` and `target_pos` in the `.mat` and are
  attached by timestamp on the host, as `decode_test.py` does.
- **None of this transfers to dissociated cultures**, which have no
  behavioural correlate to label.

## CI

`.github/workflows/ci.yml` runs `shellcheck` and `bash -n` on `scripts/*.sh`.
