import { writable } from 'svelte/store';
import { browser } from '$app/environment';

type Theme = 'light' | 'dark';

const stored = browser ? (localStorage.getItem('theme') as Theme | null) : null;
const prefersDark = browser ? window.matchMedia('(prefers-color-scheme: dark)').matches : false;
const initial: Theme = stored ?? (prefersDark ? 'dark' : 'light');

function createThemeStore() {
    const { subscribe, set } = writable<Theme>(initial);

    function apply(theme: Theme) {
        if (browser) {
            document.documentElement.setAttribute('data-theme', theme);
            localStorage.setItem('theme', theme);
        }
        set(theme);
    }

    // Apply initial theme on load
    if (browser) {
        document.documentElement.setAttribute('data-theme', initial);
    }

    return {
        subscribe,
        toggle() {
            let current: Theme = 'light';
            subscribe((v) => (current = v))();
            apply(current === 'light' ? 'dark' : 'light');
        },
        set: apply
    };
}

export const theme = createThemeStore();
