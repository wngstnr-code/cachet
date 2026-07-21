// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICachetCertificate — ERC-721 yang MEMBAWA coverage
/// @notice DIBEKUKAN di §3.1 technical plan (RFC-001).
///
///         Inti produk ada di sini: sertifikat adalah NFT biasa yang bisa
///         dipindahtangankan, dan seluruh data coverage di-key oleh `tokenId`.
///         Akibatnya transfer NFT = transfer coverage, tanpa logika tambahan.
///         **Jangan pernah membuat token ini soulbound** — itu menghapus
///         pembeda utama Cachet ("jaminan ikut pembeli").
interface ICachetCertificate {
    struct CertData {
        uint256 entryId; // link ke CachetRegistry
        uint256 declaredValue; // base unit payToken (6 desimal)
        uint64 mintedAt;
        uint64 coverageStart; // mintedAt + waitingPeriod
        uint64 coverageEnd; // coverageStart + coverageTerm
        bool insurable; // false utk GRAY_ZONE / ditolak underwriting
        bool revoked; // true bila kalah challenge
        uint32 challengesSurvived;
    }

    /// @notice Parameter jalur mint atomik (RFC-001 P1 Opsi C).
    /// @dev Digabung jadi satu struct supaya `registerAndMint` tidak punya
    ///      10 parameter posisional yang mudah tertukar.
    struct MintRequest {
        address to; // penerima cert = kreator saat mint
        bytes32[4] phashes;
        bytes32 embCommit;
        bytes32 revealedCommit; // 0x0 bila tanpa commit-reveal
        string assetURI;
        string tokenURI_;
        uint256 declaredValue; // base unit, 6 desimal
        uint256 fraudBond; // base unit
        uint256 premium; // base unit
        bool insurable;
    }

    /// @notice JALUR PRODUKSI: register + mint + tarik dana dalam SATU tx.
    /// @dev Urutan internal: registry.register → _safeMint → vault.collectOnMint.
    ///      Satu langkah gagal = seluruh tx revert. Ini yang menghilangkan
    ///      entri yatim di registry (RFC-001 P8) sekaligus masalah ayam-telur
    ///      `certId` pada `collectOnMint` (P1). onlyGateway.
    function registerAndMint(MintRequest calldata r) external returns (uint256 entryId, uint256 certId);

    /// @notice Mint terpisah, TANPA register dan TANPA tarik dana.
    /// @dev Disediakan untuk unit test dan skenario darurat. Jalur produksi
    ///      HARUS lewat `registerAndMint`. onlyGateway.
    function mintCertificate(
        address to,
        uint256 entryId,
        uint256 declaredValue,
        bool insurable,
        string calldata tokenURI_
    ) external returns (uint256 certId);

    function certData(uint256 certId) external view returns (CertData memory);

    /// @notice Coverage aktif = insurable && !revoked && now ∈ [start, end].
    /// @dev Dicek ON-CHAIN, bukan hanya di gateway (invariant §9.4).
    function isCoverageActive(uint256 certId) external view returns (bool);

    /// @dev onlyChallengeManager
    function markRevoked(uint256 certId) external;

    /// @dev onlyChallengeManager
    function incrementSurvived(uint256 certId) external;

    event CertificateMinted(
        uint256 indexed certId, uint256 indexed entryId, address indexed to, uint256 declaredValue
    );
}
