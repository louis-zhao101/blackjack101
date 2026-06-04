import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

export default defineConfig({
  plugins: [react()],
resolve: {
    alias: {
      '@blackjack101/core': new URL('../../packages/core/src/index.ts', import.meta.url).pathname,
    },
  },
});
