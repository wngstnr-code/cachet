// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {CachetCertificate} from "../src/CachetCertificate.sol";
import {CachetVault} from "../src/CachetVault.sol";
import {ChallengeManager} from "../src/ChallengeManager.sol";

/// @title SetMainnetParams — turunkan plafon ke ukuran modal yang benar-benar ada
///
/// @notice Default kontrak (`maxDeclaredValue` 100 USDT, `fraudBondAmount` 5 USDT,
///         `challengeBond` 10 USDT) mengasumsikan vault bermodal ratusan USDT.
///         Bootstrap mainnet Cachet dimulai dengan 5 USDT total, jadi angka itu
///         harus diturunkan SEBELUM sertifikat pertama diterbitkan.
///
/// @dev KENAPA INI PENTING, BUKAN SEKADAR TUNING:
///
///      Vault yang menjamin 100 USDT tapi hanya berisi 2 USDT tidak revert — ia
///      membayar sebagian lalu memancarkan `PartialPayout` (invariant §9.3,
///      disengaja supaya klaim tidak pernah terkunci). Artinya kontraknya tetap
///      jujur, tapi ANGKA YANG DIIKLANKAN jadi bohong: pemegang sertifikat
///      mengira dijamin 100 USDT padahal maksimal menerima 2.
///
///      Menurunkan plafon membuat yang diiklankan sama dengan yang benar-benar
///      bisa dibayar. Plafon kecil bukan kelemahan; plafon yang tidak didanai
///      itu yang merusak klaim produk.
///
///      Setiap perubahan memancarkan `ParamChanged` — publik bisa melihat persis
///      parameter apa yang berlaku, kapan berubah. Tidak ada yang disembunyikan.
///
///      SEMUA ANGKA DI SINI ADALAH LANTAI ATAU MENDEKATI LANTAI:
///        fraudBondAmount 1 USDT  = MIN_FRAUD_BOND     (tidak bisa lebih rendah)
///        challengeBond   1 USDT  = MIN_CHALLENGE_BOND (tidak bisa lebih rendah)
///      Konsekuensi jujur: menjamin 2 USDT menuntut bond 1 USDT (rasio 50%).
///      Secara komersial tidak masuk akal, secara mekanis sah. Ini konfigurasi
///      bootstrap/demo — jangan dipresentasikan sebagai angka produksi.
///
///      Jalankan SETELAH `make deploy`, ditandatangani DEPLOYER_PK (pemilik
///      kontrak). Aman diulang: setter dilewati kalau nilainya sudah benar.
contract SetMainnetParams is Script {
    uint256 internal constant XLAYER_MAINNET = 196;

    /// @dev Plafon klaim per sertifikat. Vault WAJIB berisi minimal sebesar ini,
    ///      kalau tidak klaim penuh pertama pun sudah jadi PartialPayout.
    uint256 internal constant MAX_DECLARED_VALUE = 2e6; // 2 USDT

    uint256 internal constant FRAUD_BOND = 1e6; // 1 USDT — lantai kontrak
    uint256 internal constant CHALLENGE_BOND = 1e6; // 1 USDT — lantai kontrak

    /// @dev 2% dipertahankan: inilah yang menumbuhkan vault dari pemakaian,
    ///      bukan dari setoran tambahan.
    uint256 internal constant PREMIUM_BPS = 200;

    function run() external {
        require(block.chainid == XLAYER_MAINNET, "SetMainnetParams: hanya X Layer Mainnet (196)");

        uint256 pk = vm.envUint("DEPLOYER_PK");

        CachetCertificate cert = CachetCertificate(vm.envAddress("ADDR_CERTIFICATE"));
        CachetVault vault = CachetVault(vm.envAddress("ADDR_VAULT"));
        ChallengeManager cm = ChallengeManager(vm.envAddress("ADDR_CHALLENGE"));

        vm.startBroadcast(pk);

        if (cert.maxDeclaredValue() != MAX_DECLARED_VALUE) {
            cert.setMaxDeclaredValue(MAX_DECLARED_VALUE);
        }
        if (vault.fraudBondAmount() != FRAUD_BOND) {
            vault.setFraudBondAmount(FRAUD_BOND);
        }
        if (cm.challengeBond() != CHALLENGE_BOND) {
            cm.setChallengeBond(CHALLENGE_BOND);
        }
        if (vault.premiumBps() != PREMIUM_BPS) {
            vault.setPremiumBps(PREMIUM_BPS);
        }

        vm.stopBroadcast();

        _report(cert, vault, cm);
    }

    function _report(CachetCertificate cert, CachetVault vault, ChallengeManager cm) internal view {
        uint256 cap = cert.maxDeclaredValue();
        uint256 vaultBal = vault.balanceOfVault();

        console.log("");
        console.log("=== PARAMETER MAINNET AKTIF ===");
        console.log("maxDeclaredValue :", cap, "(6 desimal)");
        console.log("fraudBondAmount  :", vault.fraudBondAmount());
        console.log("challengeBond    :", cm.challengeBond());
        console.log("premiumBps       :", vault.premiumBps());
        console.log("waitingPeriod    :", cert.waitingPeriod(), "detik");
        console.log("livenessWindow   :", cm.livenessWindow(), "detik");
        console.log("");
        console.log("saldo vault      :", vaultBal);

        // Peringatan, bukan revert: menyetel parameter sebelum menyetor modal
        // adalah urutan yang wajar. Yang tidak boleh adalah MENERBITKAN
        // sertifikat saat vault masih di bawah plafon.
        if (vaultBal < cap) {
            console.log("");
            console.log("!! VAULT DI BAWAH PLAFON.");
            console.log("!! Klaim penuh pertama akan jadi PartialPayout.");
            console.log("!! Setor modal sampai >= maxDeclaredValue SEBELUM mint pertama.");
        } else {
            console.log("OK: vault sanggup membayar minimal satu klaim penuh.");
        }

        console.log("");
        console.log("JANGAN LUPA: perbarui angka coverage di README, listing ASP,");
        console.log("dan deskripsi service supaya cocok dengan plafon di atas.");
    }
}
