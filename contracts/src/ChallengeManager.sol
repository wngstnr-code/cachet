// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {IChallengeManager} from "./interfaces/IChallengeManager.sol";
import {ICachetCertificate} from "./interfaces/ICachetCertificate.sol";
import {ICachetVault} from "./interfaces/ICachetVault.sol";
import {CachetGoverned} from "./base/CachetGoverned.sol";

/// @title ChallengeManager — siapa pun boleh menggugat, dengan taruhan
/// @notice Ini yang membuat sertifikat Cachet bukan sekadar klaim sepihak:
///         siapa pun boleh menantang dengan bukti, menaruh bond, dan
///         mendapat bounty bila terbukti benar.
///
/// @dev ⚠️ SENTRALISASI YANG DIAKUI TERBUKA: di MVP, yang memutus menang/kalah
///      adalah `resolver` — sebuah wallet operator, bukan mekanisme
///      terdesentralisasi. Yang diberikan kontrak ini hanyalah: jendela
///      liveness publik sebelum putusan, seluruh bukti & putusan tercatat
///      on-chain, dan dana bergerak hanya lewat jalur yang bisa diaudit.
///      JANGAN pernah menuliskan "trustless adjudication" di mana pun.
///      Roadmap: optimistic oracle.
contract ChallengeManager is IChallengeManager, CachetGoverned, ReentrancyGuard {
    struct Challenge {
        uint256 certId;
        address challenger;
        uint64 openedAt;
        Status status;
        string evidenceURI;
    }

    ICachetCertificate public certificate;
    ICachetVault public vault;

    /// @notice Wallet yang berwenang memutus. WAJIB terpisah dari deployer &
    ///         gateway (invariant §9.6).
    address public resolver;

    // ── Parameter kebijakan (§5.0) ───────────────────────────────────────────

    uint256 public challengeBond = 10e6; // 10 USDT
    uint64 public livenessWindow = 48 hours;

    /// @dev Pagar sungguhan: tanpa batas atas, owner bisa menyetel liveness
    ///      100 tahun dan membekukan seluruh gugatan yang sedang berjalan.
    uint64 public constant MAX_LIVENESS_WINDOW = 30 days;

    mapping(uint256 => Challenge) private _challenges;
    uint256 private _challengeCount;

    /// @notice Gugatan terbuka per sertifikat — mencegah spam paralel.
    mapping(uint256 => uint256) public openChallengeOf;

    error NotResolver(address caller, address expected);
    error NotWired(string what);
    error InvalidChallengeId(uint256 challengeId);
    error ChallengeNotOpen(uint256 challengeId, Status status);
    error LivenessNotElapsed(uint64 openedAt, uint64 requiredUntil);
    error CertificateNotFound(uint256 certId);
    error CertificateAlreadyRevoked(uint256 certId);
    error ChallengeAlreadyOpen(uint256 certId, uint256 challengeId);
    error EmptyEvidence();
    error ParamOutOfRange(uint256 value, uint256 max);

    event ResolverSet(address indexed previous, address indexed current);
    event CertificateSet(address indexed previous, address indexed current);
    event VaultSet(address indexed previous, address indexed current);
    event RulingRecorded(uint256 indexed challengeId, string rulingURI);

    modifier onlyResolver() {
        if (msg.sender != resolver) revert NotResolver(msg.sender, resolver);
        _;
    }

    constructor(address owner_) CachetGoverned(owner_) {}

    // ── Wiring ───────────────────────────────────────────────────────────────

    function setResolver(address resolver_) external onlyOwner {
        if (resolver_ == address(0)) revert ZeroAddress();
        emit ResolverSet(resolver, resolver_);
        resolver = resolver_;
    }

    function setCertificate(address certificate_) external onlyOwner {
        if (certificate_ == address(0)) revert ZeroAddress();
        emit CertificateSet(address(certificate), certificate_);
        certificate = ICachetCertificate(certificate_);
    }

    function setVault(address vault_) external onlyOwner {
        if (vault_ == address(0)) revert ZeroAddress();
        emit VaultSet(address(vault), vault_);
        vault = ICachetVault(vault_);
    }

    // ── Parameter (§5.0) ─────────────────────────────────────────────────────

    function setChallengeBond(uint256 v) external onlyOwner {
        emit ParamChanged("challengeBond", challengeBond, v);
        challengeBond = v;
    }

    function setLivenessWindow(uint64 v) external onlyOwner {
        if (v > MAX_LIVENESS_WINDOW) revert ParamOutOfRange(v, MAX_LIVENESS_WINDOW);
        emit ParamChanged("livenessWindow", livenessWindow, v);
        livenessWindow = v;
    }

    // ── Menggugat ────────────────────────────────────────────────────────────

    /// @inheritdoc IChallengeManager
    /// @dev Sertifikat yang TIDAK insurable tetap boleh digugat (§5-B2.4):
    ///      payout-nya nol, tapi pencabutannya tetap bermakna sebagai catatan
    ///      publik. Yang ditolak hanya sertifikat yang sudah dicabut.
    function challenge(uint256 certId, string calldata evidenceURI)
        external
        nonReentrant
        returns (uint256 challengeId)
    {
        if (address(certificate) == address(0)) revert NotWired("certificate");
        if (address(vault) == address(0)) revert NotWired("vault");
        if (bytes(evidenceURI).length == 0) revert EmptyEvidence();

        // Memastikan sertifikat ada; certData revert bila certId tak dikenal.
        ICachetCertificate.CertData memory d = certificate.certData(certId);
        if (d.revoked) revert CertificateAlreadyRevoked(certId);

        uint256 existing = openChallengeOf[certId];
        if (existing != 0) revert ChallengeAlreadyOpen(certId, existing);

        challengeId = ++_challengeCount;

        _challenges[challengeId] = Challenge({
            certId: certId,
            challenger: msg.sender,
            openedAt: uint64(block.timestamp),
            status: Status.Open,
            evidenceURI: evidenceURI
        });
        openChallengeOf[certId] = challengeId;

        emit ChallengeOpened(challengeId, certId, msg.sender);

        // Bond ditarik Vault, bukan kontrak ini — penantang harus approve ke
        // Vault (RFC-001 P6). Dilakukan TERAKHIR supaya state sudah konsisten.
        vault.collectChallengeBond(challengeId, msg.sender, challengeBond);
    }

    // ── Memutus ──────────────────────────────────────────────────────────────

    /// @inheritdoc IChallengeManager
    function resolve(uint256 challengeId, bool challengerWins, string calldata rulingURI)
        external
        onlyResolver
        nonReentrant
    {
        Challenge storage c = _challenges[challengeId];
        if (challengeId == 0 || challengeId > _challengeCount) revert InvalidChallengeId(challengeId);
        if (c.status != Status.Open) revert ChallengeNotOpen(challengeId, c.status);

        // Jendela liveness: memberi publik waktu melihat bukti sebelum
        // operator memutus. Ini satu-satunya rem terhadap resolver di MVP —
        // jangan pernah dilewati.
        uint64 requiredUntil = c.openedAt + livenessWindow;
        // forge-lint: disable-next-line(block-timestamp)
        if (block.timestamp < requiredUntil) revert LivenessNotElapsed(c.openedAt, requiredUntil);

        uint256 certId = c.certId;
        address challenger = c.challenger;

        // Status ditulis SEBELUM panggilan eksternal — double-resolve mustahil
        // bahkan bila salah satu callee mencoba reentry.
        c.status = challengerWins ? Status.UpheldChallengerWon : Status.DismissedChallengerLost;
        openChallengeOf[certId] = 0;

        emit ChallengeResolved(challengeId, c.status);
        emit RulingRecorded(challengeId, rulingURI);

        // Pemegang saat ini — dibaca SEKARANG, bukan saat gugatan dibuka.
        // Inilah yang membuat jaminan mengikuti pembeli (invariant §9.1).
        // ownerOf lewat IERC721: ICachetCertificate (beku) tidak mendeklarasikannya.
        address holder = IERC721(address(certificate)).ownerOf(certId);

        if (challengerWins) {
            certificate.markRevoked(certId);
            vault.settleChallengeWon(certId, challengeId, holder, challenger);
        } else {
            certificate.incrementSurvived(certId);
            vault.settleChallengeLost(certId, challengeId, holder);
        }
    }

    // ── Baca ─────────────────────────────────────────────────────────────────

    /// @inheritdoc IChallengeManager
    function getChallenge(uint256 challengeId)
        external
        view
        returns (
            uint256 certId,
            address challenger,
            uint64 openedAt,
            Status status,
            string memory evidenceURI
        )
    {
        if (challengeId == 0 || challengeId > _challengeCount) {
            revert InvalidChallengeId(challengeId);
        }
        Challenge storage c = _challenges[challengeId];
        return (c.certId, c.challenger, c.openedAt, c.status, c.evidenceURI);
    }

    function challengeCount() external view returns (uint256) {
        return _challengeCount;
    }
}
