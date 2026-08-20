import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  define: {
    // Provide a global object fallback for older packages like amazon-cognito-identity-js
    global: 'window',
  },
  server: {
    proxy: {
      '/api/v1/products': {
        target: 'http://localhost:3000',
        changeOrigin: true,
      },
      '/api/v1/orders': {
        target: 'http://localhost:8000',
        changeOrigin: true,
      },
      '/socket.io': {
        target: 'http://localhost:9001',
        ws: true,
        changeOrigin: true,
      },
      '/api': {
        target: 'http://localhost:3000',
        changeOrigin: true,
      },
    },
  },
});
