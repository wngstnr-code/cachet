// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title MockUSDT — token pembayaran untuk Cachet di X Layer Testnet
/// @notice ⚠️ TESTNET SAJA. Siapa pun boleh mencetak token ini secara gratis,
///         jadi nilainya nol. JANGAN pernah deploy ke mainnet — di mainnet
///         `payToken` adalah USDT asli (lihat Open Flags §10 technical plan).
///
/// @dev Kenapa mock, bukan USDT asli: di testnet tidak ada deployment Tether
///      resmi, dan test Foundry butuh kontrol penuh atas saldo tiap wallet
///      (kreator, penantang, pembeli demo, vault). Lihat §1.4 & §5-B1.
///
///      **6 desimal — bukan 18.** Ini mengikuti USDT asli dan dipakai di
///      seluruh perhitungan Cachet: `MAX_DECLARED_VALUE = 100e6` (100 USDT),
///      fraud bond `5e6`, challenge bond `10e6`, premi `declaredValue*200/10000`.
///      Mengubah desimal akan menggeser SEMUA angka itu 12 digit.
contract MockUSDT is ERC20 {
    /// @notice Batas per panggilan faucet: 1.000.000 USDT.
    /// @dev Faucet sengaja publik (§3.1) supaya Person A bisa swalayan tanpa
    ///      minta ke Person B. Batas ini bukan soal keamanan — token ini memang
    ///      tak bernilai — tapi mencegah satu panggilan iseng menggelembungkan
    ///      totalSupply sampai explorer & cert page menampilkan angka konyol
    ///      saat demo direkam.
    uint256 public constant MAX_FAUCET_AMOUNT = 1_000_000e6;

    error FaucetAmountTooLarge(uint256 requested, uint256 max);

    constructor() ERC20("Mock USDT (Cachet Testnet)", "mUSDT") {}

    /// @notice USDT memakai 6 desimal, bukan 18 bawaan ERC-20.
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /// @notice Cetak token gratis ke alamat mana pun. Publik — tanpa akses kontrol.
    /// @dev Nama fungsi mengikuti §3.1 technical plan.
    /// @param to alamat penerima
    /// @param amount jumlah dalam base unit (6 desimal) — 1 USDT = 1_000_000
    function mint(address to, uint256 amount) public {
        if (amount > MAX_FAUCET_AMOUNT) {
            revert FaucetAmountTooLarge(amount, MAX_FAUCET_AMOUNT);
        }
        _mint(to, amount);
    }

    /// @notice Alias `mint`. §3.1 menyebut fungsi ini `mint`, §5-B1 menyebutnya
    ///         `faucet` — keduanya disediakan supaya tidak ada dokumen yang
    ///         perlu diubah (§3 sudah beku sejak RFC-001).
    function faucet(address to, uint256 amount) external {
        mint(to, amount);
    }
}
