import { defineConfig } from 'vite';

// The Vite dev server proxies /api to the Node server so the frontend and API
// share an origin during development.
export default defineConfig({
  server: {
    port: 5173,
    proxy: {
      '/api': 'http://localhost:5177',
    },
  },
});
