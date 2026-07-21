# Cachet contracts — Person B
#
# Kenapa Makefile: kita sepakat SATU file .env di root monorepo, sedangkan
# Foundry hanya membaca .env dari direktori kerjanya. Baris `-include ../.env`
# di bawah menyelesaikan itu, jadi jangan jalankan `forge script` telanjang —
# pakai target di sini.

-include ../.env
export

.PHONY: help build test test-gas fmt clean deploy-mockusdt verify-env

help:
	@echo "make build            — compile"
	@echo "make test             — jalankan seluruh test"
	@echo "make test-gas         — test + laporan gas"
	@echo "make fmt              — format solidity"
	@echo "make verify-env       — cek .env root sudah terisi"
	@echo "make deploy-mockusdt  — deploy MockUSDT ke X Layer Testnet (+verifikasi)"
	@echo "make deploy           — deploy 4 kontrak inti + wiring (+verifikasi)"
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
