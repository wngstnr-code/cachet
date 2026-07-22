// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {CachetCertificate} from "../src/CachetCertificate.sol";
import {CachetVault} from "../src/CachetVault.sol";
import {ChallengeManager} from "../src/ChallengeManager.sol";
import {MockUSDT} from "../src/MockUSDT.sol";

/// @title PrepareDemo — memampatkan waktu & menyiapkan dana. Dijalankan SEKALI.
///
/// @notice Kenapa ini perlu: `waitingPeriod` 72 jam dan `livenessWindow` 48 jam
///         ditegakkan on-chain secara sungguhan (invariant §9.4). Tanpa
///         dimampatkan, skenario demo baru bisa selesai lima hari kemudian.
///
/// @dev SIKAP JUJUR ATAS PEMAMPATAN INI:
///
///      Yang dimampatkan hanya ANGKA, bukan aturan main. Setiap perubahan
///      memancarkan `ParamChanged` sehingga tercatat publik di explorer —
///      siapa pun bisa melihat persis parameter apa yang dipakai saat demo
///      direkam. Tidak ada yang disembunyikan.
///
///      KEDUA mekanisme tetap HIDUP, hanya dipercepat — tidak ada yang
///      dimatikan. Ini keputusan sadar: menyetel `waitingPeriod` ke nol akan
///      mempertunjukkan "mint lalu langsung dijamin", padahal produknya tidak
///      bekerja begitu. Penonton harus melihat mekanisme yang sebenarnya.
///
///      Di video, jeda ~40 detik ini DIPERCEPAT (time-lapse), bukan dipotong.
///      Mempercepat menunjukkan; memotong menyembunyikan.
///
///      Biayanya nol: masa tunggu berjalan BERSAMAAN dengan jendela liveness,
///      bukan berurutan. Saat liveness 30 detik habis, masa tunggu 10 detik
///      sudah lama lewat.
///        t=0   mint      -> coverage mulai t+10
///        t=~10 gugatan   -> liveness sampai t+40
///        t=40  resolve   -> 40 > 10, coverage sudah aktif
contract PrepareDemo is Script {
    uint64 internal constant DEMO_WAITING_PERIOD = 10 seconds;
    uint64 internal constant DEMO_LIVENESS_WINDOW = 30 seconds;

    /// @dev Modal awal vault. Tanpa ini klaim pertama hanya terbayar sebagian:
    ///      premi 2% berarti butuh ~50 sertifikat untuk menutup satu klaim.
    uint256 internal constant SEED_CAPITAL = 500e6; // 500 USDT
    uint256 internal constant ACTOR_FUNDING = 200e6; // per pemeran

    function run() external {
        uint256 deployerPk = vm.envUint("DEPLOYER_PK");
        address deployer = vm.addr(deployerPk);

        MockUSDT usdt = MockUSDT(vm.envAddress("ADDR_MOCKUSDT"));
        CachetCertificate cert = CachetCertificate(vm.envAddress("ADDR_CERTIFICATE"));
        CachetVault vault = CachetVault(vm.envAddress("ADDR_VAULT"));
        ChallengeManager cm = ChallengeManager(vm.envAddress("ADDR_CHALLENGE"));

        address gateway = vm.envAddress("GATEWAY_ADDR");
        address challenger = vm.envAddress("DEMO_CHALLENGER_ADDR");

        vm.startBroadcast(deployerPk);

        // 1. Mampatkan waktu (tercatat publik lewat ParamChanged).
        if (cert.waitingPeriod() != DEMO_WAITING_PERIOD) {
            cert.setWaitingPeriod(DEMO_WAITING_PERIOD);
        }
        if (cm.livenessWindow() != DEMO_LIVENESS_WINDOW) {
            cm.setLivenessWindow(DEMO_LIVENESS_WINDOW);
        }

        // 2. Cetak token untuk semua pemeran. Faucet MockUSDT terbuka publik.
        usdt.mint(deployer, SEED_CAPITAL);
        usdt.mint(gateway, ACTOR_FUNDING); // membayar bond + premi tiap mint
        usdt.mint(challenger, ACTOR_FUNDING); // membayar challenge bond

        // 3. Modal awal vault. Uang ini TIDAK BISA ditarik kembali — tidak ada
        //    fungsi withdraw, termasuk untuk owner. Itu yang membuat kata
        //    "collateralized" berarti sesuatu.
        usdt.approve(address(vault), SEED_CAPITAL);
        vault.fund(SEED_CAPITAL);

        vm.stopBroadcast();

        console.log("");
        console.log("=== DEMO PREP DONE ===");
        console.log("waitingPeriod  :", cert.waitingPeriod(), "seconds");
        console.log("livenessWindow :", cm.livenessWindow(), "seconds");
        console.log("vault balance  :", vault.balanceOfVault() / 1e6, "USDT");
        console.log("");
        console.log("STILL NEEDED MANUALLY (each requires its own key):");
        console.log("1. gateway approves MockUSDT to the vault:");
        console.log("   cast send", address(usdt));
        console.log("     'approve(address,uint256)'", address(vault));
        console.log("     <large amount> --private-key $GATEWAY_PK");
        console.log("2. challenger approves MockUSDT to the vault (not to ChallengeManager!)");
        console.log("");
        console.log("Then run: make demo");
    }
}
