// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {ChallengeManager} from "../src/ChallengeManager.sol";
import {CachetCertificate} from "../src/CachetCertificate.sol";
import {CachetRegistry} from "../src/CachetRegistry.sol";
import {CachetVault} from "../src/CachetVault.sol";
import {MockUSDT} from "../src/MockUSDT.sol";
import {ICachetCertificate} from "../src/interfaces/ICachetCertificate.sol";
import {IChallengeManager} from "../src/interfaces/IChallengeManager.sol";
import {CachetGoverned} from "../src/base/CachetGoverned.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract ChallengeManagerTest is Test {
    ChallengeManager internal cm;
    CachetCertificate internal cert;
    CachetRegistry internal reg;
    CachetVault internal vault;
    MockUSDT internal usdt;

    address internal owner = makeAddr("owner");
    address internal gateway = makeAddr("gateway");
    address internal resolver = makeAddr("resolver");
    address internal creator = makeAddr("creator");
    address internal challenger = makeAddr("challenger");
    address internal stranger = makeAddr("stranger");

    bytes32[4] internal phashes;

    function setUp() public {
        usdt = new MockUSDT();
        reg = new CachetRegistry(owner);
        cert = new CachetCertificate(owner);
        vault = new CachetVault(owner, address(usdt), address(cert));
        cm = new ChallengeManager(owner);

        vm.startPrank(owner);
        reg.setGateway(address(cert));
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

        usdt.mint(gateway, 1000e6);
        vm.prank(gateway);
        usdt.approve(address(vault), type(uint256).max);
        usdt.mint(challenger, 100e6);
        vm.prank(challenger);
        usdt.approve(address(vault), type(uint256).max);
    }

    function _mint() internal returns (uint256 certId) {
        ICachetCertificate.MintRequest memory r = ICachetCertificate.MintRequest({
            to: creator,
            phashes: phashes,
            embCommit: keccak256("emb"),
            revealedCommit: bytes32(0),
            assetURI: "ipfs://a",
            tokenURI_: "ipfs://m",
            declaredValue: 50e6,
            fraudBond: 5e6,
            premium: 1e6,
            insurable: true
        });
        vm.prank(gateway);
        (, certId) = cert.registerAndMint(r);
    }

    // ── Wiring ───────────────────────────────────────────────────────────────

    function test_RevertWhen_SetterDiberiAddressNol() public {
        vm.startPrank(owner);
        vm.expectRevert(CachetGoverned.ZeroAddress.selector);
        cm.setResolver(address(0));
        vm.expectRevert(CachetGoverned.ZeroAddress.selector);
        cm.setCertificate(address(0));
        vm.expectRevert(CachetGoverned.ZeroAddress.selector);
        cm.setVault(address(0));
        vm.stopPrank();
    }

    function test_RevertWhen_NonOwnerWiring() public {
        bytes memory err = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger);
        vm.startPrank(stranger);
        vm.expectRevert(err);
        cm.setResolver(stranger);
        vm.expectRevert(err);
        cm.setCertificate(stranger);
        vm.expectRevert(err);
        cm.setVault(stranger);
        vm.expectRevert(err);
        cm.setChallengeBond(1);
        vm.expectRevert(err);
        cm.setLivenessWindow(1);
        vm.stopPrank();
    }

    function test_RevertWhen_BelumDiWiring() public {
        ChallengeManager fresh = new ChallengeManager(owner);

        vm.expectRevert(abi.encodeWithSelector(ChallengeManager.NotWired.selector, "certificate"));
        vm.prank(challenger);
        fresh.challenge(1, "ipfs://bukti");

        vm.prank(owner);
        fresh.setCertificate(address(cert));

        vm.expectRevert(abi.encodeWithSelector(ChallengeManager.NotWired.selector, "vault"));
        vm.prank(challenger);
        fresh.challenge(1, "ipfs://bukti");
    }

    // ── Parameter (§5.0) ─────────────────────────────────────────────────────

    function test_SetChallengeBondEmitParamChanged() public {
        vm.expectEmit(true, false, false, true);
        emit CachetGoverned.ParamChanged("challengeBond", 10e6, 25e6);
        vm.prank(owner);
        cm.setChallengeBond(25e6);
        assertEq(cm.challengeBond(), 25e6);
    }

    function test_SetLivenessWindowEmitParamChanged() public {
        vm.expectEmit(true, false, false, true);
        emit CachetGoverned.ParamChanged("livenessWindow", 48 hours, 24 hours);
        vm.prank(owner);
        cm.setLivenessWindow(24 hours);
        assertEq(cm.livenessWindow(), 24 hours);
    }

    /// @dev Tanpa pagar, owner bisa menyetel liveness 100 tahun dan membekukan
    ///      seluruh gugatan yang sedang berjalan.
    function test_RevertWhen_LivenessMelebihiPagar() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                ChallengeManager.ParamOutOfRange.selector, uint256(31 days), cm.MAX_LIVENESS_WINDOW()
            )
        );
        vm.prank(owner);
        cm.setLivenessWindow(31 days);
    }

    /// @notice LANTAI TERPENTING DI SELURUH SISTEM.
    ///         Jendela liveness adalah satu-satunya rem publik terhadap
    ///         resolver di MVP. Kalau boleh disetel 0, owner+resolver bisa
    ///         menerbitkan, menggugat, dan memutus dalam satu blok tanpa
    ///         jendela pengawasan sama sekali.
    function test_RevertWhen_LivenessDiBawahLantai() public {
        uint64 floor_ = cm.MIN_LIVENESS_WINDOW();

        vm.expectRevert(abi.encodeWithSelector(CachetGoverned.ParamBelowFloor.selector, 0, floor_));
        vm.prank(owner);
        cm.setLivenessWindow(0);

        vm.expectRevert(abi.encodeWithSelector(CachetGoverned.ParamBelowFloor.selector, uint64(1), floor_));
        vm.prank(owner);
        cm.setLivenessWindow(1 seconds);
    }

    function test_LivenessTepatDiLantai_MasihMenahanResolveDini() public {
        uint64 floor_ = cm.MIN_LIVENESS_WINDOW();
        vm.prank(owner);
        cm.setLivenessWindow(floor_);

        uint256 certId = _mint();
        vm.prank(challenger);
        uint256 id = cm.challenge(certId, "ipfs://bukti");
        uint64 openedAt = uint64(block.timestamp);

        // Bahkan di lantai, resolve dini TETAP ditolak -- mekanismenya hidup.
        vm.warp(openedAt + floor_ - 1);
        vm.expectRevert(
            abi.encodeWithSelector(ChallengeManager.LivenessNotElapsed.selector, openedAt, openedAt + floor_)
        );
        vm.prank(resolver);
        cm.resolve(id, true, "ipfs://putusan");
    }

    function test_RevertWhen_ChallengeBondDiBawahLantai() public {
        uint256 floor_ = cm.MIN_CHALLENGE_BOND();
        vm.expectRevert(abi.encodeWithSelector(CachetGoverned.ParamBelowFloor.selector, 0, floor_));
        vm.prank(owner);
        cm.setChallengeBond(0);
    }

    function test_LivenessBaruBerlakuUntukGugatanBerikutnya() public {
        uint256 certId = _mint();
        vm.prank(owner);
        cm.setLivenessWindow(1 hours);

        vm.prank(challenger);
        uint256 id = cm.challenge(certId, "ipfs://bukti");

        vm.warp(block.timestamp + 1 hours);
        vm.prank(resolver);
        cm.resolve(id, false, "ipfs://putusan"); // tidak revert
    }

    /// @dev G1: memperpendek `livenessWindow` di tengah gugatan yang SUDAH
    ///      terbuka tidak boleh mempercepat putusan. Yang berlaku adalah
    ///      snapshot saat gugatan dibuka, bukan nilai saat resolve — kalau
    ///      tidak, owner bisa memangkas jendela ke lantai dan resolver langsung
    ///      memutus, melubangi mitigasi utama terhadap kolusi (A1).
    function test_G1_LivenessDiperpendekDiTengahGugatan_SnapshotBerlaku() public {
        uint64 floor_ = cm.MIN_LIVENESS_WINDOW();
        uint256 certId = _mint();
        vm.prank(challenger);
        uint256 id = cm.challenge(certId, "ipfs://bukti");
        uint64 openedAt = uint64(block.timestamp);

        // Owner memangkas liveness ke lantai SETELAH gugatan dibuka.
        vm.prank(owner);
        cm.setLivenessWindow(floor_);

        // Di nilai BARU (30 detik) sudah lewat; di snapshot (48 jam) belum.
        vm.warp(openedAt + floor_);
        vm.expectRevert(
            abi.encodeWithSelector(
                ChallengeManager.LivenessNotElapsed.selector, openedAt, openedAt + 48 hours
            )
        );
        vm.prank(resolver);
        cm.resolve(id, true, "ipfs://putusan");

        // Snapshot 48 jam tetap ditegakkan sampai penuh.
        vm.warp(openedAt + 48 hours);
        vm.prank(resolver);
        cm.resolve(id, true, "ipfs://putusan"); // baru sekarang boleh
    }

    /// @dev G1 arah sebaliknya: memperpanjang `livenessWindow` di tengah
    ///      gugatan tidak boleh menunda putusan (dan menahan sertifikat
    ///      terkunci). Gugatan yang dibuka saat liveness 1 jam tetap bisa
    ///      diputus setelah 1 jam meski owner menaikkannya ke MAX.
    function test_G1_LivenessDiperpanjangDiTengahGugatan_SnapshotBerlaku() public {
        uint64 maxW = cm.MAX_LIVENESS_WINDOW();
        uint256 certId = _mint();

        vm.prank(owner);
        cm.setLivenessWindow(1 hours); // snapshot gugatan berikutnya = 1 jam

        vm.prank(challenger);
        uint256 id = cm.challenge(certId, "ipfs://bukti");
        uint64 openedAt = uint64(block.timestamp);

        // Owner menaikkan ke MAX setelah gugatan terbuka.
        vm.prank(owner);
        cm.setLivenessWindow(maxW);

        // Snapshot 1 jam yang berlaku: putusan tidak tertunda sampai 30 hari.
        vm.warp(openedAt + 1 hours);
        vm.prank(resolver);
        cm.resolve(id, false, "ipfs://putusan"); // tidak revert
    }

    // ── challenge ────────────────────────────────────────────────────────────

    function test_ChallengeIdMulaiDari1() public {
        uint256 certId = _mint();
        assertEq(cm.challengeCount(), 0);

        vm.prank(challenger);
        assertEq(cm.challenge(certId, "ipfs://bukti"), 1);
        assertEq(cm.challengeCount(), 1);
    }

    function test_GetChallengeMengembalikanSemuaField() public {
        uint256 certId = _mint();
        vm.prank(challenger);
        uint256 id = cm.challenge(certId, "ipfs://bukti-lengkap");

        (uint256 cId, address who, uint64 openedAt, IChallengeManager.Status status, string memory uri) =
            cm.getChallenge(id);

        assertEq(cId, certId);
        assertEq(who, challenger);
        assertEq(openedAt, uint64(block.timestamp));
        assertTrue(status == IChallengeManager.Status.Open);
        assertEq(uri, "ipfs://bukti-lengkap");
    }

    function test_RevertWhen_GetChallengeIdTidakValid() public {
        vm.expectRevert(abi.encodeWithSelector(ChallengeManager.InvalidChallengeId.selector, 0));
        cm.getChallenge(0);

        vm.expectRevert(abi.encodeWithSelector(ChallengeManager.InvalidChallengeId.selector, 1));
        cm.getChallenge(1);
    }

    function test_RevertWhen_GugatCertYangTidakAda() public {
        vm.expectRevert(abi.encodeWithSelector(CachetCertificate.InvalidCertId.selector, 99));
        vm.prank(challenger);
        cm.challenge(99, "ipfs://bukti");
    }

    function test_OpenChallengeOfDilepasSetelahResolve() public {
        uint256 certId = _mint();
        vm.prank(challenger);
        uint256 id = cm.challenge(certId, "ipfs://bukti");
        assertEq(cm.openChallengeOf(certId), id);

        vm.warp(block.timestamp + 48 hours);
        vm.prank(resolver);
        cm.resolve(id, false, "ipfs://putusan");

        assertEq(cm.openChallengeOf(certId), 0, "slot harus dilepas supaya bisa digugat lagi");
    }

    // ── resolve ──────────────────────────────────────────────────────────────

    function test_RevertWhen_ResolveIdTidakValid() public {
        vm.expectRevert(abi.encodeWithSelector(ChallengeManager.InvalidChallengeId.selector, 5));
        vm.prank(resolver);
        cm.resolve(5, true, "ipfs://putusan");
    }

    function test_ResolveMenangMemancarkanStatusBenar() public {
        uint256 certId = _mint();
        vm.prank(challenger);
        uint256 id = cm.challenge(certId, "ipfs://bukti");
        vm.warp(block.timestamp + 48 hours);

        vm.expectEmit(true, false, false, true);
        emit IChallengeManager.ChallengeResolved(id, IChallengeManager.Status.UpheldChallengerWon);

        vm.prank(resolver);
        cm.resolve(id, true, "ipfs://putusan");

        (,,, IChallengeManager.Status status,) = cm.getChallenge(id);
        assertTrue(status == IChallengeManager.Status.UpheldChallengerWon);
    }

    function test_ResolveKalahMemancarkanStatusBenar() public {
        uint256 certId = _mint();
        vm.prank(challenger);
        uint256 id = cm.challenge(certId, "ipfs://bukti");
        vm.warp(block.timestamp + 48 hours);

        vm.prank(resolver);
        cm.resolve(id, false, "ipfs://putusan");

        (,,, IChallengeManager.Status status,) = cm.getChallenge(id);
        assertTrue(status == IChallengeManager.Status.DismissedChallengerLost);
    }

    function test_RulingURITercatatDiEvent() public {
        uint256 certId = _mint();
        vm.prank(challenger);
        uint256 id = cm.challenge(certId, "ipfs://bukti");
        vm.warp(block.timestamp + 48 hours);

        vm.expectEmit(true, false, false, true);
        emit ChallengeManager.RulingRecorded(id, "ipfs://alasan-putusan");

        vm.prank(resolver);
        cm.resolve(id, true, "ipfs://alasan-putusan");
    }

    /// @dev Liveness adalah SATU-SATUNYA rem terhadap resolver di MVP.
    ///      Tepat di detik batas sudah boleh — sedetik sebelumnya tidak.
    function test_ResolveTepatDiBatasLivenessDiizinkan() public {
        uint256 certId = _mint();
        vm.prank(challenger);
        uint256 id = cm.challenge(certId, "ipfs://bukti");
        uint64 openedAt = uint64(block.timestamp);

        vm.warp(openedAt + 48 hours - 1);
        vm.expectRevert(
            abi.encodeWithSelector(
                ChallengeManager.LivenessNotElapsed.selector, openedAt, openedAt + 48 hours
            )
        );
        vm.prank(resolver);
        cm.resolve(id, true, "ipfs://putusan");

        vm.warp(openedAt + 48 hours);
        vm.prank(resolver);
        cm.resolve(id, true, "ipfs://putusan"); // tepat di batas: boleh
    }
}
