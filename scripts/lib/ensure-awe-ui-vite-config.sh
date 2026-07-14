#!/usr/bin/env bash
# Write AWE admin UI Vite config into awe/ui so Node resolves vite from local node_modules.
set -euo pipefail

ui_dir="${1:?UI directory required}"
api_port="${AWE_API_PORT:-8030}"
ui_port="${AWE_UI_PORT:-8031}"
config_path="${ui_dir}/.openg2p-vite.config.mjs"

cat > "$config_path" <<EOF
import { defineConfig } from "vite";
import react from "@vitejs/plugin-react";

export default defineConfig({
  plugins: [react()],
  base: "/",
  server: {
    port: ${ui_port},
    host: "0.0.0.0",
    proxy: {
      "/v1/awe": {
        target: "http://127.0.0.1:${api_port}",
        changeOrigin: true,
      },
    },
  },
});
EOF

echo "[awe-ui] Wrote ${config_path} (UI :${ui_port}, API proxy -> :${api_port})"
