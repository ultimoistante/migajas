/** @type {import('tailwindcss').Config} */
export default {
    darkMode: 'class',
    content: ['./src/**/*.{svelte,ts,html}', './index.html'],
    theme: {
        extend: {}
    },
    plugins: [require('@tailwindcss/typography')]
};
