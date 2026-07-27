#!/usr/bin/env bash
#
# Rehearsal END-TO-END untuk fitur "kolateral dari kreator" (pullCollateralFromCreator)
# di anvil lokal (chain-id 1952) — dijalankan sampai TAHAP TERAKHIR Golden Path,
# bukan cuma sampai mint: mint (kreator bayar) -> transfer ke pembeli -> challenge
# -> resolve -> payout mendarat di pembeli. Plus satu mint fallback (kreator
# yang tidak pernah approve) untuk membuktikan tidak breaking.
#
# Prasyarat sama seperti local-anvil-e2e.sh (foundry, venv engine, deps gateway).
# Pakai: bash apps/server/scripts/local-anvil-collateral-e2e.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
ENGINE_DIR=$ROOT/services/engine; GW=$ROOT/apps/server; C=$ROOT/contracts
PY=$ENGINE_DIR/.venv/bin/python
TMP=$(mktemp -d)
RPC=http://localhost:8545
PORT=${GATEWAY_PORT:-8796}

# Akun standar anvil (mnemonic default, publik & dikenal luas — HANYA untuk anvil
# lokal). Nilai di bawah DIEKSTRAK LANGSUNG dari output `anvil` sendiri (bukan
# diketik ulang dari memori) — versi sebelumnya sempat salah ketik (beberapa
# private key terpotong satu karakter di ujung), yang membuat sender-nya
# menjadi wallet acak tak berdana, bukan akun anvil sungguhan.
GW_PK=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
GW_ADDR=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
DEPLOYER_PK=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
RESOLVER_PK=0x5de4111afa1a4b94908f83103eb1f1706367c2e68ca870fc3fb9a804cdab365a
RESOLVER_ADDR=0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC
CREATOR_PK=0x7c852118294e51e653712a81e05800f419141751be58f605c371e15141b007a6
CREATOR_ADDR=0x90F79bf6EB2c4f870365E785982E1f101E93b906
CREATOR2_PK=0x92db14e403b83dfe3df233f83dfa3a0d7096f21ca9b0d6d6b8d88b2b4ec1564e
CREATOR2_ADDR=0x976EA74026E726554dB657fA54763abd0C3a0aa9   # TIDAK PERNAH approve (skenario fallback)
BUYER_ADDR=0x15d34AAf54267DB7D7c367839AAf71A00a2C6A65
CHALLENGER_PK=0x8b3a350cf5c34c9194ca85829a2df0ec3153be0318b5e2d3348e872092edffba
CHALLENGER_ADDR=0x9965507D1a55bcC2695C58ba16FB37d819B0A4dc

cleanup() { pkill -f "anvil --chain-id 1952" 2>/dev/null; pkill -f "GATEWAY_PORT=$PORT" 2>/dev/null; pkill -f "app.main:create_app" 2>/dev/null; lsof -tiTCP:$PORT -sTCP:LISTEN 2>/dev/null | xargs -r kill 2>/dev/null; }
trap cleanup EXIT

FAIL=0
check() { if [ "$1" = "$2" ]; then echo "  OK: $3 ($1)"; else echo "  GAGAL: $3 (dapat '$1', mau '$2')"; FAIL=1; fi; }
check_gt() { if [ "$1" -gt "$2" ]; then echo "  OK: $3 ($1 > $2)"; else echo "  GAGAL: $3 ($1 tidak > $2)"; FAIL=1; fi; }

echo "== 0. Verifikasi key<->address (gagal cepat kalau ada salah ketik) =="
anvil --chain-id 1952 --silent >/dev/null 2>&1 &
for i in $(seq 1 40); do cast block-number --rpc-url $RPC >/dev/null 2>&1 && break; sleep 0.3; done
verify_key() {
  DERIVED=$(cast wallet address --private-key "$1" | tr 'A-Z' 'a-z')
  EXPECT=$(echo "$2" | tr 'A-Z' 'a-z')
  if [ "$DERIVED" != "$EXPECT" ]; then
    echo "FATAL: $3 — private key derive ke $DERIVED, bukan $EXPECT yang diharapkan. Berhenti sebelum menyesatkan langkah berikutnya."
    exit 1
  fi
}
verify_key "$GW_PK" "$GW_ADDR" "GW"
verify_key "$RESOLVER_PK" "$RESOLVER_ADDR" "RESOLVER"
verify_key "$CREATOR_PK" "$CREATOR_ADDR" "CREATOR"
verify_key "$CHALLENGER_PK" "$CHALLENGER_ADDR" "CHALLENGER"
verify_key "$CREATOR2_PK" "$CREATOR2_ADDR" "CREATOR2"
echo "  semua private key cocok alamat yang diklaim."

echo "== 1. Deploy kontrak =="

cd "$C"
DEPLOYER_PK=$DEPLOYER_PK forge script script/DeployMockUSDT.s.sol:DeployMockUSDT --rpc-url $RPC --broadcast >/dev/null 2>&1
MOCK=$($PY -c "import json;print([t['contractAddress'] for t in json.load(open('$C/broadcast/DeployMockUSDT.s.sol/1952/run-latest.json'))['transactions'] if t['transactionType']=='CREATE'][0])")
DEPLOYER_PK=$DEPLOYER_PK ADDR_MOCKUSDT=$MOCK GATEWAY_ADDR=$GW_ADDR RESOLVER_ADDR=$RESOLVER_ADDR \
  forge script script/Deploy.s.sol:Deploy --rpc-url $RPC --broadcast >"$TMP/deploy.log" 2>&1
grep -q "Wiring lengkap" "$TMP/deploy.log" || { echo "DEPLOY GAGAL"; tail -20 "$TMP/deploy.log"; exit 1; }
A=($($PY -c "import json;print(' '.join(t['contractAddress'] for t in json.load(open('$C/broadcast/Deploy.s.sol/1952/run-latest.json'))['transactions'] if t['transactionType']=='CREATE'))"))
REGISTRY=${A[0]}; CERT=${A[1]}; VAULT=${A[2]}; CHALLENGE=${A[3]}
echo "deployed: registry=$REGISTRY cert=$CERT vault=$VAULT challenge=$CHALLENGE mockUSDT=$MOCK"

# Percepat waktu demo: waiting period 10s, liveness window ke MIN (30s).
cast send $CERT "setWaitingPeriod(uint64)" 10 --private-key $DEPLOYER_PK --rpc-url $RPC >/dev/null 2>&1
cast send $CHALLENGE "setLivenessWindow(uint64)" 30 --private-key $DEPLOYER_PK --rpc-url $RPC >/dev/null 2>&1

echo "== 2. Danai wallet =="
cast send $MOCK "mint(address,uint256)" $GW_ADDR 1000000000 --private-key $DEPLOYER_PK --rpc-url $RPC >/dev/null 2>&1
cast send $MOCK "mint(address,uint256)" $CREATOR_ADDR 20000000 --private-key $CREATOR_PK --rpc-url $RPC >/dev/null 2>&1  # 20 mUSDT, faucet publik
cast send $MOCK "mint(address,uint256)" $CHALLENGER_ADDR 20000000 --private-key $CHALLENGER_PK --rpc-url $RPC >/dev/null 2>&1

echo "== 3. Start engine + gateway (viem) =="
ENGINE_EMBEDDER=fake INDEX_PATH="$TMP/idx" \
  $PY -m uvicorn app.main:create_app --factory --port 8101 --host 127.0.0.1 --app-dir "$ENGINE_DIR" >"$TMP/eng.log" 2>&1 &
( cd "$GW" && CHAIN_MODE=viem RPC_URL=$RPC CHAIN_ID=1952 \
  ADDR_REGISTRY=$REGISTRY ADDR_CERTIFICATE=$CERT ADDR_VAULT=$VAULT ADDR_CHALLENGE=$CHALLENGE ADDR_MOCKUSDT=$MOCK \
  ENGINE_URL=http://localhost:8101 GATEWAY_PORT=$PORT X402_BYPASS=1 GATEWAY_DATA_DIR="$TMP/gw" \
  GATEWAY_PK=$GW_PK pnpm start >"$TMP/gw.log" 2>&1 & )
for i in $(seq 1 60); do curl -s localhost:8101/healthz >/dev/null 2>&1 && curl -s localhost:$PORT/healthz >/dev/null 2>&1 && break; sleep 0.4; done
grep -q "gagal start\|EADDRINUSE" "$TMP/gw.log" && { echo "GATEWAY CRASH"; tail -8 "$TMP/gw.log"; exit 1; }

echo "== 4. Kreator APPROVE gateway (satu tx, sebelum mint) =="
cast send $MOCK "approve(address,uint256)" $GW_ADDR 20000000 --private-key $CREATOR_PK --rpc-url $RPC >/dev/null 2>&1
FRAUD_BOND=$(cast call $VAULT "fraudBondAmount()(uint256)" --rpc-url $RPC | awk '{print $1}')
PREMIUM=$(cast call $VAULT "quotePremium(uint256)(uint256)" 50000000 --rpc-url $RPC | awk '{print $1}')
NEEDED=$((FRAUD_BOND + PREMIUM))
echo "  fraudBond on-chain: $FRAUD_BOND, premium(declaredValue=50 USDT): $PREMIUM, total ditarik: $NEEDED"

CREATOR_BAL_BEFORE=$(cast call $MOCK "balanceOf(address)(uint256)" $CREATOR_ADDR --rpc-url $RPC | awk '{print $1}')
GW_BAL_BEFORE=$(cast call $MOCK "balanceOf(address)(uint256)" $GW_ADDR --rpc-url $RPC | awk '{print $1}')
echo "  saldo SEBELUM mint — creator=$CREATOR_BAL_BEFORE gateway=$GW_BAL_BEFORE"

IMG=$($PY -c "import io,base64;from PIL import Image,ImageDraw;im=Image.new('RGB',(400,400));d=ImageDraw.Draw(im);d.rectangle([0,0,400,133],fill=(80,10,180));d.rectangle([0,133,400,266],fill=(10,180,80));d.rectangle([0,266,400,400],fill=(180,80,10));b=io.BytesIO();im.save(b,'PNG');print(base64.b64encode(b.getvalue()).decode())")

echo "== 5. MINT #1 — kreator SUDAH approve =="
MINT1=$(curl -s -X POST localhost:$PORT/v1/mint -H 'content-type: application/json' -d "{\"image_b64\":\"$IMG\",\"creator_address\":\"$CREATOR_ADDR\",\"declared_value\":\"50000000\"}")
CERTID=$($PY -c "import json;print(json.loads('''$MINT1''')['cert_id'])")
COLSRC=$($PY -c "import json;print(json.loads('''$MINT1''')['collateral_source'])")
echo "  cert_id=$CERTID collateral_source=$COLSRC"
check "$COLSRC" "creator" "response menandai collateral_source=creator"

CREATOR_BAL_AFTER=$(cast call $MOCK "balanceOf(address)(uint256)" $CREATOR_ADDR --rpc-url $RPC | awk '{print $1}')
GW_BAL_AFTER=$(cast call $MOCK "balanceOf(address)(uint256)" $GW_ADDR --rpc-url $RPC | awk '{print $1}')
DELTA=$((CREATOR_BAL_BEFORE - CREATOR_BAL_AFTER))
echo "  saldo SESUDAH mint — creator=$CREATOR_BAL_AFTER (turun $DELTA) gateway=$GW_BAL_AFTER"
check "$DELTA" "$NEEDED" "saldo creator turun TEPAT fraudBond+premium (bukti on-chain nyata, bukan cuma klaim JSON)"
OWNER1=$(cast call $CERT "ownerOf(uint256)(address)" $CERTID --rpc-url $RPC | tr 'A-Z' 'a-z')
check "$OWNER1" "$(echo $CREATOR_ADDR | tr 'A-Z' 'a-z')" "cert #$CERTID dimiliki creator setelah mint"

echo "== 6. Sisa Golden Path: transfer ke pembeli =="
cast send $CERT "transferFrom(address,address,uint256)" $CREATOR_ADDR $BUYER_ADDR $CERTID --private-key $CREATOR_PK --rpc-url $RPC >/dev/null 2>&1
OWNER2=$(cast call $CERT "ownerOf(uint256)(address)" $CERTID --rpc-url $RPC | tr 'A-Z' 'a-z')
check "$OWNER2" "$(echo $BUYER_ADDR | tr 'A-Z' 'a-z')" "cert #$CERTID sekarang milik BUYER"

echo "== 7. Tunggu waiting period, lalu CHALLENGE dari wallet penantang sendiri =="
sleep 12
CHAL_BOND=$(cast call $CHALLENGE "challengeBond()(uint256)" --rpc-url $RPC | awk '{print $1}')
cast send $MOCK "approve(address,uint256)" $VAULT $CHAL_BOND --private-key $CHALLENGER_PK --rpc-url $RPC >/dev/null 2>&1
cast send $CHALLENGE "challenge(uint256,string)" $CERTID "ipfs://bukti-penantang" --private-key $CHALLENGER_PK --rpc-url $RPC >/dev/null 2>&1
CHID=$(cast call $CHALLENGE "openChallengeOf(uint256)(uint256)" $CERTID --rpc-url $RPC 2>/dev/null | awk '{print $1}')
echo "  challenge_id=$CHID dibuka oleh $CHALLENGER_ADDR (BUKAN gateway)"

echo "== 8. Tunggu liveness window, RESOLVER memutus (challenger MENANG) =="
sleep 35
BUYER_BAL_BEFORE=$(cast call $MOCK "balanceOf(address)(uint256)" $BUYER_ADDR --rpc-url $RPC | awk '{print $1}')
cast send $CHALLENGE "resolve(uint256,bool,string)" 1 true "ipfs://ruling" --private-key $RESOLVER_PK --rpc-url $RPC >/dev/null 2>&1
BUYER_BAL_AFTER=$(cast call $MOCK "balanceOf(address)(uint256)" $BUYER_ADDR --rpc-url $RPC | awk '{print $1}')
echo "  saldo BUYER sebelum=$BUYER_BAL_BEFORE sesudah=$BUYER_BAL_AFTER"
check_gt "$BUYER_BAL_AFTER" "$BUYER_BAL_BEFORE" "payout mendarat di BUYER (tahap TERAKHIR Golden Path)"

STATUS=$(curl -s localhost:$PORT/v1/cert/$CERTID | $PY -c 'import sys,json;print(json.load(sys.stdin)["status"])')
check "$STATUS" "REVOKED" "cert page melaporkan REVOKED setelah resolve"

echo "== 9. MINT #2 — kreator KEDUA tidak pernah approve (bukti fallback tidak breaking) =="
IMG2=$($PY -c "import io,base64;from PIL import Image,ImageDraw;im=Image.new('RGB',(400,400));d=ImageDraw.Draw(im);d.rectangle([0,0,200,400],fill=(5,5,5));d.rectangle([200,0,400,400],fill=(250,250,250));b=io.BytesIO();im.save(b,'PNG');print(base64.b64encode(b.getvalue()).decode())")
MINT2=$(curl -s -X POST localhost:$PORT/v1/mint -H 'content-type: application/json' -d "{\"image_b64\":\"$IMG2\",\"creator_address\":\"$CREATOR2_ADDR\",\"declared_value\":\"10000000\"}")
CERTID2=$($PY -c "import json;print(json.loads('''$MINT2''').get('cert_id','ERROR'))")
COLSRC2=$($PY -c "import json;print(json.loads('''$MINT2''').get('collateral_source','ERROR'))")
echo "  cert_id=$CERTID2 collateral_source=$COLSRC2 (creator2 tidak pernah approve apa pun)"
check "$COLSRC2" "gateway" "fallback tetap jalan untuk kreator yang belum approve — TIDAK breaking"

echo
if [ "$FAIL" = "0" ]; then
  echo "=== SEMUA CEK LOLOS — fitur kolateral-dari-kreator terverifikasi sampai tahap terakhir Golden Path (payout ke buyer) ==="
else
  echo "=== ADA CEK YANG GAGAL — lihat di atas ==="
fi
exit $FAIL
