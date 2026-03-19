<script lang="ts">
    import { onMount } from "svelte";
    import { push } from "svelte-spa-router";
    import { admin as adminApi, type User } from "$lib/api/client";
    import { currentUser } from "$lib/stores/auth";

    let selfRegistration = false;
    let srLoading = false;
    let srError = "";

    let users: User[] = [];
    let loading = true;
    let error = "";

    // Create form
    let showCreate = false;
    let createUsername = "";
    let createEmail = "";
    let createPassword = "";
    let createIsAdmin = false;
    let createError = "";
    let createLoading = false;

    // Edit modal
    let editingUser: User | null = null;
    let editUsername = "";
    let editEmail = "";
    let editPassword = "";
    let editIsAdmin = false;
    let editError = "";
    let editLoading = false;

    // Delete confirm
    let deletingUser: User | null = null;
    let deleteLoading = false;

    function fmtDate(iso: string): string {
        const d = new Date(iso);
        const p = (n: number) => String(n).padStart(2, "0");
        return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
    }

    onMount(async () => {
        if (!$currentUser?.is_admin) {
            push("/");
            return;
        }
        await Promise.all([loadUsers(), loadSettings()]);
    });

    async function loadSettings() {
        try {
            const s = await adminApi.getSettings();
            selfRegistration = s.allow_self_registration;
        } catch {
            /* non-fatal */
        }
    }

    async function toggleSelfRegistration() {
        srError = "";
        srLoading = true;
        try {
            const s = await adminApi.setSelfRegistration(!selfRegistration);
            selfRegistration = s.allow_self_registration;
        } catch (e: unknown) {
            srError = e instanceof Error ? e.message : "Failed to update setting";
        } finally {
            srLoading = false;
        }
    }

    async function loadUsers() {
        loading = true;
        error = "";
        try {
            users = await adminApi.listUsers();
        } catch (e: unknown) {
            error = e instanceof Error ? e.message : "Failed to load users";
        } finally {
            loading = false;
        }
    }

    async function submitCreate() {
        createError = "";
        createLoading = true;
        try {
            const u = await adminApi.createUser({
                username: createUsername.trim(),
                email: createEmail.trim(),
                password: createPassword,
                is_admin: createIsAdmin,
            });
            users = [...users, u];
            showCreate = false;
            createUsername = "";
            createEmail = "";
            createPassword = "";
            createIsAdmin = false;
        } catch (e: unknown) {
            createError = e instanceof Error ? e.message : "Failed to create user";
        } finally {
            createLoading = false;
        }
    }

    function openEdit(u: User) {
        editingUser = u;
        editUsername = u.username;
        editEmail = u.email;
        editPassword = "";
        editIsAdmin = u.is_admin;
        editError = "";
    }

    async function submitEdit() {
        if (!editingUser) return;
        editError = "";
        editLoading = true;
        try {
            const payload: { username?: string; email?: string; password?: string; is_admin?: boolean } = {
                username: editUsername.trim(),
                email: editEmail.trim(),
                is_admin: editIsAdmin,
            };
            if (editPassword) payload.password = editPassword;
            const updated = await adminApi.updateUser(editingUser.id, payload);
            users = users.map((u) => (u.id === updated.id ? updated : u));
            editingUser = null;
        } catch (e: unknown) {
            editError = e instanceof Error ? e.message : "Failed to update user";
        } finally {
            editLoading = false;
        }
    }

    async function confirmDelete() {
        if (!deletingUser) return;
        deleteLoading = true;
        try {
            await adminApi.deleteUser(deletingUser.id);
            users = users.filter((u) => u.id !== deletingUser!.id);
            deletingUser = null;
        } catch (e: unknown) {
            alert(e instanceof Error ? e.message : "Failed to delete user");
        } finally {
            deleteLoading = false;
        }
    }
</script>

<div class="admin-screen">
    <header class="admin-header">
        <h1 class="admin-title">Admin</h1>
        <button class="fab-add" on:click={() => (showCreate = !showCreate)} type="button" title="Add user">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                <path d="M12 5v14M5 12h14" />
            </svg>
        </button>
    </header>

    <div class="admin-body">
        <!-- Self-registration toggle -->
        <div class="card">
            <div class="card-body row-between">
                <div>
                    <p class="row-title">Allow self-registration</p>
                    <p class="row-desc">Anyone can create an account on the login page.</p>
                    {#if srError}
                        <p class="error-text">{srError}</p>
                    {/if}
                </div>
                <label class="toggle-wrap">
                    {#if srLoading}
                        <span class="spinner" />
                    {/if}
                    <input type="checkbox" class="toggle-checkbox" checked={selfRegistration} disabled={srLoading} on:change={toggleSelfRegistration} />
                </label>
            </div>
        </div>

        <!-- Create user form -->
        {#if showCreate}
            <div class="card">
                <div class="card-header">
                    <h2 class="section-label">New User</h2>
                    <button class="btn-ghost-sm" on:click={() => (showCreate = false)} type="button">Cancel</button>
                </div>
                <div class="card-body">
                    {#if createError}
                        <div class="alert alert-error">{createError}</div>
                    {/if}
                    <div class="field">
                        <label class="field-label" for="cu-username">Username</label>
                        <input id="cu-username" type="text" class="field-input" placeholder="username" bind:value={createUsername} autocapitalize="none" />
                    </div>
                    <div class="field">
                        <label class="field-label" for="cu-email">Email</label>
                        <input id="cu-email" type="email" class="field-input" placeholder="user@example.com" bind:value={createEmail} />
                    </div>
                    <div class="field">
                        <label class="field-label" for="cu-pass">Password</label>
                        <input id="cu-pass" type="password" class="field-input" placeholder="min. 8 characters" bind:value={createPassword} />
                    </div>
                    <label class="toggle-row-label">
                        <input type="checkbox" class="toggle-checkbox" bind:checked={createIsAdmin} />
                        <span class="field-label">Admin user</span>
                    </label>
                    <button class="btn-primary" on:click={submitCreate} disabled={createLoading || !createUsername || !createEmail || !createPassword} type="button">
                        {#if createLoading}<span class="spinner" />{/if}
                        Create user
                    </button>
                </div>
            </div>
        {/if}

        <!-- User list -->
        {#if loading}
            <div class="center-pad">
                <span class="spinner spinner-lg" />
            </div>
        {:else if error}
            <div class="alert alert-error">{error}</div>
        {:else if users.length === 0}
            <div class="empty-state">No users found.</div>
        {:else}
            {#each users as u (u.id)}
                <div class="user-card">
                    <div class="user-avatar">
                        {u.username[0]?.toUpperCase() ?? "?"}
                    </div>
                    <div class="user-info">
                        <div class="user-name-row">
                            <span class="user-name">{u.username}</span>
                            {#if u.id === $currentUser?.id}
                                <span class="badge badge-muted">you</span>
                            {/if}
                            {#if u.is_admin}
                                <span class="badge badge-primary">Admin</span>
                            {/if}
                        </div>
                        <p class="user-email">{u.email}</p>
                        <p class="user-date">{fmtDate(u.created_at)}</p>
                    </div>
                    <div class="user-actions">
                        <button class="icon-btn" on:click={() => openEdit(u)} title="Edit" type="button">
                            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
                                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
                            </svg>
                        </button>
                        <button class="icon-btn icon-btn-danger" on:click={() => (deletingUser = u)} title="Delete" disabled={u.id === $currentUser?.id} type="button">
                            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <polyline points="3 6 5 6 21 6" /><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" />
                            </svg>
                        </button>
                    </div>
                </div>
            {/each}
        {/if}
    </div>
</div>

<!-- Edit user bottom sheet -->
{#if editingUser}
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <!-- svelte-ignore a11y-no-static-element-interactions -->
    <div class="sheet-backdrop" on:click={() => (editingUser = null)} />
    <div class="sheet">
        <div class="sheet-pill" />
        <h3 class="sheet-title">Edit User — {editingUser.username}</h3>
        {#if editError}
            <div class="alert alert-error">{editError}</div>
        {/if}
        <div class="field">
            <label class="field-label" for="eu-username">Username</label>
            <input id="eu-username" type="text" class="field-input" bind:value={editUsername} autocapitalize="none" />
        </div>
        <div class="field">
            <label class="field-label" for="eu-email">Email</label>
            <input id="eu-email" type="email" class="field-input" bind:value={editEmail} />
        </div>
        <div class="field">
            <label class="field-label" for="eu-pass">New password <span class="muted">(leave blank to keep current)</span></label>
            <input id="eu-pass" type="password" class="field-input" placeholder="min. 8 characters" bind:value={editPassword} />
        </div>
        <label class="toggle-row-label">
            <input type="checkbox" class="toggle-checkbox" bind:checked={editIsAdmin} />
            <span class="field-label">Admin user</span>
        </label>
        <div class="sheet-footer">
            <button class="btn-ghost" on:click={() => (editingUser = null)} type="button">Cancel</button>
            <button class="btn-primary" on:click={submitEdit} disabled={editLoading} type="button">
                {#if editLoading}<span class="spinner" />{/if}
                Save changes
            </button>
        </div>
    </div>
{/if}

<!-- Delete confirm bottom sheet -->
{#if deletingUser}
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <!-- svelte-ignore a11y-no-static-element-interactions -->
    <div class="sheet-backdrop" on:click={() => (deletingUser = null)} />
    <div class="sheet">
        <div class="sheet-pill" />
        <h3 class="sheet-title sheet-title-danger">Delete User</h3>
        <p class="body-text">
            Are you sure you want to delete <strong>{deletingUser.username}</strong>? All their notes and attachments will be permanently removed.
        </p>
        <div class="sheet-footer">
            <button class="btn-ghost" on:click={() => (deletingUser = null)} type="button">Cancel</button>
            <button class="btn-danger" on:click={confirmDelete} disabled={deleteLoading} type="button">
                {#if deleteLoading}<span class="spinner" />{/if}
                Delete
            </button>
        </div>
    </div>
{/if}

<style>
    .admin-screen {
        min-height: 100dvh;
        background: var(--color-bg);
        display: flex;
        flex-direction: column;
        padding-bottom: calc(70px + env(safe-area-inset-bottom));
    }

    .admin-header {
        display: flex;
        align-items: center;
        justify-content: space-between;
        padding: 16px 16px 8px;
        border-bottom: 1px solid var(--color-border);
    }

    .admin-title {
        font-size: 22px;
        font-weight: 700;
        color: var(--color-text-primary);
        margin: 0;
    }

    .fab-add {
        width: 38px;
        height: 38px;
        border-radius: 10px;
        border: none;
        background: var(--color-accent);
        color: #fff;
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
    }

    .admin-body {
        display: flex;
        flex-direction: column;
        gap: 12px;
        padding: 16px;
    }

    .card {
        background: var(--color-surface);
        border-radius: 14px;
        border: 1px solid var(--color-border);
        overflow: hidden;
    }

    .card-header {
        padding: 12px 16px;
        border-bottom: 1px solid var(--color-border);
        display: flex;
        align-items: center;
        justify-content: space-between;
    }

    .card-body {
        padding: 14px 16px;
        display: flex;
        flex-direction: column;
        gap: 12px;
    }

    .section-label {
        font-size: 11px;
        font-weight: 700;
        letter-spacing: 0.06em;
        text-transform: uppercase;
        color: var(--color-text-muted);
        margin: 0;
    }

    .row-between {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 12px;
    }

    .row-title {
        font-size: 14px;
        font-weight: 500;
        color: var(--color-text-primary);
        margin: 0;
    }

    .row-desc {
        font-size: 12px;
        color: var(--color-text-muted);
        margin: 2px 0 0;
    }

    .toggle-wrap {
        display: flex;
        align-items: center;
        gap: 8px;
        cursor: pointer;
    }

    .toggle-row-label {
        display: flex;
        align-items: center;
        gap: 10px;
        cursor: pointer;
    }

    .toggle-checkbox {
        width: 18px;
        height: 18px;
        accent-color: var(--color-accent);
        cursor: pointer;
        flex-shrink: 0;
    }

    .field {
        display: flex;
        flex-direction: column;
        gap: 5px;
    }

    .field-label {
        font-size: 12px;
        font-weight: 600;
        color: var(--color-text-muted);
    }

    .muted {
        font-weight: 400;
        color: var(--color-text-muted);
    }

    .field-input {
        width: 100%;
        height: 44px;
        padding: 0 14px;
        border-radius: 10px;
        border: 1.5px solid var(--color-border);
        background: var(--color-bg);
        color: var(--color-text-primary);
        font-size: 16px;
        outline: none;
        box-sizing: border-box;
        transition: border-color 0.15s;
    }

    .field-input:focus {
        border-color: var(--color-accent);
    }

    .alert {
        font-size: 13px;
        padding: 10px 12px;
        border-radius: 8px;
        line-height: 1.4;
    }

    .alert-error {
        background: rgba(239, 68, 68, 0.1);
        border: 1px solid rgba(239, 68, 68, 0.3);
        color: #dc2626;
    }

    .error-text {
        font-size: 12px;
        color: #dc2626;
        margin: 4px 0 0;
    }

    .btn-primary {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
        height: 46px;
        border-radius: 12px;
        border: none;
        background: var(--color-accent);
        color: #fff;
        font-size: 15px;
        font-weight: 600;
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
        transition: opacity 0.15s;
    }

    .btn-primary:disabled {
        opacity: 0.45;
        cursor: not-allowed;
    }

    .btn-ghost {
        height: 44px;
        padding: 0 16px;
        border-radius: 10px;
        border: 1.5px solid var(--color-border);
        background: transparent;
        color: var(--color-text-primary);
        font-size: 15px;
        font-weight: 500;
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
        flex: 1;
    }

    .btn-ghost-sm {
        height: 30px;
        padding: 0 12px;
        border-radius: 8px;
        border: 1.5px solid var(--color-border);
        background: transparent;
        color: var(--color-text-primary);
        font-size: 13px;
        font-weight: 500;
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
    }

    .btn-danger {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
        height: 44px;
        padding: 0 16px;
        border-radius: 10px;
        border: none;
        background: #dc2626;
        color: #fff;
        font-size: 15px;
        font-weight: 600;
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
        transition: opacity 0.15s;
        flex: 1;
    }

    .btn-danger:disabled {
        opacity: 0.45;
    }

    .center-pad {
        display: flex;
        justify-content: center;
        padding: 40px 0;
    }

    .empty-state {
        text-align: center;
        font-size: 14px;
        color: var(--color-text-muted);
        padding: 40px 0;
    }

    .user-card {
        display: flex;
        align-items: center;
        gap: 12px;
        background: var(--color-surface);
        border-radius: 14px;
        border: 1px solid var(--color-border);
        padding: 12px 14px;
    }

    .user-avatar {
        width: 40px;
        height: 40px;
        border-radius: 50%;
        background: rgba(var(--accent-rgb, 99, 102, 241), 0.15);
        border: 1.5px solid rgba(var(--accent-rgb, 99, 102, 241), 0.3);
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 16px;
        font-weight: 700;
        color: var(--color-accent);
        flex-shrink: 0;
    }

    .user-info {
        flex: 1;
        min-width: 0;
    }

    .user-name-row {
        display: flex;
        align-items: center;
        gap: 6px;
        flex-wrap: wrap;
    }

    .user-name {
        font-size: 14px;
        font-weight: 600;
        color: var(--color-text-primary);
    }

    .user-email {
        font-size: 12px;
        color: var(--color-text-muted);
        margin: 2px 0 0;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
    }

    .user-date {
        font-size: 11px;
        color: var(--color-text-muted);
        margin: 2px 0 0;
    }

    .user-actions {
        display: flex;
        gap: 4px;
        flex-shrink: 0;
    }

    .icon-btn {
        width: 34px;
        height: 34px;
        border-radius: 8px;
        border: none;
        background: transparent;
        color: var(--color-text-secondary);
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
        transition: background 0.15s;
    }

    .icon-btn:hover {
        background: var(--color-border);
    }

    .icon-btn-danger {
        color: #dc2626;
    }

    .icon-btn:disabled {
        opacity: 0.3;
        cursor: not-allowed;
    }

    .badge {
        font-size: 10px;
        padding: 1px 7px;
        border-radius: 100px;
        font-weight: 600;
    }

    .badge-muted {
        background: var(--color-border);
        color: var(--color-text-secondary);
    }

    .badge-primary {
        background: var(--color-accent);
        color: #fff;
    }

    /* Bottom sheet */
    .sheet-backdrop {
        position: fixed;
        inset: 0;
        background: rgba(0, 0, 0, 0.5);
        z-index: 50;
    }

    .sheet {
        position: fixed;
        left: 0;
        right: 0;
        bottom: 0;
        z-index: 51;
        background: var(--color-surface);
        border-radius: 20px 20px 0 0;
        padding: 16px 20px calc(20px + env(safe-area-inset-bottom));
        display: flex;
        flex-direction: column;
        gap: 14px;
        max-height: 80dvh;
        overflow-y: auto;
    }

    .sheet-pill {
        width: 36px;
        height: 4px;
        border-radius: 2px;
        background: var(--color-border);
        align-self: center;
        margin-bottom: 4px;
    }

    .sheet-title {
        font-size: 18px;
        font-weight: 700;
        color: var(--color-text-primary);
        margin: 0;
    }

    .sheet-title-danger {
        color: #dc2626;
    }

    .sheet-footer {
        display: flex;
        gap: 10px;
        margin-top: 4px;
    }

    .body-text {
        font-size: 14px;
        color: var(--color-text-secondary);
        line-height: 1.5;
        margin: 0;
    }

    .spinner {
        display: inline-block;
        width: 16px;
        height: 16px;
        border: 2px solid currentColor;
        border-right-color: transparent;
        border-radius: 50%;
        animation: spin 0.6s linear infinite;
    }

    .spinner-lg {
        width: 28px;
        height: 28px;
    }

    @keyframes spin {
        to {
            transform: rotate(360deg);
        }
    }
</style>
