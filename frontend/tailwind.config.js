/** @type {import('tailwindcss').Config} */
export default {
    content: ['./src/**/*.{html,js,svelte,ts}'],
    darkMode: ['class', '[data-theme="dark"]'],
    theme: {
        extend: {}
    },
    plugins: [require('daisyui')],
    daisyui: {
        themes: [
            {
                light: {
                    ...require('daisyui/src/theming/themes')['light'],
                    primary: '#6366f1',
                    'primary-focus': '#4f46e5',
                    secondary: '#f59e0b'
                }
            },
            {
                dark: {
                    ...require('daisyui/src/theming/themes')['dark'],
                    primary: '#818cf8',
                    'primary-focus': '#6366f1',
                    secondary: '#fbbf24'
                }
            }
        ],
        darkTheme: 'dark',
        base: true,
        styled: true,
        utils: true
    }
};
