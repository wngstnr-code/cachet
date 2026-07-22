/** Pengiriman alert: webhook POST (email = dicatat saja di MVP, tak ada SMTP). */

import type { AlertPayload } from "./scan.js";

export async function sendWebhookAlert(payload: AlertPayload): Promise<void> {
  const url = payload.subscription.webhook_url;
  if (url) {
    try {
      await fetch(url, {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({
          type: "cachet.watch.copy_detected",
          cert_id: payload.subscription.cert_id,
          match: payload.match,
          draft_challenge: payload.draft,
        }),
      });
    } catch (err) {
      // eslint-disable-next-line no-console
      console.error(`[watch] webhook gagal utk ${payload.subscription.id}:`, (err as Error).message);
    }
  }
  if (payload.subscription.email) {
    // MVP: tak ada SMTP — dicatat jujur. Roadmap: kirim email sungguhan.
    // eslint-disable-next-line no-console
    console.error(`[watch] (email tak dikirim di MVP) alert utk ${payload.subscription.email}, cert ${payload.subscription.cert_id}`);
  }
}
