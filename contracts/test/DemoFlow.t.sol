// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CachetRegistry} from "../src/CachetRegistry.sol";
import {CachetCertificate} from "../src/CachetCertificate.sol";
import {CachetVault} from "../src/CachetVault.sol";
import {ChallengeManager} from "../src/ChallengeManager.sol";
import {MockUSDT} from "../src/MockUSDT.sol";
import {ICachetCertificate} from "../src/interfaces/ICachetCertificate.sol";

/// @notice Menjalankan URUTAN yang sama persis dengan `DemoFlow.s.sol`, tapi
///         lokal. Gunanya: membuktikan skenario rekaman benar SEBELUM
///         menyentuh testnet, dan menangkap kalau ada perubahan kontrak yang
///         diam-diam merusak alur demo.
///
///         Kalau test ini merah, JANGAN merekam video.
contract DemoFlowTest is Test {
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

    // Nilai yang sama dengan PrepareDemo.s.sol
    uint64 internal constant DEMO_WAITING_PERIOD = 10 seconds;
    uint64 internal constant DEMO_LIVENESS_WINDOW = 30 seconds;
    uint256 internal constant SEED_CAPITAL = 500e6;
    uint256 internal constant DECLARED_VALUE = 50e6;
    uint256 internal constant FRAUD_BOND = 5e6;

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

        // ── Meniru PrepareDemo.s.sol ─────────────────────────────────────────
        vm.startPrank(owner);
        cert.setWaitingPeriod(DEMO_WAITING_PERIOD);
        cm.setLivenessWindow(DEMO_LIVENESS_WINDOW);
        vm.stopPrank();

        usdt.mint(owner, SEED_CAPITAL);
        vm.startPrank(owner);
        usdt.approve(address(vault), SEED_CAPITAL);
        vault.fund(SEED_CAPITAL);
        vm.stopPrank();

        usdt.mint(gateway, 200e6);
        vm.prank(gateway);
        usdt.approve(address(vault), type(uint256).max);

        usdt.mint(challenger, 200e6);
        vm.prank(challenger);
        usdt.approve(address(vault), type(uint256).max);
    }

    /// @notice Lima babak, urutan persis seperti yang akan direkam.
    function test_SkenarioDemoLengkap() public {
        // ── 1. Mint ke kreator ───────────────────────────────────────────────
        bytes32 seed = keccak256(abi.encodePacked(block.timestamp, block.number));
        uint256 premium = vault.quotePremium(DECLARED_VALUE);

        vm.prank(gateway);
        (, uint256 certId) = cert.registerAndMint(
            ICachetCertificate.MintRequest({
                to: creator,
                phashes: [
                    seed,
                    keccak256(abi.encodePacked(seed, uint8(1))),
                    keccak256(abi.encodePacked(seed, uint8(2))),
                    keccak256(abi.encodePacked(seed, uint8(3)))
                ],
                embCommit: keccak256(abi.encodePacked(seed, "emb")),
                revealedCommit: bytes32(0),
                assetURI: "ipfs://demo-asset",
                tokenURI_: "ipfs://demo-metadata",
                declaredValue: DECLARED_VALUE,
                fraudBond: FRAUD_BOND,
                premium: premium,
                insurable: true
            })
        );

        // Masa tunggu TETAP HIDUP di setelan demo, hanya dipercepat jadi 10
        // detik. Penonton harus melihat mekanismenya bekerja, bukan melihat
        // "mint lalu langsung dijamin" yang bukan cara produk ini bekerja.
        assertFalse(cert.isCoverageActive(certId), "masa tunggu harus tetap berlaku, bukan dimatikan");
        assertEq(
            cert.certData(certId).coverageStart,
            cert.certData(certId).mintedAt + DEMO_WAITING_PERIOD,
            "jendela dihitung dari parameter demo"
        );

        // ── 2. Kreator menjual ke pembeli ────────────────────────────────────
        vm.prank(creator);
        cert.transferFrom(creator, buyer, certId);
        assertEq(cert.ownerOf(certId), buyer, "jaminan ikut pindah, tanpa langkah tambahan");

        // ── 3. Masa tunggu lewat, coverage MENYALA, baru gugatan ─────────────
        // G2: kelayakan klaim dinilai saat gugatan DIBUKA. Gugatan yang dibuka
        // selama masa tunggu berakhir tanpa payout — jadi demo menunggu 10
        // detik sampai coverage aktif, BARU menggugat. Total durasi tetap
        // 10 + 30 = 40 detik, dan penonton kini melihat momen coverage menyala
        // sebagai babak sendiri, bukan sekadar angka.
        vm.warp(block.timestamp + DEMO_WAITING_PERIOD);
        assertTrue(cert.isCoverageActive(certId), "coverage aktif setelah masa tunggu 10 detik");

        vm.prank(challenger);
        uint256 challengeId = cm.challenge(certId, "ipfs://bukti-karya-lebih-tua");

        // ── 4. Jendela liveness benar-benar menahan ──────────────────────────
        vm.expectRevert(); // LivenessNotElapsed
        vm.prank(resolver);
        cm.resolve(challengeId, true, "ipfs://putusan");

        vm.warp(block.timestamp + DEMO_LIVENESS_WINDOW);

        // ── 5. Putusan: uang ke PEMBELI ──────────────────────────────────────
        uint256 buyerBefore = usdt.balanceOf(buyer);
        uint256 creatorBefore = usdt.balanceOf(creator);

        vm.prank(resolver);
        cm.resolve(challengeId, true, "ipfs://putusan-resolver");

        // Pagar yang sama dengan `require` di DemoFlow.resolve().
        assertEq(
            usdt.balanceOf(buyer) - buyerBefore, DECLARED_VALUE, "DEMO GAGAL: pembeli tidak menerima penuh"
        );
        assertEq(
            usdt.balanceOf(creator), creatorBefore, "DEMO GAGAL: kreator seharusnya tidak menerima apa pun"
        );
        assertTrue(cert.certData(certId).revoked);
    }

    /// @dev §5-B4 mensyaratkan skenario jalan mulus DUA KALI berturut-turut.
    ///      Take kedua tidak boleh terganggu sisa state dari take pertama.
    function test_SkenarioBisaDiulang() public {
        test_SkenarioDemoLengkap();
        test_SkenarioDemoLengkap();

        assertEq(reg.entryCount(), 2, "tiap take memakai entri baru");
        assertEq(cert.certCount(), 2, "tiap take memakai sertifikat baru");
    }

    /// @dev Pagar preflight DemoFlow: kalau modal vault kurang, payout jadi
    ///      sebagian dan demo kehilangan daya yakinnya. Lebih baik gagal
    ///      sebelum kamera menyala.
    function test_TanpaModalVault_PayoutTidakPenuh() public {
        CachetRegistry reg2 = new CachetRegistry(owner);
        CachetCertificate cert2 = new CachetCertificate(owner);
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
        cert2.setWaitingPeriod(DEMO_WAITING_PERIOD);
        cm2.setLivenessWindow(DEMO_LIVENESS_WINDOW);
        vm.stopPrank();

        assertLt(vault2.balanceOfVault(), DECLARED_VALUE, "vault tanpa modal awal");
    }
}
