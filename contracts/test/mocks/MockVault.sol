// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ICachetVault} from "../../src/interfaces/ICachetVault.sol";

/// @notice Vault palsu untuk menguji CachetCertificate sebelum Vault asli ada (B2b).
/// @dev Merekam panggilan `collectOnMint` supaya test bisa membuktikan urutan
///      dan argumen jalur atomik, plus bisa dipaksa gagal untuk membuktikan
///      seluruh transaksi ikut revert.
contract MockVault is ICachetVault {
    struct CollectCall {
        uint256 certId;
        address payer;
        uint256 fraudBond;
        uint256 premium;
    }

    CollectCall[] public calls;

    /// @notice Bila true, `collectOnMint` revert — mensimulasikan allowance kurang.
    bool public shouldFail;

    error MockVaultForcedFailure();

    function setShouldFail(bool v) external {
        shouldFail = v;
    }

    function callCount() external view returns (uint256) {
        return calls.length;
    }

    function lastCall() external view returns (CollectCall memory) {
        return calls[calls.length - 1];
    }

    function collectOnMint(uint256 certId, address payer, uint256 fraudBond, uint256 premium) external {
        if (shouldFail) revert MockVaultForcedFailure();
        calls.push(CollectCall({certId: certId, payer: payer, fraudBond: fraudBond, premium: premium}));
    }

    // ── Sisa interface: tidak dipakai di B2a ─────────────────────────────────

    function collectChallengeBond(uint256, address, uint256) external pure {}
    function settleChallengeWon(uint256, uint256, address, address) external pure {}
    function settleChallengeLost(uint256, uint256, address) external pure {}

    function payToken() external pure returns (address) {
        return address(0);
    }

    function balanceOfVault() external pure returns (uint256) {
        return 0;
    }
}
