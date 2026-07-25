#!/usr/bin/env python3
"""Ekspor ABI kontrak ke packages/contracts-abi/ — titik temu #2 (§11.2).

Kenapa di-generate, bukan ditulis tangan: ABI yang menyimpang dari kontrak
adalah bug paling mahal di seluruh proyek ini. Person A menulis ChainClient
berdasarkan file di sini; kalau isinya basi, kegagalannya baru muncul di hari
integrasi sebagai error encoding yang tidak menunjuk ke mana pun.

Pakai: make export-abi
"""

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = ROOT / "out"
DEST = ROOT.parent / "packages" / "contracts-abi"

# Hanya kontrak yang benar-benar dipanggil Person A. Interface tidak diekspor:
# yang mengikat adalah ABI implementasi, dan mengekspor keduanya membuka
# peluang A memakai yang salah.
CONTRACTS = [
    ("CachetRegistry", "Registry first-seen + commit-reveal"),
    ("CachetCertificate", "ERC-721 pembawa coverage. Di sinilah registerAndMint."),
    ("CachetVault", "Bond, premi, pembayaran klaim"),
    ("ChallengeManager", "Gugatan & putusan"),
    ("MockUSDT", "Token pembayaran testnet (6 desimal)"),
]


def load_abi(name: str):
    artifact = OUT / f"{name}.sol" / f"{name}.json"
    if not artifact.exists():
        print(f"❌ artefak tidak ada: {artifact}\n   jalankan 'forge build' dulu")
        sys.exit(1)
    return json.loads(artifact.read_text())["abi"]


def main() -> int:
    (DEST / "abi").mkdir(parents=True, exist_ok=True)

    exported = {}
    for name, _desc in CONTRACTS:
        abi = load_abi(name)
        (DEST / "abi" / f"{name}.json").write_text(json.dumps(abi, indent=2) + "\n")
        exported[name] = abi
        fns = sum(1 for e in abi if e.get("type") == "function")
        evs = sum(1 for e in abi if e.get("type") == "event")
        print(f"  {name:<20} {fns:>3} fungsi, {evs:>2} event")

    # index.ts: viem butuh `as const` supaya inferensi tipe jalan. Tanpa itu
    # Person A kehilangan autocomplete dan pengecekan argumen — persis lapisan
    # yang paling mungkin menangkap salah encoding sebelum sampai ke chain.
    lines = [
        "// DIHASILKAN OTOMATIS oleh contracts/script/export-abi.py — JANGAN diedit tangan.",
        "// Regenerasi: cd contracts && make export-abi",
        "//",
        "// `as const` WAJIB: itu yang memberi viem inferensi tipe penuh.",
        "",
        'import addressesTestnet from "./addresses.testnet.json";',
        'import addressesMainnet from "./addresses.mainnet.json";',
        "",
        "/** Deployment per chainId. Kedua file berbentuk identik, jadi consumer",
        " *  bisa memilih salah satunya tanpa percabangan tipe. */",
        "export const addressesByChain = {",
        "  1952: addressesTestnet,",
        "  196: addressesMainnet,",
        "} as const;",
        "",
        "export type SupportedChainId = keyof typeof addressesByChain;",
        "",
        "/** Default historis = testnet. DIPERTAHANKAN supaya consumer lama tidak",
        " *  berubah arti diam-diam; kode baru sebaiknya memilih lewat addressesByChain. */",
        "export const addresses = addressesTestnet;",
        "export { addressesTestnet, addressesMainnet };",
        "",
    ]
    for name, desc in CONTRACTS:
        lines.append(f"/** {desc} */")
        lines.append(f"export const {name}Abi = {json.dumps(exported[name], indent=2)} as const;")
        lines.append("")
    (DEST / "index.ts").write_text("\n".join(lines))

    print(f"\n✅ {len(CONTRACTS)} ABI + index.ts -> packages/contracts-abi/")
    return 0


if __name__ == "__main__":
    sys.exit(main())
