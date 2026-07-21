// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title ICachetVault — pemegang bond, premi, dan pembayar klaim
/// @notice DIBEKUKAN di §3.1 (RFC-001). Implementasinya menyusul di B2b;
///         di B2a interface ini hanya dipakai CachetCertificate untuk
///         memanggil `collectOnMint` di dalam `registerAndMint`.
interface ICachetVault {
    /// @notice Dipanggil di dalam jalur mint: tarik fraudBond + premi dari payer.
    /// @dev payer WAJIB sudah `approve` ke alamat Vault (bukan ke Certificate).
    function collectOnMint(uint256 certId, address payer, uint256 fraudBond, uint256 premium) external;

    /// @dev Penantang WAJIB `approve` ke alamat Vault sebelum `challenge()`.
    function collectChallengeBond(uint256 challengeId, address challenger, uint256 amount) external;

    /// @notice Payout klaim ke pemegang cert saat ini + bounty ke penantang.
    /// @dev WAJIB (RFC-001 P2): require(certHolder == certificate.ownerOf(certId)).
    function settleChallengeWon(uint256 certId, uint256 challengeId, address certHolder, address challenger)
        external;

    /// @notice Challenge gagal: slash bond penantang (50% holder, 50% vault).
    /// @dev `certId` ditambahkan di RFC-001 P2 supaya Vault bisa memverifikasi
    ///      holder sendiri, bukan mempercayai parameter yang dioper.
    function settleChallengeLost(uint256 certId, uint256 challengeId, address certHolder) external;

    function payToken() external view returns (address);
    function balanceOfVault() external view returns (uint256);
}
