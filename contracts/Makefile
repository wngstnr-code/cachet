# Cachet contracts — Person B
#
# Kenapa Makefile: kita sepakat SATU file .env di root monorepo, sedangkan
# Foundry hanya membaca .env dari direktori kerjanya. Baris `-include ../.env`
# di bawah menyelesaikan itu, jadi jangan jalankan `forge script` telanjang —
# pakai target di sini.

-include ../.env
export

.PHONY: help build test test-gas fmt clean deploy-mockusdt deploy verify-env verify-deploy-env verify-demo-env demo-prep demo demo-challenge demo-resolve demo-all verify verify-status

help:
	@echo "make build            — compile"
	@echo "make test             — jalankan seluruh test"
	@echo "make test-gas         — test + laporan gas"
	@echo "make fmt              — format solidity"
	@echo "make verify-env       — cek .env root sudah terisi"
	@echo "make deploy-mockusdt  — deploy MockUSDT ke X Layer Testnet (+verifikasi)"
	@echo "make deploy           — deploy 4 kontrak inti + wiring (+verifikasi)"
	@echo "make demo-prep        — SEKALI: mampatkan waktu + modal vault"
	@echo "make demo             — babak 1-2: mint + jual (lalu tunggu coverage aktif)"
	@echo "make demo-challenge   — babak 3: CERT_ID=.. (G2: coverage harus sudah aktif)"
	@echo "make demo-resolve     — babak 4-5: CHALLENGE_ID=.. CERT_ID=.."
	@echo "make demo-all         — SMOKE TEST: babak 1-5 sekali jalan (tunggu otomatis)"
	@echo "make demo-links       — tautan explorer tiap tx demo (untuk juri)"
	@echo "make export-abi       — ekspor ABI ke packages/contracts-abi (untuk Person A)"
	@echo "make verify           — verifikasi susulan: ADDR=0x... NAME=src/X.sol:X"
	@echo "make verify-status    — cek status verifikasi: ADDR=0x..."

build:
	forge build

test:
	forge test -vv

test-gas:
	forge test --gas-report

fmt:
	forge fmt

clean:
	forge clean

# Gagal cepat dengan pesan jelas, bukan error viem/foundry yang membingungkan.
verify-env:
	@test -f ../.env || (echo "❌ ../.env tidak ada. Jalankan: cp ../.env.example ../.env"; exit 1)
	@test -n "$(RPC_URL)" || (echo "❌ RPC_URL kosong di ../.env"; exit 1)
	@test -n "$(DEPLOYER_PK)" || (echo "❌ DEPLOYER_PK kosong di ../.env"; exit 1)
	@echo "✅ .env root terbaca — RPC_URL=$(RPC_URL) CHAIN_ID=$(CHAIN_ID)"

# Verifikasi lewat Sourcify: gratis, tanpa API key, mendukung chain 1952 & 196.
# WAJIB untuk tiap deploy -- klaim produk ini "bukti publik yang bisa dicek
# siapa pun tanpa percaya Cachet". Kontrak yang di explorer hanya tampil sebagai
# bytecode mentah membuat klaim itu tidak berdiri sendiri.
VERIFY_FLAGS = --verify --verifier sourcify

deploy-mockusdt: verify-env
	forge script script/DeployMockUSDT.s.sol:DeployMockUSDT \
		--rpc-url $(RPC_URL) \
		--broadcast \
		$(VERIFY_FLAGS) \
		-vvv

# Deploy keempat kontrak inti + wiring lengkap. Gagal bila ada tautan
# yang tertinggal (assert di akhir Deploy.s.sol).
deploy: verify-env verify-deploy-env
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url $(RPC_URL) \
		--broadcast \
		$(VERIFY_FLAGS) \
		-vvv

verify-deploy-env:
	@test -n "$(ADDR_MOCKUSDT)" || (echo "❌ ADDR_MOCKUSDT kosong — deploy MockUSDT dulu"; exit 1)
	@test -n "$(GATEWAY_ADDR)"  || (echo "❌ GATEWAY_ADDR kosong — minta ke Person A (§3.4)"; exit 1)
	@test -n "$(RESOLVER_ADDR)" || (echo "❌ RESOLVER_ADDR kosong"; exit 1)
	@echo "✅ alamat untuk deploy lengkap"

# Verifikasi menyusul untuk kontrak yang sudah terlanjur ter-deploy tanpa --verify.
# Pemakaian: make verify ADDR=0x... NAME=src/MockUSDT.sol:MockUSDT
verify:
	@test -n "$(ADDR)" || (echo "❌ pakai: make verify ADDR=0x... NAME=src/X.sol:X"; exit 1)
	@test -n "$(NAME)" || (echo "❌ pakai: make verify ADDR=0x... NAME=src/X.sol:X"; exit 1)
	forge verify-contract $(ADDR) $(NAME) --verifier sourcify --chain-id $(CHAIN_ID)

# Cek status verifikasi sebuah alamat di Sourcify (tanpa mengirim apa pun).
verify-status:
	@test -n "$(ADDR)" || (echo "❌ pakai: make verify-status ADDR=0x..."; exit 1)
	@curl -s "https://sourcify.dev/server/v2/contract/$(CHAIN_ID)/$(ADDR)" \
		| python3 -m json.tool || echo "belum terverifikasi"

# ── Demo (B4) ────────────────────────────────────────────────────────────────
# Butuh GATEWAY_PK -- kunci milik Person A. Jalankan di sesi bersama
# (smoke test §6 / rekaman H6), bukan sendirian.

verify-demo-env:
	@test -n "$(ADDR_CERTIFICATE)"     || (echo "❌ ADDR_CERTIFICATE kosong — jalankan 'make deploy' dulu"; exit 1)
	@test -n "$(GATEWAY_PK)"           || (echo "❌ GATEWAY_PK kosong — kunci ini milik Person A"; exit 1)
	@test -n "$(DEMO_CREATOR_PK)"      || (echo "❌ DEMO_CREATOR_PK kosong"; exit 1)
	@test -n "$(DEMO_CHALLENGER_PK)"   || (echo "❌ DEMO_CHALLENGER_PK kosong"; exit 1)
	@test -n "$(RESOLVER_PK)"          || (echo "❌ RESOLVER_PK kosong"; exit 1)
	@echo "✅ demo env complete"

demo-prep: verify-env
	forge script script/PrepareDemo.s.sol:PrepareDemo --rpc-url $(RPC_URL) --broadcast -vvv

# Fase demo tanpa -vvv dan tanpa echo perintah: output ini yang direkam
# untuk publik — trace VM::env* dan estimasi gas hanya noise di layar.
demo: verify-demo-env
	@forge script script/DemoFlow.s.sol:DemoFlow --rpc-url $(RPC_URL) --broadcast

# Babak 3 terpisah (G2): gugatan baru sah setelah coverage aktif — kelayakan
# klaim dinilai pada momen gugatan dibuka, bukan saat resolve.
demo-challenge: verify-demo-env
	@test -n "$(CERT_ID)" || (echo "❌ pakai: make demo-challenge CERT_ID=1"; exit 1)
	@forge script script/DemoFlow.s.sol:DemoFlow \
		--sig "challengeCert(uint256)" $(CERT_ID) \
		--rpc-url $(RPC_URL) --broadcast

demo-resolve: verify-demo-env
	@test -n "$(CHALLENGE_ID)" || (echo "❌ pakai: make demo-resolve CHALLENGE_ID=1 CERT_ID=1"; exit 1)
	@test -n "$(CERT_ID)"      || (echo "❌ pakai: make demo-resolve CHALLENGE_ID=1 CERT_ID=1"; exit 1)
	@forge script script/DemoFlow.s.sol:DemoFlow \
		--sig "resolve(uint256,uint256)" $(CHALLENGE_ID) $(CERT_ID) \
		--rpc-url $(RPC_URL) --broadcast

# Smoke test satu perintah: babak 1-5 + demo-links, sleep otomatis di antara
# fase (durasi dibaca dari chain). Untuk rekaman tetap pakai fase terpisah.
demo-all: verify-demo-env
	@bash script/demo-all.sh

# Tautan verifikasi untuk juri: tiap transaksi demo -> URL explorer.
demo-links:
	@python3 script/demo-links.py

# Titik temu #2 (§11.2): ABI yang dipakai Person A menulis ChainClient.
# Wajib dijalankan ulang setiap kali interface kontrak berubah.
export-abi: build
	@python3 script/export-abi.py
