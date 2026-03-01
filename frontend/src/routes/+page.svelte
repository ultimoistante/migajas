<script lang="ts">
    import { onMount } from "svelte";
    import { notesStore } from "$lib/stores/notes";
    import { tagsStore, selectedTagId } from "$lib/stores/tags";
    import { authStore, currentUser } from "$lib/stores/auth";
    import { theme } from "$lib/stores/theme";
    import { goto } from "$app/navigation";
    import NoteCard from "$lib/components/NoteCard.svelte";
    import NoteModal from "$lib/components/NoteModal.svelte";
    import UnlockModal from "$lib/components/UnlockModal.svelte";
    import type { Note } from "$lib/api/client";

    let loading = true;
    let error = "";

    // Modal state
    let noteModalOpen = false;
    let editingNote: Note | null = null;

    let unlockModalOpen = false;
    let lockingNote: Note | null = null;

    // Search / filter
    let searchQuery = "";

    onMount(async () => {
        try {
            await Promise.all([notesStore.load(), tagsStore.load()]);
        } catch (e: unknown) {
            error = e instanceof Error ? e.message : "Failed to load notes";
        } finally {
            loading = false;
        }
    });

    function openCreateModal() {
        editingNote = null;
        noteModalOpen = true;
    }

    function openEditModal(note: Note) {
        if (note.is_secret && note.is_locked) {
            lockingNote = note;
            unlockModalOpen = true;
        } else {
            editingNote = note;
            noteModalOpen = true;
        }
    }

    function handleUnlocked(e: CustomEvent<Note>) {
        unlockModalOpen = false;
        editingNote = e.detail;
        noteModalOpen = true;
    }

    async function handleDelete(noteId: string) {
        if (!confirm("Delete this note?")) return;
        await notesStore.delete(noteId);
    }

    async function handleTogglePin(noteId: string) {
        const note = $notesStore.find((n) => n.id === noteId);
        if (!note) return;
        await notesStore.update(noteId, { is_pinned: !note.is_pinned });
    }

    async function logout() {
        notesStore.reset();
        tagsStore.reset();
        selectedTagId.set(null);
        await authStore.logout();
        goto("/login");
    }

    $: filtered = $notesStore.filter((n) => {
        if ($selectedTagId && !n.tags?.some((t) => t.id === $selectedTagId)) return false;
        if (!searchQuery) return true;
        const q = searchQuery.toLowerCase();
        return n.title.toLowerCase().includes(q) || (!n.is_locked && n.body?.toLowerCase().includes(q));
    });

    // Note count per tag
    $: noteCountByTag = Object.fromEntries($tagsStore.map((tag) => [tag.id, $notesStore.filter((n) => n.tags?.some((t) => t.id === tag.id)).length]));

    $: pinned = filtered.filter((n) => n.is_pinned);
    $: others = filtered.filter((n) => !n.is_pinned);
</script>

<svelte:head>
    <title>migajas</title>
</svelte:head>

<!-- Navbar -->
<nav class="navbar bg-base-100 border-b border-base-300 px-4 gap-2 sticky top-0 z-30">
    <div class="flex-1 flex items-center">
        <img src="/logo.svg" alt="migajas" class="h-10" />
    </div>

    <!-- Search -->
    <div class="flex-1 max-w-sm">
        <label class="input input-bordered input-sm flex items-center gap-2">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-base-content/40" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="11" cy="11" r="8" /><path d="m21 21-4.35-4.35" />
            </svg>
            <input type="search" class="grow" placeholder="Search notes…" bind:value={searchQuery} />
        </label>
    </div>

    <div class="flex-none flex items-center gap-1">
        <!-- Theme toggle -->
        <button class="btn btn-ghost btn-sm btn-circle" on:click={() => theme.toggle()} title="Toggle theme" type="button">
            {#if $theme === "dark"}
                <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="12" cy="12" r="5" /><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42" />
                </svg>
            {:else}
                <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
                </svg>
            {/if}
        </button>

        <!-- Settings -->
        <a href="/settings" class="btn btn-ghost btn-sm btn-circle" title="Settings">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
            </svg>
        </a>

        <!-- User menu -->
        <div class="dropdown dropdown-end">
            <div tabindex="0" role="button" class="btn btn-ghost btn-sm gap-1">
                <div class="avatar placeholder">
                    <div class="bg-primary text-primary-content rounded-full w-7">
                        <span class="text-xs font-bold">
                            {$currentUser?.username?.[0]?.toUpperCase() ?? "?"}
                        </span>
                    </div>
                </div>
                <span class="hidden sm:inline text-sm">{$currentUser?.username}</span>
            </div>
            <ul tabindex="0" class="dropdown-content menu bg-base-100 rounded-box z-50 w-44 p-1 shadow-lg border border-base-300 mt-1">
                <li><a href="/settings">Settings</a></li>
                {#if $currentUser?.is_admin}
                    <li><a href="/admin">Users</a></li>
                {/if}
                <li><button on:click={logout} type="button">Sign out</button></li>
            </ul>
        </div>
    </div>
</nav>

<!-- Main content -->
<div class="flex">
    <!-- Left sidebar: tag filter — always visible, sticky under navbar -->
    <aside class="w-52 shrink-0 sticky top-16 self-start h-[calc(100vh-4rem)] overflow-y-auto border-r border-base-300 bg-base-100 flex flex-col gap-0.5 p-3">
        <button class="flex items-center justify-between gap-2 px-2 py-1.5 rounded-lg text-sm transition-colors" class:bg-primary={$selectedTagId === null} class:text-primary-content={$selectedTagId === null} class:hover:bg-base-200={$selectedTagId !== null} on:click={() => selectedTagId.set(null)} type="button">
            <span>All notes</span>
            <span class="badge badge-xs">{$notesStore.length}</span>
        </button>
        <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wider px-2 mt-3 mb-1">Tags</p>
        {#each $tagsStore as tag (tag.id)}
            <button class="flex items-center justify-between gap-2 px-2 py-1.5 rounded-lg text-sm transition-colors" class:bg-primary={$selectedTagId === tag.id} class:text-primary-content={$selectedTagId === tag.id} class:hover:bg-base-200={$selectedTagId !== tag.id} on:click={() => selectedTagId.set($selectedTagId === tag.id ? null : tag.id)} type="button">
                <span class="truncate">{tag.emoji ? tag.emoji + " " : ""}{tag.name}</span>
                <span class="badge badge-xs shrink-0">{noteCountByTag[tag.id] ?? 0}</span>
            </button>
        {/each}
        {#if $tagsStore.length === 0}
            <p class="text-xs text-base-content/30 italic px-2 mt-1">No tags yet.<br />Create one in a note.</p>
        {/if}
    </aside>

    <!-- Notes area -->
    <main class="flex-1 min-w-0 px-6 py-6">
        {#if loading}
            <div class="flex justify-center py-20">
                <span class="loading loading-spinner loading-lg text-primary" />
            </div>
        {:else if error}
            <div class="alert alert-error">{error}</div>
        {:else}
            <!-- Pinned -->
            {#if pinned.length > 0}
                <section class="mb-6">
                    <h2 class="text-xs font-semibold text-base-content/50 uppercase tracking-wider mb-3 flex items-center gap-1.5">
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="currentColor">
                            <path d="M12 2a1 1 0 0 1 1 1v1h4a1 1 0 0 1 .7 1.7l-2.7 2.7.3 4.6L18 14a1 1 0 0 1-1 1h-4v6a1 1 0 1 1-2 0v-6H7a1 1 0 0 1-1-1l2.7-1 .3-4.6L6.3 5.7A1 1 0 0 1 7 4h4V3a1 1 0 0 1 1-1z" />
                        </svg>
                        Pinned
                    </h2>
                    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3">
                        {#each pinned as note (note.id)}
                            <NoteCard {note} on:open={(e) => openEditModal(e.detail)} on:delete={(e) => handleDelete(e.detail)} on:togglePin={(e) => handleTogglePin(e.detail)} />
                        {/each}
                    </div>
                </section>
            {/if}

            <!-- All notes -->
            {#if others.length > 0}
                <section>
                    {#if pinned.length > 0}
                        <h2 class="text-xs font-semibold text-base-content/50 uppercase tracking-wider mb-3">Other notes</h2>
                    {/if}
                    <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3">
                        {#each others as note (note.id)}
                            <NoteCard {note} on:open={(e) => openEditModal(e.detail)} on:delete={(e) => handleDelete(e.detail)} on:togglePin={(e) => handleTogglePin(e.detail)} />
                        {/each}
                    </div>
                </section>
            {/if}

            {#if filtered.length === 0}
                <div class="flex flex-col items-center justify-center py-24 gap-4 text-base-content/50">
                    {#if searchQuery || $selectedTagId}
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-12 h-12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1">
                            <circle cx="11" cy="11" r="8" /><path d="m21 21-4.35-4.35" />
                        </svg>
                        <p class="text-lg">No notes match your filter</p>
                    {:else}
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-14 h-14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1">
                            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" /><polyline points="14 2 14 8 20 8" />
                        </svg>
                        <p class="text-lg font-medium">No notes yet</p>
                        <p class="text-sm">Create your first note to get started</p>
                    {/if}
                </div>
            {/if}
        {/if}
    </main>
</div>

<!-- FAB: New note -->
<button class="btn btn-primary btn-circle btn-lg fixed bottom-8 right-8 shadow-xl z-30" on:click={openCreateModal} title="New note" type="button">
    <svg xmlns="http://www.w3.org/2000/svg" class="w-7 h-7" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
        <line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" />
    </svg>
</button>

<!-- Modals -->
<NoteModal
    open={noteModalOpen}
    note={editingNote}
    on:close={() => (noteModalOpen = false)}
    on:openNote={(e) => {
        editingNote = e.detail;
    }}
/>

<UnlockModal open={unlockModalOpen} note={lockingNote} on:unlocked={handleUnlocked} on:close={() => (unlockModalOpen = false)} />
