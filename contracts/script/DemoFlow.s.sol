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
        console.log("[1/5] Issuing a First-Seen Certificate to the CREATOR...");

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
        console.log("      holder :", c.creator);
        console.log("      covered:", DECLARED_VALUE / 1e6, "USDT");

        // ── BABAK 2: kreator menjual ke pembeli ──────────────────────────────
        console.log("");
        console.log("[2/5] Creator SELLS the asset to a buyer...");

        vm.startBroadcast(vm.envUint("DEMO_CREATOR_PK"));
        IERC721(address(c.cert)).transferFrom(c.creator, c.buyer, certId);
        vm.stopBroadcast();

        console.log("      new holder :", IERC721(address(c.cert)).ownerOf(certId));
        console.log("      -> the guarantee MOVES WITH the asset, no extra steps");
        console.log("");

        // Masa tunggu SENGAJA tetap hidup di demo (dipercepat, bukan dimatikan).
        // Kalau di detik ini coverage belum aktif, itu bukan kegagalan --
        // itu mekanismenya sedang bekerja, dan penonton harus melihatnya.
        ICachetCertificate.CertData memory d = c.cert.certData(certId);
        if (c.cert.isCoverageActive(certId)) {
            console.log("      coverage: ACTIVE");
        } else {
            console.log("      coverage: NOT ACTIVE YET -- still in the waiting period");
            console.log("      becomes active at timestamp:", d.coverageStart);
            console.log("      (the waiting period blocks claims on works minted");
            console.log("       precisely because the dispute was already known)");
        }

        // G2: kelayakan klaim dinilai saat gugatan DIBUKA. Gugatan yang dibuka
        // selama masa tunggu berakhir tanpa payout — jadi babak 3 dipisah jadi
        // fase sendiri, dijalankan SETELAH coverage menyala (~10 detik).
        console.log("");
        console.log("PAUSE HERE until coverage is active (timestamp above), then run:");
        console.log("  make demo-challenge CERT_ID=%s", certId);

        _reportBalances(c);
    }

    /// @notice BABAK 3: gugatan. Fase terpisah karena G2 — coverage harus
    ///         sudah menyala saat gugatan dibuka; kalau tidak, klaim babak 5
    ///         akan dilewati (`ClaimSkippedNoCoverage`) dan demo gagal.
    function challengeCert(uint256 certId) external {
        Ctx memory c = _ctx();

        // Tolak dini dengan alasan yang bisa dibaca, bukan demo yang diam-diam
        // berakhir tanpa payout 40 detik kemudian. Tiga kasus dibedakan supaya
        // pesannya tepat — dan supaya `coverageStart - block.timestamp` tidak
        // underflow saat coverage sudah lewat mulainya (cert revoked/expired).
        ICachetCertificate.CertData memory d = c.cert.certData(certId);
        if (!c.cert.isCoverageActive(certId)) {
            if (d.revoked) {
                console.log("cert is REVOKED -- it already lost a challenge.");
                console.log("Run 'make demo' again to mint a FRESH cert, then challenge that one.");
            } else if (block.timestamp < d.coverageStart) {
                console.log("coverage NOT active yet. Wait", d.coverageStart - block.timestamp, "more seconds.");
            } else {
                console.log("coverage window already ENDED at", d.coverageEnd);
            }
            revert("Coverage not active -- challenging now would forfeit the claim (G2)");
        }

        console.log("");
        console.log("[3/5] Challenger opens a challenge with evidence...");
        console.log("      coverage: ACTIVE since", d.coverageStart, "-- the claim is assessed at THIS moment");

        vm.startBroadcast(vm.envUint("DEMO_CHALLENGER_PK"));
        uint256 challengeId = c.cm.challenge(certId, "ipfs://evidence-earlier-work");
        vm.stopBroadcast();

        console.log("      challengeId:", challengeId);
        console.log("      challenger :", c.challenger);

        // ── BABAK 4: liveness + putusan ──────────────────────────────────────
        uint64 liveness = c.cm.livenessWindow();
        console.log("");
        console.log("[4/5] Waiting out the liveness window:", liveness, "seconds");
        console.log("      (this public window is what stops the resolver from ruling too fast)");
        console.log("");
        console.log("      PAUSE HERE. Once the window has passed:");
        console.log("      make demo-resolve CHALLENGE_ID=%s CERT_ID=%s", challengeId, certId);

        _reportBalances(c);
    }

    /// @notice Babak 4-5 dipisah supaya jeda liveness tidak menahan satu
    ///         transaksi panjang — dan supaya rekaman bisa di-jump-cut rapi.
    function resolve(uint256 challengeId, uint256 certId) external {
        Ctx memory c = _ctx();

        _preflightResolve(c, challengeId, certId);

        uint256 buyerBefore = c.usdt.balanceOf(c.buyer);
        uint256 creatorBefore = c.usdt.balanceOf(c.creator);
        uint256 challengerBefore = c.usdt.balanceOf(c.challenger);
        uint256 vaultBefore = c.vault.balanceOfVault();

        console.log("");
        console.log("[5/5] Resolver rules: the challenger WINS...");

        vm.startBroadcast(vm.envUint("RESOLVER_PK"));
        c.cm.resolve(challengeId, true, "ipfs://resolver-ruling");
        vm.stopBroadcast();

        uint256 buyerGain = c.usdt.balanceOf(c.buyer) - buyerBefore;
        uint256 creatorGain = c.usdt.balanceOf(c.creator) - creatorBefore;

        console.log("");
        console.log("=== WHERE THE MONEY WENT ===");
        console.log("From the collateral pool (vault):");
        console.log("  balance before:", vaultBefore / 1e6, "USDT");
        console.log("  balance after :", c.vault.balanceOfVault() / 1e6, "USDT");
        console.log("");
        console.log("Destinations:");
        console.log("  BUYER     (current asset holder) :", buyerGain / 1e6, "USDT  <-- the claim");
        console.log(
            "  CHALLENGER (who proved it)       :",
            (c.usdt.balanceOf(c.challenger) - challengerBefore) / 1e6,
            "USDT  <-- bond back + bounty"
        );
        console.log(
            "  CREATOR   (who issued it)        :", creatorGain / 1e6, "USDT  <-- ZERO, their bond was slashed"
        );
        console.log("");
        console.log("Certificate status:");
        console.log("  permanently revoked:", c.cert.certData(certId).revoked);
        console.log("  NFT holder         :", IERC721(address(c.cert)).ownerOf(certId));
        console.log("  (the NFT is NOT burned -- it remains as a public record)");
        console.log("");

        // Pagar terakhir: kalau ini gagal, JANGAN dipakai untuk rekaman.
        require(buyerGain == DECLARED_VALUE, "DEMO FAILED: buyer did not receive the full covered value");
        require(creatorGain == 0, "DEMO FAILED: creator should have received nothing");

        console.log("OK -- the guarantee followed the BUYER, not the creator.");
        console.log("This is Cachet's core differentiator.");

        _reportBalances(c);
    }

    /// @dev Menampilkan momen coverage MENYALA — transisi ini yang membuat
    ///      masa tunggu terlihat sebagai mekanisme, bukan sekadar angka di
    ///      dokumen. Tanpa ini, video melompat dari "belum aktif" langsung ke
    ///      payout, dan penonton tidak pernah melihat jaminan itu hidup.
    ///
    ///      Sekaligus menolak resolve yang terlalu dini dengan sisa detik yang
    ///      bisa dibaca, alih-alih revert kriptik di tengah rekaman.
    function _preflightResolve(Ctx memory c, uint256 challengeId, uint256 certId) internal view {
        ICachetCertificate.CertData memory d = c.cert.certData(certId);
        (,, uint64 openedAt,,) = c.cm.getChallenge(challengeId);

        console.log("");
        console.log("--- status before ruling ---");
        // G2: kelayakan dinilai pada saat gugatan DIBUKA, bukan saat resolve.
        if (openedAt >= d.coverageStart && openedAt <= d.coverageEnd) {
            console.log("coverage: IN FORCE when the challenge was opened (", openedAt, ")");
            console.log("          the claim pays out even if resolve happens past coverageEnd");
        } else {
            console.log("coverage: NOT in force when the challenge was opened. Claim will be SKIPPED.");
            console.log("          window :", d.coverageStart, "-", d.coverageEnd);
            console.log("          opened :", openedAt);
        }
        uint64 earliestResolve = openedAt + c.cm.livenessWindow();
        if (block.timestamp < earliestResolve) {
            console.log("");
            console.log("liveness window not over yet. Wait", earliestResolve - block.timestamp, "more seconds.");
            revert("Liveness window still open -- see remaining seconds above");
        }
        console.log("liveness : PASSED (opened at", openedAt, ")");
    }

    /// @dev Gagal lebih awal dengan pesan yang bisa dibaca manusia, daripada
    ///      revert kriptik di tengah rekaman.
    function _preflight(Ctx memory c) internal view {
        require(
            c.cert.waitingPeriod() <= 1 hours, "Run 'make demo-prep' first: waitingPeriod is still long"
        );
        require(
            c.cm.livenessWindow() <= 1 hours, "Run 'make demo-prep' first: livenessWindow is still long"
        );
        require(
            c.vault.balanceOfVault() >= DECLARED_VALUE,
            "Vault capital is below the claim value -- payout would be partial, demo unconvincing"
        );
        require(
            c.usdt.allowance(vm.addr(vm.envUint("GATEWAY_PK")), address(c.vault)) >= DECLARED_VALUE,
            "Gateway has not approved MockUSDT to the VAULT"
        );
        require(
            c.usdt.allowance(c.challenger, address(c.vault)) >= c.cm.challengeBond(),
            "Challenger has not approved MockUSDT to the VAULT (not to ChallengeManager!)"
        );
    }

    function _reportBalances(Ctx memory c) internal view {
        console.log("--- balances (USDT) ---");
        console.log("creator   :", c.usdt.balanceOf(c.creator) / 1e6);
        console.log("buyer     :", c.usdt.balanceOf(c.buyer) / 1e6);
        console.log("challenger:", c.usdt.balanceOf(c.challenger) / 1e6);
    }
}
