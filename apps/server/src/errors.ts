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
