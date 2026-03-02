import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

export default defineConfig({
  plugins: [react()],
  server: {
    port: 5173,
    open: true,
  },
  define: {
    // Suppress mapbox-gl's use of eval-based CSP
    'globalThis.__DEV__': false,
  },
})
