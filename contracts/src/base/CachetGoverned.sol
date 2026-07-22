// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Ownable2Step} from "@openzeppelin/contracts/access/Ownable2Step.sol";

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
///         disclosure listing (audit B2a). Wiring bersifat **set-once**
///         (`_lockWiring`): sekali disetel saat deploy, alamat gateway,
///         resolver, dan ChallengeManager TIDAK bisa diganti lagi. Karena itu
///         kepercayaan pada owner terbatas pada **momen deploy**, bukan
///         seterusnya:
///         1. Owner memilih alamat gateway SATU KALI saat deploy. Owner bisa
///            saja menyetel gateway = dirinya sendiri sejak awal dan
///            menerbitkan sertifikat tanpa lewat pemeriksaan originality —
///            tapi sertifikat itu tetap tunduk aturan yang sama (bond & premi
///            tetap ditarik, payout tetap ke pemegang), dan identitas gateway
///            publik & beku sejak blok deploy.
///         2. Owner tetap bisa menyetel parameter kebijakan (`waitingPeriod`,
///            `premiumBps`, `livenessWindow`, dst.) dalam pagar lantai/plafon
///            selama kontrak hidup — termasuk ke setelan demo yang lemah
///            (liveness 30 detik, premi 0,1%) atau `maxDeclaredValue = 0`
///            sebagai rem darurat penerbitan. Tiap perubahan emit
///            `ParamChanged`, tapi "terlihat" hanya berarti kalau ada yang
///            mengawasi.
///
///         Yang owner TIDAK bisa lakukan setelah deploy: mengganti alamat
///         gateway/resolver/ChallengeManager, mengubah logika, atau menarik
///         dana dari vault.
///
///         Ini konsekuensi tak terhindarkan dari MVP tanpa timelock/multisig.
///         Jangan mengklaim "trustless" — klaim yang benar adalah "aturan
///         mainnya on-chain dan bisa diaudit, operatornya masih terpusat".
///
/// @dev Setiap perubahan parameter WAJIB emit `ParamChanged` supaya kebijakan
///      tetap terlacak publik di explorer — tanpa ini, "configurable" jadi
///      tidak bisa dibedakan dari "diam-diam diubah".
///
/// @dev G5: memakai `Ownable2Step`, bukan `Ownable` biasa. Owner adalah
///      satu-satunya yang bisa menyetel parameter (termasuk rem darurat
///      `maxDeclaredValue = 0`); kalau `transferOwnership` salah ketik ke
///      alamat yang tidak bisa menerima, SEMUA setter mati permanen (sekelas
///      C1). Dua langkah menutup itu: pemilik baru WAJIB `acceptOwnership()`
///      dulu, jadi alamat salah ketik hanya menggantung sebagai `pendingOwner`
///      tanpa memutus kendali. (`renounceOwnership` tetap satu langkah bawaan
///      OZ — pemakaian eksplisit, bukan kecelakaan diam.)
abstract contract CachetGoverned is Ownable2Step {
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

    /// @notice Parameter di bawah lantai yang diizinkan.
    /// @dev Lantai ada untuk mencegah sebuah mekanisme DIMATIKAN, bukan untuk
    ///      menjamin nilainya memadai. `livenessWindow = 0` menghapus satu-
    ///      satunya rem publik terhadap resolver; `premiumBps = 0` membuat
    ///      jaminan gratis; `fraudBondAmount = 0` menghapus taruhan kreator
    ///      sekaligus bounty penantang. Ketiganya "sekadar mengubah parameter"
    ///      tapi efeknya membatalkan bagian inti sistem.
    ///
    ///      Kecukupan nilai untuk produksi (48 jam, 2%, 5 USDT) tetap keputusan
    ///      kebijakan — kontrak hanya menjamin mekanismenya hidup.
    error ParamBelowFloor(uint256 value, uint256 min);

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
