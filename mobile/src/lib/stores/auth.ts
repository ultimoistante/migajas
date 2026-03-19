import { writable, derived } from 'svelte/store';
import {
    auth as authApi,
    setAccessToken,
    storeRefreshToken,
    getStoredRefreshToken,
    clearStoredRefreshToken,
    type User
} from '$lib/api/client';
import { getServerUrl } from '$lib/serverConfig';
import { push } from 'svelte-spa-router';

interface AuthState {
    user: User | null;
    loading: boolean;
}

function createAuthStore() {
    const { subscribe, set, update } = writable<AuthState>({ user: null, loading: true });

    return {
        subscribe,

        /**
         * Call on app start to restore session.
         * Reads the stored refresh token from Preferences, POSTs it to /auth/refresh,
         * and if successful fetches the current user.
         */
        async init() {
            try {
                const storedToken = await getStoredRefreshToken();
                if (!storedToken) {
                    set({ user: null, loading: false });
                    return;
                }

                const serverUrl = await getServerUrl();
                if (!serverUrl) {
                    set({ user: null, loading: false });
                    return;
                }

                const res = await fetch(serverUrl + '/api/auth/refresh', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json',
                        'X-Client-Type': 'capacitor'
                    },
                    body: JSON.stringify({ refresh_token: storedToken })
                });

                if (res.ok) {
                    const data = await res.json() as { access_token: string; refresh_token?: string };
                    setAccessToken(data.access_token);
                    if (data.refresh_token) await storeRefreshToken(data.refresh_token);
                    const user = await authApi.me();
                    set({ user, loading: false });
                } else {
                    await clearStoredRefreshToken();
                    set({ user: null, loading: false });
                }
            } catch {
                set({ user: null, loading: false });
            }
        },

        async login(username_or_email: string, password: string) {
            const resp = await authApi.login(username_or_email, password);
            setAccessToken(resp.access_token);
            if (resp.refresh_token) await storeRefreshToken(resp.refresh_token);
            update((s) => ({ ...s, user: resp.user }));
            return resp.user;
        },

        async logout() {
            await authApi.logout().catch(() => { });
            setAccessToken(null);
            await clearStoredRefreshToken();
            set({ user: null, loading: false });
            push('/login');
        },

        setUser(user: User) {
            update((s) => ({ ...s, user }));
        }
    };
}

export const authStore = createAuthStore();
export const isAuthenticated = derived(authStore, ($a) => !!$a.user);
export const currentUser = derived(authStore, ($a) => $a.user);
