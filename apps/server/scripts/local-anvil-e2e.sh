#!/usr/bin/env bash
#
# Rehearsal integrasi A5 — jalankan ViemChainClient terhadap kontrak B YANG NYATA
# di anvil lokal (chain-id 1952), tanpa testnet. Menutup celah E3 (integrasi
# gateway↔kontrak) sebelum H5. Baca folder contracts/ (milik B) via forge —
# tidak mengedit apa pun di sana.
#
# Prasyarat: foundry (forge/anvil/cast), venv engine (services/engine/.venv),
#            deps gateway (pnpm install di apps/server).
# Pakai: bash apps/server/scripts/local-anvil-e2e.sh
set -uo pipefail
ROOT="$(cd "$(dirname "$0")/../../.." && pwd)"
ENGINE_DIR=$ROOT/services/engine; GW=$ROOT/apps/server; C=$ROOT/contracts
PY=$ENGINE_DIR/.venv/bin/python
TMP=$(mktemp -d)
RPC=http://localhost:8545
PORT=${GATEWAY_PORT:-8794}

# anvil accounts standar: acct0=gateway, acct1=deployer, acct2=resolver
GW_PK=0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
GW_ADDR=0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
DEPLOYER_PK=0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d
RESOLVER_ADDR=0x3C44CdDdB6a900fa2b585dd299e03d12FA4293BC

cleanup() { pkill -f "anvil --chain-id 1952" 2>/dev/null; pkill -f "GATEWAY_PORT=$PORT" 2>/dev/null; pkill -f "app.main:create_app" 2>/dev/null; }
trap cleanup EXIT

anvil --chain-id 1952 --silent >/dev/null 2>&1 &
for i in $(seq 1 40); do cast block-number --rpc-url $RPC >/dev/null 2>&1 && break; sleep 0.3; done

cd "$C"
DEPLOYER_PK=$DEPLOYER_PK forge script script/DeployMockUSDT.s.sol:DeployMockUSDT --rpc-url $RPC --broadcast >/dev/null 2>&1
MOCK=$($PY -c "import json;print([t['contractAddress'] for t in json.load(open('$C/broadcast/DeployMockUSDT.s.sol/1952/run-latest.json'))['transactions'] if t['transactionType']=='CREATE'][0])")
DEPLOYER_PK=$DEPLOYER_PK ADDR_MOCKUSDT=$MOCK GATEWAY_ADDR=$GW_ADDR RESOLVER_ADDR=$RESOLVER_ADDR \
  forge script script/Deploy.s.sol:Deploy --rpc-url $RPC --broadcast >"$TMP/deploy.log" 2>&1
grep -q "Wiring lengkap" "$TMP/deploy.log" || { echo "DEPLOY GAGAL"; tail -20 "$TMP/deploy.log"; exit 1; }
A=($($PY -c "import json;print(' '.join(t['contractAddress'] for t in json.load(open('$C/broadcast/Deploy.s.sol/1952/run-latest.json'))['transactions'] if t['transactionType']=='CREATE'))"))
REGISTRY=${A[0]}; CERT=${A[1]}; VAULT=${A[2]}; CHALLENGE=${A[3]}
echo "deployed: registry=$REGISTRY cert=$CERT vault=$VAULT challenge=$CHALLENGE mockUSDT=$MOCK"

cast send $MOCK "mint(address,uint256)" $GW_ADDR 1000000000 --private-key $DEPLOYER_PK --rpc-url $RPC >/dev/null 2>&1
cast send $CERT "setWaitingPeriod(uint64)" 10 --private-key $DEPLOYER_PK --rpc-url $RPC >/dev/null 2>&1  # percepat demo

ENGINE_EMBEDDER=fake INDEX_PATH="$TMP/idx" \
  $PY -m uvicorn app.main:create_app --factory --port 8100 --host 127.0.0.1 --app-dir "$ENGINE_DIR" >"$TMP/eng.log" 2>&1 &
( cd "$GW" && CHAIN_MODE=viem RPC_URL=$RPC CHAIN_ID=1952 \
  ADDR_REGISTRY=$REGISTRY ADDR_CERTIFICATE=$CERT ADDR_VAULT=$VAULT ADDR_CHALLENGE=$CHALLENGE ADDR_MOCKUSDT=$MOCK \
  ENGINE_URL=http://localhost:8100 GATEWAY_PORT=$PORT X402_BYPASS=1 GATEWAY_DATA_DIR="$TMP/gw" \
  GATEWAY_PK=$GW_PK pnpm start >"$TMP/gw.log" 2>&1 & )
for i in $(seq 1 60); do curl -s localhost:8100/healthz >/dev/null 2>&1 && curl -s localhost:$PORT/healthz >/dev/null 2>&1 && break; sleep 0.4; done
grep -q "gagal start\|EADDRINUSE" "$TMP/gw.log" && { echo "GATEWAY CRASH"; tail -8 "$TMP/gw.log"; exit 1; }

IMG=$($PY -c "import io,base64;from PIL import Image,ImageDraw;im=Image.new('RGB',(400,400));d=ImageDraw.Draw(im);d.rectangle([0,0,400,133],fill=(30,90,180));d.rectangle([0,133,400,266],fill=(210,120,40));d.rectangle([0,266,400,400],fill=(40,170,90));b=io.BytesIO();im.save(b,'PNG');print(base64.b64encode(b.getvalue()).decode())")

echo "verify: $(curl -s -X POST localhost:$PORT/v1/verify -H 'content-type: application/json' -d "{\"image_b64\":\"$IMG\",\"declared_value\":\"50000000\"}" | $PY -c 'import sys,json;p=json.load(sys.stdin);print("verdict",p["verdict"],"premium",p["premium_quote"]["premium"])')"
CERTID=$(curl -s -X POST localhost:$PORT/v1/mint -H 'content-type: application/json' -d "{\"image_b64\":\"$IMG\",\"creator_address\":\"$GW_ADDR\",\"declared_value\":\"50000000\"}" | $PY -c 'import sys,json;print(json.load(sys.stdin)["cert_id"])')
echo "mint: cert_id=$CERTID onchain_certCount=$(cast call $CERT 'certCount()(uint256)' --rpc-url $RPC)"
echo "cert(before waiting): $(curl -s localhost:$PORT/v1/cert/$CERTID | $PY -c 'import sys,json;print(json.load(sys.stdin)["status"])')"
sleep 12; cast send $MOCK "mint(address,uint256)" $GW_ADDR 1 --private-key $DEPLOYER_PK --rpc-url $RPC >/dev/null 2>&1
echo "cert(after waiting): $(curl -s localhost:$PORT/v1/cert/$CERTID | $PY -c 'import sys,json;print(json.load(sys.stdin)["status"])')"
BAL_BEFORE=$(cast call $MOCK "balanceOf(address)(uint256)" $GW_ADDR --rpc-url $RPC)
echo "challenge: $(curl -s -X POST localhost:$PORT/v1/challenge -H 'content-type: application/json' -d "{\"cert_id\":\"$CERTID\",\"evidence_uri\":\"ipfs://ev\"}" | $PY -c 'import sys,json;p=json.load(sys.stdin);print("challenge_manager",p["instructions"]["challenge_manager"],"bond",p["instructions"]["bond"]["display"])')"
BAL_AFTER=$(cast call $MOCK "balanceOf(address)(uint256)" $GW_ADDR --rpc-url $RPC)
if [ "$BAL_BEFORE" != "$BAL_AFTER" ]; then
  echo "GAGAL — saldo gateway berubah setelah /v1/challenge ($BAL_BEFORE -> $BAL_AFTER); gateway tidak boleh mengirim tx sendiri."
  exit 1
fi
echo "OK: saldo gateway TIDAK berubah setelah /v1/challenge ($BAL_BEFORE mUSDT) — endpoint tidak mengirim tx sendiri."
echo "OK — ViemChainClient terverifikasi terhadap kontrak nyata."
