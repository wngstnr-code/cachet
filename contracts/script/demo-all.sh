#!/usr/bin/env bash
# Satu perintah, siap DIREKAM untuk publik: demo penuh babak 1-5 + tautan
# explorer, dengan output yang sudah disaring.
#
# Yang ditampilkan hanya narasi skrip (bagian "== Logs ==" dari forge) dan
# tautan verifikasi — kompilasi, estimasi gas, dan path broadcast adalah
# noise untuk penonton. Kalau sebuah fase GAGAL, log mentah lengkap tetap
# dicetak supaya bisa didiagnosis.
#
# Kenapa shell, bukan satu forge script: waitingPeriod & livenessWindow
# adalah waktu on-chain sungguhan; simulasi forge jalan di satu timestamp
# fork sehingga challenge tepat setelah mint selalu gagal simulasi.
#
# Dipanggil lewat `make demo-all` — bergantung pada env dari ../.env yang
# di-export oleh Makefile (RPC_URL, ADDR_CERTIFICATE, ADDR_CHALLENGE, dst).
set -euo pipefail
cd "$(dirname "$0")/.."

LOG=$(mktemp)
trap 'rm -f "$LOG"' EXIT

# Hanya bagian "== Logs ==" dari output forge; buang juga instruksi operator
# ("PAUSE HERE", perintah make) yang tidak relevan untuk penonton.
show_logs() {
    awk '/^== Logs ==/{inlogs=1; next} /^## Setting up|^==========/{inlogs=0} inlogs' "$LOG" |
        grep -vE 'PAUSE HERE|make demo-' || true
}

# Jalankan satu fase: sukses -> tampilkan narasi saja; gagal -> log mentah.
phase() {
    if "$@" >"$LOG" 2>&1; then
        show_logs
    else
        echo ""
        echo "--- PHASE FAILED: $* --- full log below ---"
        cat "$LOG"
        exit 1
    fi
}

hr() { printf '%.0s─' {1..64}; echo ""; }

echo ""
hr
echo "  CACHET — Golden Path demo, live on X Layer Testnet"
echo "  certify -> sell -> challenge -> payout to the BUYER"
hr

phase make demo
CERT_ID=$(grep -oE 'CERT_ID=[0-9]+' "$LOG" | tail -1 | cut -d= -f2)
[ -n "${CERT_ID:-}" ] || { echo "ERROR: could not parse CERT_ID"; cat "$LOG"; exit 1; }

WAIT=$(cast call "$ADDR_CERTIFICATE" "waitingPeriod()(uint64)" --rpc-url "$RPC_URL")
echo ""
echo "  ... on-chain waiting period: ${WAIT}s until coverage activates ..."
sleep $((WAIT + 5))

phase make demo-challenge CERT_ID="$CERT_ID"
CHALLENGE_ID=$(grep -oE 'CHALLENGE_ID=[0-9]+' "$LOG" | tail -1 | cut -d= -f2)
[ -n "${CHALLENGE_ID:-}" ] || { echo "ERROR: could not parse CHALLENGE_ID"; cat "$LOG"; exit 1; }

LIVENESS=$(cast call "$ADDR_CHALLENGE" "livenessWindow()(uint64)" --rpc-url "$RPC_URL")
echo ""
echo "  ... public liveness window: ${LIVENESS}s before the resolver may rule ..."
sleep $((LIVENESS + 5))

phase make demo-resolve CHALLENGE_ID="$CHALLENGE_ID" CERT_ID="$CERT_ID"

make demo-links
