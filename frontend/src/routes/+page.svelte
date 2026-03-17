<script lang="ts">
    import { onMount } from "svelte";
    import { notesStore } from "$lib/stores/notes";
    import { tagsStore, selectedTagId } from "$lib/stores/tags";
    import { authStore, currentUser } from "$lib/stores/auth";
    import { resolvedTheme, theme } from "$lib/stores/theme";
    import { goto } from "$app/navigation";
    import NoteCard from "$lib/components/NoteCard.svelte";
    import NoteModal from "$lib/components/NoteModal.svelte";
    import UnlockModal from "$lib/components/UnlockModal.svelte";
    import type { Note, Tag } from "$lib/api/client";

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

    // Delete note modal
    let deleteNoteTarget: Note | null = null;
    let deleteNoteSaving = false;
    let deleteNoteError = "";

    function askDeleteNote(noteId: string) {
        const note = $notesStore.find((n) => n.id === noteId);
        if (!note) return;
        deleteNoteTarget = note;
        deleteNoteError = "";
    }

    async function confirmDeleteNote() {
        if (!deleteNoteTarget) return;
        deleteNoteSaving = true;
        deleteNoteError = "";
        try {
            await notesStore.delete(deleteNoteTarget.id);
            deleteNoteTarget = null;
        } catch (e: unknown) {
            deleteNoteError = e instanceof Error ? e.message : "Failed to delete note";
        } finally {
            deleteNoteSaving = false;
        }
    }

    function handleDelete(noteId: string) {
        askDeleteNote(noteId);
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

    // ── Tag CRUD ──────────────────────────────────────────────────────────────

    const EMOJIS = ["😀", "😂", "😍", "🤔", "😎", "😢", "😡", "🥳", "🤯", "🥺", "👍", "👎", "👋", "🙌", "🤝", "💪", "🫶", "❤️", "🔥", "⭐", "✅", "❌", "⚠️", "💡", "🔔", "📌", "📎", "🔗", "🏷️", "📋", "📝", "📖", "📚", "🗒️", "✏️", "🖊️", "📧", "💬", "🗨️", "📢", "🏠", "🏢", "🚀", "✈️", "🚗", "🌍", "🗺️", "📍", "⛺", "🏖️", "🍕", "🍔", "☕", "🍺", "🎂", "🍎", "🥗", "🍜", "🎉", "🎁", "💰", "💳", "📈", "📉", "🏦", "💼", "🛒", "🎯", "🏆", "🥇", "🔧", "⚙️", "🖥️", "📱", "🖨️", "🔋", "💾", "🖱️", "⌨️", "🔐", "🌱", "🌿", "🌸", "🌻", "🍀", "🌈", "☀️", "🌙", "❄️", "🌊", "🐶", "🐱", "🐭", "🐸", "🦊", "🐼", "🐨", "🦁", "🐯", "🦋"];

    // Inline rename state
    let editingTagId: string | null = null;
    let editingTagName = "";
    let editingTagEmoji = "";
    let tagEditError = "";
    let tagEditSaving = false;
    let showEditEmojiPicker = false;
    let emojiPickerAnchorEl: HTMLButtonElement;
    let emojiPickerPos = { top: 0, left: 0 };

    function openEditEmojiPicker() {
        const rect = emojiPickerAnchorEl.getBoundingClientRect();
        emojiPickerPos = { top: rect.bottom + 4, left: rect.left };
        showEditEmojiPicker = true;
    }

    function startEditTag(tag: Tag) {
        editingTagId = tag.id;
        editingTagName = tag.name;
        editingTagEmoji = tag.emoji;
        tagEditError = "";
        showEditEmojiPicker = false;
    }

    function cancelEditTag() {
        editingTagId = null;
        tagEditError = "";
        showEditEmojiPicker = false;
    }

    async function confirmEditTag(tag: Tag) {
        const name = editingTagName.trim();
        if (!name) {
            tagEditError = "Name cannot be empty.";
            return;
        }
        tagEditSaving = true;
        tagEditError = "";
        try {
            const updated = await tagsStore.updateTag(tag.id, { name, emoji: editingTagEmoji.trim() });
            // Refresh tag label inside every note that already carries it
            notesStore.patchTagInNotes(updated);
            editingTagId = null;
        } catch (e: unknown) {
            tagEditError = e instanceof Error ? e.message : "Failed to rename tag";
        } finally {
            tagEditSaving = false;
        }
    }

    // Delete confirmation state
    let deleteTagTarget: Tag | null = null;
    let deleteTagSaving = false;
    let deleteTagError = "";

    $: deleteTagAffectedNotes = deleteTagTarget ? $notesStore.filter((n) => n.tags?.some((t) => t.id === deleteTagTarget!.id)) : [];

    function askDeleteTag(tag: Tag) {
        deleteTagTarget = tag;
        deleteTagError = "";
    }

    async function confirmDeleteTag() {
        if (!deleteTagTarget) return;
        deleteTagSaving = true;
        deleteTagError = "";
        try {
            await tagsStore.remove(deleteTagTarget.id);
            // Strip the deleted tag from every note in the local store
            notesStore.removeTagFromNotes(deleteTagTarget.id);
            // If we were filtering by this tag, reset the filter
            if ($selectedTagId === deleteTagTarget.id) selectedTagId.set(null);
            deleteTagTarget = null;
        } catch (e: unknown) {
            deleteTagError = e instanceof Error ? e.message : "Failed to delete tag";
        } finally {
            deleteTagSaving = false;
        }
    }
</script>

<svelte:head>
    <title>migajas</title>
</svelte:head>

<div class="dashboard-shell min-h-screen pb-10">
    <!-- Navbar -->
    <nav class="glass-nav mx-3 mt-3 rounded-2xl flex items-center justify-between h-16 px-4 gap-3 sticky top-3 z-30">
        <div class="flex-1 flex items-center gap-2 min-w-0">
            <img src="/logo.svg" alt="migajas" class="h-8" />
            <p class="script-title text-sm font-medium truncate">All Notes</p>
        </div>

        <!-- Search -->
        <div class="flex-1 max-w-xl hidden sm:block">
            <label class="dashboard-search">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-primary/80" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="11" cy="11" r="8" /><path d="m21 21-4.35-4.35" />
                </svg>
                <input type="search" class="grow bg-transparent outline-none placeholder:text-muted-foreground" placeholder="Search notes..." bind:value={searchQuery} />
            </label>
        </div>

        <div class="flex-none flex items-center gap-1">
            <!-- Theme toggle -->
            <button class="dashboard-chip-button" on:click={() => theme.toggle()} title="Toggle theme" type="button">
                {#if $resolvedTheme === "dark"}
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
            <a href="/settings" class="dashboard-chip-button" title="Settings">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
                </svg>
            </a>

            <!-- User menu -->
            <details class="relative">
                <summary class="dashboard-user-trigger">
                    <span class="dashboard-user-badge">
                        {$currentUser?.username?.[0]?.toUpperCase() ?? "?"}
                    </span>
                    <span class="hidden sm:inline text-sm">{$currentUser?.username}</span>
                </summary>
                <ul class="dashboard-user-menu">
                    <li><a class="dashboard-user-menu-item" href="/settings">Settings</a></li>
                    {#if $currentUser?.is_admin}
                        <li><a class="dashboard-user-menu-item" href="/admin">Users</a></li>
                    {/if}
                    <li><button class="dashboard-user-menu-item w-full text-left" on:click={logout} type="button">Sign out</button></li>
                </ul>
            </details>
        </div>
    </nav>

    <!-- Main content -->
    <div class="flex gap-4 px-3 mt-4">
        <!-- Left sidebar: tag filter — always visible, sticky under navbar -->
        <aside class="glass-panel w-56 shrink-0 sticky top-24 self-start h-[calc(100vh-7rem)] overflow-y-auto rounded-2xl flex flex-col gap-0.5 p-3">
            <button class="flex items-center justify-between gap-2 px-2 py-1.5 rounded-lg text-sm transition-colors" class:bg-primary={$selectedTagId === null} class:text-primary-foreground={$selectedTagId === null} class:hover:bg-muted={$selectedTagId !== null} on:click={() => selectedTagId.set(null)} type="button">
                <span>All notes</span>
                <span class="text-xs px-2 py-1 rounded inline-flex items-center">{$notesStore.length}</span>
            </button>
            <p class="section-kicker font-semibold uppercase px-2 mt-3 mb-1">Tags</p>
            {#each $tagsStore as tag (tag.id)}
                {#if editingTagId === tag.id}
                    <!-- Inline edit row -->
                    <div class="flex flex-col gap-1 px-1 py-1">
                        <div class="flex items-center gap-1">
                            <!-- Emoji picker button -->
                            <div class="shrink-0">
                                <button type="button" class="h-8 px-2 rounded-md inline-flex items-center justify-center text-xs btn-ghost w-9 px-0 leading-none" title="Pick emoji" bind:this={emojiPickerAnchorEl} on:click|stopPropagation={openEditEmojiPicker}>
                                    {#if editingTagEmoji}
                                        <span class="text-base">{editingTagEmoji}</span>
                                    {:else}
                                        <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-muted-foreground" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                                            <circle cx="12" cy="12" r="10" />
                                            <path d="M8 14s1.5 2 4 2 4-2 4-2" />
                                            <line x1="9" y1="9" x2="9.01" y2="9" stroke-width="2.5" stroke-linecap="round" />
                                            <line x1="15" y1="9" x2="15.01" y2="9" stroke-width="2.5" stroke-linecap="round" />
                                        </svg>
                                    {/if}
                                </button>
                            </div>
                            <!-- Name input -->
                            <input
                                type="text"
                                class="flex h-10 w-full rounded-md border border-border bg-background px-3 py-2 text-sm flex-1 min-w-0"
                                bind:value={editingTagName}
                                on:keydown={(e) => {
                                    if (e.key === "Enter") {
                                        e.preventDefault();
                                        confirmEditTag(tag);
                                    } else if (e.key === "Escape") cancelEditTag();
                                }}
                            />
                        </div>
                        {#if tagEditError}
                            <p class="text-xs text-destructive px-1">{tagEditError}</p>
                        {/if}
                        <div class="flex gap-1">
                            <button class="h-8 px-2 rounded-md inline-flex items-center justify-center text-xs btn-primary flex-1" on:click={() => confirmEditTag(tag)} disabled={tagEditSaving} type="button">
                                {#if tagEditSaving}<span class="inline-block h-4 w-4 animate-spin rounded-full border border-current border-r-transparent" />{:else}Save{/if}
                            </button>
                            <button class="h-8 px-2 rounded-md inline-flex items-center justify-center text-xs btn-ghost" on:click={cancelEditTag} type="button">Cancel</button>
                        </div>
                    </div>
                {:else}
                    <!-- Normal row -->
                    <div class="group flex items-center gap-1 px-2 py-1.5 rounded-lg text-sm transition-colors" class:bg-primary={$selectedTagId === tag.id} class:text-primary-foreground={$selectedTagId === tag.id} class:hover:bg-muted={$selectedTagId !== tag.id}>
                        <button class="flex items-center justify-between gap-1 flex-1 min-w-0 text-left" on:click={() => selectedTagId.set($selectedTagId === tag.id ? null : tag.id)} type="button">
                            <span class="truncate">{tag.emoji ? tag.emoji + " " : ""}{tag.name}</span>
                            <span class="text-xs px-2 py-1 rounded inline-flex items-center shrink-0">{noteCountByTag[tag.id] ?? 0}</span>
                        </button>
                        <!-- Edit button -->
                        <button class="opacity-0 group-hover:opacity-100 h-7 w-7 rounded-md hover:bg-muted p-0 inline-flex items-center justify-center shrink-0 transition-opacity" class:text-primary-foreground={$selectedTagId === tag.id} title="Rename tag" on:click|stopPropagation={() => startEditTag(tag)} type="button">
                            <svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
                                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
                            </svg>
                        </button>
                        <!-- Delete button -->
                        <button class="opacity-0 group-hover:opacity-100 h-7 w-7 rounded-md hover:bg-muted p-0 inline-flex items-center justify-center shrink-0 text-destructive transition-opacity" title="Delete tag" on:click|stopPropagation={() => askDeleteTag(tag)} type="button">
                            <svg xmlns="http://www.w3.org/2000/svg" class="w-3 h-3" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                                <polyline points="3 6 5 6 21 6" />
                                <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" />
                            </svg>
                        </button>
                    </div>
                {/if}
            {/each}
            {#if $tagsStore.length === 0}
                <p class="text-xs text-muted-foreground/70 italic px-2 mt-1">No tags yet.<br />Create one in a note.</p>
            {/if}
        </aside>

        <!-- Notes area -->
        <main class="flex-1 min-w-0 px-1 py-2">
            {#if loading}
                <div class="flex justify-center py-20">
                    <span class="inline-block h-8 w-8 animate-spin rounded-full border-4 border-current border-r-transparent text-primary" />
                </div>
            {:else if error}
                <div class="bg-destructive text-destructive-foreground px-4 py-3 rounded-md">{error}</div>
            {:else}
                <!-- Pinned -->
                {#if pinned.length > 0}
                    <section class="mb-6">
                        <h2 class="section-kicker font-semibold uppercase tracking-wider mb-3 flex items-center gap-1.5">
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
                            <h2 class="section-kicker font-semibold uppercase tracking-wider mb-3">Other notes</h2>
                        {/if}
                        <div class="grid grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-4 gap-3">
                            {#each others as note (note.id)}
                                <NoteCard {note} on:open={(e) => openEditModal(e.detail)} on:delete={(e) => handleDelete(e.detail)} on:togglePin={(e) => handleTogglePin(e.detail)} />
                            {/each}
                        </div>
                    </section>
                {/if}

                {#if filtered.length === 0}
                    <div class="flex flex-col items-center justify-center py-24 gap-4 text-muted-foreground">
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
    <button class="fixed bottom-8 right-8 h-14 w-14 rounded-2xl border border-cyan-400/45 bg-cyan-500/20 text-cyan-100 hover:bg-cyan-400/25 shadow-[0_10px_28px_rgba(34,211,238,0.28)] z-30 inline-flex items-center justify-center" on:click={openCreateModal} title="New note" type="button">
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

    <!-- Delete tag confirmation modal -->
    <!-- Emoji picker (fixed-position portal, escapes sidebar overflow clipping) -->
    {#if showEditEmojiPicker}
        <!-- svelte-ignore a11y-click-events-have-key-events -->
        <!-- svelte-ignore a11y-no-static-element-interactions -->
        <div class="fixed inset-0 z-[55]" on:click={() => (showEditEmojiPicker = false)} />
        <!-- svelte-ignore a11y-click-events-have-key-events -->
        <!-- svelte-ignore a11y-no-static-element-interactions -->
        <div class="fixed z-[56] bg-card border border-border rounded-xl shadow-2xl p-2 w-64" style="top: {emojiPickerPos.top}px; left: {emojiPickerPos.left}px;" on:click|stopPropagation>
            <div class="grid grid-cols-10 gap-0.5 max-h-40 overflow-y-auto">
                {#each EMOJIS as em}
                    <button
                        type="button"
                        class="text-lg leading-none p-0.5 rounded hover:bg-muted transition-colors"
                        on:click={() => {
                            editingTagEmoji = em;
                            showEditEmojiPicker = false;
                        }}>{em}</button
                    >
                {/each}
            </div>
            {#if editingTagEmoji}
                <button
                    type="button"
                    class="mt-2 text-xs text-muted-foreground hover:text-foreground w-full text-left px-1"
                    on:click={() => {
                        editingTagEmoji = "";
                        showEditEmojiPicker = false;
                    }}>✕ Clear emoji</button
                >
            {/if}
        </div>
    {/if}
</div>

<!-- Delete note confirmation modal -->
{#if deleteNoteTarget}
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <!-- svelte-ignore a11y-no-static-element-interactions -->
    <div class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" on:click|self={() => (deleteNoteTarget = null)}>
        <div class="bg-card rounded-2xl shadow-2xl w-full max-w-md flex flex-col gap-4 p-6">
            <h3 class="text-lg font-bold text-destructive">Delete note?</h3>
            <div class="flex items-center gap-2 border border-border rounded-lg px-3 py-2">
                {#if deleteNoteTarget.is_secret}
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-yellow-600 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <rect x="3" y="11" width="18" height="11" rx="2" ry="2" /><path d="M7 11V7a5 5 0 0 1 10 0v4" />
                    </svg>
                {/if}
                {#if deleteNoteTarget.is_pinned}
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 text-primary shrink-0" viewBox="0 0 24 24" fill="currentColor">
                        <path d="M12 2a1 1 0 0 1 1 1v1h4a1 1 0 0 1 .7 1.7l-2.7 2.7.3 4.6L18 14a1 1 0 0 1-1 1h-4v6a1 1 0 1 1-2 0v-6H7a1 1 0 0 1-1-1l2.7-1 .3-4.6L6.3 5.7A1 1 0 0 1 7 4h4V3a1 1 0 0 1 1-1z" />
                    </svg>
                {/if}
                <span class="font-medium truncate">{deleteNoteTarget.title || "(Untitled)"}</span>
            </div>
            {#if (deleteNoteTarget.tags ?? []).length > 0}
                <div class="flex flex-wrap gap-1">
                    {#each deleteNoteTarget.tags ?? [] as tag (tag.id)}
                        <span class="text-sm px-2 py-1 rounded inline-flex items-center border border-border bg-transparent">
                            {tag.emoji ? tag.emoji + " " : ""}{tag.name}
                        </span>
                    {/each}
                </div>
            {/if}
            {#if deleteNoteTarget.attachment_count > 0}
                <p class="text-sm text-foreground/80 flex items-center gap-1.5">
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5 text-orange-500 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                        <path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48" />
                    </svg>
                    {deleteNoteTarget.attachment_count} attachment{deleteNoteTarget.attachment_count > 1 ? "s" : ""} will also be permanently deleted.
                </p>
            {/if}
            <p class="text-sm text-foreground/80">This action cannot be undone.</p>

            {#if deleteNoteError}
                <p class="text-sm text-destructive">{deleteNoteError}</p>
            {/if}

            <div class="flex justify-end gap-2 mt-1">
                <button class="h-9 px-3 rounded-md hover:bg-muted text-sm inline-flex items-center justify-center" on:click={() => (deleteNoteTarget = null)} type="button">Cancel</button>
                <button class="h-10 px-4 py-2 bg-destructive text-destructive-foreground hover:bg-destructive/90 rounded-md inline-flex items-center justify-center" on:click={confirmDeleteNote} disabled={deleteNoteSaving} type="button">
                    {#if deleteNoteSaving}<span class="loading loading-spinner loading-xs" />{/if}
                    Delete note
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Delete tag confirmation modal -->
{#if deleteTagTarget}
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <!-- svelte-ignore a11y-no-static-element-interactions -->
    <div class="fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4" on:click|self={() => (deleteTagTarget = null)}>
        <div class="bg-card rounded-2xl shadow-2xl w-full max-w-md flex flex-col gap-4 p-6">
            <h3 class="text-lg font-bold text-destructive">Delete tag "{deleteTagTarget.name}"?</h3>

            {#if deleteTagAffectedNotes.length > 0}
                <p class="text-sm text-foreground/80">
                    This tag will be removed from
                    <strong>{deleteTagAffectedNotes.length} note{deleteTagAffectedNotes.length > 1 ? "s" : ""}</strong>. The notes themselves will <em>not</em> be deleted:
                </p>
                <ul class="text-sm border border-border rounded-lg divide-y divide-base-300 max-h-52 overflow-y-auto">
                    {#each deleteTagAffectedNotes as n (n.id)}
                        <li class="px-3 py-2 flex items-center gap-2">
                            {#if n.is_secret}
                                <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5 text-yellow-600 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <rect x="3" y="11" width="18" height="11" rx="2" ry="2" /><path d="M7 11V7a5 5 0 0 1 10 0v4" />
                                </svg>
                            {/if}
                            <span class="truncate">{n.title || "(Untitled)"}</span>
                        </li>
                    {/each}
                </ul>
            {:else}
                <p class="text-sm text-foreground/80">No notes are currently tagged with this tag.</p>
            {/if}

            {#if deleteTagError}
                <p class="text-sm text-destructive">{deleteTagError}</p>
            {/if}

            <div class="flex justify-end gap-2 mt-1">
                <button class="h-9 px-3 rounded-md hover:bg-muted text-sm inline-flex items-center justify-center" on:click={() => (deleteTagTarget = null)} type="button">Cancel</button>
                <button class="h-10 px-4 py-2 bg-destructive text-destructive-foreground hover:bg-destructive/90 rounded-md inline-flex items-center justify-center" on:click={confirmDeleteTag} disabled={deleteTagSaving} type="button">
                    {#if deleteTagSaving}<span class="loading loading-spinner loading-xs" />{/if}
                    Delete tag
                </button>
            </div>
        </div>
    </div>
{/if}
