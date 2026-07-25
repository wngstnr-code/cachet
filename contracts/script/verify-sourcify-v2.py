#!/usr/bin/env python3
"""Verifikasi kontrak lewat Sourcify API v2.

Kenapa ini ada: `forge verify-contract --verifier sourcify` masih memakai API v1,
dan Sourcify sudah menaruh v1 dalam "brownout" — permintaan dijawab 503 dengan
pesan yang menyuruh migrasi ke v2. Foundry 1.3.5 belum bisa bicara v2 (mencoba
`--verifier-url .../v2` menghasilkan "error decoding response body"), jadi
verifikasi dilakukan langsung ke endpoint v2 dari sini.

Ini bukan kenyamanan. Klaim produk Cachet adalah "bukti publik yang bisa dicek
siapa pun tanpa mempercayai Cachet". Kontrak yang di explorer hanya tampil
sebagai bytecode mentah membuat klaim itu tidak berdiri sendiri.

Pakai:  make verify-v2 ENV_FILE=../.env.mainnet
        python3 script/verify-sourcify-v2.py [chainId]

Membaca alamat + tx pembuatan dari broadcast/Deploy.s.sol/<chainId>/run-latest.json,
jadi jalankan setelah `make deploy`. Aman diulang: kontrak yang sudah terverifikasi
dijawab 409 `already_verified` dan dilewati.
"""

import json
import pathlib
import subprocess
import sys
import time
import urllib.error
import urllib.request

SOURCIFY = "https://sourcify.dev/server/v2"
ROOT = pathlib.Path(__file__).resolve().parent.parent

# Kontrak inti saja. MockUSDT tidak pernah ada di mainnet (lihat DeployMockUSDT).
SOURCE_PATHS = {
    "CachetRegistry": "src/CachetRegistry.sol",
    "CachetCertificate": "src/CachetCertificate.sol",
    "CachetVault": "src/CachetVault.sol",
    "ChallengeManager": "src/ChallengeManager.sol",
}


def compiler_version() -> str:
    """Versi solc PERSIS dari artifact, bukan dari foundry.toml.

    foundry.toml hanya menyebut "0.8.24"; Sourcify menuntut versi lengkap dengan
    commit hash. Mengarangnya berarti bytecode tidak akan pernah cocok.
    """
    art = json.loads((ROOT / "out/CachetRegistry.sol/CachetRegistry.json").read_text())
    version = art.get("metadata", {}).get("compiler", {}).get("version")
    if not version:
        sys.exit("Tidak menemukan versi compiler di out/ — jalankan `forge build` dulu.")
    return version


def standard_json_input(address: str, identifier: str) -> dict:
    out = subprocess.run(
        ["forge", "verify-contract", address, identifier, "--show-standard-json-input"],
        capture_output=True,
        text=True,
        cwd=ROOT,
    )
    if out.returncode != 0 or not out.stdout.strip():
        sys.exit(f"Gagal membuat standard-json-input untuk {identifier}:\n{out.stderr[:400]}")
    return json.loads(out.stdout)


def post(url: str, body: dict) -> tuple[int, str]:
    req = urllib.request.Request(
        url,
        data=json.dumps(body).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        with urllib.request.urlopen(req) as r:
            return r.status, r.read().decode()
    except urllib.error.HTTPError as e:
        return e.code, e.read().decode()


def match_status(chain_id: str, address: str) -> str:
    try:
        with urllib.request.urlopen(f"{SOURCIFY}/contract/{chain_id}/{address}") as r:
            return json.load(r).get("match") or "belum cocok"
    except urllib.error.URLError as e:
        return f"gagal dicek ({e})"


def main() -> None:
    chain_id = sys.argv[1] if len(sys.argv) > 1 else "196"

    broadcast = ROOT / f"broadcast/Deploy.s.sol/{chain_id}/run-latest.json"
    if not broadcast.exists():
        sys.exit(f"Tidak ada {broadcast} — jalankan `make deploy` dulu.")

    txs = json.loads(broadcast.read_text())["transactions"]
    created = {
        t["contractName"]: (t["contractAddress"], t["hash"])
        for t in txs
        if t.get("transactionType") == "CREATE" and t.get("contractName") in SOURCE_PATHS
    }
    if not created:
        sys.exit("Tidak ada kontrak inti di broadcast terakhir.")

    version = compiler_version()
    print(f"chain {chain_id} · solc {version}\n")

    submitted = []
    for name, (address, tx_hash) in created.items():
        identifier = f"{SOURCE_PATHS[name]}:{name}"
        status, raw = post(
            f"{SOURCIFY}/verify/{chain_id}/{address}",
            {
                "stdJsonInput": standard_json_input(address, identifier),
                "compilerVersion": version,
                "contractIdentifier": identifier,
                # Tanpa ini Sourcify hanya bisa mencocokkan runtime bytecode;
                # dengan tx pembuatan, argumen constructor ikut terverifikasi.
                "creationTransactionHash": tx_hash,
            },
        )
        if status == 202:
            print(f"  {name:<20} dikirim")
            submitted.append(name)
        elif status == 409 and "already_verified" in raw:
            print(f"  {name:<20} sudah terverifikasi")
        else:
            print(f"  {name:<20} GAGAL (HTTP {status}) {raw[:160]}")

    if submitted:
        print("\nmenunggu Sourcify memproses...")
        time.sleep(20)

    print("\nhasil:")
    failed = []
    for name, (address, _) in created.items():
        m = match_status(chain_id, address)
        print(f"  {name:<20} {address}  {m}")
        if m != "exact_match":
            failed.append(name)

    if failed:
        print(f"\nBelum exact_match: {', '.join(failed)}. Jalankan ulang beberapa saat lagi.")
        sys.exit(1)
    print("\nSemua kontrak exact_match — sumber publik di https://repo.sourcify.dev/")


if __name__ == "__main__":
    main()
