# Cachet contracts — Person B
#
# Kenapa Makefile: kita sepakat SATU file .env di root monorepo, sedangkan
# Foundry hanya membaca .env dari direktori kerjanya. Baris `-include ../.env`
# di bawah menyelesaikan itu, jadi jangan jalankan `forge script` telanjang —
# pakai target di sini.

# ENV_FILE bisa ditimpa supaya deploy ke chain lain tidak perlu mengedit .env
# root yang dipakai BERSAMA (gateway A + cert page B ikut membacanya -- menimpanya
# ke mainnet akan mematikan setup testnet semua orang tanpa peringatan).
#
#   make deploy ENV_FILE=../.env.mainnet
#
# Lewat file, bukan variabel command line: `make deploy DEPLOYER_PK=0x...`
# menaruh kunci mainnet di shell history dan di output `ps`.
ENV_FILE ?= ../.env

-include $(ENV_FILE)
export

.PHONY: help build test test-gas fmt clean deploy-mockusdt deploy set-params verify-v2 verify-env verify-deploy-env verify-demo-env demo-prep demo demo-challenge demo-resolve demo-all verify verify-status

help:
	@echo "make build            — compile"
	@echo "make test             — jalankan seluruh test"
	@echo "make test-gas         — test + laporan gas"
	@echo "make fmt              — format solidity"
	@echo "make verify-env       — cek .env root sudah terisi"
	@echo "make deploy-mockusdt  — deploy MockUSDT ke X Layer Testnet (+verifikasi)"
	@echo "make deploy           — deploy 4 kontrak inti + wiring (+verifikasi)"
	@echo "make set-params       — MAINNET: turunkan plafon ke ukuran modal nyata"
	@echo "make demo-prep        — SEKALI: mampatkan waktu + modal vault"
	@echo "make demo             — babak 1-2: mint + jual (lalu tunggu coverage aktif)"
	@echo "make demo-challenge   — babak 3: CERT_ID=.. (G2: coverage harus sudah aktif)"
	@echo "make demo-resolve     — babak 4-5: CHALLENGE_ID=.. CERT_ID=.."
	@echo "make demo-all         — SMOKE TEST: babak 1-5 sekali jalan (tunggu otomatis)"
	@echo "make demo-links       — tautan explorer tiap tx demo (untuk juri)"
	@echo "make export-abi       — ekspor ABI ke packages/contracts-abi (untuk Person A)"
	@echo "make verify           — verifikasi susulan: ADDR=0x... NAME=src/X.sol:X"
	@echo "make verify-v2        — verifikasi susulan lewat Sourcify API v2"
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
	@test -f $(ENV_FILE) || (echo "❌ $(ENV_FILE) tidak ada. Jalankan: cp ../.env.example ../.env"; exit 1)
	@test -n "$(RPC_URL)" || (echo "❌ RPC_URL kosong di $(ENV_FILE)"; exit 1)
	@test -n "$(DEPLOYER_PK)" || (echo "❌ DEPLOYER_PK kosong di $(ENV_FILE)"; exit 1)
	@test -n "$(CHAIN_ID)" || (echo "❌ CHAIN_ID kosong di $(ENV_FILE)"; exit 1)
	@echo "✅ $(ENV_FILE) terbaca — RPC_URL=$(RPC_URL) CHAIN_ID=$(CHAIN_ID)"
	@# Pagar terakhir sebelum uang sungguhan: RPC dan CHAIN_ID harus sepakat.
	@# Tanpa ini, CHAIN_ID=196 + RPC testnet yang tertinggal = deploy diam-diam
	@# mendarat di chain yang salah, dan baru ketahuan saat alamatnya dipakai.
	@ACTUAL=$$(cast chain-id --rpc-url $(RPC_URL)); \
	  test "$$ACTUAL" = "$(CHAIN_ID)" || \
	  (echo "❌ RPC menjawab chainId $$ACTUAL, tapi CHAIN_ID=$(CHAIN_ID). Perbaiki $(ENV_FILE)."; exit 1)
	@echo "✅ RPC cocok dengan CHAIN_ID=$(CHAIN_ID)"

# Verifikasi lewat Sourcify: gratis, tanpa API key, mendukung chain 1952 & 196.
# WAJIB untuk tiap deploy -- klaim produk ini "bukti publik yang bisa dicek
# siapa pun tanpa percaya Cachet". Kontrak yang di explorer hanya tampil sebagai
# bytecode mentah membuat klaim itu tidak berdiri sendiri.
#
# ⚠️ Foundry 1.3.5 memakai Sourcify API v1, dan v1 sekarang sering menjawab
#    503 "API v1 Brownout". Kalau `make deploy` gagal di tahap verifikasi
#    (kontraknya TETAP ter-deploy -- cek broadcast/), lanjutkan dengan:
#        make verify-v2 ENV_FILE=<file yang sama>
VERIFY_FLAGS = --verify --verifier sourcify

# Verifikasi susulan lewat Sourcify API v2 (lihat script/verify-sourcify-v2.py).
verify-v2:
	@test -n "$(CHAIN_ID)" || (echo "❌ CHAIN_ID kosong di $(ENV_FILE)"; exit 1)
	@python3 script/verify-sourcify-v2.py $(CHAIN_ID)

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

# Turunkan plafon ke ukuran modal yang benar-benar ada. Jalankan SETELAH
# `make deploy`, SEBELUM sertifikat pertama diterbitkan.
set-params: verify-env
	@test -n "$(ADDR_CERTIFICATE)" || (echo "❌ ADDR_CERTIFICATE kosong — jalankan 'make deploy' dulu"; exit 1)
	@test -n "$(ADDR_VAULT)"       || (echo "❌ ADDR_VAULT kosong — jalankan 'make deploy' dulu"; exit 1)
	@test -n "$(ADDR_CHALLENGE)"   || (echo "❌ ADDR_CHALLENGE kosong — jalankan 'make deploy' dulu"; exit 1)
	forge script script/SetMainnetParams.s.sol:SetMainnetParams \
		--rpc-url $(RPC_URL) \
		--broadcast \
		-vvv

verify-deploy-env:
	@test -n "$(ADDR_MOCKUSDT)" || (echo "❌ ADDR_MOCKUSDT kosong — deploy MockUSDT dulu"; exit 1)
	@test -n "$(GATEWAY_ADDR)"  || (echo "❌ GATEWAY_ADDR kosong — minta ke Person A (§3.4)"; exit 1)
	@test -n "$(RESOLVER_ADDR)" || (echo "❌ RESOLVER_ADDR kosong"; exit 1)
	@# Spasi di belakang nilai dan komentar inline TIDAK dipotong `make` (shell
	@# memotongnya, jadi salah ini tak terlihat saat dites manual). Akibatnya
	@# muncul jauh kemudian sebagai "failed parsing $$VAR as type address" dari
	@# forge — pesan yang tidak menyebut penyebab sebenarnya sama sekali, dan
	@# mahal didiagnosis tepat sebelum deploy mainnet.
	@for pair in "ADDR_MOCKUSDT=$(ADDR_MOCKUSDT)" "GATEWAY_ADDR=$(GATEWAY_ADDR)" "RESOLVER_ADDR=$(RESOLVER_ADDR)"; do \
	  n=$${pair%%=*}; v=$${pair#*=}; \
	  printf '%s' "$$v" | grep -Eq '^0x[0-9a-fA-F]{40}$$' || { \
	    echo "❌ $$n bukan alamat bersih -> [$$v]"; \
	    echo "   Hapus spasi berlebih / komentar inline pada barisnya di $(ENV_FILE)."; \
	    exit 1; }; \
	done
	@echo "✅ alamat untuk deploy lengkap & berformat benar"

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
