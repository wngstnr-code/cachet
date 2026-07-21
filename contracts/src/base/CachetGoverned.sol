// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

/// @title CachetGoverned — dasar bersama untuk kontrak berparameter
/// @notice Cachet **tidak memakai proxy dan tidak upgradeable** (§5.0). Yang
///         bisa berubah hanya angka kebijakan, lewat setter `onlyOwner`.
///
///         Batasnya tegas: **parameter boleh berubah, aturan main tidak.**
///         Payout selalu ke `ownerOf(certId)`, apa pun setelan yang berlaku
///         (invariant §9.1). Owner tidak bisa mengubah logika, hanya angka —
///         dan angka pun dibatasi konstanta yang tidak bisa diubah siapa pun
///         (mis. `MAX_WAITING_PERIOD`).
///
///         KEKUASAAN OWNER YANG TETAP ADA, dan WAJIB diungkap di README serta
///         disclosure listing (audit B2a):
///         1. Owner bisa mengganti alamat gateway, lalu menerbitkan sertifikat
///            sendiri. Sertifikat tetap tunduk pada aturan yang sama —
///            bond & premi tetap ditarik, payout tetap ke pemegang — tapi
///            owner bisa menerbitkan tanpa lewat pemeriksaan originality.
///         2. Owner bisa mengganti alamat ChallengeManager, dan dengan begitu
///            mengendalikan siapa yang boleh mencabut sertifikat.
///
///         Ini konsekuensi tak terhindarkan dari MVP tanpa timelock/multisig.
///         Jangan mengklaim "trustless" — klaim yang benar adalah "aturan
///         mainnya on-chain dan bisa diaudit, operatornya masih terpusat".
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

    /// @notice Alamat wiring sudah pernah ditetapkan dan terkunci selamanya.
    error AlreadyWired(string what);

    constructor(address owner_) Ownable(owner_) {}

    /// @notice Wiring SEKALI SEUMUR HIDUP kontrak.
    ///
    /// @dev Menutup jalur pengurasan dana yang terbukti saat audit: owner
    ///      mengganti alamat ChallengeManager ke kontrak jahat, lalu memanggil
    ///      `settleChallengeWon` untuk dirinya sendiri. Modal 6 USDT, hasil
    ///      sampai seluruh saldo vault — dalam satu transaksi, tanpa proses.
    ///
    ///      Setelah dikunci, jalur itu tidak dipersulit; ia tidak ada lagi.
    ///
    ///      Konsekuensi operasional yang diterima sadar: **wiring yang salah
    ///      berarti redeploy.** Itu konsisten dengan keputusan §5.0 untuk tidak
    ///      memakai proxy — biaya redeploy mendekati nol selama belum ada
    ///      pengguna nyata, dan jauh lebih murah daripada menyimpan kunci yang
    ///      bisa dipakai menguras kolam.
    ///
    ///      Parameter kebijakan TIDAK ikut terkunci — angka tetap bisa
    ///      disetel dalam pagar masing-masing. Yang beku adalah siapa yang
    ///      berwenang, bukan berapa besarannya.
    function _lockWiring(address current, string memory what) internal pure {
        if (current != address(0)) revert AlreadyWired(what);
    }
}
