// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {CachetCertificate} from "../src/CachetCertificate.sol";
import {CachetVault} from "../src/CachetVault.sol";
import {ChallengeManager} from "../src/ChallengeManager.sol";
import {MockUSDT} from "../src/MockUSDT.sol";
import {ICachetCertificate} from "../src/interfaces/ICachetCertificate.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title DemoFlow — Golden Path penuh di testnet, satu perintah
///
/// @notice Skenario yang direkam untuk video (§3.1 delivery plan):
///           1. mint sertifikat ke KREATOR
///           2. kreator MENJUAL ke pembeli (NFT + coverage berpindah)
///           3. siapa pun MENGGUGAT dengan bukti
///           4. resolver MEMUTUS setelah jendela liveness
///           5. UANG mendarat di PEMBELI, bukan kreator
///
///         Babak 5 adalah pembeda #1 produk. Kalau uang mendarat di kreator,
///         seluruh premis Cachet salah.
///
/// @dev Butuh `make demo-prep` dijalankan lebih dulu (memampatkan waktu +
///      modal vault), dan dua approve manual yang butuh kunci masing-masing.
///
///      MEMBUTUHKAN GATEWAY_PK — kunci milik Person A. Person B tidak
///      memilikinya dan tidak seharusnya memilikinya. Jalankan skrip ini di
///      sesi bersama (smoke test §6 / rekaman H6), bukan sendirian.
///
///      Aman dijalankan berulang: setiap eksekusi memakai entri & sertifikat
///      BARU (phash diacak dari block.timestamp), jadi tidak bertabrakan
///      dengan sertifikat dari take sebelumnya.
contract DemoFlow is Script {
    uint256 internal constant DECLARED_VALUE = 50e6; // 50 USDT
    uint256 internal constant FRAUD_BOND = 5e6;

    /// @dev Digabung jadi struct: tanpa ini `run()` menabrak batas stack EVM.
    struct Ctx {
        MockUSDT usdt;
        CachetCertificate cert;
        CachetVault vault;
        ChallengeManager cm;
        address creator;
        address buyer;
        address challenger;
    }

    function _ctx() internal view returns (Ctx memory c) {
        c.usdt = MockUSDT(vm.envAddress("ADDR_MOCKUSDT"));
        c.cert = CachetCertificate(vm.envAddress("ADDR_CERTIFICATE"));
        c.vault = CachetVault(vm.envAddress("ADDR_VAULT"));
        c.cm = ChallengeManager(vm.envAddress("ADDR_CHALLENGE"));
        c.creator = vm.addr(vm.envUint("DEMO_CREATOR_PK"));
        c.buyer = vm.envAddress("DEMO_BUYER_ADDR");
        c.challenger = vm.addr(vm.envUint("DEMO_CHALLENGER_PK"));
    }

    function run() external {
        Ctx memory c = _ctx();
        _preflight(c);

        // ── BABAK 1: mint ke kreator ─────────────────────────────────────────
        console.log("");
        console.log("[1/5] Menerbitkan First-Seen Certificate untuk kreator...");

        uint256 premium = c.vault.quotePremium(DECLARED_VALUE);
        bytes32 seed = keccak256(abi.encodePacked(block.timestamp, block.number));

        vm.startBroadcast(vm.envUint("GATEWAY_PK"));
        (uint256 entryId, uint256 certId) = c.cert
            .registerAndMint(
                ICachetCertificate.MintRequest({
                    to: c.creator,
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
        vm.stopBroadcast();

        console.log("      entryId:", entryId, "| certId:", certId);
        console.log("      pemegang:", c.creator);
        console.log("      dijamin :", DECLARED_VALUE / 1e6, "USDT");

        // ── BABAK 2: kreator menjual ke pembeli ──────────────────────────────
        console.log("");
        console.log("[2/5] Kreator MENJUAL aset ke pembeli...");

        vm.startBroadcast(vm.envUint("DEMO_CREATOR_PK"));
        IERC721(address(c.cert)).transferFrom(c.creator, c.buyer, certId);
        vm.stopBroadcast();

        console.log("      pemegang baru :", IERC721(address(c.cert)).ownerOf(certId));
        console.log("      coverage aktif:", c.cert.isCoverageActive(certId));
        console.log("      -> jaminan IKUT PINDAH tanpa langkah tambahan");

        // ── BABAK 3: gugatan ─────────────────────────────────────────────────
        console.log("");
        console.log("[3/5] Penantang membuka gugatan dengan bukti...");

        vm.startBroadcast(vm.envUint("DEMO_CHALLENGER_PK"));
        uint256 challengeId = c.cm.challenge(certId, "ipfs://bukti-karya-lebih-tua");
        vm.stopBroadcast();

        console.log("      challengeId:", challengeId);
        console.log("      penantang  :", c.challenger);

        // ── BABAK 4: liveness + putusan ──────────────────────────────────────
        uint64 liveness = c.cm.livenessWindow();
        console.log("");
        console.log("[4/5] Menunggu jendela liveness:", liveness, "detik");
        console.log("      (jendela publik ini yang menahan resolver memutus terlalu cepat)");
        console.log("");
        console.log("      JEDA DI SINI. Jalankan lagi dengan --sig 'resolve(uint256,uint256)'");
        console.log("      setelah jendela lewat:");
        console.log("      make demo-resolve CHALLENGE_ID=%s CERT_ID=%s", challengeId, certId);

        _reportBalances(c);
    }

    /// @notice Babak 4-5 dipisah supaya jeda liveness tidak menahan satu
    ///         transaksi panjang — dan supaya rekaman bisa di-jump-cut rapi.
    function resolve(uint256 challengeId, uint256 certId) external {
        Ctx memory c = _ctx();

        uint256 buyerBefore = c.usdt.balanceOf(c.buyer);
        uint256 creatorBefore = c.usdt.balanceOf(c.creator);

        console.log("");
        console.log("[5/5] Resolver memutus: penantang MENANG...");

        vm.startBroadcast(vm.envUint("RESOLVER_PK"));
        c.cm.resolve(challengeId, true, "ipfs://putusan-resolver");
        vm.stopBroadcast();

        uint256 buyerGain = c.usdt.balanceOf(c.buyer) - buyerBefore;
        uint256 creatorGain = c.usdt.balanceOf(c.creator) - creatorBefore;

        console.log("");
        console.log("=== HASIL ===");
        console.log("PEMBELI menerima :", buyerGain / 1e6, "USDT");
        console.log("KREATOR menerima :", creatorGain / 1e6, "USDT");
        console.log("sertifikat dicabut:", c.cert.certData(certId).revoked);
        console.log("");

        // Pagar terakhir: kalau ini gagal, JANGAN dipakai untuk rekaman.
        require(buyerGain == DECLARED_VALUE, "DEMO GAGAL: pembeli tidak menerima nilai penuh");
        require(creatorGain == 0, "DEMO GAGAL: kreator seharusnya tidak menerima apa pun");

        console.log("OK -- jaminan mengikuti PEMBELI, bukan kreator.");
        console.log("Inilah pembeda utama Cachet.");

        _reportBalances(c);
    }

    /// @dev Gagal lebih awal dengan pesan yang bisa dibaca manusia, daripada
    ///      revert kriptik di tengah rekaman.
    function _preflight(Ctx memory c) internal view {
        require(
            c.cert.waitingPeriod() <= 1 hours, "Jalankan 'make demo-prep' dulu: waitingPeriod masih panjang"
        );
        require(
            c.cm.livenessWindow() <= 1 hours, "Jalankan 'make demo-prep' dulu: livenessWindow masih panjang"
        );
        require(
            c.vault.balanceOfVault() >= DECLARED_VALUE,
            "Modal vault kurang dari nilai klaim -- payout akan sebagian, demo tidak meyakinkan"
        );
        require(
            c.usdt.allowance(vm.addr(vm.envUint("GATEWAY_PK")), address(c.vault)) >= DECLARED_VALUE,
            "Gateway belum approve MockUSDT ke VAULT"
        );
        require(
            c.usdt.allowance(c.challenger, address(c.vault)) >= c.cm.challengeBond(),
            "Penantang belum approve MockUSDT ke VAULT (bukan ke ChallengeManager!)"
        );
    }

    function _reportBalances(Ctx memory c) internal view {
        console.log("--- saldo (USDT) ---");
        console.log("kreator  :", c.usdt.balanceOf(c.creator) / 1e6);
        console.log("pembeli  :", c.usdt.balanceOf(c.buyer) / 1e6);
        console.log("penantang:", c.usdt.balanceOf(c.challenger) / 1e6);
    }
}
