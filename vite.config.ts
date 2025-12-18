import { defineConfig } from 'vite';
import { resolve } from 'path';
export default defineConfig({
  root: './src/web',
  publicDir: '../../public',
  build: {
    outDir: '../../dist',
    emptyOutDir: true,
    rollupOptions: {
      external: (id) => {
        // Don't bundle config.ts in browser (it uses Node.js crypto)
        if (id.includes('/config.ts') || id.includes('\\config.ts')) {
          return true;
        }
        return false;
      }
    }
  },
  server: {
    host: '0.0.0.0', // Listen on all network interfaces (required for Docker)
    port: 8080,
    open: false, // Don't try to open browser in Docker
    cors: true,
    proxy: {
      // Proxy API requests to the Bun server
      '/api': {
        target: 'http://localhost:3001',
        changeOrigin: true,
        secure: false,
      }
    }
  },
  resolve: {
    alias: {
      '@': resolve(__dirname, './src')
    },
    dedupe: []
  },
  optimizeDeps: {
    include: ['@fatsolutions/tongo-sdk', 'get-starknet'],
    exclude: ['crypto', 'dotenv'] // Exclude Node.js modules from browser bundle
  },
  define: {
    // Replace Node.js globals with browser-safe versions
    'process.env': '{}',
    'global': 'globalThis'
  },
  ssr: {
    // Don't externalize these for SSR (we're not using SSR, but good to have)
    noExternal: ['@fatsolutions/tongo-sdk']
  },
  plugins: [],
});

