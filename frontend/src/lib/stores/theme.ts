import { writable } from 'svelte/store';
import { browser } from '$app/environment';

type ThemeMode = 'light' | 'dark' | 'system';
type ResolvedTheme = 'light' | 'dark';

function isThemeMode(value: string | null): value is ThemeMode {
    return value === 'light' || value === 'dark' || value === 'system';
}

const mediaQuery = browser ? window.matchMedia('(prefers-color-scheme: dark)') : null;
const stored = browser ? localStorage.getItem('theme') : null;
const initialMode: ThemeMode = isThemeMode(stored) ? stored : 'system';

function resolveTheme(mode: ThemeMode): ResolvedTheme {
    if (mode === 'system') {
        return mediaQuery?.matches ? 'dark' : 'light';
    }
    return mode;
}

const initialResolved: ResolvedTheme = resolveTheme(initialMode);

function createThemeStore() {
    const { subscribe, set } = writable<ThemeMode>(initialMode);
    const { subscribe: subscribeResolved, set: setResolved } = writable<ResolvedTheme>(initialResolved);

    function applyResolved(resolved: ResolvedTheme) {
        if (browser) {
            document.documentElement.classList.toggle('dark', resolved === 'dark');
        }
        setResolved(resolved);
    }

    function apply(mode: ThemeMode) {
        if (browser) {
            localStorage.setItem('theme', mode);
        }
        set(mode);
        applyResolved(resolveTheme(mode));
    }

    // Apply initial theme on load
    if (browser) {
        applyResolved(initialResolved);

        const handleSystemChange = () => {
            let current: ThemeMode = 'system';
            subscribe((value) => (current = value))();
            if (current === 'system') {
                applyResolved(resolveTheme('system'));
            }
        };

        if (mediaQuery?.addEventListener) {
            mediaQuery.addEventListener('change', handleSystemChange);
        } else {
            mediaQuery?.addListener(handleSystemChange);
        }
    }

    return {
        subscribe,
        resolved: {
            subscribe: subscribeResolved
        },
        toggle() {
            let currentMode: ThemeMode = 'system';
            let currentResolved: ResolvedTheme = 'light';
            subscribe((value) => (currentMode = value))();
            subscribeResolved((value) => (currentResolved = value))();

            if (currentMode === 'system') {
                apply(currentResolved === 'dark' ? 'light' : 'dark');
                return;
            }

            apply(currentMode === 'light' ? 'dark' : 'light');
        },
        set: apply
    };
}

export const theme = createThemeStore();
export const resolvedTheme = theme.resolved;
