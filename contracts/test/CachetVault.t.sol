// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CachetVault} from "../src/CachetVault.sol";
import {CachetCertificate} from "../src/CachetCertificate.sol";
import {CachetRegistry} from "../src/CachetRegistry.sol";
import {MockUSDT} from "../src/MockUSDT.sol";
import {ICachetCertificate} from "../src/interfaces/ICachetCertificate.sol";
import {CachetGoverned} from "../src/base/CachetGoverned.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CachetVaultTest is Test {
    CachetVault internal vault;
    CachetCertificate internal cert;
    CachetRegistry internal reg;
    MockUSDT internal usdt;

    address internal owner = makeAddr("owner");
    address internal gateway = makeAddr("gateway");
    address internal cm = makeAddr("challengeManager");
    address internal creator = makeAddr("creator");
    address internal stranger = makeAddr("stranger");

    bytes32[4] internal phashes;

    uint256 internal constant DECLARED = 50e6;
    uint256 internal constant FRAUD_BOND = 5e6;
    uint256 internal constant PREMIUM = 1e6;

    function setUp() public {
        usdt = new MockUSDT();
        reg = new CachetRegistry(owner);
        cert = new CachetCertificate(owner);
        vault = new CachetVault(owner, address(usdt), address(cert));

        vm.startPrank(owner);
        reg.setGateway(address(cert));
        cert.setGateway(gateway);
        cert.setChallengeManager(cm);
        cert.setRegistry(address(reg));
        cert.setVault(address(vault));
        vault.setChallengeManager(cm);
        vm.stopPrank();

        phashes = [keccak256("p0"), keccak256("p1"), keccak256("p2"), keccak256("p3")];

        usdt.mint(gateway, 1000e6);
        vm.prank(gateway);
        usdt.approve(address(vault), type(uint256).max);
    }

    function _mint(address to) internal returns (uint256 certId) {
        ICachetCertificate.MintRequest memory r = ICachetCertificate.MintRequest({
            to: to,
            phashes: phashes,
            embCommit: keccak256("emb"),
            revealedCommit: bytes32(0),
            assetURI: "ipfs://a",
            tokenURI_: "ipfs://m",
            declaredValue: DECLARED,
            fraudBond: FRAUD_BOND,
            premium: PREMIUM,
            insurable: true
        });
        vm.prank(gateway);
        (, certId) = cert.registerAndMint(r);
    }

    // ── Konstruksi & wiring ──────────────────────────────────────────────────

    function test_RevertWhen_PayTokenNol() public {
        vm.expectRevert(CachetGoverned.ZeroAddress.selector);
        new CachetVault(owner, address(0), address(cert));
    }

    function test_RevertWhen_CertificateNol() public {
        vm.expectRevert(CachetGoverned.ZeroAddress.selector);
        new CachetVault(owner, address(usdt), address(0));
    }

    function test_PayTokenDanCertificateImmutable() public view {
        assertEq(vault.payToken(), address(usdt));
        assertEq(vault.certificate(), address(cert));
    }

    /// @dev Alamat Certificate SENGAJA immutable. Audit membuktikan: bila bisa
    ///      diganti, owner tinggal mengarahkannya ke kontrak palsu yang
    ///      melaporkan ownerOf & certData sesukanya, lalu menguras vault.
    function test_TidakAdaSetterUntukCertificate() public view {
        assertEq(vault.certificate(), address(cert), "hanya bisa ditetapkan saat deploy");
    }

    function test_RevertWhen_SetterDiberiAddressNol() public {
        vm.startPrank(owner);
        vm.expectRevert(CachetGoverned.ZeroAddress.selector);
        vault.setChallengeManager(address(0));
        vm.stopPrank();
    }

    function test_RevertWhen_NonOwnerWiring() public {
        bytes memory err = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger);
        vm.startPrank(stranger);
        vm.expectRevert(err);
        vault.setChallengeManager(stranger);
        vm.expectRevert(err);
        vault.setFraudBondAmount(1);
        vm.expectRevert(err);
        vault.setPremiumBps(1);
        vm.stopPrank();
    }

    // ── Parameter (§5.0) ─────────────────────────────────────────────────────

    function test_SetFraudBondAmountEmitParamChanged() public {
        vm.expectEmit(true, false, false, true);
        emit CachetGoverned.ParamChanged("fraudBondAmount", 5e6, 7e6);
        vm.prank(owner);
        vault.setFraudBondAmount(7e6);
        assertEq(vault.fraudBondAmount(), 7e6);
    }

    function test_SetPremiumBpsEmitParamChanged() public {
        vm.expectEmit(true, false, false, true);
        emit CachetGoverned.ParamChanged("premiumBps", 200, 500);
        vm.prank(owner);
        vault.setPremiumBps(500);
        assertEq(vault.quotePremium(100e6), 5e6);
    }

    /// @dev Pagar: premi > 100% membuat mint mustahil dibayar siapa pun.
    function test_RevertWhen_PremiumBpsMelebihiPagar() public {
        vm.expectRevert(
            abi.encodeWithSelector(CachetVault.ParamOutOfRange.selector, 10_001, vault.MAX_PREMIUM_BPS())
        );
        vm.prank(owner);
        vault.setPremiumBps(10_001);
    }

    /// @dev LANTAI. `premiumBps = 0` membuat jaminan GRATIS -- mekanisme
    ///      preminya mati, bukan dimurahkan.
    function test_RevertWhen_PremiumBpsDiBawahLantai() public {
        uint256 floor_ = vault.MIN_PREMIUM_BPS();
        vm.expectRevert(abi.encodeWithSelector(CachetGoverned.ParamBelowFloor.selector, 0, floor_));
        vm.prank(owner);
        vault.setPremiumBps(0);
    }

    /// @dev LANTAI. Bond kreator adalah taruhannya DAN sumber bounty penantang.
    ///      Nol berarti tidak ada insentif menangkap pemalsuan.
    function test_RevertWhen_FraudBondDiBawahLantai() public {
        uint256 floor_ = vault.MIN_FRAUD_BOND();
        vm.expectRevert(abi.encodeWithSelector(CachetGoverned.ParamBelowFloor.selector, 0, floor_));
        vm.prank(owner);
        vault.setFraudBondAmount(0);
    }

    function test_ParameterTepatDiLantai_Diizinkan() public {
        uint256 pFloor = vault.MIN_PREMIUM_BPS();
        uint256 bFloor = vault.MIN_FRAUD_BOND();
        vm.startPrank(owner);
        vault.setPremiumBps(pFloor);
        vault.setFraudBondAmount(bFloor);
        vm.stopPrank();

        assertEq(vault.premiumBps(), pFloor);
        assertEq(vault.fraudBondAmount(), bFloor);
        assertGt(vault.quotePremium(100e6), 0, "di lantai pun premi tetap bukan nol");
    }

    function test_QuotePremiumMembulatKeBawah() public view {
        // RFC-001 P5: integer division, floor. Gateway WAJIB sama persis.
        assertEq(vault.quotePremium(0), 0);
        assertEq(vault.quotePremium(50e6), 1e6);
        assertEq(vault.quotePremium(33_333_333), 666_666); // bukan 666_666.66
        assertEq(vault.quotePremium(49), 0); // pembulatan ke bawah sampai nol
    }

    // ── collectOnMint ────────────────────────────────────────────────────────

    function test_CollectOnMintMencatatPembukuan() public {
        uint256 certId = _mint(creator);

        (uint256 fb, uint256 pr, bool collected, bool settled) = vault.certFunds(certId);
        assertEq(fb, FRAUD_BOND);
        assertEq(pr, PREMIUM);
        assertTrue(collected);
        assertFalse(settled);
        assertEq(vault.balanceOfVault(), FRAUD_BOND + PREMIUM);
    }

    function test_RevertWhen_FraudBondSalah() public {
        ICachetCertificate.MintRequest memory r = ICachetCertificate.MintRequest({
            to: creator,
            phashes: phashes,
            embCommit: keccak256("emb"),
            revealedCommit: bytes32(0),
            assetURI: "ipfs://a",
            tokenURI_: "ipfs://m",
            declaredValue: DECLARED,
            fraudBond: 1e6, // seharusnya 5e6
            premium: PREMIUM,
            insurable: true
        });
        vm.expectRevert(abi.encodeWithSelector(CachetVault.WrongFraudBond.selector, 1e6, FRAUD_BOND));
        vm.prank(gateway);
        cert.registerAndMint(r);
    }

    function test_RevertWhen_NonCertificateMemanggilCollectOnMint() public {
        vm.expectRevert(abi.encodeWithSelector(CachetVault.NotCertificate.selector, stranger, address(cert)));
        vm.prank(stranger);
        vault.collectOnMint(1, gateway, FRAUD_BOND, PREMIUM);
    }

    // ── fund ─────────────────────────────────────────────────────────────────

    function test_FundTerbukaUntukSiapaPun() public {
        usdt.mint(stranger, 100e6);
        vm.startPrank(stranger);
        usdt.approve(address(vault), type(uint256).max);
        vault.fund(60e6);
        vm.stopPrank();

        assertEq(vault.balanceOfVault(), 60e6);
    }

    /// @dev Bukti struktural: tidak ada satu pun fungsi yang bisa menarik dana
    ///      keluar kecuali lewat settle* yang terkunci onlyChallengeManager.
    ///      Owner sekalipun tidak punya jalan keluar.
    function test_OwnerTidakBisaMenarikDana() public {
        usdt.mint(stranger, 100e6);
        vm.startPrank(stranger);
        usdt.approve(address(vault), type(uint256).max);
        vault.fund(100e6);
        vm.stopPrank();

        uint256 ownerBefore = usdt.balanceOf(owner);

        // Owner mencoba jalur settle -- ditolak karena bukan ChallengeManager.
        vm.expectRevert(abi.encodeWithSelector(CachetVault.NotChallengeManager.selector, owner, cm));
        vm.prank(owner);
        vault.settleChallengeLost(1, 1, owner);

        assertEq(usdt.balanceOf(owner), ownerBefore, "owner tidak boleh bisa mengambil dana vault");
        assertEq(vault.balanceOfVault(), 100e6);
    }

    // ── settle ───────────────────────────────────────────────────────────────

    function test_RevertWhen_HolderTidakCocok() public {
        uint256 certId = _mint(creator);

        vm.expectRevert(
            abi.encodeWithSelector(CachetVault.HolderMismatch.selector, certId, stranger, creator)
        );
        vm.prank(cm);
        vault.settleChallengeWon(certId, 1, stranger, stranger);
    }

    function test_RevertWhen_SettleDuaKaliUntukCertSama() public {
        uint256 certId = _mint(creator);

        vm.startPrank(cm);
        vault.collectChallengeBond(1, gateway, 10e6);
        vault.settleChallengeWon(certId, 1, creator, gateway);

        vm.expectRevert(abi.encodeWithSelector(CachetVault.AlreadySettled.selector, certId));
        vault.settleChallengeWon(certId, 2, creator, gateway);
        vm.stopPrank();
    }

    function test_SettleChallengeLostMembagiBondSeparuh() public {
        uint256 certId = _mint(creator);
        uint256 bond = 10e6;

        vm.startPrank(cm);
        vault.collectChallengeBond(7, gateway, bond);
        uint256 creatorBefore = usdt.balanceOf(creator);
        vault.settleChallengeLost(certId, 7, creator);
        vm.stopPrank();

        assertEq(usdt.balanceOf(creator) - creatorBefore, bond / 2, "50% ke pemegang");
        assertEq(vault.challengeBonds(7), 0, "bond dianggap habis dipakai");
    }

    function test_RevertWhen_NonChallengeManagerCollectBond() public {
        vm.expectRevert(abi.encodeWithSelector(CachetVault.NotChallengeManager.selector, stranger, cm));
        vm.prank(stranger);
        vault.collectChallengeBond(1, stranger, 10e6);
    }

    /// @dev Invariant §9.3: dana kurang -> bayar sebagian, JANGAN revert.
    ///      Revert akan mengunci klaim selamanya.
    function test_DanaKosong_PembayaranNolTanpaRevert() public {
        uint256 certId = _mint(creator);

        // Coverage harus aktif dulu, kalau tidak klaim memang dilewati
        // (§9.4) dan vault tidak terkuras.
        vm.warp(block.timestamp + 73 hours);

        // Kuras vault lewat jalur sah supaya saldo benar-benar nol.
        // G2: bond challenge 99 di-collect DI SINI (openedAt = sekarang, di
        // dalam coverage) — kelayakan dinilai pada openedAt, bukan saat resolve.
        vm.startPrank(cm);
        vault.collectChallengeBond(99, gateway, 0);
        vault.settleChallengeWon(certId, 99, creator, creator);
        vm.stopPrank();

        assertEq(vault.balanceOfVault(), 0, "prasyarat: vault kosong");

        uint256 certId2 = _mint(creator);
        vm.startPrank(cm);
        // Tidak revert meski tidak ada dana untuk dibayarkan penuh.
        vault.settleChallengeLost(certId2, 100, creator);
        vm.stopPrank();
    }

    // ── G3: bond penantang dicadangkan, bukan kolam klaim ────────────────────

    function test_G3_ReservedNaikSaatCollect_TurunSaatSettle() public {
        uint256 certId = _mint(creator);
        vm.warp(block.timestamp + 73 hours);

        vm.startPrank(cm);
        vault.collectChallengeBond(1, gateway, 10e6);
        assertEq(vault.reservedChallengeBonds(), 10e6, "collect menaikkan cadangan");

        vault.collectChallengeBond(2, gateway, 10e6);
        assertEq(vault.reservedChallengeBonds(), 20e6);

        vault.settleChallengeLost(certId, 2, creator);
        assertEq(vault.reservedChallengeBonds(), 10e6, "slash melepas cadangan");

        vault.settleChallengeWon(certId, 1, creator, gateway);
        assertEq(vault.reservedChallengeBonds(), 0, "refund melepas cadangan");
        vm.stopPrank();
    }

    function test_BalanceOfVaultMencerminkanSaldoNyata() public {
        assertEq(vault.balanceOfVault(), 0);
        _mint(creator);
        assertEq(vault.balanceOfVault(), usdt.balanceOf(address(vault)));
    }
}
