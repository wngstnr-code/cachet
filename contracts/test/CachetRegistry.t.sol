// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CachetRegistry} from "../src/CachetRegistry.sol";
import {ICachetRegistry} from "../src/interfaces/ICachetRegistry.sol";
import {CachetGoverned} from "../src/base/CachetGoverned.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CachetRegistryTest is Test {
    CachetRegistry internal reg;

    address internal owner = makeAddr("owner");
    // Di produksi ini adalah alamat kontrak CachetCertificate, bukan wallet.
    address internal gateway = makeAddr("certificateContract");
    address internal creator = makeAddr("creator");
    address internal stranger = makeAddr("stranger");

    bytes32[4] internal phashes;
    bytes32 internal embCommit = keccak256("embedding");

    function setUp() public {
        reg = new CachetRegistry(owner);
        vm.prank(owner);
        reg.setGateway(gateway);

        phashes = [keccak256("p0"), keccak256("p1"), keccak256("p2"), keccak256("p3")];
    }

    function _register(bytes32 revealed) internal returns (uint256) {
        vm.prank(gateway);
        return reg.register(phashes, embCommit, creator, revealed, "ipfs://asset");
    }

    // ── Kontrol akses (invariant §9.2) ───────────────────────────────────────

    function test_RevertWhen_NonGatewayRegisters() public {
        vm.expectRevert(abi.encodeWithSelector(CachetRegistry.NotGateway.selector, stranger, gateway));
        vm.prank(stranger);
        reg.register(phashes, embCommit, creator, bytes32(0), "ipfs://asset");
    }

    function test_RevertWhen_OwnerRegisters() public {
        // Owner pun tidak boleh — hanya gateway. Ini yang bikin klaim
        // "tidak ada jalur register selain gateway" berarti sesuatu.
        vm.expectRevert(abi.encodeWithSelector(CachetRegistry.NotGateway.selector, owner, gateway));
        vm.prank(owner);
        reg.register(phashes, embCommit, creator, bytes32(0), "ipfs://asset");
    }

    function test_RevertWhen_NonOwnerSetsGateway() public {
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, stranger));
        vm.prank(stranger);
        reg.setGateway(stranger);
    }

    function test_RevertWhen_GatewaySetToZero() public {
        vm.expectRevert(CachetGoverned.ZeroAddress.selector);
        vm.prank(owner);
        reg.setGateway(address(0));
    }

    // ── G5: kepemilikan dua langkah (Ownable2Step) ───────────────────────────
    // Diuji di Registry sebagai wakil semua kontrak: kelimanya mewarisi perilaku
    // ini dari CachetGoverned, jadi satu pembuktian di sini menutup keempatnya.

    /// @dev G5: `transferOwnership` tidak langsung memindah kuasa. Alamat salah
    ///      ketik yang tidak pernah `acceptOwnership` hanya menggantung sebagai
    ///      `pendingOwner` — owner lama tetap memegang seluruh setter. Tanpa ini,
    ///      satu typo mematikan semua parameter permanen (sekelas C1).
    function test_G5_TransferOwnershipDuaLangkah_TypoTidakMemutusKendali() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        reg.transferOwnership(newOwner);

        // Kuasa BELUM pindah: owner lama masih owner, newOwner cuma pending.
        assertEq(reg.owner(), owner, "owner lama tetap memegang kendali sebelum accept");
        assertEq(reg.pendingOwner(), newOwner, "newOwner baru berstatus pending");

        // pendingOwner belum boleh menggovern.
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, newOwner));
        vm.prank(newOwner);
        reg.transferOwnership(newOwner);
    }

    /// @dev G5: transfer selesai HANYA setelah pemilik baru `acceptOwnership`,
    ///      dan owner lama kehilangan kuasa saat itu juga.
    function test_G5_AcceptOwnership_MenyelesaikanTransfer() public {
        address newOwner = makeAddr("newOwner");

        vm.prank(owner);
        reg.transferOwnership(newOwner);

        vm.prank(newOwner);
        reg.acceptOwnership();

        assertEq(reg.owner(), newOwner, "kuasa pindah setelah accept");
        assertEq(reg.pendingOwner(), address(0), "pending dibersihkan");

        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, owner));
        vm.prank(owner);
        reg.transferOwnership(owner);
    }

    // ── Registrasi ───────────────────────────────────────────────────────────

    function test_EntryIdDimulaiDari1_BukanNol() public {
        // 0 harus selalu berarti "tidak ada" (§3.2 nearest_entry_id null).
        assertEq(reg.entryCount(), 0);
        assertEq(_register(bytes32(0)), 1, "entryId pertama harus 1");
        assertEq(_register(bytes32(0)), 2);
        assertEq(reg.entryCount(), 2);
    }

    function test_GetEntryMengembalikanSemuaField() public {
        uint256 id = _register(bytes32(0));

        (
            bytes32[4] memory p,
            bytes32 emb,
            address c,
            uint64 registeredAt,
            uint64 commitAt,
            string memory uri
        ) = reg.getEntry(id);

        assertEq(p[0], phashes[0]);
        assertEq(p[3], phashes[3]);
        assertEq(emb, embCommit);
        assertEq(c, creator);
        assertEq(registeredAt, uint64(block.timestamp));
        assertEq(commitAt, 0, "tanpa commit-reveal, commitAt harus 0");
        assertEq(uri, "ipfs://asset");
    }

    function test_RevertWhen_GetEntryIdTidakValid() public {
        vm.expectRevert(abi.encodeWithSelector(CachetRegistry.InvalidEntryId.selector, 0));
        reg.getEntry(0);

        vm.expectRevert(abi.encodeWithSelector(CachetRegistry.InvalidEntryId.selector, 1));
        reg.getEntry(1);
    }

    function test_RevertWhen_CreatorNol() public {
        vm.expectRevert(CachetRegistry.InvalidCreator.selector);
        vm.prank(gateway);
        reg.register(phashes, embCommit, address(0), bytes32(0), "ipfs://asset");
    }

    function test_EventRegisteredMembawaPhash0() public {
        vm.expectEmit(true, true, false, true);
        emit ICachetRegistry.Registered(1, creator, phashes[0], uint64(block.timestamp));
        _register(bytes32(0));
    }

    /// @dev Didokumentasikan sebagai keputusan sadar: dedup pHash TIDAK ada
    ///      on-chain (biayanya O(n)). Penyaringan dilakukan gateway (§9.5).
    function test_PhashIdentikBolehDiRegisterDuaKali_DedupAdaDiGateway() public {
        uint256 a = _register(bytes32(0));
        uint256 b = _register(bytes32(0));
        assertEq(b, a + 1, "kontrak sengaja tidak menolak duplikat; gateway yang menyaring");
    }

    // ── Commit-reveal ────────────────────────────────────────────────────────

    function _commitHash(bytes32 phash0, bytes32 salt, address who) internal pure returns (bytes32) {
        // Rumus dikunci RFC-001 P4.
        return keccak256(abi.encodePacked(phash0, salt, who));
    }

    function test_CommitTerbukaUntukSiapaPun() public {
        bytes32 h = _commitHash(phashes[0], bytes32("salt"), creator);

        vm.prank(stranger); // bukan gateway, bukan owner
        reg.commit(h);

        assertEq(reg.commitTimestamp(h), uint64(block.timestamp));
    }

    function test_RevertWhen_CommitDuaKali() public {
        // Kalau overwrite diizinkan, penyerang bisa "menyegarkan" timestamp
        // commit orang lain dan menghancurkan klaim prioritasnya.
        bytes32 h = _commitHash(phashes[0], bytes32("salt"), creator);
        reg.commit(h);

        vm.expectRevert(abi.encodeWithSelector(CachetRegistry.CommitAlreadyExists.selector, h));
        reg.commit(h);
    }

    function test_CommitAtLebihTuaDariRegisteredAt() public {
        // Inti commit-reveal: membuktikan kreator sudah memegang karya SEBELUM
        // dipublikasikan. Ini yang dipakai di smoke test §6.
        bytes32 salt = bytes32("rahasia");
        bytes32 h = _commitHash(phashes[0], salt, creator);

        vm.prank(creator);
        reg.commit(h);
        uint64 tCommit = uint64(block.timestamp);

        vm.warp(block.timestamp + 3 days);
        uint256 id = _register(h);

        (,,, uint64 registeredAt, uint64 commitAt,) = reg.getEntry(id);
        assertEq(commitAt, tCommit);
        assertLt(commitAt, registeredAt, "commitAt WAJIB lebih tua dari registeredAt");
    }

    function test_RevertWhen_RevealCommitYangTidakAda() public {
        bytes32 palsu = keccak256("tidak pernah di-commit");
        vm.expectRevert(abi.encodeWithSelector(CachetRegistry.CommitNotFound.selector, palsu));
        _register(palsu);
    }

    /// @dev Tambahan di luar §3.1. Tanpa ini, satu commit lama bisa dipakai
    ///      berkali-kali untuk mengklaim timestamp awal yang sama pada banyak
    ///      karya berbeda — persis serangan yang commit-reveal harus cegah.
    function test_RevertWhen_CommitDipakaiUlang() public {
        bytes32 h = _commitHash(phashes[0], bytes32("salt"), creator);
        reg.commit(h);

        _register(h);
        assertTrue(reg.commitConsumed(h));

        vm.expectRevert(abi.encodeWithSelector(CachetRegistry.CommitAlreadyConsumed.selector, h));
        _register(h);
    }

    function test_RegisterGagalTidakMenandaiCommitTerpakai() public {
        // Retry setelah gagal harus tetap bisa memakai commit yang sama.
        bytes32 h = _commitHash(phashes[0], bytes32("salt"), creator);
        reg.commit(h);

        vm.expectRevert(CachetRegistry.InvalidCreator.selector);
        vm.prank(gateway);
        reg.register(phashes, embCommit, address(0), h, "ipfs://asset");

        assertFalse(reg.commitConsumed(h), "tx yang revert tidak boleh menandai commit terpakai");

        uint256 id = _register(h); // retry berhasil
        (,,,, uint64 commitAt,) = reg.getEntry(id);
        assertGt(commitAt, 0);
    }

    // ── Fuzz ─────────────────────────────────────────────────────────────────

    function testFuzz_EntryCountSelaluSamaDenganIdTerakhir(uint8 n) public {
        n = uint8(bound(n, 1, 20));
        uint256 last;
        for (uint256 i = 0; i < n; i++) {
            last = _register(bytes32(0));
        }
        assertEq(reg.entryCount(), last);
        assertEq(last, n);
    }
}
