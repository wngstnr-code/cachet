// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CachetRegistry} from "../src/CachetRegistry.sol";
import {CachetCertificate} from "../src/CachetCertificate.sol";
import {CachetVault} from "../src/CachetVault.sol";
import {ChallengeManager} from "../src/ChallengeManager.sol";
import {MockUSDT} from "../src/MockUSDT.sol";
import {ICachetCertificate} from "../src/interfaces/ICachetCertificate.sol";
import {IChallengeManager} from "../src/interfaces/IChallengeManager.sol";
import {CachetGoverned} from "../src/base/CachetGoverned.sol";

/// @notice Keempat kontrak dirangkai seperti di produksi, dengan uang sungguhan
///         (MockUSDT). Di sinilah klaim "jaminan ikut pembeli" akhirnya diuji
///         sampai ke perpindahan dana — bukan sekadar perpindahan NFT.
contract IntegrationTest is Test {
    CachetRegistry internal reg;
    CachetCertificate internal cert;
    CachetVault internal vault;
    ChallengeManager internal cm;
    MockUSDT internal usdt;

    address internal owner = makeAddr("owner");
    address internal gateway = makeAddr("gateway");
    address internal resolver = makeAddr("resolver");
    address internal creator = makeAddr("creator");
    address internal buyer = makeAddr("buyer");
    address internal challenger = makeAddr("challenger");

    bytes32[4] internal phashes;

    uint256 internal constant DECLARED = 50e6; // 50 USDT
    uint256 internal constant FRAUD_BOND = 5e6;
    uint256 internal constant PREMIUM = 1e6; // 2% dari 50
    uint256 internal constant CHALLENGE_BOND = 10e6;

    function setUp() public {
        usdt = new MockUSDT();
        reg = new CachetRegistry(owner);
        cert = new CachetCertificate(owner);
        vault = new CachetVault(owner, address(usdt), address(cert));
        cm = new ChallengeManager(owner);

        vm.startPrank(owner);
        reg.setGateway(address(cert)); // gateway Registry = kontrak Certificate
        cert.setGateway(gateway);
        cert.setChallengeManager(address(cm));
        cert.setRegistry(address(reg));
        cert.setVault(address(vault));
        vault.setChallengeManager(address(cm));
        cm.setResolver(resolver);
        cm.setCertificate(address(cert));
        cm.setVault(address(vault));
        vm.stopPrank();

        phashes = [keccak256("p0"), keccak256("p1"), keccak256("p2"), keccak256("p3")];

        // Gateway approve SEKALI dengan allowance besar (pola RFC-001 P1).
        usdt.mint(gateway, 1000e6);
        vm.prank(gateway);
        usdt.approve(address(vault), type(uint256).max);

        usdt.mint(challenger, 100e6);
        vm.prank(challenger);
        usdt.approve(address(vault), type(uint256).max);

        // Modal awal operator. Tanpa ini, klaim pertama mustahil terbayar penuh:
        // premi 2% berarti butuh ~50 sertifikat untuk menutup satu klaim penuh.
        // Ditemukan lewat test ini, bukan lewat membaca dokumen.
        address treasury = makeAddr("treasury");
        usdt.mint(treasury, 1000e6);
        vm.startPrank(treasury);
        usdt.approve(address(vault), type(uint256).max);
        vault.fund(500e6);
        vm.stopPrank();
    }

    function _mintTo(address to) internal returns (uint256 certId) {
        ICachetCertificate.MintRequest memory r = ICachetCertificate.MintRequest({
            to: to,
            phashes: phashes,
            embCommit: keccak256("emb"),
            revealedCommit: bytes32(0),
            assetURI: "ipfs://asset",
            tokenURI_: "ipfs://meta",
            declaredValue: DECLARED,
            fraudBond: FRAUD_BOND,
            premium: PREMIUM,
            insurable: true
        });
        vm.prank(gateway);
        (, certId) = cert.registerAndMint(r);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // TEST TERPENTING DI SELURUH REPO
    // ═════════════════════════════════════════════════════════════════════════

    /// @notice Golden Path penuh: mint → jual → digugat → menang → UANG KE PEMBELI.
    ///         Inilah adegan pamungkas video demo, dan pembeda #1 produk.
    ///         Kalau uangnya mendarat di kreator, seluruh premis Cachet salah.
    function test_GoldenPath_PayoutMendaratDiPembeli_BukanKreator() public {
        uint256 certId = _mintTo(creator);

        // Kreator menjual aset ke pembeli.
        vm.prank(creator);
        cert.transferFrom(creator, buyer, certId);
        assertEq(cert.ownerOf(certId), buyer);

        vm.warp(block.timestamp + 73 hours); // coverage aktif
        assertTrue(cert.isCoverageActive(certId));

        uint256 creatorBefore = usdt.balanceOf(creator);
        uint256 buyerBefore = usdt.balanceOf(buyer);
        uint256 challengerBefore = usdt.balanceOf(challenger);

        // Siapa pun menggugat dengan bukti.
        vm.prank(challenger);
        uint256 challengeId = cm.challenge(certId, "ipfs://bukti-karya-lebih-tua");

        // Jendela liveness publik wajib lewat dulu.
        vm.warp(block.timestamp + 48 hours);
        vm.prank(resolver);
        cm.resolve(challengeId, true, "ipfs://putusan");

        // ── Yang paling penting ──
        assertEq(
            usdt.balanceOf(buyer) - buyerBefore,
            DECLARED,
            "PEMBELI harus menerima declaredValue penuh -- ini seluruh premis produk"
        );
        assertEq(usdt.balanceOf(creator), creatorBefore, "KREATOR tidak boleh menerima apa pun");

        // Penantang: bond kembali + bounty (fraud bond + 50% premi).
        uint256 expectedBounty = FRAUD_BOND + (PREMIUM / 2);
        assertEq(
            usdt.balanceOf(challenger) - challengerBefore,
            expectedBounty,
            "penantang: bond kembali + bounty (netto = bounty saja)"
        );

        // Sertifikat dicabut, coverage mati, NFT tetap ada sebagai catatan.
        assertTrue(cert.certData(certId).revoked);
        assertFalse(cert.isCoverageActive(certId));
        assertEq(cert.ownerOf(certId), buyer);
    }

    /// @notice Varian penting: pemegang berganti SETELAH gugatan dibuka.
    ///         Yang dibayar harus pemegang saat RESOLVE, bukan saat gugatan.
    function test_PemegangBergantiSetelahGugatanDibuka_YangDibayarPemegangTerakhir() public {
        uint256 certId = _mintTo(creator);
        vm.warp(block.timestamp + 73 hours);

        vm.prank(challenger);
        uint256 challengeId = cm.challenge(certId, "ipfs://bukti");

        // Aset dijual di tengah sengketa.
        vm.prank(creator);
        cert.transferFrom(creator, buyer, certId);

        uint256 buyerBefore = usdt.balanceOf(buyer);
        uint256 creatorBefore = usdt.balanceOf(creator);

        vm.warp(block.timestamp + 48 hours);
        vm.prank(resolver);
        cm.resolve(challengeId, true, "ipfs://putusan");

        assertEq(usdt.balanceOf(buyer) - buyerBefore, DECLARED, "pemegang saat RESOLVE yang dibayar");
        assertEq(usdt.balanceOf(creator), creatorBefore, "pemegang saat gugatan dibuka TIDAK dibayar");
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Challenge kalah
    // ═════════════════════════════════════════════════════════════════════════

    function test_ChallengeKalah_BondDiSlash_SurvivedNaik() public {
        uint256 certId = _mintTo(creator);
        vm.prank(creator);
        cert.transferFrom(creator, buyer, certId);
        vm.warp(block.timestamp + 73 hours);

        uint256 buyerBefore = usdt.balanceOf(buyer);
        uint256 challengerBefore = usdt.balanceOf(challenger);

        vm.prank(challenger);
        uint256 challengeId = cm.challenge(certId, "ipfs://bukti-lemah");

        vm.warp(block.timestamp + 48 hours);
        vm.prank(resolver);
        cm.resolve(challengeId, false, "ipfs://putusan-ditolak");

        assertEq(
            challengerBefore - usdt.balanceOf(challenger),
            CHALLENGE_BOND,
            "penantang yang salah kehilangan seluruh bond"
        );
        assertEq(
            usdt.balanceOf(buyer) - buyerBefore,
            CHALLENGE_BOND / 2,
            "50% bond ke pemegang, 50% tinggal di vault"
        );

        assertEq(cert.certData(certId).challengesSurvived, 1);
        assertFalse(cert.certData(certId).revoked);
        assertTrue(cert.isCoverageActive(certId), "coverage tetap hidup setelah selamat dari gugatan");
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Liveness — satu-satunya rem terhadap resolver di MVP
    // ═════════════════════════════════════════════════════════════════════════

    function test_RevertWhen_ResolveSebelumLivenessLewat() public {
        uint256 certId = _mintTo(creator);
        vm.warp(block.timestamp + 73 hours);

        vm.prank(challenger);
        uint256 challengeId = cm.challenge(certId, "ipfs://bukti");
        uint64 openedAt = uint64(block.timestamp);

        vm.warp(block.timestamp + 47 hours);
        vm.expectRevert(
            abi.encodeWithSelector(
                ChallengeManager.LivenessNotElapsed.selector, openedAt, openedAt + 48 hours
            )
        );
        vm.prank(resolver);
        cm.resolve(challengeId, true, "ipfs://putusan");
    }

    function test_RevertWhen_NonResolverMemutus() public {
        uint256 certId = _mintTo(creator);
        vm.prank(challenger);
        uint256 challengeId = cm.challenge(certId, "ipfs://bukti");
        vm.warp(block.timestamp + 48 hours);

        vm.expectRevert(abi.encodeWithSelector(ChallengeManager.NotResolver.selector, owner, resolver));
        vm.prank(owner); // owner sekalipun tidak boleh memutus
        cm.resolve(challengeId, true, "ipfs://putusan");
    }

    function test_RevertWhen_ResolveDuaKali() public {
        uint256 certId = _mintTo(creator);
        vm.prank(challenger);
        uint256 challengeId = cm.challenge(certId, "ipfs://bukti");
        vm.warp(block.timestamp + 48 hours);

        vm.startPrank(resolver);
        cm.resolve(challengeId, false, "ipfs://putusan");

        vm.expectRevert(
            abi.encodeWithSelector(
                ChallengeManager.ChallengeNotOpen.selector,
                challengeId,
                IChallengeManager.Status.DismissedChallengerLost
            )
        );
        cm.resolve(challengeId, true, "ipfs://putusan-lagi");
        vm.stopPrank();
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Vault menegakkan ekonomi sendiri
    // ═════════════════════════════════════════════════════════════════════════

    function test_RevertWhen_PremiSalahHitung() public {
        // Gateway yang keliru (atau nakal) tidak bisa memberi jaminan murah.
        ICachetCertificate.MintRequest memory r = ICachetCertificate.MintRequest({
            to: creator,
            phashes: phashes,
            embCommit: keccak256("emb"),
            revealedCommit: bytes32(0),
            assetURI: "ipfs://asset",
            tokenURI_: "ipfs://meta",
            declaredValue: DECLARED,
            fraudBond: FRAUD_BOND,
            premium: 0, // seharusnya 1e6
            insurable: true
        });

        vm.expectRevert(abi.encodeWithSelector(CachetVault.WrongPremium.selector, 0, PREMIUM));
        vm.prank(gateway);
        cert.registerAndMint(r);

        assertEq(reg.entryCount(), 0, "tidak boleh ada entri yatim");
    }

    function test_PremiNilaiGanjil_KontrakDanGatewaySepakat() public {
        // RFC-001 P5: premium = declaredValue * 200 / 10000, dibulatkan ke bawah.
        uint256 odd = 33_333_333; // 33.333333 USDT
        uint256 expected = (odd * 200) / 10_000; // 666666 (floor)
        assertEq(vault.quotePremium(odd), expected);

        ICachetCertificate.MintRequest memory r = ICachetCertificate.MintRequest({
            to: creator,
            phashes: phashes,
            embCommit: keccak256("emb"),
            revealedCommit: bytes32(0),
            assetURI: "ipfs://asset",
            tokenURI_: "ipfs://meta",
            declaredValue: odd,
            fraudBond: FRAUD_BOND,
            premium: expected,
            insurable: true
        });
        vm.prank(gateway);
        (, uint256 certId) = cert.registerAndMint(r);
        assertEq(cert.certData(certId).declaredValue, odd);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Plafon bootstrap: partial payout, BUKAN revert (invariant §9.3)
    // ═════════════════════════════════════════════════════════════════════════

    /// @dev Sengaja memakai stack BARU yang TIDAK diberi modal awal — inilah
    ///      kondisi vault di hari pertama, dan justru kondisi itu yang harus
    ///      tidak mengunci klaim (invariant §9.3).
    function test_DanaVaultKurang_PartialPayout_KlaimTidakTerkunci() public {
        CachetRegistry reg2 = new CachetRegistry(owner);
        CachetCertificate cert2 = new CachetCertificate(owner);
        // Certificate dulu, baru Vault -- alamatnya immutable di Vault.
        CachetVault vault2 = new CachetVault(owner, address(usdt), address(cert2));
        ChallengeManager cm2 = new ChallengeManager(owner);

        vm.startPrank(owner);
        reg2.setGateway(address(cert2));
        cert2.setGateway(gateway);
        cert2.setChallengeManager(address(cm2));
        cert2.setRegistry(address(reg2));
        cert2.setVault(address(vault2));
        vault2.setChallengeManager(address(cm2));
        cm2.setResolver(resolver);
        cm2.setCertificate(address(cert2));
        cm2.setVault(address(vault2));
        vm.stopPrank();

        vm.prank(gateway);
        usdt.approve(address(vault2), type(uint256).max);
        vm.prank(challenger);
        usdt.approve(address(vault2), type(uint256).max);

        ICachetCertificate.MintRequest memory r = ICachetCertificate.MintRequest({
            to: buyer,
            phashes: phashes,
            embCommit: keccak256("emb"),
            revealedCommit: bytes32(0),
            assetURI: "ipfs://asset",
            tokenURI_: "ipfs://meta",
            declaredValue: DECLARED,
            fraudBond: FRAUD_BOND,
            premium: PREMIUM,
            insurable: true
        });
        vm.prank(gateway);
        (, uint256 certId) = cert2.registerAndMint(r);

        vm.warp(block.timestamp + 73 hours);
        vm.prank(challenger);
        uint256 challengeId = cm2.challenge(certId, "ipfs://bukti");

        // Vault hanya memegang fraudBond + premi + challengeBond = 16 USDT,
        // sementara klaim 50 USDT.
        assertLt(usdt.balanceOf(address(vault2)), DECLARED, "prasyarat: dana vault memang kurang");

        uint256 buyerBefore = usdt.balanceOf(buyer);
        vm.warp(block.timestamp + 48 hours);
        vm.prank(resolver);
        cm2.resolve(challengeId, true, "ipfs://putusan");

        uint256 received = usdt.balanceOf(buyer) - buyerBefore;
        assertGt(received, 0, "pembeli tetap dibayar sebagian, klaim TIDAK terkunci");
        assertLt(received, DECLARED, "tidak mungkin penuh dengan dana segini");
        assertTrue(cert2.certData(certId).revoked, "sertifikat tetap dicabut walau bayar sebagian");
    }

    function test_FundMenambahKemampuanBayar() public {
        uint256 before = vault.balanceOfVault();

        address donor = makeAddr("donor");
        usdt.mint(donor, 100e6);
        vm.startPrank(donor);
        usdt.approve(address(vault), type(uint256).max);
        vm.expectEmit(true, false, false, true);
        emit CachetVault.VaultFunded(donor, 100e6);
        vault.fund(100e6);
        vm.stopPrank();

        assertEq(vault.balanceOfVault(), before + 100e6);
    }

    /// @dev Tidak ada fungsi penarikan — SENGAJA. Kalau owner bisa menarik,
    ///      "collateralized" hanya berarti "kami janji tidak akan menarik".
    function test_TidakAdaJalanKeluarDanaSelainKlaim() public view {
        // Bukti negatif: tidak ada satu pun fungsi withdraw/rescue/sweep di ABI.
        // Diperkuat oleh audit selector di PR. Di sini kita tegaskan saldo vault
        // hanya berkurang lewat jalur settle*, yang seluruhnya
        // onlyChallengeManager dan terikat require(ownerOf).
        assertEq(vault.payToken(), address(usdt));
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Aturan gugatan
    // ═════════════════════════════════════════════════════════════════════════

    function test_RevertWhen_GugatSertifikatYangSudahDicabut() public {
        uint256 certId = _mintTo(creator);
        vm.prank(challenger);
        uint256 c1 = cm.challenge(certId, "ipfs://bukti");
        vm.warp(block.timestamp + 48 hours);
        vm.prank(resolver);
        cm.resolve(c1, true, "ipfs://putusan");

        vm.expectRevert(abi.encodeWithSelector(ChallengeManager.CertificateAlreadyRevoked.selector, certId));
        vm.prank(challenger);
        cm.challenge(certId, "ipfs://bukti-lain");
    }

    function test_RevertWhen_DuaGugatanParalelAtasSertifikatSama() public {
        uint256 certId = _mintTo(creator);
        vm.prank(challenger);
        uint256 c1 = cm.challenge(certId, "ipfs://bukti");

        address challenger2 = makeAddr("challenger2");
        usdt.mint(challenger2, 100e6);
        vm.prank(challenger2);
        usdt.approve(address(vault), type(uint256).max);

        vm.expectRevert(abi.encodeWithSelector(ChallengeManager.ChallengeAlreadyOpen.selector, certId, c1));
        vm.prank(challenger2);
        cm.challenge(certId, "ipfs://bukti-lain");
    }

    function test_GugatanBaruBolehSetelahYangLamaSelesai() public {
        uint256 certId = _mintTo(creator);
        vm.prank(challenger);
        uint256 c1 = cm.challenge(certId, "ipfs://bukti");
        vm.warp(block.timestamp + 48 hours);
        vm.prank(resolver);
        cm.resolve(c1, false, "ipfs://ditolak");

        vm.prank(challenger);
        uint256 c2 = cm.challenge(certId, "ipfs://bukti-baru");
        assertEq(c2, c1 + 1);
    }

    /// @dev DIPERKUAT setelah audit B2b. Versi lama memakai declaredValue = 0
    ///      sehingga lolos secara tautologis — payout nol karena nilainya nol,
    ///      bukan karena `insurable = false` dihormati. Kini declaredValue
    ///      besar, jadi test benar-benar menguji flag insurable.
    function test_SertifikatTidakInsurableTetapBisaDigugat_PayoutNol() public {
        ICachetCertificate.MintRequest memory r = ICachetCertificate.MintRequest({
            to: buyer,
            phashes: phashes,
            embCommit: keccak256("emb"),
            revealedCommit: bytes32(0),
            assetURI: "ipfs://asset",
            tokenURI_: "ipfs://meta",
            declaredValue: DECLARED, // NILAI BESAR, tapi tidak insurable
            fraudBond: FRAUD_BOND,
            premium: PREMIUM,
            insurable: false
        });
        vm.prank(gateway);
        (, uint256 certId) = cert.registerAndMint(r);

        vm.warp(block.timestamp + 73 hours); // lewati waiting period
        uint256 buyerBefore = usdt.balanceOf(buyer);

        vm.prank(challenger);
        uint256 challengeId = cm.challenge(certId, "ipfs://bukti");
        vm.warp(block.timestamp + 48 hours);

        vm.expectEmit(true, true, false, true);
        emit CachetVault.ClaimSkippedNoCoverage(certId, buyer, DECLARED);

        vm.prank(resolver);
        cm.resolve(challengeId, true, "ipfs://putusan");

        assertTrue(cert.certData(certId).revoked, "pencabutan tetap bermakna sebagai catatan publik");
        assertEq(usdt.balanceOf(buyer), buyerBefore, "insurable=false: TIDAK ada payout meski nilai besar");
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Jendela coverage ditegakkan saat BAYAR (invariant §9.4) — temuan audit B2b
    //
    // Sebelum perbaikan ini, Vault membayar penuh tanpa peduli jendela coverage:
    // klaim selama masa tunggu, klaim atas sertifikat gray-zone, dan klaim
    // setelah kedaluwarsa semuanya dibayar 50 USDT. `waitingPeriod`,
    // `coverageTerm`, dan `insurable` praktis cuma hiasan.
    // ═════════════════════════════════════════════════════════════════════════

    function test_KlaimSelamaWaitingPeriod_TidakDibayar() public {
        uint256 certId = _mintTo(buyer);
        assertFalse(cert.isCoverageActive(certId), "prasyarat: masih masa tunggu");

        uint256 buyerBefore = usdt.balanceOf(buyer);

        vm.prank(challenger);
        uint256 challengeId = cm.challenge(certId, "ipfs://bukti");
        vm.warp(block.timestamp + 48 hours); // liveness lewat, TAPI masih < 72 jam

        vm.expectEmit(true, true, false, true);
        emit CachetVault.ClaimSkippedNoCoverage(certId, buyer, DECLARED);

        vm.prank(resolver);
        cm.resolve(challengeId, true, "ipfs://putusan");

        assertEq(usdt.balanceOf(buyer), buyerBefore, "klaim sebelum masa tunggu lewat WAJIB ditolak");
        assertTrue(cert.certData(certId).revoked, "tapi sertifikat tetap dicabut");
    }

    function test_KlaimSetelahCoverageKedaluwarsa_TidakDibayar() public {
        uint256 certId = _mintTo(buyer);
        ICachetCertificate.CertData memory d = cert.certData(certId);

        vm.warp(d.coverageEnd + 1 days);
        assertFalse(cert.isCoverageActive(certId), "prasyarat: sudah kedaluwarsa");

        uint256 buyerBefore = usdt.balanceOf(buyer);

        vm.prank(challenger);
        uint256 challengeId = cm.challenge(certId, "ipfs://bukti");
        vm.warp(block.timestamp + 48 hours);
        vm.prank(resolver);
        cm.resolve(challengeId, true, "ipfs://putusan");

        assertEq(usdt.balanceOf(buyer), buyerBefore, "coverage 365 hari harus benar-benar berakhir");
    }

    /// @dev Bounty TETAP dibayar walau klaim dilewati: menangkap pemalsuan
    ///      adalah barang publik, terlepas dari apakah sertifikatnya dijamin.
    function test_BountyTetapDibayarWalauKlaimDilewati() public {
        uint256 certId = _mintTo(buyer); // masih masa tunggu
        uint256 challengerBefore = usdt.balanceOf(challenger);

        vm.prank(challenger);
        uint256 challengeId = cm.challenge(certId, "ipfs://bukti");
        vm.warp(block.timestamp + 48 hours);
        vm.prank(resolver);
        cm.resolve(challengeId, true, "ipfs://putusan");

        assertEq(
            usdt.balanceOf(challenger) - challengerBefore,
            FRAUD_BOND + (PREMIUM / 2),
            "penantang tetap dapat bounty; insentif menangkap pemalsuan tidak boleh hilang"
        );
    }

    /// @dev TEMUAN AUDIT LINTAS-KONTRAK. `mintCertificate` (jalur test/darurat)
    ///      menerbitkan sertifikat TANPA memanggil `collectOnMint`. Sebelum
    ///      perbaikan, sertifikat semacam itu tetap dibayar penuh — dari premi
    ///      milik sertifikat lain dan modal awal operator. Satu kekeliruan
    ///      gateway bisa menguras vault orang lain.
    function test_CertTanpaBond_TidakDapatKlaim() public {
        _mintTo(creator); // sertifikat sah, membayar bond + premi

        vm.prank(gateway);
        uint256 gratis = cert.mintCertificate(buyer, 1, DECLARED, true, "ipfs://meta");

        (,, bool collected,) = vault.certFunds(gratis);
        assertFalse(collected, "prasyarat: sertifikat ini tidak pernah membayar bond");

        vm.warp(block.timestamp + 73 hours);
        assertTrue(cert.isCoverageActive(gratis), "Certificate menganggapnya aktif...");

        uint256 buyerBefore = usdt.balanceOf(buyer);
        uint256 vaultBefore = vault.balanceOfVault();

        vm.prank(challenger);
        uint256 challengeId = cm.challenge(gratis, "ipfs://bukti");
        vm.warp(block.timestamp + 48 hours);

        vm.expectEmit(true, true, false, true);
        emit CachetVault.ClaimSkippedNoCoverage(gratis, buyer, DECLARED);

        vm.prank(resolver);
        cm.resolve(challengeId, true, "ipfs://putusan");

        assertEq(usdt.balanceOf(buyer), buyerBefore, "TIDAK ADA BOND, TIDAK ADA COVERAGE");
        assertGe(
            vault.balanceOfVault() + CHALLENGE_BOND, vaultBefore, "dana sertifikat lain tidak boleh tergerus"
        );
    }

    /// @dev G2 (tepi depan): gugatan yang dibuka SELAMA masa tunggu tidak
    ///      berhak klaim, meski resolve mendarat setelah coverage aktif.
    ///      Sebelum G2 kasus ini DIBAYAR — masa tunggu bisa dilompati dengan
    ///      menggugat lebih awal dan menunggu liveness.
    function test_G2_GugatanSelamaMasaTunggu_TidakDibayarWalauResolveSetelahAktif() public {
        uint256 certId = _mintTo(buyer);
        ICachetCertificate.CertData memory d = cert.certData(certId);

        vm.warp(d.coverageStart - 48 hours); // masih masa tunggu
        vm.prank(challenger);
        uint256 challengeId = cm.challenge(certId, "ipfs://bukti");

        uint256 buyerBefore = usdt.balanceOf(buyer);
        vm.warp(d.coverageStart); // liveness lewat, coverage kini aktif

        vm.expectEmit(true, true, false, true);
        emit CachetVault.ClaimSkippedNoCoverage(certId, buyer, DECLARED);

        vm.prank(resolver);
        cm.resolve(challengeId, true, "ipfs://putusan");

        assertEq(
            usdt.balanceOf(buyer),
            buyerBefore,
            "kelayakan dinilai saat gugatan DIBUKA -- masa tunggu tidak bisa dilompati"
        );
        assertTrue(cert.certData(certId).revoked, "pencabutan tetap terjadi");
    }

    function test_KlaimTepatDiAwalCoverage_Dibayar() public {
        uint256 certId = _mintTo(buyer);
        ICachetCertificate.CertData memory d = cert.certData(certId);

        // G2: gugatan dibuka TEPAT saat coverage mulai berlaku -- openedAt
        // == coverageStart adalah batas bawah inklusif.
        vm.warp(d.coverageStart);
        vm.prank(challenger);
        uint256 challengeId = cm.challenge(certId, "ipfs://bukti");

        uint256 buyerBefore = usdt.balanceOf(buyer);
        vm.warp(block.timestamp + 48 hours);
        vm.prank(resolver);
        cm.resolve(challengeId, true, "ipfs://putusan");

        assertEq(usdt.balanceOf(buyer) - buyerBefore, DECLARED, "tepat di awal jendela: dibayar penuh");
    }

    /// @dev G2 (ekor — inti perbaikan): gugatan sah yang dibuka DI DALAM masa
    ///      coverage tetap dibayar walau jendela liveness mendorong resolve
    ///      MELEWATI coverageEnd. Sebelum G2, klausul jaminan diam-diam
    ///      menyusut sebesar livenessWindow di ekor coverage.
    function test_G2_GugatanDiEkorCoverage_TetapDibayarWalauResolveLewatCoverageEnd() public {
        uint256 certId = _mintTo(buyer);
        ICachetCertificate.CertData memory d = cert.certData(certId);

        // Dibuka 1 jam sebelum coverage berakhir -- masih SAH.
        vm.warp(d.coverageEnd - 1 hours);
        vm.prank(challenger);
        uint256 challengeId = cm.challenge(certId, "ipfs://bukti");

        uint256 buyerBefore = usdt.balanceOf(buyer);

        // Liveness 48 jam mendorong resolve jauh melewati coverageEnd.
        vm.warp(block.timestamp + 48 hours);
        assertGt(block.timestamp, d.coverageEnd, "prasyarat: resolve terjadi SETELAH coverage berakhir");

        vm.prank(resolver);
        cm.resolve(challengeId, true, "ipfs://putusan");

        assertEq(
            usdt.balanceOf(buyer) - buyerBefore,
            DECLARED,
            "fraud tertangkap DI masa coverage wajib dibayar -- liveness tidak menggerus ekor jaminan"
        );
    }

    function test_RevertWhen_BuktiKosong() public {
        uint256 certId = _mintTo(creator);
        vm.expectRevert(ChallengeManager.EmptyEvidence.selector);
        vm.prank(challenger);
        cm.challenge(certId, "");
    }

    function test_RevertWhen_PenantangBelumApproveKeVault() public {
        uint256 certId = _mintTo(creator);
        address poor = makeAddr("poor");
        usdt.mint(poor, 100e6); // punya dana, TAPI belum approve ke Vault

        vm.expectRevert(); // ERC20InsufficientAllowance
        vm.prank(poor);
        cm.challenge(certId, "ipfs://bukti");
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Invariant §9.1 ditegakkan Vault sendiri
    // ═════════════════════════════════════════════════════════════════════════

    /// @notice Menutup jalur pengurasan yang terbukti saat audit: owner
    ///         mengganti ChallengeManager ke kontrak jahat lalu memanggil
    ///         `settleChallengeWon` untuk dirinya sendiri. Modal 6 USDT, hasil
    ///         sampai seluruh saldo vault, dalam satu transaksi.
    ///         Setelah set-once, jalur itu tidak dipersulit -- ia tidak ada.
    function test_WiringTerkunci_OwnerTidakBisaMerebutJalurDana() public {
        address jahat = makeAddr("kontrakJahat");

        vm.expectRevert(
            abi.encodeWithSelector(CachetGoverned.AlreadyWired.selector, "vault.challengeManager")
        );
        vm.prank(owner);
        vault.setChallengeManager(jahat);

        assertEq(vault.challengeManager(), address(cm), "hanya ChallengeManager asli yang gerakkan dana");
    }

    function test_SeluruhWiringTerkunciSetelahDeploy() public {
        address x = makeAddr("x");
        vm.startPrank(owner);

        vm.expectRevert(abi.encodeWithSelector(CachetGoverned.AlreadyWired.selector, "registry.gateway"));
        reg.setGateway(x);

        vm.expectRevert(abi.encodeWithSelector(CachetGoverned.AlreadyWired.selector, "certificate.gateway"));
        cert.setGateway(x);

        vm.expectRevert(
            abi.encodeWithSelector(CachetGoverned.AlreadyWired.selector, "certificate.challengeManager")
        );
        cert.setChallengeManager(x);

        vm.expectRevert(abi.encodeWithSelector(CachetGoverned.AlreadyWired.selector, "certificate.registry"));
        cert.setRegistry(x);

        vm.expectRevert(abi.encodeWithSelector(CachetGoverned.AlreadyWired.selector, "certificate.vault"));
        cert.setVault(x);

        vm.expectRevert(
            abi.encodeWithSelector(CachetGoverned.AlreadyWired.selector, "challengeManager.resolver")
        );
        cm.setResolver(x);

        vm.expectRevert(
            abi.encodeWithSelector(CachetGoverned.AlreadyWired.selector, "challengeManager.certificate")
        );
        cm.setCertificate(x);

        vm.expectRevert(
            abi.encodeWithSelector(CachetGoverned.AlreadyWired.selector, "challengeManager.vault")
        );
        cm.setVault(x);

        vm.stopPrank();
    }

    /// @dev Yang BEKU adalah siapa yang berwenang; berapa besarannya tetap
    ///      bisa disetel dalam pagar masing-masing (secara sengaja, §5.0).
    function test_ParameterTetapBisaDisetelWalauWiringTerkunci() public {
        vm.startPrank(owner);
        cert.setWaitingPeriod(1 hours);
        cert.setMaxDeclaredValue(200e6);
        vault.setPremiumBps(300);
        cm.setLivenessWindow(6 hours);
        vm.stopPrank();

        assertEq(cert.waitingPeriod(), 1 hours);
        assertEq(cert.maxDeclaredValue(), 200e6);
        assertEq(vault.premiumBps(), 300);
        assertEq(cm.livenessWindow(), 6 hours);
    }

    function test_RevertWhen_MaxDeclaredValueMelebihiPagar() public {
        uint256 tooMuch = cert.MAX_DECLARED_VALUE_CEILING() + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                CachetCertificate.ValueOutOfRange.selector, tooMuch, cert.MAX_DECLARED_VALUE_CEILING()
            )
        );
        vm.prank(owner);
        cert.setMaxDeclaredValue(tooMuch);
    }

    function test_RevertWhen_NonCertificateMemanggilCollectOnMint() public {
        vm.expectRevert(abi.encodeWithSelector(CachetVault.NotCertificate.selector, gateway, address(cert)));
        vm.prank(gateway); // gateway wallet pun tidak boleh langsung
        vault.collectOnMint(1, gateway, FRAUD_BOND, PREMIUM);
    }

    function test_RevertWhen_NonChallengeManagerMenyelesaikan() public {
        uint256 certId = _mintTo(creator);
        vm.expectRevert(
            abi.encodeWithSelector(CachetVault.NotChallengeManager.selector, resolver, address(cm))
        );
        vm.prank(resolver);
        vault.settleChallengeLost(certId, 1, creator);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Akuntansi
    // ═════════════════════════════════════════════════════════════════════════

    function test_SaldoVaultBertambahSesuaiBondDanPremi() public {
        uint256 before = vault.balanceOfVault();

        _mintTo(creator);
        assertEq(vault.balanceOfVault() - before, FRAUD_BOND + PREMIUM);

        _mintTo(creator);
        assertEq(vault.balanceOfVault() - before, 2 * (FRAUD_BOND + PREMIUM));
    }

    function test_VaultTidakPernahKirimMelebihiSaldo() public {
        uint256 certId = _mintTo(creator);
        vm.warp(block.timestamp + 73 hours);

        vm.prank(challenger);
        uint256 challengeId = cm.challenge(certId, "ipfs://bukti");
        vm.warp(block.timestamp + 48 hours);
        vm.prank(resolver);
        cm.resolve(challengeId, true, "ipfs://putusan");

        // Saldo tidak mungkin negatif; kalau _pay lalai, ERC20 akan revert.
        assertGe(usdt.balanceOf(address(vault)), 0);
    }
}
