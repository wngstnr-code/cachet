#!/usr/bin/env python3
"""Ubah hasil broadcast Foundry jadi tautan explorer yang bisa ditempel.

Kenapa ini ada: klaim produk Cachet adalah "bukti publik yang bisa dicek siapa
pun tanpa mempercayai Cachet". Klaim itu hanya berdiri kalau juri benar-benar
bisa membuka tiap transaksi dan melihat sendiri. Menyalin hash satu per satu
dari JSON di tengah rekaman terlalu lambat dan rawan salah.

Pakai: make demo-links
"""

import json
import os
import pathlib
import sys

# Demo hanya jalan di testnet (dipagari on-chain di DemoFlow/PrepareDemo), tapi
# CHAIN_ID tetap dibaca dari .env root supaya tautan tidak diam-diam menunjuk ke
# explorer yang salah kalau nanti ada babak lain di chain lain.
CHAIN_ID = os.environ.get("CHAIN_ID", "1952")
EXPLORER_BY_CHAIN = {
    "1952": "https://www.okx.com/web3/explorer/xlayer-test",
    "196": "https://www.okx.com/web3/explorer/xlayer",
}
EXPLORER = EXPLORER_BY_CHAIN.get(CHAIN_ID)

if EXPLORER is None:
    sys.exit(f"CHAIN_ID={CHAIN_ID} tidak dikenal (yang didukung: {', '.join(EXPLORER_BY_CHAIN)})")

# Nama fungsi -> babak dalam cerita demo, dalam urutan Golden Path.
# Label bahasa Inggris: output ini ditempel untuk juri internasional.
ACTS = {
    "registerAndMint": "1. Certificate issued to the creator",
    "transferFrom": "2. Creator SELLS to a buyer (the guarantee moves with it)",
    "challenge": "3. Challenger disputes with evidence",
    "resolve": "4. Resolver rules -> PAYOUT TO THE BUYER",
    "setWaitingPeriod": "prep: waiting period compressed (publicly recorded)",
    "setLivenessWindow": "prep: liveness window compressed (publicly recorded)",
    "fund": "prep: seed capital deposited into the vault",
    "mint": "prep: test USDT minted to a demo actor",
    "approve": "prep: vault funding approved",
}

ROOT = pathlib.Path(__file__).resolve().parent.parent
SCRIPTS = ["DemoFlow.s.sol", "PrepareDemo.s.sol"]


def collect():
    rows = []
    for script in SCRIPTS:
        base = ROOT / "broadcast" / script / CHAIN_ID
        if not base.exists():
            continue
        # Hanya *-latest.json (run-, challengeCert-, resolve-): tautan untuk
        # TAKE TERAKHIR. File run-<timestamp> adalah riwayat — menyertakannya
        # mencampur tx dari deployment lama yang sudah diorfankan.
        for run in sorted(base.glob("*-latest.json")):
            if "dry-run" in str(run):
                continue
            data = json.loads(run.read_text())
            for tx in data.get("transactions", []):
                fn = tx.get("function") or ""
                name = fn.split("(")[0] if fn else tx.get("transactionType", "")
                rows.append(
                    {
                        "name": name,
                        "hash": tx.get("hash"),
                        "label": ACTS.get(name, name),
                        "ts": data.get("timestamp", 0),
                    }
                )
    return rows


def main():
    rows = [r for r in collect() if r["hash"]]
    if not rows:
        print("No demo broadcast results yet. Run 'make demo' first.")
        return 0

    rows.sort(key=lambda r: r["ts"])
    seen, unik = set(), []
    for r in rows:
        if r["hash"] not in seen:
            seen.add(r["hash"])
            unik.append(r)
    rows = unik

    # Golden Path dulu (label berawalan angka babak), prep belakangan:
    # penonton harus melihat ceritanya sebelum setup-nya.
    story = [r for r in rows if r["label"][:1].isdigit()]
    prep = [r for r in rows if not r["label"][:1].isdigit()]

    print()
    print("=" * 66)
    print("  VERIFICATION LINKS — every step is a public transaction")
    print("=" * 66)
    for r in story:
        print()
        print(f"  {r['label']}")
        print(f"  {EXPLORER}/tx/{r['hash']}")
    if prep:
        print()
        print("-" * 66)
        print("  Demo setup (also public):")
        for r in prep:
            print()
            print(f"  {r['label']}")
            print(f"  {EXPLORER}/tx/{r['hash']}")

    print()
    print("-" * 66)
    print("  Contracts (source verified on Sourcify):")
    env = ROOT.parent / ".env"
    if env.exists():
        wanted = ("ADDR_REGISTRY", "ADDR_CERTIFICATE", "ADDR_VAULT", "ADDR_CHALLENGE", "ADDR_MOCKUSDT")
        for line in env.read_text().splitlines():
            key = line.split("=")[0].strip()
            if key in wanted and "=" in line:
                addr = line.split("=", 1)[1].split("#")[0].strip()
                if addr:
                    print(f"    {key:<17} {EXPLORER}/address/{addr}")
                    print(f"    {'':<17} https://repo.sourcify.dev/{CHAIN_ID}/{addr}")
    print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
