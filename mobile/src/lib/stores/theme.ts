import { writable } from 'svelte/store';

type ThemeMode = 'light' | 'dark' | 'system';
type ResolvedTheme = 'light' | 'dark';

function isThemeMode(value: string | null): value is ThemeMode {
    return value === 'light' || value === 'dark' || value === 'system';
}

// Use typeof window guard instead of SvelteKit $app/environment
const isBrowser = typeof window !== 'undefined';

const mediaQuery = isBrowser ? window.matchMedia('(prefers-color-scheme: dark)') : null;
const stored = isBrowser ? localStorage.getItem('theme') : null;
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
        if (isBrowser) {
            document.documentElement.classList.toggle('dark', resolved === 'dark');
        }
        setResolved(resolved);
    }

    function apply(mode: ThemeMode) {
        if (isBrowser) {
            localStorage.setItem('theme', mode);
        }
        set(mode);
        applyResolved(resolveTheme(mode));
    }

    // Apply initial theme on load and listen for system changes
    if (isBrowser) {
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
            const unsubResolved = subscribeResolved((value) => (currentResolved = value));
            unsubResolved();
            if (currentMode === 'system') {
                apply(currentResolved === 'dark' ? 'light' : 'dark');
            } else {
                apply(currentMode === 'dark' ? 'light' : 'dark');
            }
        },
        setMode(mode: ThemeMode) {
            apply(mode);
        }
    };
}

export const themeStore = createThemeStore();

// Compatibility exports matching the web frontend API
export const theme = {
    subscribe: themeStore.subscribe,
    set: (mode: ThemeMode) => themeStore.setMode(mode),
    toggle: () => themeStore.toggle()
};

export const resolvedTheme = themeStore.resolved;
