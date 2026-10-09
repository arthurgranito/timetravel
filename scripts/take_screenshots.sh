#!/usr/bin/env bash
# Tira um print de cada estado de demonstração num simulador.
# Uso: scripts/take_screenshots.sh <udid> <prefixo> <caminho/TimeRewind.app> [pasta-de-saída]
set -euo pipefail
UDID="$1"
PREFIX="$2"
APP="$3"
OUT="${4:-screenshots}"
BUNDLE_ID="com.magic.timerewind"

mkdir -p "$OUT"
xcrun simctl boot "$UDID" 2>/dev/null || true
xcrun simctl bootstatus "$UDID" -b
xcrun simctl install "$UDID" "$APP"

shoot() {
  local name="$1"
  shift
  xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
  xcrun simctl launch "$UDID" "$BUNDLE_ID" "$@" >/dev/null
  sleep 4
  xcrun simctl io "$UDID" screenshot "$OUT/$PREFIX-$name.png" >/dev/null
  echo "ok: $OUT/$PREFIX-$name.png"
}

# Primeira abertura (o simulador às vezes demora mais na primeira vez).
xcrun simctl launch "$UDID" "$BUNDLE_ID" -demoState dark-grid >/dev/null || true
sleep 6

shoot 01-dark-grid -demoState dark-grid
shoot 02-lock -demoState lock -demoOffset 8 -demoTime 14:30
shoot 03-rewinding-mid -demoState rewinding-mid -demoOffset 8 -demoTime 14:30
shoot 04-live -demoState live -demoTime 14:22
shoot 05-settings -demoState settings
shoot 06-calibration -demoState calibration

xcrun simctl terminate "$UDID" "$BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl shutdown "$UDID" >/dev/null 2>&1 || true
