<script lang="ts">
    import { onMount } from "svelte";
    import { goto } from "$app/navigation";
    import { admin as adminApi, type User } from "$lib/api/client";
    import { currentUser } from "$lib/stores/auth";

    // ── Self-registration setting ─────────────────────────────────────────────
    let selfRegistration = false;
    let srLoading = false;
    let srError = "";

    // ── State ─────────────────────────────────────────────────────────────────
    let users: User[] = [];
    let loading = true;
    let error = "";

    // ── Create form ───────────────────────────────────────────────────────────
    let showCreate = false;
    let createUsername = "";
    let createEmail = "";
    let createPassword = "";
    let createIsAdmin = false;
    let createError = "";
    let createLoading = false;

    // ── Edit modal ────────────────────────────────────────────────────────────
    let editingUser: User | null = null;
    let editUsername = "";
    let editEmail = "";
    let editPassword = "";
    let editIsAdmin = false;
    let editError = "";
    let editLoading = false;

    // ── Delete confirm ────────────────────────────────────────────────────────
    let deletingUser: User | null = null;
    let deleteLoading = false;

    // ── Helpers ───────────────────────────────────────────────────────────────
    function fmtDate(iso: string): string {
        const d = new Date(iso);
        const p = (n: number) => String(n).padStart(2, "0");
        return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
    }

    // ── Load ──────────────────────────────────────────────────────────────────
    onMount(async () => {
        if (!$currentUser?.is_admin) {
            goto("/");
            return;
        }
        await Promise.all([loadUsers(), loadSettings()]);
    });

    async function loadSettings() {
        try {
            const s = await adminApi.getSettings();
            selfRegistration = s.allow_self_registration;
        } catch {
            // non-fatal
        }
    }

    async function toggleSelfRegistration() {
        srError = "";
        srLoading = true;
        try {
            const s = await adminApi.setSelfRegistration(!selfRegistration);
            selfRegistration = s.allow_self_registration;
        } catch (e) {
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
        } catch (e) {
            error = e instanceof Error ? e.message : "Failed to load users";
        } finally {
            loading = false;
        }
    }

    // ── Create ────────────────────────────────────────────────────────────────
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
        } catch (e) {
            createError = e instanceof Error ? e.message : "Failed to create user";
        } finally {
            createLoading = false;
        }
    }

    // ── Edit ──────────────────────────────────────────────────────────────────
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
        } catch (e) {
            editError = e instanceof Error ? e.message : "Failed to update user";
        } finally {
            editLoading = false;
        }
    }

    // ── Delete ────────────────────────────────────────────────────────────────
    async function confirmDelete() {
        if (!deletingUser) return;
        deleteLoading = true;
        try {
            await adminApi.deleteUser(deletingUser.id);
            users = users.filter((u) => u.id !== deletingUser!.id);
            deletingUser = null;
        } catch (e) {
            alert(e instanceof Error ? e.message : "Failed to delete user");
        } finally {
            deleteLoading = false;
        }
    }
</script>

<svelte:head>
    <title>Users — migajas</title>
</svelte:head>

<div class="min-h-screen bg-muted">
    <!-- Header -->
    <nav class="flex items-center justify-between h-16 border-b border-border bg-card border-b border-border px-4">
        <div class="flex-none">
            <a href="/" class="h-9 px-3 rounded-md hover:bg-muted text-sm inline-flex items-center justify-center gap-1">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="m15 18-6-6 6-6" />
                </svg>
                Back
            </a>
        </div>
        <div class="flex-1 px-3">
            <h1 class="font-bold text-base">Users</h1>
        </div>
        <div class="flex-none">
            <button class="h-10 px-4 py-2 bg-primary text-primary-foreground hover:bg-primary/90 rounded-md inline-flex items-center justify-center gap-1.5" on:click={() => (showCreate = !showCreate)} type="button">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                    <path d="M12 5v14M5 12h14" />
                </svg>
                Add User
            </button>
        </div>
    </nav>

    <div class="max-w-4xl mx-auto px-4 py-6 flex flex-col gap-4">
        <!-- Self-registration toggle -->
        <div class="rounded-lg border border-border shadow-sm bg-card border border-border shadow-sm">
            <div class="rounded-lg border border-border shadow-sm-body p-4">
                <div class="flex items-center justify-between gap-4">
                    <div>
                        <p class="font-semibold text-sm">Allow self-registration</p>
                        <p class="text-xs text-foreground/80 mt-0.5">When enabled, anyone can create an account on the login page.</p>
                        {#if srError}
                            <p class="text-xs text-destructive mt-1">{srError}</p>
                        {/if}
                    </div>
                    <label class="cursor-pointer flex items-center gap-2">
                        {#if srLoading}
                            <span class="loading loading-spinner loading-xs text-primary" />
                        {/if}
                        <input type="checkbox" class="toggle toggle-primary toggle-sm" checked={selfRegistration} disabled={srLoading} on:change={toggleSelfRegistration} />
                    </label>
                </div>
            </div>
        </div>

        <!-- Create form -->
        {#if showCreate}
            <div class="rounded-lg border border-border shadow-sm bg-card border border-border shadow-sm">
                <div class="rounded-lg border border-border shadow-sm-body p-5 gap-4">
                    <h2 class="font-semibold text-base">New User</h2>
                    {#if createError}
                        <div class="bg-destructive text-destructive-foreground px-4 py-3 rounded-md text-sm py-2">{createError}</div>
                    {/if}
                    <div class="grid grid-cols-1 sm:grid-cols-2 gap-3">
                        <label class="form-control">
                            <div class="flex flex-col gap-1.5 py-0.5"><span class="flex flex-col gap-1.5-text text-xs">Username</span></div>
                            <input class="flex h-10 w-full rounded-md border border-border bg-background px-3 py-2 text-sm" type="text" placeholder="username" bind:value={createUsername} />
                        </label>
                        <label class="form-control">
                            <div class="flex flex-col gap-1.5 py-0.5"><span class="flex flex-col gap-1.5-text text-xs">Email</span></div>
                            <input class="flex h-10 w-full rounded-md border border-border bg-background px-3 py-2 text-sm" type="email" placeholder="user@example.com" bind:value={createEmail} />
                        </label>
                        <label class="form-control">
                            <div class="flex flex-col gap-1.5 py-0.5"><span class="flex flex-col gap-1.5-text text-xs">Password</span></div>
                            <input class="flex h-10 w-full rounded-md border border-border bg-background px-3 py-2 text-sm" type="password" placeholder="min. 8 characters" bind:value={createPassword} />
                        </label>
                        <label class="form-control justify-end">
                            <label class="flex flex-col gap-1.5 cursor-pointer justify-start gap-3 pb-1">
                                <input type="checkbox" class="toggle toggle-sm toggle-primary" bind:checked={createIsAdmin} />
                                <span class="flex flex-col gap-1.5-text text-xs">Admin user</span>
                            </label>
                        </label>
                    </div>
                    <div class="flex justify-end gap-2">
                        <button class="h-9 px-3 rounded-md hover:bg-muted text-sm inline-flex items-center justify-center" on:click={() => (showCreate = false)} type="button">Cancel</button>
                        <button class="h-10 px-4 py-2 bg-primary text-primary-foreground hover:bg-primary/90 rounded-md inline-flex items-center justify-center" on:click={submitCreate} disabled={createLoading} type="button">
                            {#if createLoading}<span class="loading loading-spinner loading-xs" />{/if}
                            Create
                        </button>
                    </div>
                </div>
            </div>
        {/if}

        <!-- Users table -->
        <div class="rounded-lg border border-border shadow-sm bg-card border border-border shadow-sm overflow-x-auto">
            {#if loading}
                <div class="flex justify-center py-16">
                    <span class="loading loading-spinner loading-md text-primary" />
                </div>
            {:else if error}
                <div class="p-6">
                    <div class="bg-destructive text-destructive-foreground px-4 py-3 rounded-md text-sm">{error}</div>
                </div>
            {:else if users.length === 0}
                <div class="p-10 text-center text-muted-foreground text-sm">No users found.</div>
            {:else}
                <table class="table table-sm">
                    <thead>
                        <tr>
                            <th>Username</th>
                            <th>Email</th>
                            <th>Role</th>
                            <th>Created</th>
                            <th class="text-right">Actions</th>
                        </tr>
                    </thead>
                    <tbody>
                        {#each users as u (u.id)}
                            <tr class="hover">
                                <td class="font-medium">
                                    {u.username}
                                    {#if u.id === $currentUser?.id}
                                        <span class="text-xs px-2 py-1 rounded bg-muted text-muted-foreground inline-flex items-center ml-1">you</span>
                                    {/if}
                                </td>
                                <td class="text-foreground/80">{u.email}</td>
                                <td>
                                    {#if u.is_admin}
                                        <span class="text-xs px-2 py-1 rounded bg-primary text-primary-foreground inline-flex items-center">Admin</span>
                                    {:else}
                                        <span class="text-xs px-2 py-1 rounded bg-muted text-muted-foreground inline-flex items-center">User</span>
                                    {/if}
                                </td>
                                <td class="text-xs text-muted-foreground">{fmtDate(u.created_at)}</td>
                                <td class="text-right">
                                    <div class="flex justify-end gap-1">
                                        <button class="h-8 w-8 rounded-md hover:bg-muted p-0 inline-flex items-center justify-center" title="Edit" on:click={() => openEdit(u)} type="button">
                                            <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
                                                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
                                            </svg>
                                        </button>
                                        <button class="h-8 w-8 rounded-md hover:bg-muted p-0 inline-flex items-center justify-center text-destructive" title="Delete" disabled={u.id === $currentUser?.id} on:click={() => (deletingUser = u)} type="button">
                                            <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                                <polyline points="3 6 5 6 21 6" /><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" />
                                            </svg>
                                        </button>
                                    </div>
                                </td>
                            </tr>
                        {/each}
                    </tbody>
                </table>
            {/if}
        </div>
    </div>
</div>

<!-- Edit modal -->
{#if editingUser}
    <div class="modal modal-open">
        <div class="modal-box max-w-md">
            <h3 class="font-bold text-lg mb-4">Edit User — {editingUser.username}</h3>
            {#if editError}
                <div class="bg-destructive text-destructive-foreground px-4 py-3 rounded-md text-sm py-2 mb-3">{editError}</div>
            {/if}
            <div class="flex flex-col gap-3">
                <label class="form-control">
                    <div class="flex flex-col gap-1.5 py-0.5"><span class="flex flex-col gap-1.5-text text-xs">Username</span></div>
                    <input class="flex h-10 w-full rounded-md border border-border bg-background px-3 py-2 text-sm" type="text" bind:value={editUsername} />
                </label>
                <label class="form-control">
                    <div class="flex flex-col gap-1.5 py-0.5"><span class="flex flex-col gap-1.5-text text-xs">Email</span></div>
                    <input class="flex h-10 w-full rounded-md border border-border bg-background px-3 py-2 text-sm" type="email" bind:value={editEmail} />
                </label>
                <label class="form-control">
                    <div class="flex flex-col gap-1.5 py-0.5"><span class="flex flex-col gap-1.5-text text-xs">New Password <span class="text-muted-foreground">(leave blank to keep current)</span></span></div>
                    <input class="flex h-10 w-full rounded-md border border-border bg-background px-3 py-2 text-sm" type="password" placeholder="min. 8 characters" bind:value={editPassword} />
                </label>
                <label class="flex flex-col gap-1.5 cursor-pointer justify-start gap-3 p-0">
                    <input type="checkbox" class="toggle toggle-sm toggle-primary" bind:checked={editIsAdmin} />
                    <span class="flex flex-col gap-1.5-text text-xs">Admin user</span>
                </label>
            </div>
            <div class="modal-action mt-5">
                <button class="h-9 px-3 rounded-md hover:bg-muted text-sm inline-flex items-center justify-center" on:click={() => (editingUser = null)} type="button">Cancel</button>
                <button class="h-10 px-4 py-2 bg-primary text-primary-foreground hover:bg-primary/90 rounded-md inline-flex items-center justify-center" on:click={submitEdit} disabled={editLoading} type="button">
                    {#if editLoading}<span class="loading loading-spinner loading-xs" />{/if}
                    Save Changes
                </button>
            </div>
        </div>
        <div class="modal-backdrop" on:click={() => (editingUser = null)} role="presentation" />
    </div>
{/if}

<!-- Delete confirm modal -->
{#if deletingUser}
    <div class="modal modal-open">
        <div class="modal-box max-w-sm">
            <h3 class="font-bold text-lg">Delete User</h3>
            <p class="py-4 text-sm">
                Are you sure you want to delete <strong>{deletingUser.username}</strong>? All their notes and attachments will be permanently removed.
            </p>
            <div class="modal-action">
                <button class="h-9 px-3 rounded-md hover:bg-muted text-sm inline-flex items-center justify-center" on:click={() => (deletingUser = null)} type="button">Cancel</button>
                <button class="h-10 px-4 py-2 bg-destructive text-destructive-foreground hover:bg-destructive/90 rounded-md inline-flex items-center justify-center" on:click={confirmDelete} disabled={deleteLoading} type="button">
                    {#if deleteLoading}<span class="loading loading-spinner loading-xs" />{/if}
                    Delete
                </button>
            </div>
        </div>
        <div class="modal-backdrop" on:click={() => (deletingUser = null)} role="presentation" />
    </div>
{/if}
