// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICachetRegistry} from "./interfaces/ICachetRegistry.sol";
import {CachetGoverned} from "./base/CachetGoverned.sol";

/// @title CachetRegistry — catatan first-seen + commit-reveal
/// @notice Menyimpan sidik jari (4 pHash) tiap karya beserta waktu pertama
///         terlihat. Ini basis klaim Cachet: "first-seen di registry Cachet
///         per timestamp T" — BUKAN klaim keaslian, dan BUKAN klaim tentang
///         seluruh internet.
///
/// @dev Tidak upgradeable (§5.0). Tidak punya parameter yang bisa disetel —
///      mewarisi CachetGoverned hanya untuk Ownable + konsistensi error.
contract CachetRegistry is ICachetRegistry, CachetGoverned {
    struct Entry {
        bytes32[4] phashes;
        bytes32 embCommit;
        address creator;
        uint64 registeredAt;
        uint64 commitAt;
        string assetURI;
    }

    /// @notice Alamat yang boleh memanggil `register`.
    /// @dev Sejak RFC-001 P1 ini adalah **alamat kontrak CachetCertificate**,
    ///      bukan wallet gateway — `registerAndMint` yang memanggil register
    ///      di dalam satu transaksi atomik. Salah men-set ini ke wallet akan
    ///      membuat seluruh jalur mint revert dengan `NotGateway`.
    address public gateway;

    mapping(uint256 => Entry) private _entries;
    uint256 private _entryCount;

    mapping(bytes32 => uint64) private _commitTimestamp;

    /// @notice Commit yang sudah dipakai untuk sebuah registrasi.
    /// @dev TAMBAHAN di luar §3.1 (bukan perubahan interface). Tanpa ini, satu
    ///      commit lama bisa dipakai berkali-kali untuk mengklaim timestamp
    ///      awal yang sama pada banyak karya berbeda — persis serangan yang
    ///      commit-reveal seharusnya cegah. Retry mint yang gagal tetap aman:
    ///      tx yang revert tidak menandai commit sebagai terpakai.
    mapping(bytes32 => bool) public commitConsumed;

    error NotGateway(address caller, address expected);
    error CommitAlreadyExists(bytes32 commitHash);
    error CommitNotFound(bytes32 commitHash);
    error CommitAlreadyConsumed(bytes32 commitHash);
    error InvalidEntryId(uint256 entryId);
    error InvalidCreator();

    event GatewaySet(address indexed previous, address indexed current);

    modifier onlyGateway() {
        if (msg.sender != gateway) revert NotGateway(msg.sender, gateway);
        _;
    }

    constructor(address owner_) CachetGoverned(owner_) {}

    // ── Wiring (§3.1) ────────────────────────────────────────────────────────

    /// @param gateway_ alamat kontrak CachetCertificate (lihat catatan di atas)
    /// @dev Set-once. Wiring salah = redeploy (lihat `_lockWiring`).
    function setGateway(address gateway_) external onlyOwner {
        if (gateway_ == address(0)) revert ZeroAddress();
        _lockWiring(gateway, "registry.gateway");
        emit GatewaySet(gateway, gateway_);
        gateway = gateway_;
    }

    // ── Commit-reveal ────────────────────────────────────────────────────────

    /// @inheritdoc ICachetRegistry
    function commit(bytes32 commitHash) external {
        // Menolak overwrite: kalau boleh ditimpa, penyerang bisa "menyegarkan"
        // timestamp commit orang lain dan menghancurkan klaim prioritasnya.
        if (_commitTimestamp[commitHash] != 0) revert CommitAlreadyExists(commitHash);

        uint64 nowTs = uint64(block.timestamp);
        _commitTimestamp[commitHash] = nowTs;
        emit Committed(commitHash, nowTs);
    }

    /// @inheritdoc ICachetRegistry
    function commitTimestamp(bytes32 commitHash) external view returns (uint64) {
        return _commitTimestamp[commitHash];
    }

    // ── Registrasi ───────────────────────────────────────────────────────────

    /// @inheritdoc ICachetRegistry
    /// @dev TIDAK ada dedup pHash on-chain. Penolakan registrasi ulang untuk
    ///      sidik jari identik dilakukan di gateway (invariant §9.5) — di sini
    ///      biayanya akan O(n) terhadap seluruh registry dan tidak terjangkau.
    ///      Konsekuensinya: kontrak ini percaya gateway sudah menyaring.
    function register(
        bytes32[4] calldata phashes,
        bytes32 embCommit,
        address creator,
        bytes32 revealedCommit,
        string calldata assetURI
    ) external onlyGateway returns (uint256 entryId) {
        if (creator == address(0)) revert InvalidCreator();

        uint64 commitAt = 0;
        if (revealedCommit != bytes32(0)) {
            uint64 committedAt = _commitTimestamp[revealedCommit];
            if (committedAt == 0) revert CommitNotFound(revealedCommit);
            if (commitConsumed[revealedCommit]) revert CommitAlreadyConsumed(revealedCommit);

            commitConsumed[revealedCommit] = true;
            commitAt = committedAt;
        }

        // entryId mulai dari 1 supaya 0 selalu berarti "tidak ada" —
        // §3.2 memakai null/0 untuk nearest_entry_id saat registry kosong.
        entryId = ++_entryCount;

        _entries[entryId] = Entry({
            phashes: phashes,
            embCommit: embCommit,
            creator: creator,
            registeredAt: uint64(block.timestamp),
            commitAt: commitAt,
            assetURI: assetURI
        });

        emit Registered(entryId, creator, phashes[0], uint64(block.timestamp));
    }

    // ── Baca ─────────────────────────────────────────────────────────────────

    /// @inheritdoc ICachetRegistry
    function entryCount() external view returns (uint256) {
        return _entryCount;
    }

    /// @inheritdoc ICachetRegistry
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
        )
    {
        if (entryId == 0 || entryId > _entryCount) revert InvalidEntryId(entryId);
        Entry storage e = _entries[entryId];
        return (e.phashes, e.embCommit, e.creator, e.registeredAt, e.commitAt, e.assetURI);
    }
}
