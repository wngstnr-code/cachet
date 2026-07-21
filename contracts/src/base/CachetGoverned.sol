// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title CachetGoverned — dasar bersama untuk kontrak berparameter
/// @notice Cachet **tidak memakai proxy dan tidak upgradeable** (§5.0). Yang
///         bisa berubah hanya angka kebijakan, lewat setter `onlyOwner`.
///
///         Batasnya tegas: **parameter boleh berubah, aturan main tidak.**
///         Payout selalu ke `ownerOf(certId)`, apa pun setelan yang berlaku
///         (invariant §9.1). Owner tidak bisa mengubah logika, hanya angka.
///
/// @dev Setiap perubahan parameter WAJIB emit `ParamChanged` supaya kebijakan
///      tetap terlacak publik di explorer — tanpa ini, "configurable" jadi
///      tidak bisa dibedakan dari "diam-diam diubah".
abstract contract CachetGoverned is Ownable {
    /// @param key nama parameter sebagai bytes32, mis. bytes32("waitingPeriod")
    event ParamChanged(bytes32 indexed key, uint256 oldValue, uint256 newValue);

    /// @notice Dipakai setter wiring; BUKAN untuk constructor.
    /// @dev Constructor sengaja tidak memvalidasi `owner_` sendiri: `Ownable`
    ///      milik OZ5 sudah revert dengan `OwnableInvalidOwner(address(0))`
    ///      lebih dulu karena constructor base berjalan duluan. Cek tambahan di
    ///      sini akan jadi kode mati — dan memang terdeteksi begitu oleh
    ///      branch coverage sebelum dihapus.
    error ZeroAddress();

    constructor(address owner_) Ownable(owner_) {}
}
