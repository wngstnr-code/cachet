/**
 * Builder Originality Profile §3.2 — output publik /verify & bagian dari /mint.
 *
 * Engine memberi bagian analisis; gateway menambah premium_quote (uang string
 * base-unit + _display), phashes_hash, dan signed (EIP-712). Bentuk di sini WAJIB
 * persis §3.2 — cert page B & pemanggil bergantung padanya.
 */

import type { Hex } from "viem";

import type { EngineQuery } from "./engine/client.js";
import { toDisplay } from "./money.js";
import { phashesHash, type SignedVerdict } from "./signer.js";

export interface PremiumQuoteInput {
  declaredValue: bigint;
  premium: bigint;
  fraudBond: bigint;
}

export interface BuildProfileArgs {
  requestId: string;
  engine: EngineQuery;
  signed: SignedVerdict;
  premium?: PremiumQuoteInput; // hanya bila declared_value diberi
}

export function buildProfile(args: BuildProfileArgs): Record<string, unknown> {
  const { engine, signed, premium, requestId } = args;

  const profile: Record<string, unknown> = {
    version: "1.0",
    request_id: requestId,
    asset_sha256: engine.asset_sha256,
    verdict: engine.verdict,
    first_seen: engine.first_seen,
    distinctiveness: engine.distinctiveness,
    ai_declaration: engine.ai_declaration,
    insurable: engine.insurable,
    phashes: engine.phashes,
    phashes_hash: phashesHash(engine.phashes as Hex[]),
    embedding_commit: engine.embedding_commit,
    signed: {
      signer: signed.signer,
      signature: signed.signature,
      timestamp: signed.timestamp,
    },
  };

  if (premium) {
    profile.premium_quote = {
      currency: "USDT",
      decimals: 6,
      declared_value: premium.declaredValue.toString(),
      premium: premium.premium.toString(),
      fraud_bond: premium.fraudBond.toString(),
      _display: {
        declared_value: toDisplay(premium.declaredValue),
        premium: toDisplay(premium.premium),
        fraud_bond: toDisplay(premium.fraudBond),
      },
    };
  }

  return profile;
}
