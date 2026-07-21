// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {ERC721URIStorage} from "@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ICachetCertificate} from "./interfaces/ICachetCertificate.sol";
import {ICachetRegistry} from "./interfaces/ICachetRegistry.sol";
import {ICachetVault} from "./interfaces/ICachetVault.sol";
import {CachetGoverned} from "./base/CachetGoverned.sol";

/// @title CachetCertificate — First-Seen Certificate (ERC-721 pembawa coverage)
/// @notice Sertifikat = NFT biasa. Seluruh data coverage di-key oleh `tokenId`,
///         jadi **transfer NFT otomatis memindahkan coverage** tanpa logika
///         tambahan. Inilah pembeda utama Cachet: kalau aset dijual, jaminan
///         ikut pembeli — bukan tinggal di kreator.
///
///         Jangan pernah menjadikan token ini soulbound atau membatasi
///         transfer. Itu menghapus alasan produk ini ada.
///
/// @dev Tidak upgradeable (§5.0). Yang bisa diubah owner hanya angka
///      kebijakan, dan setiap perubahan emit `ParamChanged`.
contract CachetCertificate is ICachetCertificate, ERC721URIStorage, CachetGoverned, ReentrancyGuard {
    // ── Wiring (§3.1) ────────────────────────────────────────────────────────

    /// @notice Wallet gateway milik Person A — satu-satunya yang boleh mint.
    address public gateway;
    /// @notice ChallengeManager — satu-satunya yang boleh revoke / tambah survived.
    address public challengeManager;

    ICachetRegistry public registry;
    ICachetVault public vault;

    // ── Parameter kebijakan (variabel, BUKAN constant — §5.0) ────────────────

    /// @notice Jeda sebelum coverage aktif. Menahan klaim instan atas karya
    ///         yang di-mint justru karena kreator sudah tahu ada sengketa.
    uint64 public waitingPeriod = 72 hours;
    /// @notice Lama coverage berlaku. Sertifikatnya sendiri tetap perpetual.
    uint64 public coverageTerm = 365 days;
    /// @notice Plafon nilai yang dijamin. Jujur: coverage terbatas selama bootstrap.
    uint256 public maxDeclaredValue = 100e6; // 100 USDT (6 desimal)

    // ── Pagar parameter: konstanta SUNGGUHAN, tidak bisa diubah siapa pun ────
    //
    // Tanpa batas ini, owner bisa menyetel `waitingPeriod` sangat besar dan
    // membuat coverage tidak pernah aktif — secara teknis "hanya mengubah
    // parameter", tapi efeknya membatalkan jaminan. Nilai ekstrem juga membuat
    // `mintedAt + waitingPeriod` overflow uint64 sehingga SELURUH penerbitan
    // sertifikat revert (terbukti saat audit B2a).
    //
    // Inilah yang membuat janji §5.0 "parameter boleh berubah, aturan main
    // tidak" benar-benar ditegakkan kontrak, bukan sekadar niat baik owner.

    uint64 public constant MAX_WAITING_PERIOD = 30 days;
    uint64 public constant MAX_COVERAGE_TERM = 3650 days; // 10 tahun

    /// @notice Lantai = nilai tercepat yang pernah kami niatkan dipakai, yaitu
    ///         setelan demo. Mencegah masa tunggu dimatikan sepenuhnya.
    uint64 public constant MIN_WAITING_PERIOD = 10 seconds;
    /// @notice Coverage berumur sangat pendek = sertifikat tanpa makna.
    uint64 public constant MIN_COVERAGE_TERM = 1 days;

    /// @notice Plafon tertinggi yang boleh disetel untuk `maxDeclaredValue`.
    /// @dev Tanpa pagar ini, owner bisa menaikkan plafon sampai tak terhingga
    ///      lalu menerbitkan satu sertifikat yang jaminannya sebesar seluruh
    ///      saldo vault. Membatasi ledakan terburuk dari satu sertifikat.
    ///      10.000 USDT memberi ruang tumbuh 100x dari default tanpa membuka
    ///      pintu itu.
    uint256 public constant MAX_DECLARED_VALUE_CEILING = 10_000e6;

    mapping(uint256 => CertData) private _certData;
    uint256 private _certCount;

    error NotGateway(address caller, address expected);
    error NotChallengeManager(address caller, address expected);
    error NotWired(string what);
    error DeclaredValueTooHigh(uint256 declaredValue, uint256 max);
    error InvalidCertId(uint256 certId);
    error AlreadyRevoked(uint256 certId);
    error ParamOutOfRange(uint64 value, uint64 max);
    error ValueOutOfRange(uint256 value, uint256 max);
    error UnknownEntryId(uint256 entryId, uint256 entryCount);

    event GatewaySet(address indexed previous, address indexed current);
    event ChallengeManagerSet(address indexed previous, address indexed current);
    event RegistrySet(address indexed previous, address indexed current);
    event VaultSet(address indexed previous, address indexed current);
    event CertificateRevoked(uint256 indexed certId);
    event ChallengeSurvived(uint256 indexed certId, uint32 total);

    modifier onlyGateway() {
        if (msg.sender != gateway) revert NotGateway(msg.sender, gateway);
        _;
    }

    modifier onlyChallengeManager() {
        if (msg.sender != challengeManager) revert NotChallengeManager(msg.sender, challengeManager);
        _;
    }

    constructor(address owner_) ERC721("Cachet First-Seen Certificate", "CACHET") CachetGoverned(owner_) {}

    // ── Wiring ───────────────────────────────────────────────────────────────

    /// @dev Set-once. Wiring salah = redeploy (lihat `_lockWiring`).
    function setGateway(address gateway_) external onlyOwner {
        if (gateway_ == address(0)) revert ZeroAddress();
        _lockWiring(gateway, "certificate.gateway");
        emit GatewaySet(gateway, gateway_);
        gateway = gateway_;
    }

    /// @dev Set-once. Wiring salah = redeploy (lihat `_lockWiring`).
    function setChallengeManager(address cm_) external onlyOwner {
        if (cm_ == address(0)) revert ZeroAddress();
        _lockWiring(challengeManager, "certificate.challengeManager");
        emit ChallengeManagerSet(challengeManager, cm_);
        challengeManager = cm_;
    }

    /// @dev Set-once. Wiring salah = redeploy (lihat `_lockWiring`).
    function setRegistry(address registry_) external onlyOwner {
        if (registry_ == address(0)) revert ZeroAddress();
        _lockWiring(address(registry), "certificate.registry");
        emit RegistrySet(address(registry), registry_);
        registry = ICachetRegistry(registry_);
    }

    /// @dev Set-once. Wiring salah = redeploy (lihat `_lockWiring`).
    function setVault(address vault_) external onlyOwner {
        if (vault_ == address(0)) revert ZeroAddress();
        _lockWiring(address(vault), "certificate.vault");
        emit VaultSet(address(vault), vault_);
        vault = ICachetVault(vault_);
    }

    // ── Parameter (§5.0) ─────────────────────────────────────────────────────

    /// @param v 0 diperbolehkan (coverage aktif seketika); batas atas menjaga
    ///          owner tidak bisa menunda coverage sampai tak berarti.
    function setWaitingPeriod(uint64 v) external onlyOwner {
        if (v < MIN_WAITING_PERIOD) revert ParamBelowFloor(v, MIN_WAITING_PERIOD);
        if (v > MAX_WAITING_PERIOD) revert ParamOutOfRange(v, MAX_WAITING_PERIOD);
        emit ParamChanged("waitingPeriod", waitingPeriod, v);
        waitingPeriod = v;
    }

    function setCoverageTerm(uint64 v) external onlyOwner {
        if (v < MIN_COVERAGE_TERM) revert ParamBelowFloor(v, MIN_COVERAGE_TERM);
        if (v > MAX_COVERAGE_TERM) revert ParamOutOfRange(v, MAX_COVERAGE_TERM);
        emit ParamChanged("coverageTerm", coverageTerm, v);
        coverageTerm = v;
    }

    /// @notice SENGAJA tanpa lantai. `maxDeclaredValue = 0` menghentikan
    ///         penerbitan sertifikat berjaminan baru tanpa menyentuh sertifikat
    ///         yang sudah terbit maupun jalur pembayaran klaim.
    /// @dev Ini yang paling mendekati "emergency stop" tanpa memberi owner
    ///      kuasa membekukan payout — kuasa yang justru sengaja tidak kami
    ///      berikan (§5.0, tidak ada Pausable).
    function setMaxDeclaredValue(uint256 v) external onlyOwner {
        if (v > MAX_DECLARED_VALUE_CEILING) revert ValueOutOfRange(v, MAX_DECLARED_VALUE_CEILING);
        emit ParamChanged("maxDeclaredValue", maxDeclaredValue, v);
        maxDeclaredValue = v;
    }

    // ── Jalur produksi: satu tx atomik (RFC-001 P1) ──────────────────────────

    /// @inheritdoc ICachetCertificate
    function registerAndMint(MintRequest calldata r)
        external
        onlyGateway
        nonReentrant
        returns (uint256 entryId, uint256 certId)
    {
        if (address(registry) == address(0)) revert NotWired("registry");
        if (address(vault) == address(0)) revert NotWired("vault");

        // Dicek SEBELUM menyentuh registry: kalau plafon terlampaui, jangan
        // sampai ada entri yang terlanjur tercatat lalu di-rollback.
        if (r.declaredValue > maxDeclaredValue) {
            revert DeclaredValueTooHigh(r.declaredValue, maxDeclaredValue);
        }

        entryId = registry.register(r.phashes, r.embCommit, r.to, r.revealedCommit, r.assetURI);
        certId = _issueCertificate(r.to, entryId, r.declaredValue, r.insurable, r.tokenURI_);

        // payer = wallet gateway. Gateway cukup approve ke Vault SEKALI di awal
        // dengan allowance besar, lalu memanggil ini berkali-kali (RFC-001 P1).
        // Kalau allowance kurang, tarikan gagal dan SELURUH tx revert —
        // tidak ada sertifikat tanpa bond, tidak ada entri yatim.
        vault.collectOnMint(certId, msg.sender, r.fraudBond, r.premium);
    }

    /// @inheritdoc ICachetCertificate
    function mintCertificate(
        address to,
        uint256 entryId,
        uint256 declaredValue,
        bool insurable,
        string calldata tokenURI_
    ) external onlyGateway nonReentrant returns (uint256 certId) {
        if (declaredValue > maxDeclaredValue) {
            revert DeclaredValueTooHigh(declaredValue, maxDeclaredValue);
        }

        // Tanpa cek ini, gateway yang keliru bisa menerbitkan sertifikat yang
        // menunjuk entri tidak ada — cert page akan gagal membacanya dan
        // "bukti publik" jadi tautan mati. Dilewati bila registry belum
        // di-wiring (skenario unit test murni).
        if (address(registry) != address(0)) {
            uint256 count = registry.entryCount();
            if (entryId == 0 || entryId > count) revert UnknownEntryId(entryId, count);
        }

        certId = _issueCertificate(to, entryId, declaredValue, insurable, tokenURI_);
    }

    /// @dev SENGAJA tidak dinamai `_mint`: ERC721 sudah punya `_mint(address,uint256)`.
    ///      Dua fungsi bernama sama dengan makna berbeda di kontrak yang
    ///      memegang uang adalah jebakan bagi reviewer -- ditemukan saat audit B2a.
    function _issueCertificate(
        address to,
        uint256 entryId,
        uint256 declaredValue,
        bool insurable,
        string memory tokenURI_
    ) private returns (uint256 certId) {
        certId = ++_certCount; // mulai 1; 0 selalu berarti "tidak ada"

        uint64 nowTs = uint64(block.timestamp);
        uint64 start = nowTs + waitingPeriod;

        // State ditulis SEBELUM _safeMint: hook onERC721Received milik penerima
        // bisa memanggil balik kontrak ini. nonReentrant sudah menjaga, tapi
        // urutan ini membuat state konsisten bahkan bila guard dilepas nanti.
        _certData[certId] = CertData({
            entryId: entryId,
            declaredValue: declaredValue,
            mintedAt: nowTs,
            coverageStart: start,
            coverageEnd: start + coverageTerm,
            insurable: insurable,
            revoked: false,
            challengesSurvived: 0
        });

        _safeMint(to, certId);
        _setTokenURI(certId, tokenURI_);

        emit CertificateMinted(certId, entryId, to, declaredValue);
    }

    // ── Dipanggil ChallengeManager ───────────────────────────────────────────

    /// @inheritdoc ICachetCertificate
    function markRevoked(uint256 certId) external onlyChallengeManager {
        _requireExists(certId);
        if (_certData[certId].revoked) revert AlreadyRevoked(certId);

        _certData[certId].revoked = true;
        emit CertificateRevoked(certId);
    }

    /// @inheritdoc ICachetCertificate
    function incrementSurvived(uint256 certId) external onlyChallengeManager {
        _requireExists(certId);

        uint32 total = ++_certData[certId].challengesSurvived;
        emit ChallengeSurvived(certId, total);
    }

    // ── Baca ─────────────────────────────────────────────────────────────────

    /// @inheritdoc ICachetCertificate
    function certData(uint256 certId) external view returns (CertData memory) {
        _requireExists(certId);
        return _certData[certId];
    }

    /// @inheritdoc ICachetCertificate
    /// @dev Sengaja mengembalikan false (bukan revert) untuk certId tak dikenal:
    ///      pemanggilnya adalah ChallengeManager dan cert page, dan keduanya
    ///      lebih baik memperlakukan "tidak ada" sama dengan "tidak aktif".
    function isCoverageActive(uint256 certId) external view returns (bool) {
        if (certId == 0 || certId > _certCount) return false;

        CertData storage c = _certData[certId];
        if (!c.insurable || c.revoked) return false;

        // Jendela coverage diukur dalam HARI (waiting 72 jam, term 365 hari).
        // Kemampuan validator menggeser timestamp beberapa detik tidak
        // memberi keuntungan apa pun di sini — tidak ada batas yang bisa
        // dilewati dengan menggeser detik. Alternatifnya (block number) justru
        // lebih buruk: waktu blok X Layer bisa berubah dan membuat "365 hari"
        // meleset berminggu-minggu.
        // forge-lint: disable-next-line(block-timestamp)
        return block.timestamp >= c.coverageStart && block.timestamp <= c.coverageEnd;
    }

    function certCount() external view returns (uint256) {
        return _certCount;
    }

    function _requireExists(uint256 certId) private view {
        if (certId == 0 || certId > _certCount) revert InvalidCertId(certId);
    }
}
