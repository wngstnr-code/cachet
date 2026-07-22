import type { Network } from "@okxweb3/x402-core/types";
import type { RoutesConfig } from "@okxweb3/x402-core/http";

import { DESCRIPTIONS, PRICES } from "./prices.js";

export interface X402RouteSettings {
  network: Network;
  payTo: `0x${string}`;
  resourceBase: string;
}

/** Bentuk route resmi SDK dari satu sumber harga Cachet. */
export function buildPaymentRoutes(settings: X402RouteSettings): RoutesConfig {
  return Object.fromEntries(
    Object.entries(PRICES).map(([route, price]) => {
      const path = route.slice(route.indexOf(" ") + 1);
      return [
        route,
        {
          accepts: {
            scheme: "exact",
            price,
            network: settings.network,
            payTo: settings.payTo,
            maxTimeoutSeconds: 300,
          },
          resource: `${settings.resourceBase}${path}`,
          description: DESCRIPTIONS[route] ?? "Cachet paid endpoint",
          mimeType: "application/json",
          unpaidResponseBody: () => ({
            contentType: "application/json",
            body: { error: "payment required", x402Version: 2 },
          }),
          settlementFailedResponseBody: () => ({
            contentType: "application/json",
            body: { error: "payment settlement failed" },
          }),
        },
      ];
    }),
  );
}
