#!/usr/bin/env python3
"""Ubah hasil broadcast Foundry jadi tautan explorer yang bisa ditempel.

Kenapa ini ada: klaim produk Cachet adalah "bukti publik yang bisa dicek siapa
pun tanpa mempercayai Cachet". Klaim itu hanya berdiri kalau juri benar-benar
bisa membuka tiap transaksi dan melihat sendiri. Menyalin hash satu per satu
dari JSON di tengah rekaman terlalu lambat dan rawan salah.

Pakai: make demo-links
"""

import json
import pathlib
import sys

CHAIN_ID = "1952"
EXPLORER = "https://www.okx.com/web3/explorer/xlayer-test"

# Nama fungsi -> babak dalam cerita demo, dalam urutan Golden Path.
BABAK = {
    "registerAndMint": "1. Sertifikat diterbitkan untuk kreator",
    "transferFrom": "2. Kreator MENJUAL ke pembeli (jaminan ikut pindah)",
    "challenge": "3. Penantang menggugat dengan bukti",
    "resolve": "4. Resolver memutus -> PAYOUT KE PEMBELI",
    "setWaitingPeriod": "prep: masa tunggu dipercepat (tercatat publik)",
    "setLivenessWindow": "prep: jendela liveness dipercepat (tercatat publik)",
    "fund": "prep: modal awal disetor ke vault",
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
                        "label": BABAK.get(name, name),
                        "ts": data.get("timestamp", 0),
                    }
                )
    return rows


def main():
    rows = [r for r in collect() if r["hash"]]
    if not rows:
        print("Belum ada hasil broadcast demo. Jalankan 'make demo' dulu.")
        return 0

    rows.sort(key=lambda r: r["ts"])
    seen, unik = set(), []
    for r in rows:
        if r["hash"] not in seen:
            seen.add(r["hash"])
            unik.append(r)
    rows = unik

    print()
    print("=" * 66)
    print("  TAUTAN VERIFIKASI — buka satu per satu saat merekam")
    print("=" * 66)
    for r in rows:
        print()
        print(f"  {r['label']}")
        print(f"  {EXPLORER}/tx/{r['hash']}")

    print()
    print("-" * 66)
    print("  Kontrak (source terverifikasi di Sourcify):")
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
