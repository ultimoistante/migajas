// Typed API client for the migajas backend — mobile (Capacitor) version.
// Key differences from the web client:
//   - Base URL is read at runtime from Capacitor Preferences (no proxy)
//   - X-Client-Type: capacitor header sent on login/refresh
//   - Refresh token stored in Preferences instead of httpOnly cookie

import { Preferences } from '@capacitor/preferences';
import { getServerUrl } from '$lib/serverConfig';

export interface User {
    id: string;
    username: string;
    email: string;
    has_vault: boolean;
    is_admin: boolean;
    created_at: string;
}

export interface SetupStatus {
    initialized: boolean;
    allow_self_registration: boolean;
}

export interface Tag {
    id: string;
    name: string;
    emoji: string;
}

export interface Note {
    id: string;
    user_id: string;
    title: string;
    body: string | null;
    is_secret: boolean;
    is_locked: boolean;
    is_pinned: boolean;
    color: string;
    tags: Tag[];
    created_at: string;
    updated_at: string;
    attachment_count: number;
}

export interface Attachment {
    id: string;
    note_id: string;
    original_name: string;
    mime_type: string;
    size: number;
    created_at: string;
}

export interface LoginResponse {
    access_token: string;
    refresh_token?: string;
    user: User;
}

export interface AdminSettings {
    allow_self_registration: boolean;
}

const REFRESH_TOKEN_KEY = 'migajas_refresh_token';

let accessToken: string | null = null;

export function setAccessToken(t: string | null) {
    accessToken = t;
}
export function getAccessToken(): string | null {
    return accessToken;
}

export async function storeRefreshToken(token: string): Promise<void> {
    await Preferences.set({ key: REFRESH_TOKEN_KEY, value: token });
}

export async function getStoredRefreshToken(): Promise<string | null> {
    const { value } = await Preferences.get({ key: REFRESH_TOKEN_KEY });
    return value;
}

export async function clearStoredRefreshToken(): Promise<void> {
    await Preferences.remove({ key: REFRESH_TOKEN_KEY });
}

async function getBase(): Promise<string> {
    const url = await getServerUrl();
    if (!url) throw new Error('Server URL not configured');
    return url + '/api';
}

async function request<T>(
    method: string,
    path: string,
    body?: unknown,
    retry = true
): Promise<T> {
    const base = await getBase();
    const headers: Record<string, string> = {
        'Content-Type': 'application/json',
        'X-Client-Type': 'capacitor'
    };
    if (accessToken) headers['Authorization'] = `Bearer ${accessToken}`;

    const res = await fetch(base + path, {
        method,
        headers,
        body: body !== undefined ? JSON.stringify(body) : undefined
    });

    if (res.status === 401 && retry) {
        const refreshed = await tryRefresh();
        if (refreshed) return request<T>(method, path, body, false);
    }

    if (!res.ok) {
        const err = await res.json().catch(() => ({ error: res.statusText }));
        throw new ApiError(res.status, err.error ?? 'Unknown error');
    }

    return res.json() as Promise<T>;
}

async function tryRefresh(): Promise<boolean> {
    try {
        const storedToken = await getStoredRefreshToken();
        if (!storedToken) return false;
        const base = await getBase();
        const res = await fetch(base + '/auth/refresh', {
            method: 'POST',
            headers: {
                'Content-Type': 'application/json',
                'X-Client-Type': 'capacitor'
            },
            body: JSON.stringify({ refresh_token: storedToken })
        });
        if (!res.ok) {
            await clearStoredRefreshToken();
            setAccessToken(null);
            return false;
        }
        const data = await res.json() as { access_token: string; refresh_token?: string };
        setAccessToken(data.access_token);
        if (data.refresh_token) await storeRefreshToken(data.refresh_token);
        return true;
    } catch {
        setAccessToken(null);
        return false;
    }
}

export class ApiError extends Error {
    constructor(
        public readonly status: number,
        message: string
    ) {
        super(message);
        this.name = 'ApiError';
    }
}

async function requestFormData<T>(method: string, path: string, formData: FormData): Promise<T> {
    const base = await getBase();
    const headers: Record<string, string> = {
        'X-Client-Type': 'capacitor'
    };
    if (accessToken) headers['Authorization'] = `Bearer ${accessToken}`;

    const res = await fetch(base + path, {
        method,
        headers,
        body: formData
    });

    if (res.status === 401) {
        const refreshed = await tryRefresh();
        if (refreshed) return requestFormData<T>(method, path, formData);
    }

    if (!res.ok) {
        const err = await res.json().catch(() => ({ error: res.statusText }));
        throw new ApiError(res.status, err.error ?? 'Unknown error');
    }

    return res.json() as Promise<T>;
}

// ── Auth ──────────────────────────────────────────────────────────────────────

export const auth = {
    register: (username: string, email: string, password: string) =>
        request<{ message: string }>('POST', '/auth/register', { username, email, password }),

    login: (username_or_email: string, password: string) =>
        request<LoginResponse>('POST', '/auth/login', { username_or_email, password }),

    logout: () => request<{ message: string }>('POST', '/auth/logout'),

    me: () => request<User>('GET', '/auth/me'),

    setupVault: (type: 'pin' | 'password', credential: string) =>
        request<{ message: string }>('POST', '/auth/vault', { type, credential }),

    rotateVault: (type: 'pin' | 'password', old_credential: string, new_credential: string) =>
        request<{ message: string }>('PATCH', '/auth/vault', { type, old_credential, new_credential })
};

// ── Setup ────────────────────────────────────────────────────────────────────

export interface SetupPayload {
    username: string;
    email: string;
    password: string;
    allow_self_registration: boolean;
}

export const setup = {
    status: () => request<SetupStatus>('GET', '/setup/status'),
    initialize: (payload: SetupPayload) => request<{ message: string }>('POST', '/setup', payload)
};

// ── Notes ─────────────────────────────────────────────────────────────────────

export interface CreateNotePayload {
    title: string;
    body: string;
    is_secret: boolean;
    credential?: string;
    color?: string;
    tags?: string[];
}

export interface UpdateNotePayload {
    title?: string;
    body?: string;
    is_pinned?: boolean;
    is_secret?: boolean;
    color?: string;
    credential?: string;
    tags?: string[];
}

export const notes = {
    list: () => request<Note[]>('GET', '/notes'),
    get: (id: string) => request<Note>('GET', `/notes/${id}`),
    create: (payload: CreateNotePayload) => request<Note>('POST', '/notes', payload),
    update: (id: string, payload: UpdateNotePayload) => request<Note>('PUT', `/notes/${id}`, payload),
    delete: (id: string) => request<{ message: string }>('DELETE', `/notes/${id}`),
    unlock: (id: string, credential: string) =>
        request<Note>('POST', `/notes/${id}/unlock`, { credential })
};

// ── Attachments ───────────────────────────────────────────────────────────────

export const attachments = {
    list: (noteId: string) => request<Attachment[]>('GET', `/notes/${noteId}/attachments`),

    upload: (noteId: string, file: File) => {
        const fd = new FormData();
        fd.append('file', file, file.name);
        return requestFormData<Attachment>('POST', `/notes/${noteId}/attachments`, fd);
    },

    delete: (id: string) => request<{ message: string }>('DELETE', `/attachments/${id}`),

    contentUrl: async (id: string): Promise<string> => {
        const base = await getBase();
        return `${base}/attachments/${id}/content`;
    },

    async fetchBlobUrl(id: string): Promise<string> {
        const base = await getBase();
        const headers: Record<string, string> = { 'X-Client-Type': 'capacitor' };
        if (accessToken) headers['Authorization'] = `Bearer ${accessToken}`;
        const res = await fetch(`${base}/attachments/${id}/content`, { headers });
        if (res.status === 401) {
            const refreshed = await tryRefresh();
            if (refreshed) return attachments.fetchBlobUrl(id);
        }
        if (!res.ok) throw new Error(`Failed to load attachment: ${res.status}`);
        const blob = await res.blob();
        return URL.createObjectURL(blob);
    }
};

// ── Tags ───────────────────────────────────────────────────────────────────────

export const tags = {
    list: () => request<Tag[]>('GET', '/tags'),
    create: (name: string, emoji: string) => request<Tag>('POST', '/tags', { name, emoji }),
    update: (id: string, payload: { name?: string; emoji?: string }) =>
        request<Tag>('PUT', `/tags/${id}`, payload),
    delete: (id: string) => request<{ message: string }>('DELETE', `/tags/${id}`)
};

// ── Admin ──────────────────────────────────────────────────────────────────────

export const admin = {
    listUsers: () => request<User[]>('GET', '/admin/users'),
    createUser: (payload: { username: string; email: string; password: string; is_admin: boolean }) =>
        request<User>('POST', '/admin/users', payload),
    updateUser: (
        id: string,
        payload: { username?: string; email?: string; password?: string; is_admin?: boolean }
    ) => request<User>('PUT', `/admin/users/${id}`, payload),
    deleteUser: (id: string) => request<{ message: string }>('DELETE', `/admin/users/${id}`),
    getSettings: () => request<AdminSettings>('GET', '/admin/settings'),
    setSelfRegistration: (enabled: boolean) =>
        request<AdminSettings>('PUT', '/admin/settings/self-registration', { enabled })
};
