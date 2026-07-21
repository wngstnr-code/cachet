// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script, console} from "forge-std/Script.sol";
import {MockUSDT} from "../src/MockUSDT.sol";

/// @notice Deploy MockUSDT ke X Layer Testnet (chainId 1952).
/// @dev Jalankan lewat `make deploy-mockusdt` supaya .env root ikut terbaca.
///      Setelah sukses, salin alamatnya ke ADDR_MOCKUSDT di .env root, dan
///      nanti ke packages/contracts-abi/addresses.testnet.json (serah-terima H3).
contract DeployMockUSDT is Script {
    /// @dev Pagar keselamatan: token ini gratis dicetak siapa pun. Kalau
    ///      sampai ter-deploy ke mainnet, siapa pun bisa mencetak "USDT" palsu
    ///      yang dipakai Vault sebagai payToken. Lihat NatSpec MockUSDT.
    uint256 internal constant XLAYER_TESTNET = 1952;

    function run() external returns (MockUSDT usdt) {
        require(
            block.chainid == XLAYER_TESTNET,
            "MockUSDT hanya boleh di X Layer Testnet (1952). Mainnet pakai USDT asli."
        );

        uint256 pk = vm.envUint("DEPLOYER_PK");

        vm.startBroadcast(pk);
        usdt = new MockUSDT();
        vm.stopBroadcast();

        console.log("MockUSDT   :", address(usdt));
        console.log("decimals   :", usdt.decimals());
        console.log("chainId    :", block.chainid);
        console.log("");
        console.log("-> salin alamat di atas ke ADDR_MOCKUSDT pada .env root");
    }
}
