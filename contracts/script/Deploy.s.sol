// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {CachetRegistry} from "../src/CachetRegistry.sol";
import {CachetCertificate} from "../src/CachetCertificate.sol";
import {CachetVault} from "../src/CachetVault.sol";
import {ChallengeManager} from "../src/ChallengeManager.sol";

/// @notice Deploy + wiring keempat kontrak inti ke X Layer Testnet (1952).
/// @dev Jalankan lewat `make deploy` supaya .env root terbaca dan verifikasi
///      Sourcify ikut jalan.
///
///      Deploy dianggap GAGAL bila ada satu setter pun yang belum terpanggil.
///      Assert di akhir bukan hiasan: wiring yang tertinggal separuh
///      menghasilkan error runtime yang membingungkan (mis. `NotGateway`
///      dengan alamat nol) berjam-jam setelah deploy dianggap sukses.
contract Deploy is Script {
    uint256 internal constant XLAYER_TESTNET = 1952;

    function run() external {
        require(block.chainid == XLAYER_TESTNET, "Deploy: hanya X Layer Testnet (1952)");

        uint256 pk = vm.envUint("DEPLOYER_PK");
        address deployer = vm.addr(pk);

        address payTokenAddr = vm.envAddress("ADDR_MOCKUSDT");
        address gatewayAddr = vm.envAddress("GATEWAY_ADDR");
        address resolverAddr = vm.envAddress("RESOLVER_ADDR");

        // Invariant §9.6: tiga peran, tiga kunci berbeda. Kalau ini dilanggar,
        // pembuktian "hanya gateway yang bisa mint" jadi tidak berarti apa-apa.
        require(gatewayAddr != deployer, "GATEWAY_ADDR tidak boleh sama dengan deployer (sec 9.6)");
        require(resolverAddr != deployer, "RESOLVER_ADDR tidak boleh sama dengan deployer (sec 9.6)");
        require(resolverAddr != gatewayAddr, "RESOLVER_ADDR tidak boleh sama dengan GATEWAY_ADDR (sec 9.6)");

        vm.startBroadcast(pk);

        // URUTAN PENTING: Vault menyimpan alamat Certificate secara immutable,
        // jadi Certificate wajib ter-deploy lebih dulu. Certificate sendiri
        // tidak butuh Vault saat konstruksi (di-set belakangan).
        CachetRegistry registry = new CachetRegistry(deployer);
        CachetCertificate certificate = new CachetCertificate(deployer);
        CachetVault vault = new CachetVault(deployer, payTokenAddr, address(certificate));
        ChallengeManager challengeManager = new ChallengeManager(deployer);

        // ── Wiring (§3.1) ───────────────────────────────────────────────────
        // Gateway Registry = alamat KONTRAK Certificate, bukan wallet gateway.
        // `registerAndMint` yang memanggil `register` di dalam satu tx atomik.
        registry.setGateway(address(certificate));

        certificate.setGateway(gatewayAddr);
        certificate.setChallengeManager(address(challengeManager));
        certificate.setRegistry(address(registry));
        certificate.setVault(address(vault));

        vault.setChallengeManager(address(challengeManager));

        challengeManager.setResolver(resolverAddr);
        challengeManager.setCertificate(address(certificate));
        challengeManager.setVault(address(vault));

        vm.stopBroadcast();

        _assertWiring(registry, certificate, vault, challengeManager, gatewayAddr, resolverAddr, payTokenAddr);
        _log(registry, certificate, vault, challengeManager);
    }

    /// @dev Setiap tautan diperiksa. Gagal di sini = deploy tidak boleh dipakai.
    function _assertWiring(
        CachetRegistry registry,
        CachetCertificate certificate,
        CachetVault vault,
        ChallengeManager challengeManager,
        address gatewayAddr,
        address resolverAddr,
        address payTokenAddr
    ) internal view {
        require(registry.gateway() == address(certificate), "wiring: registry.gateway");

        require(certificate.gateway() == gatewayAddr, "wiring: certificate.gateway");
        require(certificate.challengeManager() == address(challengeManager), "wiring: certificate.cm");
        require(address(certificate.registry()) == address(registry), "wiring: certificate.registry");
        require(address(certificate.vault()) == address(vault), "wiring: certificate.vault");

        require(vault.certificate() == address(certificate), "wiring: vault.certificate");
        require(vault.challengeManager() == address(challengeManager), "wiring: vault.cm");
        require(vault.payToken() == payTokenAddr, "wiring: vault.payToken");

        require(challengeManager.resolver() == resolverAddr, "wiring: cm.resolver");
        require(address(challengeManager.certificate()) == address(certificate), "wiring: cm.certificate");
        require(address(challengeManager.vault()) == address(vault), "wiring: cm.vault");
    }

    function _log(
        CachetRegistry registry,
        CachetCertificate certificate,
        CachetVault vault,
        ChallengeManager challengeManager
    ) internal pure {
        console.log("");
        console.log("=== ALAMAT (salin ke .env root + packages/contracts-abi) ===");
        console.log("ADDR_REGISTRY   =", address(registry));
        console.log("ADDR_CERTIFICATE=", address(certificate));
        console.log("ADDR_VAULT      =", address(vault));
        console.log("ADDR_CHALLENGE  =", address(challengeManager));
        console.log("");
        console.log("Wiring lengkap & terverifikasi.");
        console.log("");
        console.log("LANGKAH BERIKUTNYA:");
        console.log("1. Gateway approve MockUSDT ke ADDR_VAULT (allowance besar)");
        console.log("2. Setor modal awal: MockUSDT.approve(vault) lalu vault.fund(...)");
        console.log("   -- tanpa modal, klaim pertama hanya terbayar sebagian");
    }
}
