import { resolve } from "node:path";
import { defineConfig } from "vite";

const monorepoRoot = resolve(import.meta.dirname, "../..");

export default defineConfig({
  // WAJIB (claude.md §6): satu .env di ROOT monorepo, bukan di folder ini.
  envDir: monorepoRoot,
  server: {
    // Izinkan import packages/contracts-abi dari luar root Vite.
    fs: { allow: [monorepoRoot] },
  },
  build: { target: "es2022" },
});
