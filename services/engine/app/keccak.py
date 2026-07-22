"""keccak256 (Ethereum), BUKAN SHA3-256 standar.

embedding_commit = keccak256(vektor float32 bytes) (§4-A1.3). Dipakai gateway
sebagai bytes32 embCommit saat register on-chain. Wajib keccak, bukan sha3:
Solidity/viem memakai keccak, dan nilai ini harus konsisten dengan sisi chain.
"""

from __future__ import annotations

from Crypto.Hash import keccak as _keccak


def keccak256(data: bytes) -> bytes:
    h = _keccak.new(digest_bits=256)
    h.update(data)
    return h.digest()


def keccak256_hex(data: bytes) -> str:
    return "0x" + keccak256(data).hex()
