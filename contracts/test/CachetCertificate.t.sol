// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CachetCertificate} from "../src/CachetCertificate.sol";
import {CachetRegistry} from "../src/CachetRegistry.sol";
import {ICachetCertificate} from "../src/interfaces/ICachetCertificate.sol";
import {CachetGoverned} from "../src/base/CachetGoverned.sol";
import {MockVault} from "./mocks/MockVault.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";

contract CachetCertificateTest is Test {
    CachetCertificate internal cert;
    CachetRegistry internal reg;
    MockVault internal vault;

    address internal owner = makeAddr("owner");
    address internal gateway = makeAddr("gatewayWallet");
    address internal challengeManager = makeAddr("challengeManager");
    address internal creator = makeAddr("creator");
    address internal buyer = makeAddr("buyer");
    address internal stranger = makeAddr("stranger");

    bytes32[4] internal phashes;

    uint256 internal constant DECLARED = 50e6; // 50 USDT
    uint256 internal constant FRAUD_BOND = 5e6;
    uint256 internal constant PREMIUM = 1e6; // 2% dari 50

    function setUp() public {
        reg = new CachetRegistry(owner);
        cert = new CachetCertificate(owner);
        vault = new MockVault();

        vm.startPrank(owner);
        // Gateway Registry = alamat KONTRAK Certificate (RFC-001 P1), bukan wallet.
        reg.setGateway(address(cert));
        cert.setGateway(gateway);
        cert.setChallengeManager(challengeManager);
        cert.setRegistry(address(reg));
        cert.setVault(address(vault));
        vm.stopPrank();

        phashes = [keccak256("p0"), keccak256("p1"), keccak256("p2"), keccak256("p3")];
    }

    function _req(address to, uint256 declaredValue, bool insurable)
        internal
        view
        returns (ICachetCertificate.MintRequest memory)
    {
        return ICachetCertificate.MintRequest({
            to: to,
            phashes: phashes,
            embCommit: keccak256("emb"),
            revealedCommit: bytes32(0),
            assetURI: "ipfs://asset",
            tokenURI_: "ipfs://meta",
            declaredValue: declaredValue,
            fraudBond: FRAUD_BOND,
            premium: PREMIUM,
            insurable: insurable
        });
    }

    function _mint(address to) internal returns (uint256 entryId, uint256 certId) {
        vm.prank(gateway);
        return cert.registerAndMint(_req(to, DECLARED, true));
    }

    // ═════════════════════════════════════════════════════════════════════════
    // COVERAGE IKUT PEMBELI — klaim inti produk
    // ═════════════════════════════════════════════════════════════════════════

    /// @notice INI TEST TERPENTING DI SELURUH REPO.
    ///         Pembeda utama Cachet: kalau aset dijual, jaminan ikut pembeli.
    ///         Kalau test ini gagal, produknya kehilangan alasan untuk ada.
    function test_TransferNFT_CoverageIkutPemegangBaru() public {
        (, uint256 certId) = _mint(creator);
        vm.warp(block.timestamp + 73 hours); // lewati waiting period

        assertEq(cert.ownerOf(certId), creator);
        assertTrue(cert.isCoverageActive(certId));

        vm.prank(creator);
        cert.transferFrom(creator, buyer, certId);

        assertEq(cert.ownerOf(certId), buyer, "NFT harus pindah");
        assertTrue(cert.isCoverageActive(certId), "coverage HARUS tetap aktif setelah transfer");

        ICachetCertificate.CertData memory d = cert.certData(certId);
        assertEq(d.declaredValue, DECLARED, "nilai jaminan tidak boleh berubah karena transfer");
        assertEq(d.coverageEnd, cert.certData(certId).coverageEnd, "jendela coverage tidak reset");
    }

    function test_TokenTidakSoulbound_TransferTidakDibatasi() public {
        (, uint256 certId) = _mint(creator);

        vm.prank(creator);
        cert.transferFrom(creator, buyer, certId);
        vm.prank(buyer);
        cert.transferFrom(buyer, stranger, certId);

        assertEq(cert.ownerOf(certId), stranger, "transfer berantai harus bebas");
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ATOMICITY (RFC-001 P1 & P8)
    // ═════════════════════════════════════════════════════════════════════════

    function test_RegisterAndMint_SatuTxMenghasilkanEntriDanSertifikat() public {
        (uint256 entryId, uint256 certId) = _mint(creator);

        assertEq(entryId, 1);
        assertEq(certId, 1);
        assertEq(reg.entryCount(), 1);
        assertEq(cert.ownerOf(certId), creator);
        assertEq(cert.tokenURI(certId), "ipfs://meta");

        (,, address c,,,) = reg.getEntry(entryId);
        assertEq(c, creator, "creator di registry = penerima sertifikat");
    }

    function test_RegisterAndMint_MemanggilVaultDenganArgumenBenar() public {
        (, uint256 certId) = _mint(creator);

        assertEq(vault.callCount(), 1);
        MockVault.CollectCall memory call = vault.lastCall();
        assertEq(call.certId, certId, "certId harus SUDAH ADA saat collectOnMint dipanggil");
        assertEq(call.payer, gateway, "payer = wallet gateway, bukan kreator");
        assertEq(call.fraudBond, FRAUD_BOND);
        assertEq(call.premium, PREMIUM);
    }

    /// @dev Ini yang membuktikan RFC-001 P8 selesai: kalau tarikan dana gagal
    ///      (mis. allowance kurang), TIDAK boleh ada entri yatim di registry.
    function test_VaultGagal_SeluruhTxRevert_TidakAdaEntriYatim() public {
        vault.setShouldFail(true);

        vm.expectRevert(MockVault.MockVaultForcedFailure.selector);
        vm.prank(gateway);
        cert.registerAndMint(_req(creator, DECLARED, true));

        assertEq(reg.entryCount(), 0, "registry tidak boleh punya entri yatim");
        assertEq(cert.certCount(), 0, "tidak boleh ada sertifikat tanpa bond");
    }

    function test_PlafonDilampaui_RevertSebelumMenyentuhRegistry() public {
        uint256 tooMuch = cert.maxDeclaredValue() + 1;

        vm.expectRevert(
            abi.encodeWithSelector(
                CachetCertificate.DeclaredValueTooHigh.selector, tooMuch, cert.maxDeclaredValue()
            )
        );
        vm.prank(gateway);
        cert.registerAndMint(_req(creator, tooMuch, true));

        assertEq(reg.entryCount(), 0, "cek plafon harus terjadi SEBELUM register");
    }

    function test_RevertWhen_BelumDiWiring() public {
        CachetCertificate fresh = new CachetCertificate(owner);
        vm.prank(owner);
        fresh.setGateway(gateway);

        vm.expectRevert(abi.encodeWithSelector(CachetCertificate.NotWired.selector, "registry"));
        vm.prank(gateway);
        fresh.registerAndMint(_req(creator, DECLARED, true));
    }

    // ═════════════════════════════════════════════════════════════════════════
    // KONTROL AKSES (invariant §9.2)
    // ═════════════════════════════════════════════════════════════════════════

    function test_RevertWhen_NonGatewayMint() public {
        vm.expectRevert(abi.encodeWithSelector(CachetCertificate.NotGateway.selector, stranger, gateway));
        vm.prank(stranger);
        cert.registerAndMint(_req(creator, DECLARED, true));
    }

    function test_RevertWhen_OwnerMint() public {
        vm.expectRevert(abi.encodeWithSelector(CachetCertificate.NotGateway.selector, owner, gateway));
        vm.prank(owner);
        cert.registerAndMint(_req(creator, DECLARED, true));
    }

    function test_RevertWhen_NonChallengeManagerRevoke() public {
        (, uint256 certId) = _mint(creator);

        vm.expectRevert(
            abi.encodeWithSelector(CachetCertificate.NotChallengeManager.selector, gateway, challengeManager)
        );
        vm.prank(gateway);
        cert.markRevoked(certId);
    }

    function test_RevertWhen_OwnerRevoke() public {
        // Owner boleh mengubah PARAMETER, tidak boleh menyentuh sertifikat.
        (, uint256 certId) = _mint(creator);

        vm.expectRevert(
            abi.encodeWithSelector(CachetCertificate.NotChallengeManager.selector, owner, challengeManager)
        );
        vm.prank(owner);
        cert.markRevoked(certId);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // JENDELA COVERAGE — dicek on-chain (invariant §9.4)
    // ═════════════════════════════════════════════════════════════════════════

    function test_CoverageBelumAktifSelamaWaitingPeriod() public {
        (, uint256 certId) = _mint(creator);

        assertFalse(cert.isCoverageActive(certId), "aktif seketika = klaim instan bisa lolos");

        vm.warp(block.timestamp + 71 hours);
        assertFalse(cert.isCoverageActive(certId), "masih di dalam waiting period");

        vm.warp(block.timestamp + 2 hours);
        assertTrue(cert.isCoverageActive(certId), "harus aktif setelah 72 jam");
    }

    function test_CoverageKedaluwarsaSetelahTerm() public {
        (, uint256 certId) = _mint(creator);
        ICachetCertificate.CertData memory d = cert.certData(certId);

        vm.warp(d.coverageEnd);
        assertTrue(cert.isCoverageActive(certId), "batas akhir masih termasuk");

        vm.warp(d.coverageEnd + 1);
        assertFalse(cert.isCoverageActive(certId));
    }

    function test_JendelaCoverageDihitungBenar() public {
        (, uint256 certId) = _mint(creator);
        ICachetCertificate.CertData memory d = cert.certData(certId);

        assertEq(d.coverageStart, d.mintedAt + 72 hours);
        assertEq(d.coverageEnd, d.coverageStart + 365 days);
    }

    function test_TidakInsurable_CoverageTidakPernahAktif() public {
        // GRAY_ZONE boleh mint, tapi tidak dijamin (§1.3).
        vm.prank(gateway);
        (, uint256 certId) = cert.registerAndMint(_req(creator, DECLARED, false));

        vm.warp(block.timestamp + 100 days);
        assertFalse(cert.isCoverageActive(certId), "insurable=false tidak boleh pernah aktif");
    }

    function test_CertIdTidakDikenal_IsCoverageActiveMengembalikanFalse() public view {
        assertFalse(cert.isCoverageActive(0));
        assertFalse(cert.isCoverageActive(999));
    }

    // ═════════════════════════════════════════════════════════════════════════
    // REVOKE & SURVIVED
    // ═════════════════════════════════════════════════════════════════════════

    function test_Revoke_MematikanCoverageWalaupunMasihDalamJendela() public {
        (, uint256 certId) = _mint(creator);
        vm.warp(block.timestamp + 73 hours);
        assertTrue(cert.isCoverageActive(certId));

        vm.prank(challengeManager);
        cert.markRevoked(certId);

        assertFalse(cert.isCoverageActive(certId));
        assertTrue(cert.certData(certId).revoked);
    }

    function test_RevertWhen_RevokeDuaKali() public {
        (, uint256 certId) = _mint(creator);

        vm.startPrank(challengeManager);
        cert.markRevoked(certId);

        vm.expectRevert(abi.encodeWithSelector(CachetCertificate.AlreadyRevoked.selector, certId));
        cert.markRevoked(certId);
        vm.stopPrank();
    }

    function test_IncrementSurvived() public {
        (, uint256 certId) = _mint(creator);

        vm.startPrank(challengeManager);
        cert.incrementSurvived(certId);
        cert.incrementSurvived(certId);
        vm.stopPrank();

        assertEq(cert.certData(certId).challengesSurvived, 2);
    }

    function test_RevokedTetapDimilikiPemegang_NFTTidakDibakar() public {
        // Sertifikat dicabut tetap ada sebagai catatan publik — cert page
        // menampilkannya sebagai REVOKED, bukan menghilang.
        (, uint256 certId) = _mint(creator);
        vm.prank(challengeManager);
        cert.markRevoked(certId);

        assertEq(cert.ownerOf(certId), creator);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // PARAMETER (§5.0) — configurable, bukan upgradeable
    // ═════════════════════════════════════════════════════════════════════════

    function test_OwnerBisaUbahParameterDanEmitEvent() public {
        vm.expectEmit(true, false, false, true);
        emit CachetGoverned.ParamChanged("maxDeclaredValue", 100e6, 250e6);

        vm.prank(owner);
        cert.setMaxDeclaredValue(250e6);
        assertEq(cert.maxDeclaredValue(), 250e6);
    }

    function test_ParameterBaruBerlakuUntukMintBerikutnya() public {
        vm.prank(owner);
        cert.setWaitingPeriod(1 hours);

        (, uint256 certId) = _mint(creator);
        ICachetCertificate.CertData memory d = cert.certData(certId);
        assertEq(d.coverageStart, d.mintedAt + 1 hours);
    }

    function test_UbahParameterTidakMengubahSertifikatLama() public {
        // Batasnya: parameter boleh berubah, sertifikat yang sudah terbit tidak.
        (, uint256 certId) = _mint(creator);
        ICachetCertificate.CertData memory before = cert.certData(certId);

        vm.startPrank(owner);
        cert.setWaitingPeriod(1 seconds);
        cert.setCoverageTerm(1 days);
        vm.stopPrank();

        ICachetCertificate.CertData memory after_ = cert.certData(certId);
        assertEq(after_.coverageStart, before.coverageStart, "jendela sertifikat lama tidak boleh bergeser");
        assertEq(after_.coverageEnd, before.coverageEnd);
    }

    function test_RevertWhen_NonOwnerUbahParameter() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, gateway));
        vm.prank(gateway);
        cert.setMaxDeclaredValue(1);
    }

    function test_RevertWhen_CoverageTermNol() public {
        vm.expectRevert(CachetCertificate.InvalidParam.selector);
        vm.prank(owner);
        cert.setCoverageTerm(0);
    }

    // ── Pagar parameter (temuan audit B2a) ───────────────────────────────────
    //
    // Sebelum pagar ini ada, owner bisa menyetel waitingPeriod = type(uint64).max
    // sehingga `mintedAt + waitingPeriod` overflow dan SELURUH penerbitan
    // sertifikat revert. Secara teknis "cuma mengubah parameter", efeknya
    // membekukan produk. Inilah yang membuat janji §5.0 ditegakkan kontrak.

    function test_RevertWhen_WaitingPeriodMelebihiPagar() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                CachetCertificate.ParamOutOfRange.selector, uint64(31 days), cert.MAX_WAITING_PERIOD()
            )
        );
        vm.prank(owner);
        cert.setWaitingPeriod(31 days);
    }

    function test_RevertWhen_CoverageTermMelebihiPagar() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                CachetCertificate.ParamOutOfRange.selector, uint64(3651 days), cert.MAX_COVERAGE_TERM()
            )
        );
        vm.prank(owner);
        cert.setCoverageTerm(3651 days);
    }

    function test_PagarMencegahOverflowPenerbitan() public {
        // Nilai maksimum yang diizinkan harus tetap menghasilkan mint yang sehat.
        vm.startPrank(owner);
        cert.setWaitingPeriod(cert.MAX_WAITING_PERIOD());
        cert.setCoverageTerm(cert.MAX_COVERAGE_TERM());
        vm.stopPrank();

        (, uint256 certId) = _mint(creator);
        ICachetCertificate.CertData memory d = cert.certData(certId);

        assertGt(d.coverageEnd, d.coverageStart, "tidak boleh overflow di batas atas");
        vm.warp(d.coverageStart);
        assertTrue(cert.isCoverageActive(certId));
    }

    function test_WaitingPeriodNolDiizinkan_CoverageAktifSeketika() public {
        vm.prank(owner);
        cert.setWaitingPeriod(0);

        (, uint256 certId) = _mint(creator);
        assertTrue(cert.isCoverageActive(certId), "waitingPeriod 0 = coverage langsung aktif");
    }

    // ═════════════════════════════════════════════════════════════════════════
    // COMMIT-REVEAL lewat jalur mint
    // ═════════════════════════════════════════════════════════════════════════

    function test_MintDenganReveal_CommitAtLebihTuaDariMintedAt() public {
        bytes32 salt = bytes32("rahasia");
        bytes32 h = keccak256(abi.encodePacked(phashes[0], salt, creator));

        vm.prank(creator);
        reg.commit(h);
        uint64 tCommit = uint64(block.timestamp);

        vm.warp(block.timestamp + 5 days);

        ICachetCertificate.MintRequest memory r = _req(creator, DECLARED, true);
        r.revealedCommit = h;

        vm.prank(gateway);
        (uint256 entryId, uint256 certId) = cert.registerAndMint(r);

        (,,,, uint64 commitAt,) = reg.getEntry(entryId);
        assertEq(commitAt, tCommit);
        assertLt(commitAt, cert.certData(certId).mintedAt, "commitAt WAJIB lebih tua dari mintedAt");
    }

    // ═════════════════════════════════════════════════════════════════════════
    // ERC-721 dasar
    // ═════════════════════════════════════════════════════════════════════════

    function test_NamaDanSimbol() public view {
        assertEq(cert.name(), "Cachet First-Seen Certificate");
        assertEq(cert.symbol(), "CACHET");
    }

    function test_RevertWhen_CertDataUntukIdTidakValid() public {
        vm.expectRevert(abi.encodeWithSelector(CachetCertificate.InvalidCertId.selector, 1));
        cert.certData(1);
    }

    function test_RevertWhen_OwnerOfIdTidakAda() public {
        vm.expectRevert(abi.encodeWithSelector(IERC721Errors.ERC721NonexistentToken.selector, 1));
        cert.ownerOf(1);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // mintCertificate terpisah — jalur test/darurat, BUKAN produksi
    // ═════════════════════════════════════════════════════════════════════════

    function test_MintCertificateTerpisah_TidakMenyentuhRegistryMaupunVault() public {
        // Butuh entri nyata dulu — sejak audit B2a, entryId hantu ditolak.
        (uint256 entryId,) = _mint(creator);
        uint256 vaultCallsBefore = vault.callCount();

        vm.prank(gateway);
        uint256 certId = cert.mintCertificate(buyer, entryId, DECLARED, true, "ipfs://meta2");

        assertEq(cert.ownerOf(certId), buyer);
        assertEq(cert.certData(certId).entryId, entryId);
        assertEq(reg.entryCount(), 1, "jalur ini sengaja TIDAK me-register entri baru");
        assertEq(vault.callCount(), vaultCallsBefore, "jalur ini sengaja tidak menarik dana");
    }

    /// @dev Temuan audit B2a. Tanpa cek ini, gateway yang keliru bisa
    ///      menerbitkan sertifikat yang menunjuk entri tidak ada — cert page
    ///      akan gagal membacanya dan "bukti publik" jadi tautan mati.
    function test_RevertWhen_MintCertificateEntryIdHantu() public {
        vm.expectRevert(abi.encodeWithSelector(CachetCertificate.UnknownEntryId.selector, 999, 0));
        vm.prank(gateway);
        cert.mintCertificate(creator, 999, DECLARED, true, "ipfs://meta");

        vm.expectRevert(abi.encodeWithSelector(CachetCertificate.UnknownEntryId.selector, 0, 0));
        vm.prank(gateway);
        cert.mintCertificate(creator, 0, DECLARED, true, "ipfs://meta");
    }

    function test_RevertWhen_MintCertificateMelampauiPlafon() public {
        uint256 tooMuch = cert.maxDeclaredValue() + 1;
        vm.expectRevert(
            abi.encodeWithSelector(
                CachetCertificate.DeclaredValueTooHigh.selector, tooMuch, cert.maxDeclaredValue()
            )
        );
        vm.prank(gateway);
        cert.mintCertificate(creator, 1, tooMuch, true, "ipfs://meta");
    }

    function test_RevertWhen_NonGatewayMintCertificate() public {
        vm.expectRevert(abi.encodeWithSelector(CachetCertificate.NotGateway.selector, stranger, gateway));
        vm.prank(stranger);
        cert.mintCertificate(creator, 1, DECLARED, true, "ipfs://meta");
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Wiring — setiap setter menolak address(0)
    // ═════════════════════════════════════════════════════════════════════════

    function test_RevertWhen_VaultBelumDiWiring() public {
        CachetCertificate fresh = new CachetCertificate(owner);
        vm.startPrank(owner);
        fresh.setGateway(gateway);
        fresh.setRegistry(address(reg));
        vm.stopPrank();

        vm.expectRevert(abi.encodeWithSelector(CachetCertificate.NotWired.selector, "vault"));
        vm.prank(gateway);
        fresh.registerAndMint(_req(creator, DECLARED, true));
    }

    function test_RevertWhen_SetterDiberiAddressNol() public {
        vm.startPrank(owner);

        vm.expectRevert(CachetGoverned.ZeroAddress.selector);
        cert.setGateway(address(0));

        vm.expectRevert(CachetGoverned.ZeroAddress.selector);
        cert.setChallengeManager(address(0));

        vm.expectRevert(CachetGoverned.ZeroAddress.selector);
        cert.setRegistry(address(0));

        vm.expectRevert(CachetGoverned.ZeroAddress.selector);
        cert.setVault(address(0));

        vm.stopPrank();
    }

    function test_RevertWhen_OwnerNolSaatDeploy() public {
        // Owner nol = kontrak tanpa siapa pun yang bisa menyetel wiring:
        // permanen tak terpakai. Yang menolaknya adalah Ownable milik OZ5,
        // bukan cek kita sendiri — constructor base berjalan lebih dulu.
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableInvalidOwner.selector, address(0)));
        new CachetCertificate(address(0));
    }

    function test_SetterHanyaUntukOwner() public {
        vm.startPrank(stranger);
        bytes memory err = abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger);

        vm.expectRevert(err);
        cert.setGateway(stranger);
        vm.expectRevert(err);
        cert.setChallengeManager(stranger);
        vm.expectRevert(err);
        cert.setRegistry(stranger);
        vm.expectRevert(err);
        cert.setVault(stranger);
        vm.expectRevert(err);
        cert.setWaitingPeriod(1);
        vm.expectRevert(err);
        cert.setCoverageTerm(1);

        vm.stopPrank();
    }

    function test_SetWaitingPeriodEmitParamChanged() public {
        vm.expectEmit(true, false, false, true);
        emit CachetGoverned.ParamChanged("waitingPeriod", 72 hours, 1 hours);
        vm.prank(owner);
        cert.setWaitingPeriod(1 hours);
    }

    function test_SetCoverageTermEmitParamChanged() public {
        vm.expectEmit(true, false, false, true);
        emit CachetGoverned.ParamChanged("coverageTerm", 365 days, 30 days);
        vm.prank(owner);
        cert.setCoverageTerm(30 days);
    }

    function test_RevertWhen_MarkRevokedCertIdTidakValid() public {
        vm.expectRevert(abi.encodeWithSelector(CachetCertificate.InvalidCertId.selector, 99));
        vm.prank(challengeManager);
        cert.markRevoked(99);
    }

    function test_RevertWhen_IncrementSurvivedCertIdTidakValid() public {
        vm.expectRevert(abi.encodeWithSelector(CachetCertificate.InvalidCertId.selector, 99));
        vm.prank(challengeManager);
        cert.incrementSurvived(99);
    }

    // ═════════════════════════════════════════════════════════════════════════
    // Fuzz
    // ═════════════════════════════════════════════════════════════════════════

    function testFuzz_CoverageAktifHanyaDiDalamJendela(uint64 offset) public {
        (, uint256 certId) = _mint(creator);
        ICachetCertificate.CertData memory d = cert.certData(certId);

        offset = uint64(bound(offset, 0, 400 days));
        vm.warp(d.mintedAt + offset);

        bool expected = (block.timestamp >= d.coverageStart && block.timestamp <= d.coverageEnd);
        assertEq(cert.isCoverageActive(certId), expected);
    }

    function testFuzz_TransferKeSiapaPunMempertahankanCoverage(address to) public {
        vm.assume(to != address(0) && to != creator);
        vm.assume(to.code.length == 0); // hindari kontrak tanpa onERC721Received

        (, uint256 certId) = _mint(creator);
        vm.warp(block.timestamp + 73 hours);

        vm.prank(creator);
        cert.transferFrom(creator, to, certId);

        assertEq(cert.ownerOf(certId), to);
        assertTrue(cert.isCoverageActive(certId), "coverage harus bertahan ke pemegang mana pun");
    }
}
