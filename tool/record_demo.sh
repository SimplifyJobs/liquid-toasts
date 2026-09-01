#!/usr/bin/env bash
#
# record_demo.sh — record a clean, high-quality demo video of a liquid_toasts
# reel running on the iOS simulator, with zero manual ffmpeg/simctl fuss.
#
# It drives the example app like this:
#   1. launch `flutter run` (debug) on a booted sim, stdin wired to a FIFO
#   2. wait for the harness to print "<PREFIX>:DONE" once  (build is good, the
#      reel played once, screen is now clean)
#   3. start a simctl screen recording
#   4. hot-restart the app (over the FIFO) to replay the reel from a clean state
#   5. wait for the SECOND "<PREFIX>:DONE", then stop the recording
#   6. transcode the variable-fps capture to a constant 60 fps, high-quality mp4,
#      cropped to the toast zone, with the dead lead-in auto-trimmed
#
# The harness contract: the target entrypoint must print
#   <PREFIX>:<name>:START  / <PREFIX>:<name>:END   around each preview, and
#   <PREFIX>:DONE           once the reel finishes and the screen is clean.
# `runDemoReel()` in liquid_toasts/example/lib/demo_harness.dart prints these
# for you.
#
# Why 60 fps: the iOS sim captures ~60 fps *while content animates* (its display
# link is 60 Hz) but almost nothing during static gaps, so the capture is highly
# variable. fps=60 on encode keeps every real motion frame and only duplicates
# during the still gaps. True 120 fps needs a physical ProMotion device.
#
# Usage:
#   tool/record_demo.sh --target lib/multiline_demo.dart --prefix MULTILINE
#
# Options:
#   --target PATH     Dart entrypoint, relative to liquid_toasts/example/
#                     (required)
#   --prefix STR      log-marker prefix the harness prints (required)
#   --out PATH        output mp4 (default: .demos/<target-basename>_vN.mp4,
#                     auto-versioned; .demos/ is created + gitignored for you)
#   --device UDID     simulator udid, or "booted" (default: first booted sim)
#   --fps N           output frame rate (default: 60)
#   --crf N           x264 quality, lower = better (default: 16; ~18 is lighter)
#   --preset NAME     x264 preset (default: slow)
#   --crop-height PX  crop to top PX pixels (default: ~23% of the screen height)
#   --scale-width PX  downscale to this width (default: 0 = keep native res)
#   --no-crop         keep the full screen instead of cropping to the toast zone
#   --lead SEC        seconds of lead-in to trim (default: auto — 1s before the
#                     first toast, computed from the marker timing)
#   --contact         also write a <out>_contact.png contact sheet to eyeball it
#   --keep            keep the raw capture + intermediates (prints their paths)
#   -h, --help        this help
set -euo pipefail

# ---- args ----------------------------------------------------------------
TARGET="" PREFIX="" OUT="" DEVICE="" FPS=60 CRF=16 PRESET=slow
CROP_H="" CROP_FRAC=0.23 SCALE_W=0 NOCROP=false LEAD="" CONTACT=false KEEP=false
die() { echo "error: $*" >&2; exit 1; }
usage() { sed -n '2,/^set -euo/p' "$0" | sed 's/^# \{0,1\}//; s/^#$//' | sed '$d'; exit "${1:-0}"; }
while [[ $# -gt 0 ]]; do
  case "$1" in
    --target) TARGET="$2"; shift 2;;
    --prefix) PREFIX="$2"; shift 2;;
    --out) OUT="$2"; shift 2;;
    --device) DEVICE="$2"; shift 2;;
    --fps) FPS="$2"; shift 2;;
    --crf) CRF="$2"; shift 2;;
    --preset) PRESET="$2"; shift 2;;
    --crop-height) CROP_H="$2"; shift 2;;
    --scale-width) SCALE_W="$2"; shift 2;;
    --no-crop) NOCROP=true; shift;;
    --lead) LEAD="$2"; shift 2;;
    --contact) CONTACT=true; shift;;
    --keep) KEEP=true; shift;;
    -h|--help) usage 0;;
    *) die "unknown option: $1 (try --help)";;
  esac
done
[[ -n "$TARGET" ]] || die "missing --target (try --help)"
[[ -n "$PREFIX" ]] || die "missing --prefix"

# ---- paths & deps --------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO="$(dirname "$SCRIPT_DIR")"
EXAMPLE="$REPO/liquid_toasts/example"
[[ -d "$EXAMPLE" ]] || die "example app not found at $EXAMPLE"
[[ -f "$EXAMPLE/$TARGET" ]] || die "target not found: $EXAMPLE/$TARGET"
for bin in flutter xcrun ffmpeg ffprobe python3; do
  command -v "$bin" >/dev/null || die "$bin not found on PATH"
done
# Recordings are saved (auto-versioned) under .demos/ in the repo, kept gitignored.
DEMODIR="$REPO/.demos"
ensure_demos_gitignored() {
  local gi="$REPO/.gitignore"
  if ! { [[ -f "$gi" ]] && grep -qxF '.demos/' "$gi"; }; then
    printf '\n# Local demo recordings (tool/record_demo.sh)\n.demos/\n' >> "$gi"
  fi
}
if [[ -z "$OUT" ]]; then
  mkdir -p "$DEMODIR"; ensure_demos_gitignored
  base="$(basename "${TARGET%.dart}")"; v=1
  while [[ -e "$DEMODIR/${base}_v${v}.mp4" ]]; do v=$((v + 1)); done
  OUT="$DEMODIR/${base}_v${v}.mp4"
else
  mkdir -p "$(dirname "$OUT")"
fi
now() { python3 -c 'import time; print(time.time())'; }
calc() { python3 -c "import sys; print($1)"; }
# Count matching lines in the run log, always printing a single integer.
# (`grep -c` prints "0" *and* exits 1 on no match, so a naive `|| echo 0`
# would emit a doubled "0\n0" and break the numeric tests below.)
count() { local n; n="$(grep -c "$1" "$LOG" 2>/dev/null)" || true; printf '%s\n' "${n:-0}"; }

# ---- device --------------------------------------------------------------
if [[ -z "$DEVICE" || "$DEVICE" == "booted" ]]; then
  DEVICE="$(xcrun simctl list devices booted -j | python3 -c \
    'import sys,json; d=json.load(sys.stdin)["devices"]; ids=[x["udid"] for r in d.values() for x in r if x.get("state")=="Booted"]; print(ids[0] if ids else "")')"
fi
[[ -n "$DEVICE" ]] || die "no booted simulator. Boot one, e.g.:
  xcrun simctl boot <udid> && open -a Simulator   (list: xcrun simctl list devices available)"
DEV_NAME="$(xcrun simctl list devices -j | python3 -c \
  "import sys,json; d=json.load(sys.stdin)['devices']; print(next((x['name'] for r in d.values() for x in r if x['udid']=='$DEVICE'),'?'))")"
echo "▶ device:  $DEV_NAME ($DEVICE)"
echo "▶ target:  liquid_toasts/example/$TARGET   prefix: $PREFIX"

# ---- temp + cleanup ------------------------------------------------------
TMP="$(mktemp -d)"
FIFO="$TMP/flutterin"; LOG="$TMP/run.log"; RECLOG="$TMP/rec.log"; RAW="$TMP/raw.mov"
mkfifo "$FIFO"
FLUTTER_PID="" REC_PID=""
cleanup() {
  [[ -n "$REC_PID" ]] && kill -INT "$REC_PID" 2>/dev/null || true
  if [[ -n "$FLUTTER_PID" ]]; then printf 'q\n' >&9 2>/dev/null || true; sleep 1; kill "$FLUTTER_PID" 2>/dev/null || true; fi
  exec 9>&- 2>/dev/null || true
  if [[ "$KEEP" == true ]]; then echo "▶ kept intermediates in $TMP"; else rm -rf "$TMP"; fi
}
trap cleanup EXIT

# hold the FIFO's write end open (rw, so opening never blocks on a reader)
exec 9<>"$FIFO"

# ---- launch --------------------------------------------------------------
echo "▶ building & launching (first build can take a few minutes)…"
( cd "$EXAMPLE" && exec flutter run -d "$DEVICE" -t "$TARGET" ) <"$FIFO" >"$LOG" 2>&1 &
FLUTTER_PID=$!

wait_done() {  # wait_done <min-count> <timeout-sec> <what>
  local want="$1" timeout="$2" what="$3" waited=0
  while :; do
    [[ "$(count "$PREFIX:DONE")" -ge "$want" ]] && return 0
    if grep -qE "Could not build|Error launching|Failed to build|the Dart compiler exited|Build failed|FAILURE:|No such device|Lost connection to device" "$LOG"; then
      echo "--- log tail ---" >&2; tail -25 "$LOG" >&2; die "build/launch failed while $what"
    fi
    kill -0 "$FLUTTER_PID" 2>/dev/null || { tail -25 "$LOG" >&2; die "flutter exited while $what"; }
    sleep 0.3; waited=$(calc "$waited+0.3")
    (( $(calc "1 if $waited>$timeout else 0") )) && { tail -25 "$LOG" >&2; die "timed out while $what"; }
  done
}

echo "▶ waiting for first reel to validate the build…"
wait_done 1 600 "waiting for first $PREFIX:DONE"

# ---- record + replay -----------------------------------------------------
echo "▶ recording…"
xcrun simctl io "$DEVICE" recordVideo --codec=h264 --force "$RAW" >"$RECLOG" 2>&1 &
REC_PID=$!
for _ in $(seq 1 40); do grep -q "Recording started" "$RECLOG" && break; sleep 0.1; done
REC_T0="$(now)"
START0="$(count "$PREFIX:.*:START")"
printf 'R\n' >&9   # hot restart -> replay the reel from a clean state

FIRST_START_AT=""
while :; do
  if [[ -z "$FIRST_START_AT" && "$(count "$PREFIX:.*:START")" -gt "$START0" ]]; then
    FIRST_START_AT="$(calc "$(now)-$REC_T0")"
  fi
  [[ "$(count "$PREFIX:DONE")" -ge 2 ]] && break
  sleep 0.2
done
sleep 0.6                       # let the trailing clean frame land
kill -INT "$REC_PID" 2>/dev/null || true
wait "$REC_PID" 2>/dev/null || true
REC_PID=""

# ---- encode --------------------------------------------------------------
# auto lead-trim: start ~1s before the first toast appeared
if [[ -z "$LEAD" ]]; then
  if [[ -n "$FIRST_START_AT" ]]; then LEAD="$(calc "max(0.0, $FIRST_START_AT-1.0)")"; else LEAD=4.0; fi
fi
filters=()
if [[ "$NOCROP" != true ]]; then
  if [[ -n "$CROP_H" ]]; then filters+=("crop=in_w:${CROP_H}:0:0")
  else filters+=("crop=in_w:trunc(ih*${CROP_FRAC}/2)*2:0:0"); fi
fi
filters+=("fps=${FPS}")
[[ "$SCALE_W" != 0 ]] && filters+=("scale=${SCALE_W}:-2")
VF="$(IFS=,; echo "${filters[*]}")"

echo "▶ encoding ${FPS}fps crf=${CRF} (lead-trim ${LEAD}s)…"
ffmpeg -y -ss "$LEAD" -i "$RAW" -vf "$VF" \
  -c:v libx264 -preset "$PRESET" -crf "$CRF" -pix_fmt yuv420p -movflags +faststart -an \
  "$OUT" -loglevel error

if [[ "$CONTACT" == true ]]; then
  ffmpeg -y -i "$OUT" -vf "fps=1/1.6,scale=360:-1,tile=3x6:padding=6:color=gray" \
    -frames:v 1 "${OUT%.*}_contact.png" -loglevel error
fi

# ---- report --------------------------------------------------------------
read -r W H FR DUR < <(ffprobe -v error -select_streams v:0 \
  -show_entries stream=width,height,r_frame_rate -show_entries format=duration \
  -of csv=p=0 "$OUT" | tr ',\n' '  ') || true   # read exits 1 at EOF (no newline)
SRC_MED="$(ffprobe -v error -select_streams v:0 -show_entries frame=pts_time -of csv=p=0 "$RAW" 2>/dev/null \
  | python3 -c 'import sys; t=sorted(float(l.strip().rstrip(",")) for l in sys.stdin if l.strip()); d=sorted(b-a for a,b in zip(t,t[1:]) if b>a); print(f"{1/d[len(d)//2]:.0f}") if d else print("?")')"
echo "✔ ${OUT}"
echo "  ${W}x${H}  ${FPS}fps (capture motion median ~${SRC_MED}fps)  $(calc "round(float('$DUR'),1)")s  $(du -h "$OUT" | cut -f1)"
[[ "$CONTACT" == true ]] && echo "  contact sheet: ${OUT%.*}_contact.png"
