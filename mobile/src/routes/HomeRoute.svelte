<script lang="ts">
    import { onMount } from "svelte";
    import { notesStore } from "$lib/stores/notes";
    import { tagsStore, selectedTagId } from "$lib/stores/tags";
    import { authStore, currentUser } from "$lib/stores/auth";
    import { resolvedTheme, theme } from "$lib/stores/theme";
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

    // Search
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

    // Delete note
    let deleteNoteTarget: Note | null = null;
    let deleteNoteSaving = false;
    let deleteNoteError = "";

    function handleDelete(noteId: string) {
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

    async function handleTogglePin(noteId: string) {
        const note = $notesStore.find((n) => n.id === noteId);
        if (!note) return;
        await notesStore.update(noteId, { is_pinned: !note.is_pinned });
    }

    $: filtered = $notesStore.filter((n) => {
        if ($selectedTagId && !n.tags?.some((t) => t.id === $selectedTagId)) return false;
        if (!searchQuery) return true;
        const q = searchQuery.toLowerCase();
        return n.title.toLowerCase().includes(q) || (!n.is_locked && n.body?.toLowerCase().includes(q));
    });

    $: noteCountByTag = Object.fromEntries($tagsStore.map((tag) => [tag.id, $notesStore.filter((n) => n.tags?.some((t) => t.id === tag.id)).length]));

    $: pinned = filtered.filter((n) => n.is_pinned);
    $: others = filtered.filter((n) => !n.is_pinned);

    // Tag CRUD
    const EMOJIS = ["😀", "😂", "😍", "🤔", "😎", "😢", "😡", "🥳", "🤯", "🥺", "👍", "👎", "👋", "🙌", "🤝", "💪", "🫶", "❤️", "🔥", "⭐", "✅", "❌", "⚠️", "💡", "🔔", "📌", "📎", "🔗", "🏷️", "📋", "📝", "📖", "📚", "🗒️", "✏️", "🖊️", "📧", "💬", "🗨️", "📢", "🏠", "🏢", "🚀", "✈️", "🚗", "🌍", "🗺️", "📍", "⛺", "🏖️", "🍕", "🍔", "☕", "🍺", "🎂", "🍎", "🥗", "🍜", "🎉", "🎁", "💰", "💳", "📈", "📉", "🏦", "💼", "🛒", "🎯", "🏆", "🥇", "🔧", "⚙️", "🖥️", "📱", "🖨️", "🔋", "💾", "🖱️", "⌨️", "🔐", "🌱", "🌿", "🌸", "🌻", "🍀", "🌈", "☀️", "🌙", "❄️", "🌊", "🐶", "🐱", "🐭", "🐸", "🦊", "🐼", "🐨", "🦁", "🐯", "🦋"];

    let editingTagId: string | null = null;
    let editingTagName = "";
    let editingTagEmoji = "";
    let tagEditError = "";
    let tagEditSaving = false;
    let showEditEmojiPicker = false;

    // Tag management sheet
    let showTagSheet = false;

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
            notesStore.patchTagInNotes(updated);
            editingTagId = null;
        } catch (e: unknown) {
            tagEditError = e instanceof Error ? e.message : "Failed to rename tag";
        } finally {
            tagEditSaving = false;
        }
    }

    // Delete tag
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
            notesStore.removeTagFromNotes(deleteTagTarget.id);
            if ($selectedTagId === deleteTagTarget.id) selectedTagId.set(null);
            deleteTagTarget = null;
        } catch (e: unknown) {
            deleteTagError = e instanceof Error ? e.message : "Failed to delete tag";
        } finally {
            deleteTagSaving = false;
        }
    }
</script>

<div class="home-screen">
    <!-- Top bar -->
    <div class="top-bar">
        <div class="search-row">
            <svg xmlns="http://www.w3.org/2000/svg" class="search-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="11" cy="11" r="8" /><path d="m21 21-4.35-4.35" />
            </svg>
            <input type="search" class="search-input" placeholder="Search notes…" bind:value={searchQuery} />
            <button class="theme-btn" on:click={() => theme.toggle()} title="Toggle theme" type="button">
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
        </div>

        <!-- Tag filter chips -->
        <div class="chips-row">
            <button class="chip" class:chip-active={$selectedTagId === null} on:click={() => selectedTagId.set(null)} type="button">All&nbsp;<span class="chip-count">{$notesStore.length}</span></button>

            {#each $tagsStore as tag (tag.id)}
                <button class="chip" class:chip-active={$selectedTagId === tag.id} on:click={() => selectedTagId.set($selectedTagId === tag.id ? null : tag.id)} type="button">
                    {tag.emoji ? tag.emoji + " " : ""}{tag.name}&nbsp;<span class="chip-count">{noteCountByTag[tag.id] ?? 0}</span>
                </button>
            {/each}

            {#if $tagsStore.length > 0}
                <button class="chip chip-manage" on:click={() => (showTagSheet = true)} type="button" title="Manage tags">
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <circle cx="12" cy="12" r="3" /><path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
                    </svg>
                </button>
            {/if}
        </div>
    </div>

    <!-- Notes area -->
    <main class="notes-area">
        {#if loading}
            <div class="center-pad">
                <span class="spinner spinner-lg" />
            </div>
        {:else if error}
            <div class="alert alert-error">{error}</div>
        {:else}
            {#if pinned.length > 0}
                <section class="notes-section">
                    <h2 class="section-label">
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="currentColor">
                            <path d="M12 2a1 1 0 0 1 1 1v1h4a1 1 0 0 1 .7 1.7l-2.7 2.7.3 4.6L18 14a1 1 0 0 1-1 1h-4v6a1 1 0 1 1-2 0v-6H7a1 1 0 0 1-1-1l2.7-1 .3-4.6L6.3 5.7A1 1 0 0 1 7 4h4V3a1 1 0 0 1 1-1z" />
                        </svg>
                        Pinned
                    </h2>
                    <div class="notes-grid">
                        {#each pinned as note (note.id)}
                            <NoteCard {note} on:open={(e) => openEditModal(e.detail)} on:delete={(e) => handleDelete(e.detail)} on:togglePin={(e) => handleTogglePin(e.detail)} />
                        {/each}
                    </div>
                </section>
            {/if}

            {#if others.length > 0}
                <section class="notes-section">
                    {#if pinned.length > 0}
                        <h2 class="section-label">Other notes</h2>
                    {/if}
                    <div class="notes-grid">
                        {#each others as note (note.id)}
                            <NoteCard {note} on:open={(e) => openEditModal(e.detail)} on:delete={(e) => handleDelete(e.detail)} on:togglePin={(e) => handleTogglePin(e.detail)} />
                        {/each}
                    </div>
                </section>
            {/if}

            {#if filtered.length === 0}
                <div class="empty-state">
                    {#if searchQuery || $selectedTagId}
                        <svg xmlns="http://www.w3.org/2000/svg" class="empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1">
                            <circle cx="11" cy="11" r="8" /><path d="m21 21-4.35-4.35" />
                        </svg>
                        <p class="empty-title">No notes match your filter</p>
                    {:else}
                        <svg xmlns="http://www.w3.org/2000/svg" class="empty-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1">
                            <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" /><polyline points="14 2 14 8 20 8" />
                        </svg>
                        <p class="empty-title">No notes yet</p>
                        <p class="empty-desc">Tap + to create your first note</p>
                    {/if}
                </div>
            {/if}
        {/if}
    </main>

    <!-- FAB: New note -->
    <button class="fab" on:click={openCreateModal} title="New note" type="button">
        <svg xmlns="http://www.w3.org/2000/svg" class="w-7 h-7" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
            <line x1="12" y1="5" x2="12" y2="19" /><line x1="5" y1="12" x2="19" y2="12" />
        </svg>
    </button>
</div>

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

<!-- Delete note confirmation -->
{#if deleteNoteTarget}
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <!-- svelte-ignore a11y-no-static-element-interactions -->
    <div class="modal-backdrop" on:click|self={() => (deleteNoteTarget = null)}>
        <div class="confirm-sheet">
            <div class="sheet-pill" />
            <h3 class="confirm-title">Delete note?</h3>
            <div class="note-preview-row">
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
                <span class="note-preview-title">{deleteNoteTarget.title || "(Untitled)"}</span>
            </div>
            {#if deleteNoteTarget.attachment_count > 0}
                <p class="confirm-warn">
                    {deleteNoteTarget.attachment_count} attachment{deleteNoteTarget.attachment_count > 1 ? "s" : ""} will also be permanently deleted.
                </p>
            {/if}
            <p class="confirm-body">This action cannot be undone.</p>
            {#if deleteNoteError}
                <p class="error-text">{deleteNoteError}</p>
            {/if}
            <div class="confirm-footer">
                <button class="btn-ghost" on:click={() => (deleteNoteTarget = null)} type="button">Cancel</button>
                <button class="btn-danger" on:click={confirmDeleteNote} disabled={deleteNoteSaving} type="button">
                    {#if deleteNoteSaving}<span class="spinner" />{/if}
                    Delete note
                </button>
            </div>
        </div>
    </div>
{/if}

<!-- Tag management bottom sheet -->
{#if showTagSheet}
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <!-- svelte-ignore a11y-no-static-element-interactions -->
    <div
        class="sheet-backdrop"
        on:click={() => {
            showTagSheet = false;
            cancelEditTag();
        }}
    />
    <div class="sheet">
        <div class="sheet-pill" />
        <div class="sheet-header-row">
            <h3 class="sheet-title">Manage Tags</h3>
            <button
                class="btn-ghost-sm"
                on:click={() => {
                    showTagSheet = false;
                    cancelEditTag();
                }}
                type="button">Done</button
            >
        </div>

        {#if $tagsStore.length === 0}
            <p class="body-text muted-text">No tags yet. Create one from inside a note.</p>
        {/if}

        {#each $tagsStore as tag (tag.id)}
            <div class="tag-row">
                {#if editingTagId === tag.id}
                    <div class="tag-edit-block">
                        <div class="tag-edit-row">
                            <button type="button" class="emoji-btn" on:click={() => (showEditEmojiPicker = showEditEmojiPicker ? false : true)}>
                                {#if editingTagEmoji}
                                    <span>{editingTagEmoji}</span>
                                {:else}
                                    <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                                        <circle cx="12" cy="12" r="10" />
                                        <path d="M8 14s1.5 2 4 2 4-2 4-2" />
                                        <line x1="9" y1="9" x2="9.01" y2="9" stroke-width="2.5" stroke-linecap="round" />
                                        <line x1="15" y1="9" x2="15.01" y2="9" stroke-width="2.5" stroke-linecap="round" />
                                    </svg>
                                {/if}
                            </button>
                            <input
                                type="text"
                                class="tag-name-input"
                                bind:value={editingTagName}
                                on:keydown={(e) => {
                                    if (e.key === "Enter") {
                                        e.preventDefault();
                                        confirmEditTag(tag);
                                    } else if (e.key === "Escape") cancelEditTag();
                                }}
                            />
                        </div>
                        {#if showEditEmojiPicker}
                            <div class="emoji-grid">
                                {#each EMOJIS as em}
                                    <button
                                        type="button"
                                        class="emoji-grid-btn"
                                        on:click={() => {
                                            editingTagEmoji = em;
                                            showEditEmojiPicker = false;
                                        }}>{em}</button
                                    >
                                {/each}
                                {#if editingTagEmoji}
                                    <button
                                        type="button"
                                        class="emoji-clear-btn"
                                        on:click={() => {
                                            editingTagEmoji = "";
                                            showEditEmojiPicker = false;
                                        }}>✕ Clear emoji</button
                                    >
                                {/if}
                            </div>
                        {/if}
                        {#if tagEditError}
                            <p class="error-text">{tagEditError}</p>
                        {/if}
                        <div class="tag-edit-actions">
                            <button class="btn-primary-sm" on:click={() => confirmEditTag(tag)} disabled={tagEditSaving} type="button">
                                {#if tagEditSaving}<span class="spinner spinner-sm" />{:else}Save{/if}
                            </button>
                            <button class="btn-ghost-sm" on:click={cancelEditTag} type="button">Cancel</button>
                        </div>
                    </div>
                {:else}
                    <span class="tag-name">
                        {tag.emoji ? tag.emoji + " " : ""}{tag.name}
                        <span class="tag-count">{noteCountByTag[tag.id] ?? 0}</span>
                    </span>
                    <div class="tag-row-actions">
                        <button class="icon-btn" on:click={() => startEditTag(tag)} title="Rename" type="button">
                            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
                                <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
                            </svg>
                        </button>
                        <button class="icon-btn icon-btn-danger" on:click={() => askDeleteTag(tag)} title="Delete" type="button">
                            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <polyline points="3 6 5 6 21 6" /><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" />
                            </svg>
                        </button>
                    </div>
                {/if}
            </div>
        {/each}
    </div>
{/if}

<!-- Delete tag confirmation -->
{#if deleteTagTarget}
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <!-- svelte-ignore a11y-no-static-element-interactions -->
    <div class="modal-backdrop" on:click|self={() => (deleteTagTarget = null)}>
        <div class="confirm-sheet">
            <div class="sheet-pill" />
            <h3 class="confirm-title">Delete tag "{deleteTagTarget.name}"?</h3>
            {#if deleteTagAffectedNotes.length > 0}
                <p class="confirm-body">
                    This tag will be removed from <strong>{deleteTagAffectedNotes.length} note{deleteTagAffectedNotes.length > 1 ? "s" : ""}</strong>. The notes themselves will <em>not</em> be deleted.
                </p>
                <ul class="affected-list">
                    {#each deleteTagAffectedNotes as n (n.id)}
                        <li class="affected-item">
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
                <p class="confirm-body">No notes are currently tagged with this tag.</p>
            {/if}
            {#if deleteTagError}
                <p class="error-text">{deleteTagError}</p>
            {/if}
            <div class="confirm-footer">
                <button class="btn-ghost" on:click={() => (deleteTagTarget = null)} type="button">Cancel</button>
                <button class="btn-danger" on:click={confirmDeleteTag} disabled={deleteTagSaving} type="button">
                    {#if deleteTagSaving}<span class="spinner" />{/if}
                    Delete tag
                </button>
            </div>
        </div>
    </div>
{/if}

<style>
    .home-screen {
        min-height: 100dvh;
        background: var(--color-bg);
        display: flex;
        flex-direction: column;
        padding-bottom: calc(70px + env(safe-area-inset-bottom));
    }

    /* Top bar */
    .top-bar {
        position: sticky;
        top: 0;
        z-index: 20;
        background: var(--color-bg);
        border-bottom: 1px solid var(--color-border);
        padding: 10px 12px 0;
        display: flex;
        flex-direction: column;
        gap: 8px;
    }

    .search-row {
        display: flex;
        align-items: center;
        gap: 8px;
        background: var(--color-surface);
        border: 1.5px solid var(--color-border);
        border-radius: 12px;
        padding: 0 12px;
        height: 42px;
    }

    .search-icon {
        width: 16px;
        height: 16px;
        color: var(--color-text-muted);
        flex-shrink: 0;
    }

    .search-input {
        flex: 1;
        background: transparent;
        border: none;
        outline: none;
        font-size: 15px;
        color: var(--color-text-primary);
    }

    .search-input::placeholder {
        color: var(--color-text-muted);
    }

    .theme-btn {
        width: 32px;
        height: 32px;
        display: flex;
        align-items: center;
        justify-content: center;
        border: none;
        background: transparent;
        color: var(--color-text-secondary);
        cursor: pointer;
        flex-shrink: 0;
        -webkit-tap-highlight-color: transparent;
        border-radius: 8px;
    }

    /* Chip row */
    .chips-row {
        display: flex;
        gap: 6px;
        overflow-x: auto;
        padding-bottom: 10px;
        -webkit-overflow-scrolling: touch;
        scrollbar-width: none;
    }

    .chips-row::-webkit-scrollbar {
        display: none;
    }

    .chip {
        display: flex;
        align-items: center;
        gap: 4px;
        height: 30px;
        padding: 0 12px;
        border-radius: 100px;
        border: 1.5px solid var(--color-border);
        background: transparent;
        color: var(--color-text-secondary);
        font-size: 13px;
        font-weight: 500;
        white-space: nowrap;
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
        flex-shrink: 0;
        transition:
            background 0.15s,
            color 0.15s,
            border-color 0.15s;
    }

    .chip-active {
        background: var(--color-accent);
        border-color: var(--color-accent);
        color: #fff;
    }

    .chip-count {
        font-size: 11px;
        opacity: 0.7;
    }

    .chip-manage {
        padding: 0 10px;
    }

    /* Notes area */
    .notes-area {
        flex: 1;
        padding: 12px;
        display: flex;
        flex-direction: column;
        gap: 16px;
    }

    .notes-section {
        display: flex;
        flex-direction: column;
        gap: 10px;
    }

    .section-label {
        display: flex;
        align-items: center;
        gap: 5px;
        font-size: 11px;
        font-weight: 700;
        letter-spacing: 0.06em;
        text-transform: uppercase;
        color: var(--color-text-muted);
        margin: 0;
    }

    .notes-grid {
        display: grid;
        grid-template-columns: repeat(2, 1fr);
        gap: 10px;
    }

    @media (max-width: 360px) {
        .notes-grid {
            grid-template-columns: 1fr;
        }
    }

    /* FAB */
    .fab {
        position: fixed;
        bottom: calc(70px + env(safe-area-inset-bottom) + 16px);
        right: 20px;
        width: 56px;
        height: 56px;
        border-radius: 18px;
        border: 1.5px solid rgba(34, 211, 238, 0.45);
        background: rgba(6, 182, 212, 0.2);
        color: #ecfeff;
        display: flex;
        align-items: center;
        justify-content: center;
        box-shadow: 0 8px 24px rgba(34, 211, 238, 0.25);
        z-index: 10;
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
    }

    /* Empty state */
    .center-pad {
        display: flex;
        justify-content: center;
        padding: 60px 0;
    }

    .empty-state {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        gap: 10px;
        padding: 60px 20px;
        color: var(--color-text-muted);
    }

    .empty-icon {
        width: 52px;
        height: 52px;
    }

    .empty-title {
        font-size: 18px;
        font-weight: 600;
        color: var(--color-text-secondary);
        margin: 0;
    }

    .empty-desc {
        font-size: 14px;
        margin: 0;
    }

    /* Misc */
    .alert {
        font-size: 13px;
        padding: 10px 14px;
        border-radius: 10px;
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
        margin: 0;
    }

    /* Delete modal backdrop */
    .modal-backdrop {
        position: fixed;
        inset: 0;
        background: rgba(0, 0, 0, 0.5);
        z-index: 50;
        display: flex;
        align-items: flex-end;
    }

    .confirm-sheet {
        width: 100%;
        background: var(--color-surface);
        border-radius: 20px 20px 0 0;
        padding: 16px 20px calc(20px + env(safe-area-inset-bottom));
        display: flex;
        flex-direction: column;
        gap: 12px;
    }

    .sheet-pill {
        width: 36px;
        height: 4px;
        border-radius: 2px;
        background: var(--color-border);
        align-self: center;
        margin-bottom: 4px;
    }

    .confirm-title {
        font-size: 18px;
        font-weight: 700;
        color: #dc2626;
        margin: 0;
    }

    .note-preview-row {
        display: flex;
        align-items: center;
        gap: 8px;
        border: 1px solid var(--color-border);
        border-radius: 10px;
        padding: 10px 12px;
    }

    .note-preview-title {
        font-size: 15px;
        font-weight: 500;
        color: var(--color-text-primary);
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
    }

    .confirm-warn {
        font-size: 13px;
        color: #ea580c;
        margin: 0;
    }

    .confirm-body {
        font-size: 14px;
        color: var(--color-text-secondary);
        margin: 0;
        line-height: 1.5;
    }

    .confirm-footer {
        display: flex;
        gap: 10px;
        margin-top: 4px;
    }

    .btn-ghost {
        flex: 1;
        height: 46px;
        border-radius: 12px;
        border: 1.5px solid var(--color-border);
        background: transparent;
        color: var(--color-text-primary);
        font-size: 15px;
        font-weight: 500;
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
    }

    .btn-danger {
        flex: 1;
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
        height: 46px;
        border-radius: 12px;
        border: none;
        background: #dc2626;
        color: #fff;
        font-size: 15px;
        font-weight: 600;
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
        transition: opacity 0.15s;
    }

    .btn-danger:disabled {
        opacity: 0.5;
    }

    /* Tag sheet */
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
        gap: 8px;
        max-height: 70dvh;
        overflow-y: auto;
    }

    .sheet-header-row {
        display: flex;
        align-items: center;
        justify-content: space-between;
        margin-bottom: 6px;
    }

    .sheet-title {
        font-size: 18px;
        font-weight: 700;
        color: var(--color-text-primary);
        margin: 0;
    }

    .body-text {
        font-size: 14px;
        color: var(--color-text-secondary);
        line-height: 1.5;
        margin: 0;
    }

    .muted-text {
        color: var(--color-text-muted);
    }

    /* Tag rows */
    .tag-row {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 8px;
        padding: 8px 0;
        border-bottom: 1px solid var(--color-border);
    }

    .tag-row:last-child {
        border-bottom: none;
    }

    .tag-name {
        font-size: 15px;
        color: var(--color-text-primary);
        display: flex;
        align-items: center;
        gap: 8px;
        flex: 1;
        min-width: 0;
    }

    .tag-count {
        font-size: 11px;
        color: var(--color-text-muted);
        background: var(--color-border);
        border-radius: 100px;
        padding: 0 6px;
        height: 18px;
        display: inline-flex;
        align-items: center;
    }

    .tag-row-actions {
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
    }

    .icon-btn-danger {
        color: #dc2626;
    }

    /* Tag edit inline */
    .tag-edit-block {
        flex: 1;
        display: flex;
        flex-direction: column;
        gap: 8px;
    }

    .tag-edit-row {
        display: flex;
        align-items: center;
        gap: 8px;
    }

    .emoji-btn {
        width: 36px;
        height: 36px;
        border-radius: 8px;
        border: 1.5px solid var(--color-border);
        background: var(--color-bg);
        display: flex;
        align-items: center;
        justify-content: center;
        cursor: pointer;
        flex-shrink: 0;
        font-size: 18px;
        color: var(--color-text-muted);
        -webkit-tap-highlight-color: transparent;
    }

    .tag-name-input {
        flex: 1;
        height: 36px;
        padding: 0 10px;
        border-radius: 8px;
        border: 1.5px solid var(--color-accent);
        background: var(--color-bg);
        color: var(--color-text-primary);
        font-size: 15px;
        outline: none;
    }

    .emoji-grid {
        display: grid;
        grid-template-columns: repeat(10, 1fr);
        gap: 2px;
        max-height: 120px;
        overflow-y: auto;
        background: var(--color-bg);
        border-radius: 10px;
        border: 1px solid var(--color-border);
        padding: 6px;
    }

    .emoji-grid-btn {
        font-size: 18px;
        padding: 3px;
        border: none;
        background: transparent;
        border-radius: 6px;
        cursor: pointer;
        line-height: 1;
        -webkit-tap-highlight-color: transparent;
    }

    .emoji-clear-btn {
        grid-column: 1 / -1;
        font-size: 11px;
        color: var(--color-text-muted);
        background: transparent;
        border: none;
        cursor: pointer;
        text-align: left;
        padding: 4px 2px 0;
    }

    .tag-edit-actions {
        display: flex;
        gap: 8px;
    }

    .btn-primary-sm {
        display: flex;
        align-items: center;
        gap: 6px;
        height: 32px;
        padding: 0 14px;
        border-radius: 8px;
        border: none;
        background: var(--color-accent);
        color: #fff;
        font-size: 13px;
        font-weight: 600;
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
    }

    .btn-primary-sm:disabled {
        opacity: 0.5;
    }

    .btn-ghost-sm {
        height: 32px;
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

    /* Affected notes list */
    .affected-list {
        padding: 0;
        margin: 0;
        list-style: none;
        border: 1px solid var(--color-border);
        border-radius: 10px;
        max-height: 140px;
        overflow-y: auto;
    }

    .affected-item {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 8px 12px;
        border-bottom: 1px solid var(--color-border);
        font-size: 13px;
        color: var(--color-text-secondary);
    }

    .affected-item:last-child {
        border-bottom: none;
    }

    .truncate {
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
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

    .spinner-sm {
        width: 12px;
        height: 12px;
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
