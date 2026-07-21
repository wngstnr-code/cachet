// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockUSDT} from "../src/MockUSDT.sol";

contract MockUSDTTest is Test {
    MockUSDT internal usdt;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");

    function setUp() public {
        usdt = new MockUSDT();
    }

    // ── Desimal: ini yang paling penting ─────────────────────────────────────
    // Seluruh angka Cachet (plafon 100e6, bond 5e6/10e6, premi 2%) mengasumsikan
    // 6 desimal. Kalau test ini gagal, semua perhitungan lain ikut salah.

    function test_DecimalsIs6NotDefault18() public view {
        assertEq(usdt.decimals(), 6, "MockUSDT wajib 6 desimal seperti USDT asli");
    }

    function test_OneUsdtEqualsOneMillionBaseUnits() public {
        usdt.mint(alice, 1e6); // 1 USDT
        assertEq(usdt.balanceOf(alice), 1_000_000);
    }

    function test_PlafonDeclaredValueIs100Usdt() public {
        // MAX_DECLARED_VALUE = 100e6 di CachetCertificate (§5-B2).
        // Pastikan 100e6 memang bernilai 100 USDT pada token ini.
        uint256 maxDeclaredValue = 100e6;
        usdt.mint(alice, maxDeclaredValue);
        assertEq(usdt.balanceOf(alice) / 10 ** usdt.decimals(), 100);
    }

    // ── Metadata ─────────────────────────────────────────────────────────────

    function test_NameAndSymbol() public view {
        assertEq(usdt.name(), "Mock USDT (Cachet Testnet)");
        assertEq(usdt.symbol(), "mUSDT");
    }

    // ── Faucet publik ────────────────────────────────────────────────────────

    function test_FaucetIsPubliclyCallableByAnyone() public {
        // Person A harus bisa swalayan tanpa minta ke Person B.
        vm.prank(bob);
        usdt.mint(bob, 500e6);
        assertEq(usdt.balanceOf(bob), 500e6);
    }

    function test_FaucetAliasBehavesIdenticallyToMint() public {
        usdt.faucet(alice, 42e6);
        assertEq(usdt.balanceOf(alice), 42e6, "alias faucet() harus setara mint()");
    }

    function test_MintIncreasesTotalSupply() public {
        assertEq(usdt.totalSupply(), 0);
        usdt.mint(alice, 10e6);
        usdt.mint(bob, 25e6);
        assertEq(usdt.totalSupply(), 35e6);
    }

    function test_RevertWhen_FaucetAmountExceedsCap() public {
        uint256 tooMuch = usdt.MAX_FAUCET_AMOUNT() + 1;
        vm.expectRevert(
            abi.encodeWithSelector(MockUSDT.FaucetAmountTooLarge.selector, tooMuch, usdt.MAX_FAUCET_AMOUNT())
        );
        usdt.mint(alice, tooMuch);
    }

    function test_FaucetAtExactCapSucceeds() public {
        uint256 cap = usdt.MAX_FAUCET_AMOUNT();
        usdt.mint(alice, cap);
        assertEq(usdt.balanceOf(alice), cap);
    }

    /// @dev Mendokumentasikan batasan yang DISENGAJA: cap berlaku per panggilan,
    ///      bukan kumulatif, jadi siapa pun bisa memanggil berulang kali. Cap ini
    ///      anti-kecerobohan (biar totalSupply tidak konyol di explorer), BUKAN
    ///      anti-penyalahgunaan. Token testnet ini memang tak bernilai.
    function test_CapBerlakuPerPanggilan_BukanKumulatif() public {
        uint256 cap = usdt.MAX_FAUCET_AMOUNT();
        usdt.mint(alice, cap);
        usdt.mint(alice, cap);
        usdt.mint(alice, cap);
        assertEq(usdt.balanceOf(alice), 3 * cap, "cap sengaja bisa dilewati dengan panggilan berulang");
    }

    function test_RevertWhen_MintKeAddressNol() public {
        vm.expectRevert(); // OZ5: ERC20InvalidReceiver
        usdt.mint(address(0), 1e6);
    }

    // ── Perilaku ERC-20 yang dipakai Vault ───────────────────────────────────
    // Vault memakai transferFrom untuk menarik fraud bond, premi, dan challenge
    // bond. Alur approve→transferFrom harus terbukti jalan sebelum B2 dibangun.

    function test_ApproveThenTransferFrom_JalurYangDipakaiVault() public {
        address vault = makeAddr("vault");
        usdt.mint(alice, 100e6);

        vm.prank(alice);
        usdt.approve(vault, 15e6); // fraud bond 5 + challenge bond 10

        vm.prank(vault);
        bool ok = usdt.transferFrom(alice, vault, 15e6);
        assertTrue(ok, "transferFrom wajib mengembalikan true (Vault mengandalkan ini via SafeERC20)");

        assertEq(usdt.balanceOf(vault), 15e6);
        assertEq(usdt.balanceOf(alice), 85e6);
        assertEq(usdt.allowance(alice, vault), 0);
    }

    function test_RevertWhen_TransferFromTanpaApproveCukup() public {
        address vault = makeAddr("vault");
        usdt.mint(alice, 100e6);

        vm.prank(alice);
        usdt.approve(vault, 5e6);

        vm.prank(vault);
        vm.expectRevert(); // OZ5: ERC20InsufficientAllowance
        // Return value sengaja tidak dicek: panggilan ini memang revert,
        // jadi tidak ada nilai yang dikembalikan.
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        usdt.transferFrom(alice, vault, 10e6);
    }

    /// @dev Pola persis yang dipakai gateway per RFC-001 P1: approve SEKALI di
    ///      awal dengan allowance besar, lalu banyak mint tanpa approve ulang.
    ///      OZ5 tidak mengurangi allowance bila nilainya type(uint256).max —
    ///      kalau perilaku ini berubah, alur mint Person A ikut rusak.
    function test_AllowanceMaxTidakBerkurang_PolaGatewayRFC001() public {
        address vault = makeAddr("vault");
        usdt.mint(alice, 1000e6);

        vm.prank(alice);
        usdt.approve(vault, type(uint256).max);

        vm.startPrank(vault);
        assertTrue(usdt.transferFrom(alice, vault, 100e6));
        assertTrue(usdt.transferFrom(alice, vault, 100e6));
        vm.stopPrank();

        assertEq(
            usdt.allowance(alice, vault), type(uint256).max, "allowance tak terbatas tidak boleh berkurang"
        );
        assertEq(usdt.balanceOf(vault), 200e6);
    }

    /// @dev ⚠️ DIVERGENSI DARI USDT ASLI. Tether di Ethereum menolak approve
    ///      dari nilai non-nol ke non-nol (wajib reset ke 0 dulu). MockUSDT
    ///      mengizinkannya karena ERC-20 standar OZ. Artinya kode yang lolos di
    ///      sini BELUM tentu jalan bila flag §10 diputar ke mainnet dengan USDT
    ///      asli. Mitigasi: selalu SafeERC20 + forceApprove di kontrak inti.
    function test_ApproveNonZeroKeNonZero_LebihPermisifDariUsdtAsli() public {
        address vault = makeAddr("vault");
        vm.startPrank(alice);
        usdt.approve(vault, 100e6);
        usdt.approve(vault, 200e6); // USDT asli di ETH: revert. Di sini: lolos.
        vm.stopPrank();
        assertEq(usdt.allowance(alice, vault), 200e6);
    }

    // ── Fuzz ─────────────────────────────────────────────────────────────────

    function testFuzz_MintDalamBatasSelaluMenambahSaldo(address to, uint256 amount) public {
        vm.assume(to != address(0));
        amount = bound(amount, 0, usdt.MAX_FAUCET_AMOUNT());

        uint256 before = usdt.balanceOf(to);
        usdt.mint(to, amount);
        assertEq(usdt.balanceOf(to), before + amount);
    }
}
