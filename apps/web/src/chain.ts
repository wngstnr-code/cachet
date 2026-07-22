import {
  createPublicClient,
  defineChain,
  http,
  BaseError,
  ContractFunctionRevertedError,
} from "viem";
import {
  CachetCertificateAbi,
  CachetRegistryAbi,
  ChallengeManagerAbi,
} from "../../../packages/contracts-abi/index";
import { addresses, CHAIN_ID, DEPLOY_BLOCK, RPC_URL } from "./config";

const xLayerTestnet = defineChain({
  id: CHAIN_ID,
  name: addresses.chain.name,
  nativeCurrency: { name: "OKB", symbol: "OKB", decimals: 18 },
  rpcUrls: { default: { http: [RPC_URL] } },
});

const client = createPublicClient({ chain: xLayerTestnet, transport: http() });

const CERT = addresses.contracts.certificate as `0x${string}`;
const REGISTRY = addresses.contracts.registry as `0x${string}`;
const CHALLENGE = addresses.contracts.challengeManager as `0x${string}`;

/** enum IChallengeManager.Status — urutan dari interface §3.1. */
export const ChallengeStatus = {
  None: 0,
  Open: 1,
  UpheldChallengerWon: 2,
  DismissedChallengerLost: 3,
} as const;

export interface ChallengeRow {
  challengeId: bigint;
  challenger: `0x${string}`;
  openedAt: bigint;
  status: number;
  evidenceURI: string;
  openedTx: string | null;
  resolvedTx: string | null;
}

export interface CertView {
  certId: bigint;
  entryId: bigint;
  declaredValue: bigint;
  mintedAt: bigint;
  coverageStart: bigint;
  coverageEnd: bigint;
  insurable: boolean;
  revoked: boolean;
  challengesSurvived: number;
  coverageActive: boolean;
  holder: `0x${string}`;
  creator: `0x${string}`;
  registeredAt: bigint;
  phash0: string;
  assetURI: string;
  tokenURI: string;
  challenges: ChallengeRow[];
}

/** Lima state tampilan. WAITING bukan badge §5-B3, tapi masa tunggu adalah
 *  mekanisme produk — menyembunyikannya membuat cert baru tampak "ACTIVE"
 *  padahal klaim yang dibuka sekarang hangus (G2). */
export type CertStatus = "ACTIVE" | "WAITING" | "NOT_INSURABLE" | "REVOKED" | "EXPIRED";

export function deriveStatus(c: CertView): CertStatus {
  if (c.revoked) return "REVOKED";
  if (!c.insurable) return "NOT_INSURABLE";
  if (c.coverageActive) return "ACTIVE";
  const now = BigInt(Math.floor(Date.now() / 1000));
  return now < c.coverageStart ? "WAITING" : "EXPIRED";
}

export class CertNotFoundError extends Error {}

export async function loadCert(certId: bigint): Promise<CertView> {
  // Reads paralel; TANPA multicall3 — belum diverifikasi ter-deploy di 1952.
  let cert, holder, uri, coverageActive;
  try {
    [cert, holder, uri, coverageActive] = await Promise.all([
      client.readContract({ address: CERT, abi: CachetCertificateAbi, functionName: "certData", args: [certId] }),
      client.readContract({ address: CERT, abi: CachetCertificateAbi, functionName: "ownerOf", args: [certId] }),
      client.readContract({ address: CERT, abi: CachetCertificateAbi, functionName: "tokenURI", args: [certId] }),
      client.readContract({ address: CERT, abi: CachetCertificateAbi, functionName: "isCoverageActive", args: [certId] }),
    ]);
  } catch (err) {
    if (isNonexistent(err)) throw new CertNotFoundError(`cert ${certId} does not exist`);
    throw err;
  }

  const [entry, challenges] = await Promise.all([
    client.readContract({ address: REGISTRY, abi: CachetRegistryAbi, functionName: "getEntry", args: [cert.entryId] }),
    loadChallenges(certId),
  ]);

  return {
    certId,
    entryId: cert.entryId,
    declaredValue: cert.declaredValue,
    mintedAt: BigInt(cert.mintedAt),
    coverageStart: BigInt(cert.coverageStart),
    coverageEnd: BigInt(cert.coverageEnd),
    insurable: cert.insurable,
    revoked: cert.revoked,
    challengesSurvived: cert.challengesSurvived,
    coverageActive,
    holder,
    creator: entry[2],
    registeredAt: BigInt(entry[3]),
    phash0: entry[0][0],
    assetURI: entry[5],
    tokenURI: uri,
    challenges,
  };
}

/** Riwayat gugatan DARI STATE, bukan scan log penuh: RPC publik X Layer
 *  membatasi eth_getLogs ke rentang 100 blok (diverifikasi 22 Jul), jadi
 *  "sejak blok deploy" mustahil. challengeCount kecil selama bootstrap —
 *  iterasi state selalu jalan; tx hash dilengkapi best-effort di bawah. */
async function loadChallenges(certId: bigint): Promise<ChallengeRow[]> {
  const count = await client.readContract({
    address: CHALLENGE,
    abi: ChallengeManagerAbi,
    functionName: "challengeCount",
  });

  const all = await Promise.all(
    Array.from({ length: Number(count) }, (_, i) =>
      client.readContract({
        address: CHALLENGE,
        abi: ChallengeManagerAbi,
        functionName: "getChallenge",
        args: [BigInt(i + 1)], // challengeId mulai dari 1
      }).then((ch) => ({ challengeId: BigInt(i + 1), ch })),
    ),
  );

  return Promise.all(
    all
      .filter(({ ch }) => ch[0] === certId)
      .map(async ({ challengeId, ch }) => {
        const { openedTx, resolvedTx } = await findChallengeTxs(challengeId, BigInt(ch[2]));
        return {
          challengeId,
          challenger: ch[1],
          openedAt: BigInt(ch[2]),
          status: ch[3],
          evidenceURI: ch[4],
          openedTx,
          resolvedTx,
        };
      }),
  );
}

/** Tx hash via binary search blok berdasar timestamp openedAt (~20 read
 *  header), lalu SATU jendela getLogs ≤100 blok. Putusan yang jatuh di luar
 *  jendela (liveness produksi 2 hari) → resolvedTx null; UI sudah punya
 *  fallback link. Gagal total → link kosong, halaman tetap berdiri. */
async function findChallengeTxs(
  challengeId: bigint,
  openedAt: bigint,
): Promise<{ openedTx: string | null; resolvedTx: string | null }> {
  try {
    const openBlock = await findBlockByTimestamp(openedAt);
    const [opened, resolved] = await Promise.all([
      client.getContractEvents({
        address: CHALLENGE,
        abi: ChallengeManagerAbi,
        eventName: "ChallengeOpened",
        args: { challengeId },
        fromBlock: openBlock - 2n,
        toBlock: openBlock + 97n,
      }),
      client.getContractEvents({
        address: CHALLENGE,
        abi: ChallengeManagerAbi,
        eventName: "ChallengeResolved",
        args: { challengeId },
        fromBlock: openBlock - 2n,
        toBlock: openBlock + 97n,
      }),
    ]);
    return {
      openedTx: opened[0]?.transactionHash ?? null,
      resolvedTx: resolved[0]?.transactionHash ?? null,
    };
  } catch {
    return { openedTx: null, resolvedTx: null };
  }
}

async function findBlockByTimestamp(target: bigint): Promise<bigint> {
  let lo = DEPLOY_BLOCK;
  let hi = (await client.getBlock({ blockTag: "latest" })).number;
  while (lo < hi) {
    const mid = (lo + hi) / 2n;
    const block = await client.getBlock({ blockNumber: mid });
    if (block.timestamp < target) lo = mid + 1n;
    else hi = mid;
  }
  return lo;
}

function isNonexistent(err: unknown): boolean {
  if (err instanceof BaseError) {
    const revert = err.walk((e) => e instanceof ContractFunctionRevertedError);
    if (revert instanceof ContractFunctionRevertedError) {
      const name = revert.data?.errorName ?? "";
      return name === "ERC721NonexistentToken" || name === "InvalidCertId";
    }
  }
  return false;
}

/** ipfs:// -> gateway publik; http(s)/data dibiarkan. */
export function resolveURI(uri: string): string | null {
  if (uri.startsWith("ipfs://")) return `https://ipfs.io/ipfs/${uri.slice(7)}`;
  if (/^(https?:|data:)/.test(uri)) return uri;
  return null;
}

/** Ambil gambar dari metadata ERC-721. Gagal = null — halaman tetap berdiri
 *  tanpa gambar (fixture demo memakai URI yang memang tidak resolvable). */
export async function loadImage(tokenURI: string): Promise<string | null> {
  const metaURL = resolveURI(tokenURI);
  if (!metaURL) return null;
  try {
    const res = await fetch(metaURL, { signal: AbortSignal.timeout(8000) });
    if (!res.ok) return null;
    const meta: unknown = await res.json();
    const image = (meta as { image?: unknown }).image;
    if (typeof image !== "string") return null;
    return resolveURI(image);
  } catch {
    return null;
  }
}
