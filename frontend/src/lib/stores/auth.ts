import { writable, derived } from 'svelte/store';
import { auth as authApi, setAccessToken, type User } from '$lib/api/client';

interface AuthState {
    user: User | null;
    loading: boolean;
}

function createAuthStore() {
    const { subscribe, set, update } = writable<AuthState>({ user: null, loading: true });

    return {
        subscribe,
        /** Call on app start to restore session via refresh token */
        async init() {
            try {
                const data = await fetch('/api/auth/refresh', {
                    method: 'POST',
                    credentials: 'include'
                });
                if (data.ok && data.status !== 204) {
                    const json = await data.json();
                    setAccessToken(json.access_token);
                    const user = await authApi.me();
                    set({ user, loading: false });
                } else {
                    set({ user: null, loading: false });
                }
            } catch {
                set({ user: null, loading: false });
            }
        },
        async login(username_or_email: string, password: string) {
            const resp = await authApi.login(username_or_email, password);
            setAccessToken(resp.access_token);
            update((s) => ({ ...s, user: resp.user }));
            return resp.user;
        },
        async logout() {
            await authApi.logout().catch(() => { });
            setAccessToken(null);
            set({ user: null, loading: false });
        },
        setUser(user: User) {
            update((s) => ({ ...s, user }));
        }
    };
}

export const authStore = createAuthStore();
export const isAuthenticated = derived(authStore, ($a) => !!$a.user);
export const currentUser = derived(authStore, ($a) => $a.user);
