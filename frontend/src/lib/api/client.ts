// Typed API client for the migajas backend

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

export interface Note {
    id: string;
    user_id: string;
    title: string;
    body: string | null; // null when secret and locked
    is_secret: boolean;
    is_locked: boolean;
    is_pinned: boolean;
    color: string;
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
    user: User;
}

const BASE = '/api';

let accessToken: string | null = null;

export function setAccessToken(t: string | null) {
    accessToken = t;
}
export function getAccessToken(): string | null {
    return accessToken;
}

async function request<T>(
    method: string,
    path: string,
    body?: unknown,
    retry = true
): Promise<T> {
    const headers: Record<string, string> = {
        'Content-Type': 'application/json'
    };
    if (accessToken) headers['Authorization'] = `Bearer ${accessToken}`;

    const res = await fetch(BASE + path, {
        method,
        headers,
        credentials: 'include', // send httpOnly refresh cookie
        body: body !== undefined ? JSON.stringify(body) : undefined
    });

    // Auto-refresh on 401
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
        const data = await request<{ access_token: string }>('POST', '/auth/refresh', undefined, false);
        setAccessToken(data.access_token);
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

// ── Auth ──────────────────────────────────────────────────────────────────────

export const auth = {
    register: (username: string, email: string, password: string) =>
        request<{ message: string }>('POST', '/auth/register', { username, email, password }),

    login: (username_or_email: string, password: string) =>
        request<LoginResponse>('POST', '/auth/login', { username_or_email, password }),

    logout: () => request<{ message: string }>('POST', '/auth/logout'),

    me: () => request<User>('GET', '/auth/me'),

    setupVault: (type: 'pin' | 'password', credential: string) =>
        request<{ message: string }>('POST', '/auth/vault', { type, credential })
};

// ── Notes ─────────────────────────────────────────────────────────────────────

export interface CreateNotePayload {
    title: string;
    body: string;
    is_secret: boolean;
    credential?: string;
    color?: string;
}

export interface UpdateNotePayload {
    title?: string;
    body?: string;
    is_pinned?: boolean;
    is_secret?: boolean;
    color?: string;
    credential?: string;
}

export interface SetupPayload {
    username: string;
    email: string;
    password: string;
    allow_self_registration: boolean;
}

// ── Setup ────────────────────────────────────────────────────────────────────

export const setup = {
    status: () => request<SetupStatus>('GET', '/setup/status'),
    initialize: (payload: SetupPayload) => request<{ message: string }>('POST', '/setup', payload)
};

// ── Notes ─────────────────────────────────────────────────────────────────────

export const notes = {
    list: () => request<Note[]>('GET', '/notes'),

    get: (id: string) => request<Note>('GET', `/notes/${id}`),

    create: (payload: CreateNotePayload) => request<Note>('POST', '/notes', payload),

    update: (id: string, payload: UpdateNotePayload) =>
        request<Note>('PUT', `/notes/${id}`, payload),

    delete: (id: string) => request<{ message: string }>('DELETE', `/notes/${id}`),

    unlock: (id: string, credential: string) =>
        request<Note>('POST', `/notes/${id}/unlock`, { credential })
};

// ── Attachments ───────────────────────────────────────────────────────────────

async function requestFormData<T>(method: string, path: string, formData: FormData): Promise<T> {
    const headers: Record<string, string> = {};
    if (accessToken) headers['Authorization'] = `Bearer ${accessToken}`;
    // Do NOT set Content-Type — browser must set it with the multipart boundary

    const res = await fetch(BASE + path, {
        method,
        headers,
        credentials: 'include',
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

export const attachments = {
    list: (noteId: string) =>
        request<Attachment[]>('GET', `/notes/${noteId}/attachments`),

    upload: (noteId: string, file: File) => {
        const fd = new FormData();
        fd.append('file', file, file.name);
        return requestFormData<Attachment>('POST', `/notes/${noteId}/attachments`, fd);
    },

    delete: (id: string) =>
        request<{ message: string }>('DELETE', `/attachments/${id}`),

    /** Returns the URL to stream/download an attachment (same-origin). */
    contentUrl: (id: string) => `${BASE}/attachments/${id}/content`,

    /**
     * Fetches an attachment content with the auth header and returns a
     * revocable object URL (blob URL). The caller is responsible for
     * calling URL.revokeObjectURL() when done.
     */
    async fetchBlobUrl(id: string): Promise<string> {
        const headers: Record<string, string> = {};
        if (accessToken) headers['Authorization'] = `Bearer ${accessToken}`;
        const res = await fetch(`${BASE}/attachments/${id}/content`, {
            headers,
            credentials: 'include'
        });
        if (res.status === 401) {
            const refreshed = await tryRefresh();
            if (refreshed) return attachments.fetchBlobUrl(id);
        }
        if (!res.ok) throw new Error(`Failed to load attachment: ${res.status}`);
        const blob = await res.blob();
        return URL.createObjectURL(blob);
    }
};

// ── Admin ──────────────────────────────────────────────────────────────────────

export const admin = {
    listUsers: () => request<User[]>('GET', '/admin/users'),
    createUser: (payload: { username: string; email: string; password: string; is_admin: boolean }) =>
        request<User>('POST', '/admin/users', payload),
    updateUser: (id: string, payload: { username?: string; email?: string; password?: string; is_admin?: boolean }) =>
        request<User>('PUT', `/admin/users/${id}`, payload),
    deleteUser: (id: string) => request<{ message: string }>('DELETE', `/admin/users/${id}`),
};
