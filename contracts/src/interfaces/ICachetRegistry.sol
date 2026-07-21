// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICachetRegistry — catatan "first-seen" untuk setiap karya
/// @notice Interface ini DIBEKUKAN di §3.1 technical plan (RFC-001). Perubahan
///         wajib disepakati Person A + Person B dan dicatat di changelog §3.
interface ICachetRegistry {
    /// @notice Kreator mengunci hash komitmen SEBELUM karya dipublikasikan.
    ///         Murah, privat, terbuka untuk siapa pun.
    ///
    /// RUMUS DIKUNCI (RFC-001 P4) — identik di NatSpec, helper gateway, README:
    ///   commitHash = keccak256(abi.encodePacked(
    ///       bytes32 phash0,   // hash PERTAMA ensemble (imagehash `phash`)
    ///       bytes32 salt,     // 32 byte acak milik kreator
    ///       address creator
    ///   ))
    /// Aman dari ambiguity `encodePacked` karena ketiganya tipe fixed-size.
    ///
    /// @dev Kontrak SENGAJA tidak memverifikasi isi commitment — ia hanya
    ///      menyimpan hash apa adanya. Verifikasi rumus dilakukan gateway saat
    ///      reveal. Trade-off ini disadari: on-chain kita hanya bisa
    ///      membuktikan "hash X ada sejak timestamp T", bukan "hash X memang
    ///      berasal dari karya Y". Itu sudah cukup untuk anti-sniping.
    ///
    /// @dev DIKETAHUI (audit B2a): `commit` bisa di-front-run. Penyerang yang
    ///      melihat tx di mempool bisa menyalin hash-nya dan mengirim lebih
    ///      dulu, membuat tx kreator revert dengan `CommitAlreadyExists`.
    ///      Dampaknya terbatas pada gas yang terbuang: hash tetap tercatat pada
    ///      timestamp yang praktis sama, dan hanya kreator yang tahu `salt`
    ///      sehingga hanya dia yang bisa reveal. Tidak dimitigasi di MVP karena
    ///      biayanya (commit dua fase) tidak sepadan dengan kerugiannya.
    function commit(bytes32 commitHash) external;

    /// @return timestamp komitmen, 0 bila tidak ada
    function commitTimestamp(bytes32 commitHash) external view returns (uint64);

    /// @notice Registrasi entri. HANYA gateway.
    /// @dev Sejak RFC-001 P1, "gateway" di Registry adalah **alamat kontrak
    ///      CachetCertificate**, bukan wallet — karena `registerAndMint` yang
    ///      memanggil fungsi ini di dalam satu transaksi atomik.
    /// @param phashes 4 hash ensemble
    /// @param embCommit keccak256 dari bytes embedding
    /// @param creator pemilik karya (= penerima sertifikat saat mint)
    /// @param revealedCommit 0x0 bila tanpa commit-reveal
    /// @param assetURI lokasi aset (IPFS/URL)
    function register(
        bytes32[4] calldata phashes,
        bytes32 embCommit,
        address creator,
        bytes32 revealedCommit,
        string calldata assetURI
    ) external returns (uint256 entryId);

    function entryCount() external view returns (uint256);

    /// @param entryId mulai dari 1; 0 tidak pernah valid
    function getEntry(uint256 entryId)
        external
        view
        returns (
            bytes32[4] memory phashes,
            bytes32 embCommit,
            address creator,
            uint64 registeredAt,
            uint64 commitAt,
            string memory assetURI
        );

    event Committed(bytes32 indexed commitHash, uint64 timestamp);
    event Registered(uint256 indexed entryId, address indexed creator, bytes32 phash0, uint64 timestamp);
}
