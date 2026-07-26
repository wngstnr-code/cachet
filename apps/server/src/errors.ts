/**
 * Error aplikasi → format respons SERAGAM `{ error: { code, message } }` (§3.3).
 *
 * `code` sengaja mencerminkan nama error kontrak (WrongPremium, DeclaredValueTooHigh,
 * dst.) supaya pesan yang dilihat pemanggil konsisten baik saat pakai stub maupun
 * viem nanti — bug integrasi jadi kelihatan lebih dini.
 */

export class AppError extends Error {
  constructor(
    public code: string,
    message: string,
    public statusCode = 400,
  ) {
    super(message);
    this.name = "AppError";
  }
}

export const errNearDup = () =>
  new AppError("NEAR_DUP_REJECTED", "Gambar terdeteksi near-duplicate; tidak bisa di-mint.", 409);

export const errBadRequest = (msg: string) => new AppError("BAD_REQUEST", msg, 400);

export const errNotFound = (msg: string) => new AppError("NOT_FOUND", msg, 404);

/** 405 untuk endpoint berbayar yang hanya boleh POST.
 *
 *  Path-nya tetap ter-gate x402, jadi pemanggil TANPA pembayaran melihat 402 lebih
 *  dulu — itu yang dibaca validator listing OKX. 405 ini hanya untuk pemanggil yang
 *  SUDAH bayar tapi memakai method yang salah; SDK tidak melakukan settlement pada
 *  respons ≥400 (`x402-fastify/dist/cjs/index.js:322`), jadi tidak ada uang terpotong. */
export const errPostOnly = (msg: string) => new AppError("METHOD_NOT_ALLOWED", msg, 405);
