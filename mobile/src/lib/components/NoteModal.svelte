<script lang="ts">
    import { createEventDispatcher, onDestroy } from "svelte";
    import { notesStore } from "$lib/stores/notes";
    import { currentUser } from "$lib/stores/auth";
    import { tagsStore } from "$lib/stores/tags";
    import RichEditor from "./RichEditor.svelte";
    import { attachments as attachmentsApi, type Attachment, type Note, type Tag } from "$lib/api/client";

    export let note: Note | null = null; // null = create mode
    export let open: boolean = false;

    const dispatch = createEventDispatcher<{ close: void; openNote: Note }>();

    // Form state
    let title = "";
    let body = "";
    let isSecret = false;
    let color = "";
    let credential = "";
    let saving = false;
    let error = "";

    // Tags
    let noteTags: Tag[] = [];
    let tagInput = "";
    let showTagSuggestions = false;
    let newTagEmoji = "";

    $: tagSuggestions = $tagsStore.filter((t) => !noteTags.find((nt) => nt.id === t.id) && (tagInput === "" || t.name.toLowerCase().includes(tagInput.toLowerCase())));

    function addTag(tag: Tag) {
        if (!noteTags.find((t) => t.id === tag.id)) noteTags = [...noteTags, tag];
        tagInput = "";
        showTagSuggestions = false;
    }

    function removeTag(id: string) {
        noteTags = noteTags.filter((t) => t.id !== id);
    }

    async function createAndAddTag() {
        const name = tagInput.trim();
        if (!name) return;
        try {
            const tag = await tagsStore.create(name, newTagEmoji.trim());
            addTag(tag);
            newTagEmoji = "";
        } catch (e: unknown) {
            error = e instanceof Error ? e.message : "Failed to create tag";
        }
    }

    // Attachments
    let noteAttachments: Attachment[] = [];
    let currentNoteId: string | null = null;
    let audioBlobUrls: Record<string, string> = {};
    let imageBlobUrls: Record<string, string> = {};
    let previewImageId: string | null = null;

    async function loadAudioBlobUrl(id: string) {
        try {
            audioBlobUrls = { ...audioBlobUrls, [id]: await attachmentsApi.fetchBlobUrl(id) };
        } catch {}
    }
    async function loadImageBlobUrl(id: string) {
        try {
            imageBlobUrls = { ...imageBlobUrls, [id]: await attachmentsApi.fetchBlobUrl(id) };
        } catch {}
    }

    $: noteAttachments.forEach((att) => {
        if (att.mime_type.startsWith("audio/") && !audioBlobUrls[att.id]) loadAudioBlobUrl(att.id);
        if (att.mime_type.startsWith("image/") && !imageBlobUrls[att.id]) loadImageBlobUrl(att.id);
    });

    onDestroy(() => {
        Object.values(audioBlobUrls).forEach((u) => URL.revokeObjectURL(u));
        Object.values(imageBlobUrls).forEach((u) => URL.revokeObjectURL(u));
    });

    let editMode = false;

    const COLORS = [
        { value: "", label: "Default" },
        { value: "yellow", label: "Yellow" },
        { value: "blue", label: "Blue" },
        { value: "green", label: "Green" },
        { value: "pink", label: "Pink" },
        { value: "purple", label: "Purple" },
    ];

    const COLOR_DOT: Record<string, string> = {
        "": "transparent",
        yellow: "#fbbf24",
        blue: "#60a5fa",
        green: "#4ade80",
        pink: "#f472b6",
        purple: "#c084fc",
    };

    // Open/close guard
    let _prevOpen = false;
    $: if (open !== _prevOpen) {
        _prevOpen = open;
        if (open) {
            if (note) {
                title = note.title;
                body = note.body ?? "";
                isSecret = note.is_secret;
                color = note.color;
                noteTags = [...(note.tags ?? [])];
                editMode = false;
                currentNoteId = note.id;
                Object.values(audioBlobUrls).forEach((u) => URL.revokeObjectURL(u));
                Object.values(imageBlobUrls).forEach((u) => URL.revokeObjectURL(u));
                audioBlobUrls = {};
                imageBlobUrls = {};
                previewImageId = null;
                noteAttachments = [];
                attachmentsApi
                    .list(note.id)
                    .then((a) => (noteAttachments = a))
                    .catch(() => {});
            } else {
                title = "";
                body = "";
                isSecret = false;
                color = "";
                noteTags = [];
                editMode = true;
                currentNoteId = null;
                noteAttachments = [];
            }
            credential = "";
            error = "";
        }
    }

    $: hasVault = $currentUser?.has_vault ?? false;
    $: secretStateChanged = note ? isSecret !== note.is_secret : false;

    async function save() {
        error = "";
        saving = true;
        try {
            if (note) {
                const payload: Record<string, unknown> = {
                    title,
                    body,
                    color,
                    tags: noteTags.map((t) => t.id),
                };
                if (secretStateChanged) {
                    if (!credential) {
                        error = "Enter your vault credential to change the secret state.";
                        saving = false;
                        return;
                    }
                    payload.is_secret = isSecret;
                    payload.credential = credential;
                } else if (note.is_secret && credential) {
                    payload.credential = credential;
                }
                await notesStore.update(note.id, payload);
                dispatch("close");
            } else if (currentNoteId) {
                if (isSecret && !credential) {
                    error = "Please enter your vault credential to create a secret note.";
                    saving = false;
                    return;
                }
                const payload: Record<string, unknown> = {
                    title: title || "Untitled",
                    body,
                    color,
                    tags: noteTags.map((t) => t.id),
                };
                if (isSecret) {
                    payload.is_secret = true;
                    payload.credential = credential;
                }
                await notesStore.update(currentNoteId, payload);
                dispatch("close");
            } else {
                if (isSecret && !credential) {
                    error = "Please enter your vault credential to create a secret note.";
                    saving = false;
                    return;
                }
                const created = await notesStore.create({
                    title,
                    body,
                    is_secret: isSecret,
                    color,
                    tags: noteTags.map((t) => t.id),
                    ...(isSecret ? { credential } : {}),
                });
                currentNoteId = created.id;
                dispatch("close");
            }
        } catch (e: unknown) {
            error = e instanceof Error ? e.message : "Failed to save note";
        } finally {
            saving = false;
        }
    }

    async function handleAutoSave() {
        if (currentNoteId) return;
        error = "";
        saving = true;
        try {
            const created = await notesStore.create({
                title: title || "Untitled",
                body,
                is_secret: false,
                color,
            });
            currentNoteId = created.id;
        } catch (e: unknown) {
            error = e instanceof Error ? e.message : "Auto-save failed";
        } finally {
            saving = false;
        }
    }

    function handleAttachmentAdded(att: Attachment) {
        noteAttachments = [...noteAttachments, att];
        if (currentNoteId) notesStore.patchAttachmentCount(currentNoteId, 1);
    }

    function handleAttachmentDeleted(id: string) {
        noteAttachments = noteAttachments.filter((a) => a.id !== id);
        if (currentNoteId) notesStore.patchAttachmentCount(currentNoteId, -1);
    }

    function handleViewClick(event: MouseEvent) {
        const anchor = (event.target as HTMLElement).closest("a") as HTMLAnchorElement | null;
        if (!anchor) return;
        const href = anchor.getAttribute("href") ?? "";
        if (href.startsWith("#note-")) {
            event.preventDefault();
            const targetId = href.slice(6);
            const targetNote = $notesStore.find((n) => n.id === targetId);
            if (targetNote) dispatch("openNote", targetNote);
        }
    }

    function close() {
        dispatch("close");
    }
</script>

{#if open}
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <!-- svelte-ignore a11y-no-static-element-interactions -->
    <div class="modal-overlay" on:click|self={close} role="dialog" aria-modal="true">
        <div class="modal-sheet" on:click|stopPropagation>
            <!-- ── Header ─────────────────────────────────────────────────────────── -->
            <div class="modal-header">
                <div class="header-drag-pill" />
                <div class="header-content">
                    {#if editMode}
                        <input type="text" class="title-input" placeholder="Note title" bind:value={title} />
                    {:else}
                        <h2 class="title-view">{title || "Untitled"}</h2>
                    {/if}
                    <div class="header-actions">
                        {#if note && !editMode}
                            <button class="icon-btn" title="Edit" on:click={() => (editMode = true)} type="button">
                                <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
                                    <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
                                </svg>
                            </button>
                        {/if}
                        <button class="icon-btn" title="Close" on:click={close} type="button">
                            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M18 6 6 18M6 6l12 12" />
                            </svg>
                        </button>
                    </div>
                </div>
            </div>

            <!-- ── Body (scrollable) ──────────────────────────────────────────────── -->
            <div class="modal-body">
                {#if editMode}
                    <div class="editor-wrap">
                        <RichEditor content={body} editable={true} placeholder="Write something…" noteId={currentNoteId} allNotes={$notesStore} {noteAttachments} attachments={noteAttachments} on:change={(e) => (body = e.detail)} on:autoSave={handleAutoSave} on:attachmentAdded={(e) => handleAttachmentAdded(e.detail)} on:attachmentDeleted={(e) => handleAttachmentDeleted(e.detail)} />
                    </div>
                {:else if note?.is_secret && note?.is_locked}
                    <div class="locked-view">
                        <svg xmlns="http://www.w3.org/2000/svg" width="56" height="56" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                            <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                            <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                        </svg>
                        <p class="locked-hint">This note is locked. Unlock it to view the content.</p>
                    </div>
                {:else}
                    <!-- svelte-ignore a11y-click-events-have-key-events -->
                    <!-- svelte-ignore a11y-no-static-element-interactions -->
                    <div class="view-body" on:click={handleViewClick}>
                        {#if body}
                            {@html body}
                        {:else}
                            <p class="empty-hint">Empty note</p>
                        {/if}
                    </div>

                    <!-- Attachments in view mode -->
                    {#if noteAttachments.length > 0}
                        <div class="att-view-section">
                            <p class="att-view-title">Attachments</p>
                            {#each noteAttachments as att (att.id)}
                                <div class="att-view-row">
                                    <span class="att-view-icon">
                                        {att.mime_type.startsWith("audio/") ? "🎵" : att.mime_type.startsWith("image/") ? "🖼️" : att.mime_type.startsWith("video/") ? "🎬" : att.mime_type.includes("pdf") ? "📄" : "📎"}
                                    </span>
                                    <span class="att-view-name">{att.original_name}</span>
                                    {#if att.mime_type.startsWith("image/")}
                                        {#if imageBlobUrls[att.id]}
                                            <!-- svelte-ignore a11y-click-events-have-key-events -->
                                            <!-- svelte-ignore a11y-no-noninteractive-element-interactions -->
                                            <img src={imageBlobUrls[att.id]} alt={att.original_name} class="att-view-thumb" on:click={() => (previewImageId = att.id)} />
                                        {:else}
                                            <span class="att-loading">Loading…</span>
                                        {/if}
                                    {/if}
                                    {#if att.mime_type.startsWith("audio/")}
                                        {#if audioBlobUrls[att.id]}
                                            <!-- svelte-ignore a11y-media-has-caption -->
                                            <audio controls class="att-view-audio" src={audioBlobUrls[att.id]} />
                                        {:else}
                                            <span class="att-loading">Loading…</span>
                                        {/if}
                                    {/if}
                                </div>
                            {/each}
                        </div>
                    {/if}
                {/if}

                {#if editMode}
                    <!-- ── Colour ──────────────────────────────────────────────────────── -->
                    <div class="section">
                        <p class="section-label">Color</p>
                        <div class="color-row">
                            {#each COLORS as c}
                                <button class="color-dot" class:selected={color === c.value} style={`background: ${c.value ? COLOR_DOT[c.value] : "var(--color-surface)"}; border: 2px solid ${color === c.value ? "var(--color-accent)" : "var(--color-border)"}`} title={c.label} on:click={() => (color = c.value)} type="button" />
                            {/each}
                        </div>
                    </div>

                    <!-- ── Tags ─────────────────────────────────────────────────────────── -->
                    <div class="section">
                        <p class="section-label">Tags</p>
                        <div class="tag-row">
                            {#each noteTags as tag (tag.id)}
                                <span class="tag-chip">
                                    {tag.emoji}{tag.name}
                                    <button class="tag-rm" on:click={() => removeTag(tag.id)} type="button" aria-label="Remove tag">✕</button>
                                </span>
                            {/each}
                            <div class="tag-input-wrap">
                                <input
                                    type="text"
                                    class="tag-input"
                                    placeholder="Add tag…"
                                    bind:value={tagInput}
                                    on:focus={() => (showTagSuggestions = true)}
                                    on:blur={() => setTimeout(() => (showTagSuggestions = false), 150)}
                                    on:keydown={(e) => {
                                        if (e.key === "Enter") {
                                            e.preventDefault();
                                            if (tagSuggestions.length) addTag(tagSuggestions[0]);
                                            else if (tagInput.trim()) createAndAddTag();
                                        }
                                    }}
                                />
                                {#if showTagSuggestions && (tagSuggestions.length > 0 || tagInput.trim())}
                                    <div class="tag-suggestions">
                                        {#each tagSuggestions as t}
                                            <button class="tag-sug-item" on:mousedown|preventDefault={() => addTag(t)} type="button">
                                                {t.emoji}
                                                {t.name}
                                            </button>
                                        {/each}
                                        {#if tagInput.trim() && !tagSuggestions.find((t) => t.name.toLowerCase() === tagInput.trim().toLowerCase())}
                                            <div class="tag-create-row">
                                                <input type="text" class="emoji-input" placeholder="Emoji" bind:value={newTagEmoji} maxlength="4" />
                                                <button class="tag-create-btn" on:mousedown|preventDefault={createAndAddTag} type="button">
                                                    Create "{tagInput.trim()}"
                                                </button>
                                            </div>
                                        {/if}
                                    </div>
                                {/if}
                            </div>
                        </div>
                    </div>

                    <!-- ── Secret toggle ─────────────────────────────────────────────────── -->
                    {#if hasVault}
                        <div class="section">
                            <label class="secret-toggle">
                                <span class="secret-label">🔒 Secret note</span>
                                <input type="checkbox" bind:checked={isSecret} />
                                <span class="toggle-track" class:on={isSecret} />
                            </label>
                            {#if isSecret || note?.is_secret}
                                <input type="password" class="cred-input" placeholder="Vault PIN or password{secretStateChanged ? ' (required to change)' : ''}" bind:value={credential} />
                            {/if}
                        </div>
                    {/if}
                {/if}

                {#if error}
                    <p class="error-msg">{error}</p>
                {/if}
            </div>

            <!-- ── Footer ─────────────────────────────────────────────────────────── -->
            {#if editMode}
                <div class="modal-footer">
                    <button class="btn-cancel" on:click={close} type="button">Cancel</button>
                    <button class="btn-save" on:click={save} disabled={saving} type="button">
                        {saving ? "Saving…" : "Save"}
                    </button>
                </div>
            {/if}
        </div>
    </div>

    <!-- Image lightbox -->
    {#if previewImageId && imageBlobUrls[previewImageId]}
        <!-- svelte-ignore a11y-click-events-have-key-events -->
        <!-- svelte-ignore a11y-no-static-element-interactions -->
        <div class="lightbox" on:click={() => (previewImageId = null)}>
            <img src={imageBlobUrls[previewImageId]} alt="Preview" class="lightbox-img" />
        </div>
    {/if}
{/if}

<style>
    .modal-overlay {
        position: fixed;
        inset: 0;
        z-index: 80;
        background: var(--color-bg);
        display: flex;
        align-items: stretch;
        justify-content: center;
    }

    .modal-sheet {
        width: 100%;
        height: 100dvh;
        background: var(--color-bg);
        border-radius: 0;
        display: flex;
        flex-direction: column;
        overflow: hidden;
    }

    .modal-header {
        flex-shrink: 0;
        border-bottom: 1px solid var(--color-border);
    }

    .header-drag-pill {
        display: none;
    }

    .header-content {
        display: flex;
        align-items: center;
        gap: 8px;
        padding: 10px 14px 12px;
    }

    .title-input {
        flex: 1;
        height: 40px;
        padding: 0 12px;
        border: 1.5px solid var(--color-border);
        border-radius: 10px;
        background: var(--color-surface);
        color: var(--color-text-primary);
        font-size: 17px;
        font-weight: 600;
        outline: none;
        transition: border-color 0.15s;
    }

    .title-input:focus {
        border-color: var(--color-accent);
    }

    .title-view {
        flex: 1;
        font-size: 18px;
        font-weight: 700;
        color: var(--color-text-primary);
        margin: 0;
        overflow: hidden;
        display: -webkit-box;
        -webkit-line-clamp: 2;
        -webkit-box-orient: vertical;
    }

    .header-actions {
        display: flex;
        gap: 4px;
        flex-shrink: 0;
    }

    .icon-btn {
        width: 36px;
        height: 36px;
        border-radius: 8px;
        border: none;
        background: none;
        cursor: pointer;
        display: flex;
        align-items: center;
        justify-content: center;
        color: var(--color-text-primary);
        -webkit-tap-highlight-color: transparent;
    }

    .icon-btn:active {
        background: var(--color-muted);
    }

    .modal-body {
        flex: 1;
        overflow-y: auto;
        -webkit-overflow-scrolling: touch;
        display: flex;
        flex-direction: column;
        gap: 0;
    }

    .editor-wrap {
        border-radius: 0;
        overflow: hidden;
    }

    /* View mode */
    .locked-view {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        padding: 48px 24px;
        gap: 12px;
        opacity: 0.4;
    }

    .locked-hint {
        font-size: 14px;
        color: var(--color-text-muted);
        text-align: center;
        margin: 0;
    }

    .view-body {
        padding: 16px;
        font-size: 15px;
        line-height: 1.65;
        color: var(--color-text-primary);
        min-height: 120px;
    }

    .view-body :global(h1) {
        font-size: 1.4em;
        font-weight: 700;
        margin: 0.4em 0;
    }
    .view-body :global(h2) {
        font-size: 1.2em;
        font-weight: 600;
        margin: 0.35em 0;
    }
    .view-body :global(h3) {
        font-size: 1.05em;
        font-weight: 600;
        margin: 0.3em 0;
    }
    .view-body :global(p) {
        margin: 0 0 0.5em;
    }
    .view-body :global(ul),
    .view-body :global(ol) {
        padding-left: 1.4em;
        margin: 0 0 0.4em;
    }
    .view-body :global(blockquote) {
        border-left: 3px solid var(--color-accent);
        padding-left: 0.75em;
        color: var(--color-text-muted);
        margin: 0.5em 0;
    }
    .view-body :global(pre) {
        background: rgba(0, 0, 0, 0.1);
        border-radius: 6px;
        padding: 10px 12px;
        font-family: monospace;
        font-size: 13px;
        overflow-x: auto;
    }
    .view-body :global(code) {
        font-family: monospace;
        font-size: 0.9em;
        background: rgba(0, 0, 0, 0.1);
        border-radius: 3px;
        padding: 1px 4px;
    }
    .view-body :global(a) {
        color: var(--color-accent);
        text-decoration: underline;
    }
    .view-body :global(table) {
        border-collapse: collapse;
        width: 100%;
    }
    .view-body :global(th),
    .view-body :global(td) {
        border: 1px solid var(--color-border);
        padding: 5px 8px;
        font-size: 13px;
    }
    .view-body :global(.task-list) {
        list-style: none;
        padding-left: 0.5em;
    }
    .view-body :global(.task-list li) {
        display: flex;
        align-items: flex-start;
        gap: 6px;
    }

    .empty-hint {
        font-style: italic;
        color: var(--color-text-muted);
        font-size: 14px;
        margin: 0;
    }

    /* Attachments (view mode) */
    .att-view-section {
        padding: 12px 16px;
        border-top: 1px solid var(--color-border);
        display: flex;
        flex-direction: column;
        gap: 10px;
    }

    .att-view-title {
        font-size: 10px;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        color: var(--color-text-muted);
        margin: 0;
    }

    .att-view-row {
        display: flex;
        flex-direction: column;
        gap: 4px;
    }

    .att-view-icon {
        font-size: 16px;
    }

    .att-view-name {
        font-size: 13px;
        color: var(--color-text-primary);
    }

    .att-view-thumb {
        max-height: 120px;
        border-radius: 8px;
        object-fit: cover;
        cursor: pointer;
        align-self: flex-start;
    }

    .att-view-audio {
        width: 100%;
    }

    .att-loading {
        font-size: 11px;
        color: var(--color-text-muted);
        font-style: italic;
    }

    /* Edit mode sections */
    .section {
        padding: 14px 16px;
        border-top: 1px solid var(--color-border);
        display: flex;
        flex-direction: column;
        gap: 8px;
    }

    .section-label {
        font-size: 11px;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        color: var(--color-text-muted);
        margin: 0;
    }

    .color-row {
        display: flex;
        gap: 10px;
        align-items: center;
    }

    .color-dot {
        width: 26px;
        height: 26px;
        border-radius: 50%;
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
        transition: transform 0.12s;
    }

    .color-dot.selected {
        transform: scale(1.2);
    }

    .tag-row {
        display: flex;
        flex-wrap: wrap;
        gap: 6px;
        align-items: center;
    }

    .tag-chip {
        display: inline-flex;
        align-items: center;
        gap: 3px;
        padding: 4px 8px;
        border-radius: 12px;
        background: rgba(34, 211, 238, 0.1);
        border: 1px solid rgba(34, 211, 238, 0.3);
        font-size: 12px;
        color: var(--color-accent);
    }

    .tag-rm {
        background: none;
        border: none;
        font-size: 10px;
        cursor: pointer;
        color: inherit;
        opacity: 0.6;
        margin-left: 2px;
        padding: 0 2px;
        -webkit-tap-highlight-color: transparent;
    }

    .tag-input-wrap {
        position: relative;
    }

    .tag-input {
        height: 32px;
        padding: 0 10px;
        border: 1px solid var(--color-border);
        border-radius: 8px;
        background: var(--color-surface);
        color: var(--color-text-primary);
        font-size: 13px;
        outline: none;
        width: 120px;
    }

    .tag-suggestions {
        position: absolute;
        top: calc(100% + 4px);
        left: 0;
        z-index: 60;
        background: var(--color-surface);
        border: 1px solid var(--color-border);
        border-radius: 10px;
        box-shadow: 0 8px 24px rgba(0, 0, 0, 0.2);
        min-width: 180px;
        max-height: 200px;
        overflow-y: auto;
    }

    .tag-sug-item {
        display: block;
        width: 100%;
        text-align: left;
        padding: 8px 12px;
        background: none;
        border: none;
        font-size: 13px;
        color: var(--color-text-primary);
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
    }

    .tag-sug-item:active {
        background: var(--color-muted);
    }

    .tag-create-row {
        display: flex;
        gap: 6px;
        align-items: center;
        padding: 6px 10px;
        border-top: 1px solid var(--color-border);
    }

    .emoji-input {
        width: 44px;
        height: 30px;
        padding: 0 6px;
        border: 1px solid var(--color-border);
        border-radius: 6px;
        background: var(--color-bg);
        color: var(--color-text-primary);
        font-size: 16px;
        text-align: center;
        outline: none;
    }

    .tag-create-btn {
        flex: 1;
        height: 30px;
        padding: 0 8px;
        border-radius: 6px;
        border: none;
        background: var(--color-accent);
        color: #fff;
        font-size: 12px;
        font-weight: 600;
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
        white-space: nowrap;
        overflow: hidden;
        text-overflow: ellipsis;
    }

    /* Secret toggle */
    .secret-toggle {
        display: flex;
        align-items: center;
        gap: 10px;
        cursor: pointer;
    }

    .secret-label {
        flex: 1;
        font-size: 14px;
        color: var(--color-text-primary);
    }

    .secret-toggle input[type="checkbox"] {
        display: none;
    }

    .toggle-track {
        width: 42px;
        height: 24px;
        border-radius: 12px;
        background: var(--color-border);
        position: relative;
        transition: background 0.2s;
        flex-shrink: 0;
    }

    .toggle-track::after {
        content: "";
        position: absolute;
        top: 2px;
        left: 2px;
        width: 20px;
        height: 20px;
        border-radius: 50%;
        background: #fff;
        transition: transform 0.2s;
    }

    .toggle-track.on {
        background: var(--color-accent);
    }

    .toggle-track.on::after {
        transform: translateX(18px);
    }

    .cred-input {
        width: 100%;
        height: 40px;
        padding: 0 12px;
        border: 1.5px solid var(--color-border);
        border-radius: 10px;
        background: var(--color-surface);
        color: var(--color-text-primary);
        font-size: 15px;
        outline: none;
        box-sizing: border-box;
        transition: border-color 0.15s;
    }

    .cred-input:focus {
        border-color: var(--color-accent);
    }

    .error-msg {
        margin: 0 16px 12px;
        padding: 10px 14px;
        border-radius: 8px;
        background: rgba(239, 68, 68, 0.12);
        color: #dc2626;
        font-size: 13px;
    }

    /* Footer */
    .modal-footer {
        flex-shrink: 0;
        display: flex;
        gap: 10px;
        padding: 12px 16px;
        padding-bottom: max(12px, env(safe-area-inset-bottom, 12px));
        border-top: 1px solid var(--color-border);
        background: var(--color-surface);
    }

    .btn-cancel,
    .btn-save {
        flex: 1;
        height: 46px;
        border-radius: 12px;
        border: none;
        font-size: 15px;
        font-weight: 600;
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
        transition: opacity 0.15s;
    }

    .btn-cancel {
        background: var(--color-muted);
        color: var(--color-text-primary);
    }

    .btn-save {
        background: var(--color-accent);
        color: #fff;
    }

    .btn-save:disabled {
        opacity: 0.5;
    }

    /* Lightbox */
    .lightbox {
        position: fixed;
        inset: 0;
        z-index: 200;
        background: rgba(0, 0, 0, 0.88);
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 20px;
        cursor: zoom-out;
    }

    .lightbox-img {
        max-width: 100%;
        max-height: 100%;
        object-fit: contain;
        border-radius: 10px;
    }
</style>
