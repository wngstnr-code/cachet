/**
 * Definisi 6 tool MCP (§3.3) → forward ke gateway. Dipisah dari server.ts supaya
 * bisa dites tanpa transport MCP: test memanggil handler langsung dgn GatewayClient
 * ber-fetch palsu.
 */

import { z, type ZodRawShape } from "zod";

import type { GatewayClient, GatewayResult } from "./gateway.js";

export interface ToolResult {
  // Index signature diminta tipe CallToolResult SDK MCP.
  [x: string]: unknown;
  content: { type: "text"; text: string }[];
  isError?: boolean;
}

export interface ToolSpec {
  name: string;
  description: string;
  schema: ZodRawShape;
  handler: (args: Record<string, unknown>) => Promise<ToolResult>;
}

/** Bungkus hasil gateway → hasil tool MCP. 402 & error diteruskan jujur. */
function present(r: GatewayResult): ToolResult {
  if (r.ok) {
    return { content: [{ type: "text", text: JSON.stringify(r.body, null, 2) }] };
  }
  const payload: Record<string, unknown> = { status: r.status, response: r.body };
  if (r.status === 402) {
    // Klien pemanggil membayar lalu retry dengan PAYMENT-SIGNATURE (x402 v2).
    payload.payment_required_header = r.paymentRequired;
    payload.hint = "Bayar via x402 v2 lalu retry dengan header PAYMENT-SIGNATURE.";
  }
  return { content: [{ type: "text", text: JSON.stringify(payload, null, 2) }], isError: true };
}

const imageFields = {
  image_b64: z.string().optional().describe("Byte gambar mentah, base64"),
  image_url: z.string().url().optional().describe("URL gambar (alternatif image_b64)"),
};

export function makeTools(gw: GatewayClient): ToolSpec[] {
  return [
    {
      name: "verify_originality",
      description:
        "Cek gambar terhadap registry Cachet → Originality Profile (verdict first-seen, distinctiveness advisory). Berbayar x402 (0.02 USDT).",
      schema: {
        ...imageFields,
        declared_value: z.string().optional().describe("Nilai deklarasi base-unit 6 desimal (opsional)"),
        request_id: z.string().optional(),
      },
      handler: async (a) => present(await gw.verify(a)),
    },
    {
      name: "commit_work",
      description:
        "Kunci commit-reveal SEBELUM karya publik (anti registry-sniping). Kirim commit_hash, atau (phash0+salt+creator) untuk dihitung server. Berbayar x402 (0.01 USDT).",
      schema: {
        commit_hash: z.string().optional(),
        phash0: z.string().optional(),
        salt: z.string().optional(),
        creator: z.string().optional(),
        request_id: z.string().optional(),
      },
      handler: async (a) => present(await gw.commit(a)),
    },
    {
      name: "register_and_mint",
      description:
        "Terbitkan sertifikat First-Seen (ERC-721 ber-jaminan, transferable) untuk gambar. Tolak near-duplicate. Berbayar x402 (0.5 USDT + premi 2% on-chain). Fraud bond + premi ditarik dari wallet creator_address bila sudah approve gateway (payToken.approve), kalau belum gateway yang menanggung sementara — respons menyebut collateral_source.",
      schema: {
        ...imageFields,
        creator_address: z.string().describe("Alamat penerima sertifikat"),
        declared_value: z.string().describe("Nilai deklarasi base-unit 6 desimal"),
        salt: z.string().optional().describe("Ungkap commit-reveal (opsional)"),
        asset_uri: z.string().optional(),
        token_uri: z.string().optional(),
        request_id: z.string().optional(),
      },
      handler: async (a) => present(await gw.mint(a)),
    },
    {
      name: "get_certificate",
      description:
        "Ambil data sertifikat + status coverage (ACTIVE/PENDING/EXPIRED/REVOKED/NOT_INSURABLE) + umur + challenges survived. Gratis.",
      schema: { cert_id: z.string().describe("ID sertifikat") },
      handler: async (a) => present(await gw.getCertificate(String(a.cert_id))),
    },
    {
      name: "challenge_certificate",
      description:
        "Gugat sertifikat dengan bukti admissible. Mengembalikan instruksi bond (approve ke VAULT). On-chain bond.",
      schema: {
        cert_id: z.string(),
        evidence_uri: z.string().describe("Bukti admissible: timestamp on-chain / web-archive / C2PA"),
        request_id: z.string().optional(),
      },
      handler: async (a) => present(await gw.challenge(a)),
    },
    {
      name: "watch_subscribe",
      description:
        "Langganan monitoring: registry dipindai berkala, salinan baru memicu alert. Berbayar x402 (0.1 USDT / 30 hari).",
      schema: {
        cert_id: z.string(),
        webhook_url: z.string().url().optional(),
        email: z.string().email().optional(),
        request_id: z.string().optional(),
      },
      handler: async (a) => present(await gw.watch(a)),
    },
  ];
}
