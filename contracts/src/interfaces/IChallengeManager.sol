// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title IChallengeManager — pasar gugatan atas sertifikat
/// @notice DIBEKUKAN di §3.1 technical plan (RFC-001).
interface IChallengeManager {
    enum Status {
        None,
        Open,
        UpheldChallengerWon,
        DismissedChallengerLost
    }

    /// @notice Siapa pun boleh menggugat. `evidenceURI` = bukti admissible
    ///         (timestamp on-chain / snapshot web-archive / capture C2PA).
    /// @dev ⚠️ PRASYARAT (RFC-001 P6): penantang WAJIB
    ///      `payToken.approve(VAULT, challengeBond)` SEBELUM memanggil ini —
    ///      `transferFrom` dilakukan Vault, BUKAN kontrak ini. Approve ke
    ///      ChallengeManager akan membuat panggilan revert.
    function challenge(uint256 certId, string calldata evidenceURI) external returns (uint256 challengeId);

    /// @notice MVP: hanya resolver (operator) yang memutus, SETELAH jendela
    ///         liveness lewat.
    /// @dev Ini titik sentralisasi yang diakui terbuka. JANGAN pernah
    ///      mengklaim "trustless adjudication". Roadmap: optimistic oracle.
    function resolve(uint256 challengeId, bool challengerWins, string calldata rulingURI) external;

    function getChallenge(uint256 challengeId)
        external
        view
        returns (
            uint256 certId,
            address challenger,
            uint64 openedAt,
            Status status,
            string memory evidenceURI
        );

    event ChallengeOpened(uint256 indexed challengeId, uint256 indexed certId, address indexed challenger);
    event ChallengeResolved(uint256 indexed challengeId, Status status);
}
