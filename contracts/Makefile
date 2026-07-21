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
	@echo "make deploy-mockusdt  — deploy MockUSDT ke X Layer Testnet"

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

deploy-mockusdt: verify-env
	forge script script/DeployMockUSDT.s.sol:DeployMockUSDT \
		--rpc-url $(RPC_URL) \
		--broadcast \
		-vvv
