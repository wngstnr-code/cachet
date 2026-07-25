// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {CachetRegistry} from "../src/CachetRegistry.sol";
import {CachetCertificate} from "../src/CachetCertificate.sol";
import {CachetVault} from "../src/CachetVault.sol";
import {ChallengeManager} from "../src/ChallengeManager.sol";

/// @notice Deploy + wiring keempat kontrak inti ke X Layer (1952 testnet / 196 mainnet).
/// @dev Jalankan lewat `make deploy` supaya .env root terbaca dan verifikasi
///      Sourcify ikut jalan.
///
///      Deploy dianggap GAGAL bila ada satu setter pun yang belum terpanggil.
///      Assert di akhir bukan hiasan: wiring yang tertinggal separuh
///      menghasilkan error runtime yang membingungkan (mis. `NotGateway`
///      dengan alamat nol) berjam-jam setelah deploy dianggap sukses.
contract Deploy is Script {
    uint256 internal constant XLAYER_TESTNET = 1952;
    uint256 internal constant XLAYER_MAINNET = 196;

    /// @dev Seluruh angka Cachet (`MAX_DECLARED_VALUE = 100e6`, bond `5e6`/`10e6`,
    ///      premi `declaredValue * 200 / 10000`) mengasumsikan payToken 6 desimal.
    ///      Token 18 desimal tetap ter-deploy dan ter-wiring tanpa keluhan, lalu
    ///      salah seribu miliar kali secara diam-diam saat runtime.
    uint8 internal constant REQUIRED_PAY_TOKEN_DECIMALS = 6;

    function run() external {
        require(
            block.chainid == XLAYER_TESTNET || block.chainid == XLAYER_MAINNET,
            "Deploy: hanya X Layer (1952 testnet / 196 mainnet)"
        );

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

        // payToken salah = seluruh sistem salah, dan gejalanya baru muncul saat
        // klaim pertama. Dicek SEBELUM broadcast supaya gagalnya gratis.
        _assertPayToken(payTokenAddr);
        _assertResolver(resolverAddr);

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

    /// @dev Pagar payToken. Di mainnet ADDR_MOCKUSDT diisi USDT ASLI — tidak ada
    ///      MockUSDT yang boleh ter-deploy ke 196 (lihat DeployMockUSDT.s.sol).
    ///      Yang diperiksa di sini bukan "apakah ini USDT yang benar" (itu tidak
    ///      bisa dibuktikan dari dalam kontrak), melainkan dua hal yang bisa:
    ///      alamatnya memang kontrak, dan desimalnya 6.
    function _assertPayToken(address payTokenAddr) internal view {
        require(payTokenAddr.code.length > 0, "ADDR_MOCKUSDT bukan kontrak di chain ini");

        uint8 dec = IERC20Metadata(payTokenAddr).decimals();
        require(dec == REQUIRED_PAY_TOKEN_DECIMALS, "payToken wajib 6 desimal (lihat README)");
    }

    /// @dev Di mainnet resolver WAJIB kontrak (multisig), bukan EOA.
    ///
    ///      `ChallengeManager.setResolver` bersifat set-once: identitas pemutus
    ///      terkunci sejak deploy dan tidak bisa diganti tanpa redeploy seluruh
    ///      sistem (risiko C1 di README). Artinya EOA yang salah ter-paste bukan
    ///      kesalahan yang bisa diperbaiki lima menit kemudian -- ia permanen,
    ///      dan satu kunci yang bocor atau hilang mematikan seluruh jalur gugatan
    ///      untuk selamanya.
    ///
    ///      Yang bisa diperiksa dari sini hanya "ada bytecode di alamat itu",
    ///      bukan "ini benar Safe dengan threshold 2-dari-3". Sisanya tanggung
    ///      jawab operator -- lihat RESOLVER.md. Pagar ini menangkap kesalahan
    ///      yang paling mungkin dan paling mahal, bukan seluruhnya.
    ///
    ///      Testnet tetap boleh EOA: demo butuh resolver yang bisa menandatangani
    ///      sendiri tanpa koordinasi dua orang di tengah rekaman.
    function _assertResolver(address resolverAddr) internal view {
        bool isContract = resolverAddr.code.length > 0;

        if (block.chainid == XLAYER_MAINNET) {
            require(isContract, "RESOLVER_ADDR wajib multisig (kontrak) di mainnet, bukan EOA");
            console.log("resolver: kontrak (multisig) -- OK untuk mainnet");
        } else {
            console.log("resolver: EOA -- diizinkan di testnet saja");
        }
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
    ) internal view {
        console.log("");
        console.log("=== ALAMAT (salin ke .env root + packages/contracts-abi) ===");
        console.log("chainId         =", block.chainid);
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
