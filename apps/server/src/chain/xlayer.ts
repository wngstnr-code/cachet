/** Definisi chain X Layer untuk viem (§1.4). chainId dari env supaya sama dipakai
 *  testnet (1952) maupun anvil lokal (kita jalankan anvil --chain-id 1952). */

import { defineChain } from "viem";

export function xlayerChain(chainId: number, rpcUrl: string) {
  return defineChain({
    id: chainId,
    name: chainId === 196 ? "X Layer" : "X Layer Testnet",
    nativeCurrency: { name: "OKB", symbol: "OKB", decimals: 18 },
    rpcUrls: { default: { http: [rpcUrl] } },
  });
}
