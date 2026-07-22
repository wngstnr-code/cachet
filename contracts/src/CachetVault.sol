// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

import {ICachetVault} from "./interfaces/ICachetVault.sol";
import {ICachetCertificate} from "./interfaces/ICachetCertificate.sol";
import {CachetGoverned} from "./base/CachetGoverned.sol";

/// @title CachetVault — pemegang bond & premi, pembayar klaim
/// @notice Di sinilah kata "collateralized" pada janji Cachet ditepati atau
///         tidak. Dua aturan yang tidak boleh dilanggar:
///
///         1. Payout SELALU ke `ownerOf(certId)` pada saat resolve — bukan ke
///            kreator, bukan ke alamat yang dioper pemanggil (invariant §9.1).
///            Inilah yang membuat "jaminan ikut pembeli" nyata, bukan slogan.
///         2. Vault tidak pernah mengirim melebihi saldonya. Kalau dana kurang,
///            bayar sebagian dan emit `PartialPayout` — JANGAN revert, karena
///            revert akan mengunci klaim selamanya (invariant §9.3).
///
/// @dev Tidak upgradeable (§5.0). SafeERC20 dipakai di semua transfer supaya
///      tetap benar bila `payToken` diganti USDT asli di mainnet — sebagian
///      deployment USDT tidak mengembalikan `bool`.
contract CachetVault is ICachetVault, CachetGoverned, ReentrancyGuard {
    using SafeERC20 for IERC20;

    /// @notice Token pembayaran. Immutable: mengganti token setelah ada dana
    ///         tersimpan akan membuat pembukuan tidak bisa dipertanggungjawabkan.
    IERC20 private immutable _payToken;

    /// @notice Kontrak CachetCertificate — sumber kebenaran `ownerOf` & `certData`.
    /// @dev IMMUTABLE, ditetapkan saat deploy. Audit menemukan: bila alamat ini
    ///      bisa diganti, owner tinggal mengarahkannya ke kontrak palsu yang
    ///      melaporkan `ownerOf` dan `certData` sesukanya, lalu menguras vault
    ///      ke dirinya sendiri. Terbukti di probe: owner menerima 105 USDT dari
    ///      dana orang lain. Membuatnya immutable menutup jalur itu sepenuhnya.
    address public immutable certificate;
    /// @notice Kontrak ChallengeManager — satu-satunya yang boleh menggerakkan dana klaim.
    address public challengeManager;

    // ── Parameter kebijakan (§5.0) ───────────────────────────────────────────

    /// @notice Bond kreator yang di-slash bila fraud terbukti.
    uint256 public fraudBondAmount = 5e6; // 5 USDT
    /// @notice Premi dalam basis point dari declaredValue. 200 = 2%.
    uint256 public premiumBps = 200;

    /// @dev Pagar sungguhan: premi > 100% membuat mint mustahil dibayar.
    uint256 public constant MAX_PREMIUM_BPS = 10_000;

    /// @notice Lantai premi 0,1%. Tanpa ini jaminan bisa dibuat gratis.
    uint256 public constant MIN_PREMIUM_BPS = 10;
    /// @notice Lantai bond kreator 1 USDT. Bond adalah taruhan kreator DAN
    ///         sumber bounty penantang — nol berarti tidak ada insentif
    ///         menangkap pemalsuan.
    uint256 public constant MIN_FRAUD_BOND = 1e6;

    // ── Pembukuan ────────────────────────────────────────────────────────────

    struct CertFunds {
        uint256 fraudBond;
        uint256 premium;
        bool collected;
        bool settled;
    }

    mapping(uint256 => CertFunds) public certFunds;
    mapping(uint256 => uint256) public challengeBonds;

    /// @notice G2: timestamp saat gugatan DIBUKA, dicatat di `collectChallengeBond`
    ///         (dipanggil sinkron dari `challenge()`, jadi `block.timestamp` di
    ///         sana = openedAt). Kelayakan coverage dinilai terhadap momen INI,
    ///         bukan momen resolve — jendela liveness tidak boleh menggerus
    ///         ekor coverage, dan gugatan yang dibuka sebelum coverage aktif
    ///         tidak berhak atas klaim.
    mapping(uint256 => uint64) public challengeOpenedAt;

    /// @notice G3: total bond penantang yang gugatannya masih terbuka.
    ///         Dana ini MILIK PENANTANG, bukan kolam klaim. Klaim & bounty
    ///         (sertifikat mana pun) dibayar dari saldo DI LUAR cadangan ini
    ///         (`_payUnreserved`) — jadi klaim besar sertifikat lain tidak
    ///         bisa memakan bond gugatan yang belum diputus, dan refund bond
    ///         penantang yang menang selalu terbayar penuh.
    ///
    ///         Invariant: saldo vault >= reservedChallengeBonds, karena tiap
    ///         kenaikan cadangan disertai transfer masuk sebesar itu, dan
    ///         semua jalur keluar lain dibatasi saldo-di-luar-cadangan.
    uint256 public reservedChallengeBonds;

    error NotCertificate(address caller, address expected);
    error NotChallengeManager(address caller, address expected);
    error NotWired(string what);
    error AlreadyCollected(uint256 certId);
    error AlreadySettled(uint256 certId);
    error HolderMismatch(uint256 certId, address claimed, address actual);
    error WrongFraudBond(uint256 got, uint256 expected);
    error WrongPremium(uint256 got, uint256 expected);
    error ParamOutOfRange(uint256 value, uint256 max);

    event ChallengeManagerSet(address indexed previous, address indexed current);
    event CollectedOnMint(uint256 indexed certId, address indexed payer, uint256 fraudBond, uint256 premium);
    event ChallengeBondCollected(uint256 indexed challengeId, address indexed challenger, uint256 amount);
    event ClaimPaid(uint256 indexed certId, address indexed holder, uint256 amount);
    event BountyPaid(uint256 indexed challengeId, address indexed challenger, uint256 amount);
    event BondRefunded(uint256 indexed challengeId, address indexed challenger, uint256 amount);
    event BondSlashed(uint256 indexed challengeId, address indexed toHolder, uint256 toHolderAmount);

    /// @notice Dana tidak cukup untuk membayar penuh — dibayar sebagian.
    /// @dev Jujur soal plafon bootstrap. Ini yang dilaporkan cert page.
    event PartialPayout(uint256 indexed certId, uint256 owed, uint256 paid);

    /// @notice Modal disetor ke vault. Tidak ada jalan keluar selain klaim.
    event VaultFunded(address indexed from, uint256 amount);

    /// @notice Gugatan menang, sertifikat dicabut, TAPI klaim tidak dibayar
    ///         karena coverage tidak berlaku (belum aktif / kedaluwarsa /
    ///         sertifikat memang tidak insurable).
    /// @dev Dipakai cert page untuk menjelaskan kenapa payout nol — tanpa ini
    ///      pemegang hanya melihat sertifikatnya dicabut tanpa penjelasan.
    event ClaimSkippedNoCoverage(uint256 indexed certId, address indexed holder, uint256 declaredValue);

    modifier onlyCertificate() {
        if (msg.sender != certificate) revert NotCertificate(msg.sender, certificate);
        _;
    }

    modifier onlyChallengeManager() {
        if (msg.sender != challengeManager) revert NotChallengeManager(msg.sender, challengeManager);
        _;
    }

    /// @param certificate_ alamat CachetCertificate. Harus sudah ter-deploy —
    ///        Certificate tidak membutuhkan Vault saat konstruksi, jadi urutan
    ///        deploy-nya: Certificate dulu, baru Vault.
    constructor(address owner_, address payToken_, address certificate_) CachetGoverned(owner_) {
        if (payToken_ == address(0)) revert ZeroAddress();
        if (certificate_ == address(0)) revert ZeroAddress();
        _payToken = IERC20(payToken_);
        certificate = certificate_;
    }

    // ── Wiring ───────────────────────────────────────────────────────────────

    /// @dev SET-ONCE. Ini setter paling kritis di seluruh sistem: sebelum
    ///      dikunci, owner bisa mengarahkannya ke kontrak jahat lalu memanggil
    ///      `settleChallengeWon` untuk dirinya sendiri.
    function setChallengeManager(address cm_) external onlyOwner {
        if (cm_ == address(0)) revert ZeroAddress();
        _lockWiring(challengeManager, "vault.challengeManager");
        emit ChallengeManagerSet(challengeManager, cm_);
        challengeManager = cm_;
    }

    // ── Parameter (§5.0) ─────────────────────────────────────────────────────

    function setFraudBondAmount(uint256 v) external onlyOwner {
        if (v < MIN_FRAUD_BOND) revert ParamBelowFloor(v, MIN_FRAUD_BOND);
        emit ParamChanged("fraudBondAmount", fraudBondAmount, v);
        fraudBondAmount = v;
    }

    function setPremiumBps(uint256 v) external onlyOwner {
        if (v < MIN_PREMIUM_BPS) revert ParamBelowFloor(v, MIN_PREMIUM_BPS);
        if (v > MAX_PREMIUM_BPS) revert ParamOutOfRange(v, MAX_PREMIUM_BPS);
        emit ParamChanged("premiumBps", premiumBps, v);
        premiumBps = v;
    }

    /// @notice Rumus premi dikunci RFC-001 P5: integer, dibulatkan KE BAWAH.
    /// @dev Gateway WAJIB memakai rumus yang sama persis. Kalau meleset satu
    ///      unit pun, `collectOnMint` revert dan seluruh mint gagal.
    function quotePremium(uint256 declaredValue) public view returns (uint256) {
        return (declaredValue * premiumBps) / 10_000;
    }

    // ── Jalur mint ───────────────────────────────────────────────────────────

    /// @inheritdoc ICachetVault
    /// @dev Dipanggil kontrak CachetCertificate di dalam `registerAndMint`,
    ///      BUKAN oleh wallet gateway. `payer` tetap wallet gateway — dialah
    ///      yang sudah `approve` ke Vault ini.
    ///
    ///      Vault MEMVERIFIKASI SENDIRI besaran bond & premi terhadap
    ///      `declaredValue` yang tercatat on-chain, alih-alih mempercayai angka
    ///      yang dioper. Tanpa ini, gateway yang keliru (atau nakal) bisa
    ///      menerbitkan sertifikat berjaminan 100 USDT dengan premi 0 — dan
    ///      kata "collateralized" jadi bergantung pada kejujuran operator,
    ///      bukan pada kontrak.
    function collectOnMint(uint256 certId, address payer, uint256 fraudBond, uint256 premium)
        external
        onlyCertificate
        nonReentrant
    {
        if (certFunds[certId].collected) revert AlreadyCollected(certId);

        if (fraudBond != fraudBondAmount) revert WrongFraudBond(fraudBond, fraudBondAmount);

        uint256 declaredValue = ICachetCertificate(certificate).certData(certId).declaredValue;
        uint256 expectedPremium = quotePremium(declaredValue);
        if (premium != expectedPremium) revert WrongPremium(premium, expectedPremium);

        certFunds[certId] =
            CertFunds({fraudBond: fraudBond, premium: premium, collected: true, settled: false});

        _payToken.safeTransferFrom(payer, address(this), fraudBond + premium);
        emit CollectedOnMint(certId, payer, fraudBond, premium);
    }

    // ── Permodalan ───────────────────────────────────────────────────────────

    /// @notice Menambah modal ke vault. Terbuka untuk siapa pun.
    ///
    /// @dev DITEMUKAN saat menulis test integrasi B2b, dan ini soal ekonomi
    ///      bukan sekadar kode: premi 2% berarti butuh ~50 sertifikat sebelum
    ///      vault sanggup membayar SATU klaim bernilai penuh. Tanpa modal awal,
    ///      klaim pertama pasti hanya terbayar sebagian — dan janji
    ///      "collateralized" praktis kosong di masa bootstrap.
    ///
    ///      Karena itu operator menyetor modal awal lewat fungsi ini. Jujur,
    ///      dan tercatat publik lewat event.
    ///
    ///      TIDAK ADA fungsi penarikan — termasuk untuk owner. Uang yang masuk
    ///      tidak bisa keluar kecuali sebagai klaim, bounty, atau refund bond.
    ///      Ini disengaja: kalau owner bisa menarik dana, "collateralized"
    ///      hanya berarti "kami janji tidak akan menarik". Konsekuensinya modal
    ///      awal operator memang hangus — itu harga dari jaminan yang bisa
    ///      dipercaya tanpa mempercayai kami.
    function fund(uint256 amount) external nonReentrant {
        _payToken.safeTransferFrom(msg.sender, address(this), amount);
        emit VaultFunded(msg.sender, amount);
    }

    // ── Jalur challenge ──────────────────────────────────────────────────────

    /// @inheritdoc ICachetVault
    /// @dev Penantang WAJIB `approve` ke Vault ini (bukan ke ChallengeManager)
    ///      sebelum memanggil `challenge()` — RFC-001 P6.
    function collectChallengeBond(uint256 challengeId, address challenger, uint256 amount)
        external
        onlyChallengeManager
        nonReentrant
    {
        challengeBonds[challengeId] = amount;
        challengeOpenedAt[challengeId] = uint64(block.timestamp); // G2
        reservedChallengeBonds += amount; // G3: bond dicadangkan, bukan kolam klaim

        _payToken.safeTransferFrom(challenger, address(this), amount);
        emit ChallengeBondCollected(challengeId, challenger, amount);
    }

    /// @inheritdoc ICachetVault
    /// @dev Urutan pembayaran DISENGAJA:
    ///      1. kembalikan bond penantang — itu uangnya sendiri
    ///      2. bayar klaim pemegang — janji inti produk, didahulukan
    ///      3. bayar bounty penantang — insentif, terakhir
    ///      Kalau dana tidak cukup, yang tergerus lebih dulu adalah bounty,
    ///      bukan klaim pemegang.
    function settleChallengeWon(uint256 certId, uint256 challengeId, address certHolder, address challenger)
        external
        onlyChallengeManager
        nonReentrant
    {
        _requireHolder(certId, certHolder);
        if (certFunds[certId].settled) revert AlreadySettled(certId);
        certFunds[certId].settled = true;

        CertFunds memory f = certFunds[certId];
        ICachetCertificate.CertData memory d = ICachetCertificate(certificate).certData(certId);

        // 1. Bond penantang kembali — uangnya sendiri. Cadangan dilepas dulu
        //    (G3); refund dijamin penuh oleh invariant saldo >= cadangan.
        uint256 bond = challengeBonds[challengeId];
        challengeBonds[challengeId] = 0;
        if (bond > 0) {
            reservedChallengeBonds -= bond;
            uint256 refunded = _pay(challenger, bond);
            emit BondRefunded(challengeId, challenger, refunded);
        }

        // 2. Klaim pemegang — HANYA bila coverage memang berlaku.
        //    INVARIANT §9.4: jendela coverage dicek ON-CHAIN, bukan hanya di
        //    gateway. Tanpa cek ini, `waitingPeriod`, `coverageTerm`, dan flag
        //    `insurable` cuma hiasan: sertifikat gray-zone atau yang masih
        //    dalam masa tunggu tetap dibayar penuh.
        uint256 declaredValue = d.declaredValue;
        uint256 paid = 0;

        if (_coverageApplies(certId, d, challengeOpenedAt[challengeId])) {
            paid = _payUnreserved(certHolder, declaredValue); // G3: jangan makan bond gugatan lain
            if (paid < declaredValue) emit PartialPayout(certId, declaredValue, paid);
            emit ClaimPaid(certId, certHolder, paid);
        } else {
            // Pencabutan TETAP terjadi dan bounty TETAP dibayar: menangkap
            // pemalsuan adalah barang publik, terlepas dari apakah sertifikat
            // itu dijamin. Yang tidak terjadi hanyalah pembayaran klaim.
            emit ClaimSkippedNoCoverage(certId, certHolder, declaredValue);
        }

        // 3. Bounty penantang = fraud bond kreator + 50% premi (§1.3).
        uint256 bounty = f.fraudBond + (f.premium / 2);
        uint256 bountyPaid = _payUnreserved(challenger, bounty); // G3
        emit BountyPaid(challengeId, challenger, bountyPaid);
    }

    /// @inheritdoc ICachetVault
    /// @dev Bond penantang yang kalah: 50% ke pemegang cert, 50% tinggal di
    ///      vault. Pembagian ini yang membuat menggugat sembarangan mahal.
    function settleChallengeLost(uint256 certId, uint256 challengeId, address certHolder)
        external
        onlyChallengeManager
        nonReentrant
    {
        _requireHolder(certId, certHolder);

        uint256 bond = challengeBonds[challengeId];
        challengeBonds[challengeId] = 0;
        reservedChallengeBonds -= bond; // G3: bond terpakai (slash), cadangan dilepas

        uint256 toHolder = bond / 2; // sisanya tinggal di vault (jadi kolam bebas)
        uint256 paid = _pay(certHolder, toHolder);
        emit BondSlashed(challengeId, certHolder, paid);
    }

    // ── Baca ─────────────────────────────────────────────────────────────────

    function payToken() external view returns (address) {
        return address(_payToken);
    }

    function balanceOfVault() external view returns (uint256) {
        return _payToken.balanceOf(address(this));
    }

    // ── Internal ─────────────────────────────────────────────────────────────

    /// @dev INVARIANT §9.1. `certHolder` yang dioper hanya dipakai untuk event;
    ///      kebenarannya diverifikasi terhadap `ownerOf` saat ini. Parameter
    ///      bebas tanpa verifikasi = pintu belakang untuk mengalihkan payout.
    function _requireHolder(uint256 certId, address certHolder) private view {
        if (certificate == address(0)) revert NotWired("certificate");

        // ICachetCertificate (§3.1, beku) tidak mendeklarasikan ownerOf --
        // itu milik ERC-721. Di-cast di sini alih-alih mengubah interface beku.
        address actual = IERC721(certificate).ownerOf(certId);
        if (certHolder != actual) revert HolderMismatch(certId, certHolder, actual);
    }

    /// @dev INVARIANT §9.4. Menilai jendela coverage SENDIRI dari CertData,
    ///      dan SENGAJA mengabaikan flag `revoked` — pencabutan justru sedang
    ///      diproses pada transaksi ini (ChallengeManager memanggil
    ///      `markRevoked` sebelum menyelesaikan pembayaran), jadi memakai
    ///      `isCoverageActive` di sini akan selalu mengembalikan false dan
    ///      tidak ada klaim yang pernah terbayar.
    ///
    ///      Sertifikat yang sudah dicabut sebelumnya tidak mungkin sampai ke
    ///      sini: `challenge()` menolaknya lebih dulu.
    ///
    ///      G2: jendela dinilai terhadap `openedAt` (saat gugatan dibuka),
    ///      BUKAN `block.timestamp` saat resolve. Dua lubang yang ditutup:
    ///      - ekor: gugatan sah di ujung coverage tidak lagi gugur hanya
    ///        karena liveness mendorong resolve melewati `coverageEnd`;
    ///      - tepi depan: gugatan yang dibuka SEBELUM `coverageStart` (masa
    ///        tunggu) tidak berhak klaim meski resolve mendarat setelahnya —
    ///        masa tunggu jadi benar-benar berarti.
    ///      `openedAt == 0` (bond tak pernah ditarik untuk challengeId ini)
    ///      otomatis gagal — konsisten dengan "tidak ada bond, tidak ada
    ///      coverage".
    function _coverageApplies(uint256 certId, ICachetCertificate.CertData memory d, uint64 openedAt)
        private
        view
        returns (bool)
    {
        // TIDAK ADA BOND, TIDAK ADA COVERAGE.
        //
        // Ditemukan saat audit lintas-kontrak: `mintCertificate` (jalur
        // test/darurat) menerbitkan sertifikat TANPA memanggil `collectOnMint`.
        // Sebelum cek ini, sertifikat semacam itu tetap dibayar penuh — dari
        // premi milik sertifikat lain dan modal awal operator. Gateway yang
        // keliru satu kali bisa menguras vault orang lain.
        //
        // Prinsipnya sama dengan verifikasi premi di `collectOnMint`: jaminan
        // tidak boleh bergantung pada kedisiplinan gateway.
        if (!certFunds[certId].collected) return false;

        if (!d.insurable) return false;
        return openedAt >= d.coverageStart && openedAt <= d.coverageEnd;
    }

    /// @dev G3: seperti `_pay`, tapi dibatasi saldo DI LUAR cadangan bond
    ///      penantang. Dipakai untuk klaim & bounty — dua-duanya janji sistem,
    ///      bukan uang titipan; keduanya boleh terbayar sebagian, tapi tidak
    ///      boleh mengambil dari bond gugatan yang belum diputus.
    function _payUnreserved(address to, uint256 amount) private returns (uint256 sent) {
        if (amount == 0) return 0;

        uint256 balance = _payToken.balanceOf(address(this));
        uint256 reserved = reservedChallengeBonds;
        uint256 available = balance > reserved ? balance - reserved : 0;
        sent = amount > available ? available : amount;
        if (sent == 0) return 0;

        _payToken.safeTransfer(to, sent);
    }

    /// @dev INVARIANT §9.3. Tidak pernah mengirim melebihi saldo; mengembalikan
    ///      jumlah yang benar-benar terkirim supaya pemanggil bisa melaporkan
    ///      pembayaran sebagian dengan jujur.
    function _pay(address to, uint256 amount) private returns (uint256 sent) {
        if (amount == 0) return 0;

        uint256 balance = _payToken.balanceOf(address(this));
        sent = amount > balance ? balance : amount;
        if (sent == 0) return 0;

        _payToken.safeTransfer(to, sent);
    }
}
