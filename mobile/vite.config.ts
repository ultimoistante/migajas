import { svelte, vitePreprocess } from '@sveltejs/vite-plugin-svelte';
import { defineConfig } from 'vite';
import { resolve } from 'path';

export default defineConfig({
    plugins: [
        svelte({
            preprocess: vitePreprocess()
        })
    ],
    resolve: {
        alias: {
            '$lib': resolve('./src/lib')
        }
    },
    base: './',
    build: {
        outDir: 'dist',
        emptyOutDir: true
    }
});
