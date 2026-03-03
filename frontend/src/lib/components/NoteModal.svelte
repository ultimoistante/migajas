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
    let showEmojiPicker = false;

    const EMOJIS = ["😀", "😂", "😍", "🤔", "😎", "😢", "😡", "🥳", "🤯", "🥺", "👍", "👎", "👋", "🙌", "🤝", "💪", "🫶", "❤️", "🔥", "⭐", "✅", "❌", "⚠️", "💡", "🔔", "📌", "📎", "🔗", "🏷️", "📋", "📝", "📖", "📚", "🗒️", "✏️", "🖊️", "📧", "💬", "🗨️", "📢", "🏠", "🏢", "🚀", "✈️", "🚗", "🌍", "🗺️", "📍", "⛺", "🏖️", "🍕", "🍔", "☕", "🍺", "🎂", "🍎", "🥗", "🍜", "🎉", "🎁", "💰", "💳", "📈", "📉", "🏦", "💼", "🛒", "🎯", "🏆", "🥇", "🔧", "⚙️", "🖥️", "📱", "🖨️", "🔋", "💾", "🖱️", "⌨️", "🔐", "🌱", "🌿", "🌸", "🌻", "🍀", "🌈", "☀️", "🌙", "❄️", "🌊", "🐶", "🐱", "🐭", "🐸", "🦊", "🐼", "🐨", "🦁", "🐯", "🦋"];

    function pickEmoji(e: string) {
        newTagEmoji = e;
        showEmojiPicker = false;
        showTagSuggestions = true;
    }

    $: tagSuggestions = $tagsStore.filter((t) => !noteTags.find((nt) => nt.id === t.id) && (tagInput === "" || t.name.toLowerCase().includes(tagInput.toLowerCase())));

    function addTag(tag: Tag) {
        if (!noteTags.find((t) => t.id === tag.id)) {
            noteTags = [...noteTags, tag];
        }
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

    // Blob URLs for audio/image attachments (authenticated fetch)
    let audioBlobUrls: Record<string, string> = {};
    let imageBlobUrls: Record<string, string> = {};
    let previewImageId: string | null = null;

    async function loadAudioBlobUrl(id: string) {
        try {
            audioBlobUrls = { ...audioBlobUrls, [id]: await attachmentsApi.fetchBlobUrl(id) };
        } catch {
            // silently fail
        }
    }

    async function loadImageBlobUrl(id: string) {
        try {
            imageBlobUrls = { ...imageBlobUrls, [id]: await attachmentsApi.fetchBlobUrl(id) };
        } catch {
            // silently fail
        }
    }

    $: noteAttachments.forEach((att) => {
        if (att.mime_type.startsWith("audio/") && !audioBlobUrls[att.id]) {
            loadAudioBlobUrl(att.id);
        }
        if (att.mime_type.startsWith("image/") && !imageBlobUrls[att.id]) {
            loadImageBlobUrl(att.id);
        }
    });

    onDestroy(() => {
        Object.values(audioBlobUrls).forEach((u) => URL.revokeObjectURL(u));
        Object.values(imageBlobUrls).forEach((u) => URL.revokeObjectURL(u));
    });

    // View vs edit mode (only relevant for existing notes)
    let editMode = false;

    const COLORS = [
        { value: "", label: "Default" },
        { value: "yellow", label: "Yellow" },
        { value: "blue", label: "Blue" },
        { value: "green", label: "Green" },
        { value: "pink", label: "Pink" },
        { value: "purple", label: "Purple" },
    ];

    const COLOR_SWATCHES: Record<string, string> = {
        "": "bg-base-100 border-2 border-base-300",
        yellow: "bg-yellow-300",
        blue: "bg-blue-300",
        green: "bg-green-300",
        pink: "bg-pink-300",
        purple: "bg-purple-300",
    };

    // Reset form when modal opens — tracked with a prev-value guard so that
    // reactive updates to `note` (e.g. store re-emissions) never reset editMode
    // while the modal is already open and the user may be editing.
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
                editMode = false; // always start in view mode for existing notes
                currentNoteId = note.id;
                // Load attachments for this note (revoke any old blob URLs first)
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
                editMode = true; // create mode is always "edit"
                currentNoteId = null;
                noteAttachments = [];
            }
            credential = "";
            error = "";
        }
    }

    $: hasVault = $currentUser?.has_vault ?? false;

    // Whether user is toggling the secret state compared to original
    $: secretStateChanged = note ? isSecret !== note.is_secret : false;

    async function save() {
        error = "";
        saving = true;
        try {
            if (note) {
                // Update existing note
                const payload: Record<string, unknown> = { title, body, color, tags: noteTags.map((t) => t.id) };
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
                // Auto-save already created the note (e.g. a file was attached before
                // the user clicked Save). Update it with the final title, body, tags
                // and colour instead of creating a duplicate.
                if (isSecret && !credential) {
                    error = "Please enter your vault credential to create a secret note.";
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
                // Create new note
                if (isSecret && !credential) {
                    error = "Please enter your vault credential to create a secret note.";
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
                // Expose the new note's id so pending file uploads can proceed
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
        // Called by RichEditor when a file is dropped on an unsaved note.
        // Save the note first so we have an id for the upload.
        if (currentNoteId) return; // already saved
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
        // Keep the note card badge in sync immediately (no need to wait for save)
        if (currentNoteId) notesStore.patchAttachmentCount(currentNoteId, 1);
    }

    function handleAttachmentDeleted(id: string) {
        noteAttachments = noteAttachments.filter((a) => a.id !== id);
        if (currentNoteId) notesStore.patchAttachmentCount(currentNoteId, -1);
    }

    /**
     * Intercept clicks on note-reference links rendered in view mode.
     * Links use href="#note-{id}".
     */
    function handleViewClick(event: MouseEvent) {
        const target = event.target as HTMLElement;
        const anchor = target.closest("a") as HTMLAnchorElement | null;
        if (!anchor) return;
        const href = anchor.getAttribute("href") ?? "";
        if (href.startsWith("#note-")) {
            event.preventDefault();
            const targetId = href.slice(6); // strip "#note-"
            const targetNote = $notesStore.find((n) => n.id === targetId);
            if (targetNote) dispatch("openNote", targetNote);
        }
    }

    function close() {
        dispatch("close");
    }
</script>

{#if open}
    <!-- Backdrop -->
    <div class="fixed inset-0 bg-black/50 z-40 flex items-center justify-center p-4" on:click|self={close} on:keydown={(e) => e.key === "Escape" && close()} role="dialog" aria-modal="true">
        <div class="bg-base-100 rounded-2xl shadow-2xl w-full max-w-2xl max-h-[90vh] flex flex-col" on:click|stopPropagation>
            <!-- Header -->
            <div class="flex items-center gap-3 p-5 border-b border-base-300">
                {#if editMode}
                    <input type="text" placeholder="Note title" class="input input-ghost text-xl font-semibold flex-1 focus:outline-none px-0" bind:value={title} />
                {:else}
                    <h2 class="text-xl font-semibold flex-1 line-clamp-2">{title || "Untitled"}</h2>
                {/if}

                <!-- Pencil (enter edit mode) — only in view mode for existing notes -->
                {#if note && !editMode}
                    <button class="btn btn-ghost btn-sm btn-circle" title="Edit note" on:click={() => (editMode = true)} type="button">
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M11 4H4a2 2 0 0 0-2 2v14a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-7" />
                            <path d="M18.5 2.5a2.121 2.121 0 0 1 3 3L12 15l-4 1 1-4 9.5-9.5z" />
                        </svg>
                    </button>
                {/if}

                <!-- Close -->
                <button class="btn btn-ghost btn-sm btn-circle" on:click={close} type="button">
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M18 6 6 18M6 6l12 12" />
                    </svg>
                </button>
            </div>

            <!-- Body (scrollable) -->
            <div class="flex-1 overflow-y-auto p-5 flex flex-col gap-4">
                <!-- Editor / viewer -->
                {#if editMode}
                    <div class="border border-base-300 rounded-xl overflow-hidden">
                        <RichEditor content={body} editable={true} placeholder="Write something…" noteId={currentNoteId} allNotes={$notesStore} attachments={noteAttachments} on:change={(e) => (body = e.detail)} on:autoSave={handleAutoSave} on:attachmentAdded={(e) => handleAttachmentAdded(e.detail)} on:attachmentDeleted={(e) => handleAttachmentDeleted(e.detail)} />
                    </div>
                {:else if note?.is_secret && note?.is_locked}
                    <!-- Secret and still locked: big lock -->
                    <div class="flex flex-col items-center justify-center py-12 text-base-content/30">
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-16 h-16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                            <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                            <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                        </svg>
                        <p class="text-sm mt-3">This note is locked. Unlock it to view the content.</p>
                    </div>
                {:else}
                    <!-- View mode: rendered HTML -->
                    <!-- svelte-ignore a11y-click-events-have-key-events -->
                    <!-- svelte-ignore a11y-no-static-element-interactions -->
                    <div class="prose prose-sm prose-headings:text-base-content prose-headings:font-semibold max-w-none min-h-[120px]" on:click={handleViewClick}>
                        {#if body}
                            {@html body}
                        {:else}
                            <p class="text-base-content/40 italic">Empty note</p>
                        {/if}
                    </div>
                    {#if noteAttachments.length > 0}
                        <div class="mt-3 flex flex-col gap-1.5">
                            <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wide">Attachments</p>
                            {#each noteAttachments as att (att.id)}
                                <div class="flex flex-col gap-1 text-sm">
                                    <div class="flex items-center gap-2">
                                        <span class="text-base">{att.mime_type.startsWith("audio/") ? "🎵" : att.mime_type.startsWith("image/") ? "🖼️" : att.mime_type.startsWith("video/") ? "🎬" : att.mime_type.includes("pdf") ? "📄" : "📎"}</span>
                                        <a href={attachmentsApi.contentUrl(att.id)} class="text-sm hover:underline truncate flex-1" download={att.original_name} target="_blank" rel="noopener">{att.original_name}</a>
                                    </div>
                                    {#if att.mime_type.startsWith("image/")}
                                        {#if imageBlobUrls[att.id]}
                                            <!-- svelte-ignore a11y-click-events-have-key-events -->
                                            <!-- svelte-ignore a11y-no-noninteractive-element-interactions -->
                                            <img src={imageBlobUrls[att.id]} alt={att.original_name} class="max-h-32 rounded cursor-pointer object-cover hover:opacity-80 transition-opacity self-start" on:click={() => (previewImageId = att.id)} />
                                        {:else}
                                            <div class="flex items-center gap-1 text-xs text-base-content/40">
                                                <span class="loading loading-spinner loading-xs" />
                                                Loading image…
                                            </div>
                                        {/if}
                                    {/if}
                                    {#if att.mime_type.startsWith("audio/")}
                                        {#if audioBlobUrls[att.id]}
                                            <!-- svelte-ignore a11y-media-has-caption -->
                                            <audio controls class="w-40" src={audioBlobUrls[att.id]} />
                                        {:else}
                                            <span class="loading loading-spinner loading-xs" />
                                        {/if}
                                    {/if}
                                </div>
                            {/each}
                        </div>
                    {/if}
                {/if}

                {#if editMode}
                    <!-- Color & tags (below editor) -->
                    <div class="divider my-0">Style &amp; Tags</div>

                    <!-- Color picker -->
                    <div class="flex items-center gap-2">
                        <span class="text-xs text-base-content/50 w-10 shrink-0">Color</span>
                        <div class="flex gap-1 items-center">
                            {#each COLORS as c}
                                <button class="w-5 h-5 rounded-full transition-transform hover:scale-110 {COLOR_SWATCHES[c.value]}" class:ring-2={color === c.value} class:ring-primary={color === c.value} title={c.label} on:click={() => (color = c.value)} type="button" />
                            {/each}
                        </div>
                    </div>

                    <!-- Tag editor -->
                    <div class="flex flex-col gap-1.5">
                        <span class="text-xs text-base-content/50">Tags</span>
                        <div class="flex flex-wrap gap-1 items-center min-h-[28px]">
                            {#each noteTags as tag (tag.id)}
                                <span class="badge badge-sm gap-1 pr-0.5">
                                    {#if tag.emoji}<span>{tag.emoji}</span>{/if}{tag.name}
                                    <button class="ml-0.5 opacity-60 hover:opacity-100" on:click={() => removeTag(tag.id)} type="button" aria-label="Remove tag">
                                        <svg xmlns="http://www.w3.org/2000/svg" class="w-2.5 h-2.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="3"><path d="M18 6 6 18M6 6l12 12" /></svg>
                                    </button>
                                </span>
                            {/each}
                            <div class="relative">
                                <input
                                    type="text"
                                    class="input input-ghost input-xs w-28 focus:outline-none px-1"
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
                                    <div class="absolute top-full left-0 z-50 w-56 bg-base-200 border border-base-300 rounded-lg shadow-lg text-sm flex flex-col">
                                        <!-- Existing tag matches (scrollable) -->
                                        {#if tagSuggestions.length > 0}
                                            <ul class="max-h-40 overflow-y-auto p-1">
                                                {#each tagSuggestions as s}
                                                    <li>
                                                        <button class="w-full text-left px-2 py-1 hover:bg-base-300 rounded" on:mousedown|preventDefault={() => addTag(s)} type="button">
                                                            {s.emoji ? s.emoji + " " : ""}{s.name}
                                                        </button>
                                                    </li>
                                                {/each}
                                            </ul>
                                        {/if}
                                        <!-- Create new tag row — outside scroll container so picker isn't clipped -->
                                        {#if tagInput.trim() && !tagSuggestions.find((s) => s.name.toLowerCase() === tagInput.trim().toLowerCase())}
                                            <div class="border-t border-base-300 p-1 relative">
                                                <div class="flex items-center gap-1">
                                                    <!-- Emoji button -->
                                                    <button type="button" class="btn btn-xs btn-ghost w-9 px-0 text-base leading-none shrink-0" title="Pick emoji" on:mousedown|preventDefault={() => (showEmojiPicker = !showEmojiPicker)}>{newTagEmoji || "😀"}</button>
                                                    <button class="flex-1 text-left py-1 px-1 hover:bg-base-300 rounded text-primary text-xs" on:mousedown|preventDefault={createAndAddTag} type="button">
                                                        + Create "{tagInput.trim()}"
                                                    </button>
                                                </div>
                                                <!-- Emoji grid — opens upward, outside any overflow container -->
                                                {#if showEmojiPicker}
                                                    <div class="absolute bottom-full left-0 mb-1 z-[70] bg-base-100 border border-base-300 rounded-xl shadow-2xl p-2 w-64" on:mousedown|preventDefault>
                                                        <div class="grid grid-cols-10 gap-0.5">
                                                            {#each EMOJIS as em}
                                                                <button type="button" class="text-lg leading-none p-0.5 rounded hover:bg-base-200 transition-colors" on:mousedown|preventDefault={() => pickEmoji(em)}>{em}</button>
                                                            {/each}
                                                        </div>
                                                        {#if newTagEmoji}
                                                            <button
                                                                type="button"
                                                                class="mt-2 text-xs text-base-content/40 hover:text-base-content w-full text-left px-1"
                                                                on:mousedown|preventDefault={() => {
                                                                    newTagEmoji = "";
                                                                    showEmojiPicker = false;
                                                                    showTagSuggestions = true;
                                                                }}>✕ Clear emoji</button
                                                            >
                                                        {/if}
                                                    </div>
                                                {/if}
                                            </div>
                                        {/if}
                                    </div>
                                {/if}
                            </div>
                        </div>
                    </div>
                {/if}

                {#if editMode}
                    <!-- Secret toggle (available for both new and existing notes) -->
                    <div class="divider my-0">Security</div>

                    {#if !hasVault}
                        <div class="alert alert-warning text-sm">
                            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="m21.73 18-8-14a2 2 0 0 0-3.48 0l-8 14A2 2 0 0 0 4 21h16a2 2 0 0 0 1.73-3Z" /><path d="M12 9v4m0 4h.01" />
                            </svg>
                            <span>You haven't set up a vault credential yet. Go to <strong>Settings</strong> to set your PIN or vault password first.</span>
                        </div>
                    {:else}
                        <label class="label cursor-pointer justify-start gap-3 p-0">
                            <input type="checkbox" class="toggle toggle-warning toggle-sm" bind:checked={isSecret} />
                            <span class="label-text flex items-center gap-1.5">
                                <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <rect x="3" y="11" width="18" height="11" rx="2" ry="2" /><path d="M7 11V7a5 5 0 0 1 10 0v4" />
                                </svg>
                                {isSecret ? "Secret note (encrypted)" : "Make this a secret note"}
                            </span>
                        </label>

                        {#if isSecret || note?.is_secret}
                            <div>
                                <label class="label pb-1" for="cred-input">
                                    <span class="label-text text-sm">
                                        {#if secretStateChanged}
                                            {isSecret ? "Enter vault credential to encrypt this note" : "Enter vault credential to decrypt and un-secret this note"}
                                        {:else}
                                            Vault credential (required to save changes to a secret note)
                                        {/if}
                                    </span>
                                </label>
                                <input id="cred-input" type="password" placeholder="Vault PIN or password" class="input input-bordered w-full input-sm" bind:value={credential} autocomplete="off" />
                                {#if secretStateChanged && isSecret}
                                    <p class="text-xs text-base-content/50 mt-1">The note body will be encrypted end-to-end. You'll need this credential to unlock it later.</p>
                                {/if}
                            </div>
                        {/if}
                    {/if}
                {/if}

                {#if error}
                    <div class="alert alert-error text-sm">{error}</div>
                {/if}
            </div>

            <!-- Footer -->
            {#if editMode}
                <div class="flex justify-end gap-2 p-4 border-t border-base-300">
                    {#if note}
                        <button
                            class="btn btn-ghost btn-sm"
                            on:click={() => {
                                editMode = false;
                                error = "";
                            }}
                            type="button">Cancel</button
                        >
                    {:else}
                        <button class="btn btn-ghost btn-sm" on:click={close} type="button">Cancel</button>
                    {/if}
                    <button class="btn btn-primary btn-sm" on:click={save} disabled={saving || (!note && isSecret && (!hasVault || !credential)) || (secretStateChanged && !credential)} type="button">
                        {#if saving}
                            <span class="loading loading-spinner loading-xs" />
                        {/if}
                        {note ? "Save changes" : "Create note"}
                    </button>
                </div>
            {:else}
                <div class="flex justify-end gap-2 p-4 border-t border-base-300">
                    <button class="btn btn-ghost btn-sm" on:click={close} type="button">Close</button>
                </div>
            {/if}
        </div>
    </div>
{/if}

{#if previewImageId && imageBlobUrls[previewImageId]}
    {@const previewAtt = noteAttachments.find((a) => a.id === previewImageId)}
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <!-- svelte-ignore a11y-no-static-element-interactions -->
    <div class="fixed inset-0 z-[9999] bg-black/85 flex flex-col items-center justify-center" on:click|self={() => (previewImageId = null)}>
        <div class="relative flex flex-col items-center gap-3 max-w-[90vw] max-h-[90vh]">
            <img src={imageBlobUrls[previewImageId]} alt={previewAtt?.original_name ?? ""} class="max-w-full max-h-[80vh] rounded-lg shadow-2xl object-contain" />
            <div class="flex items-center gap-2">
                {#if previewAtt}
                    <a href={imageBlobUrls[previewImageId]} download={previewAtt.original_name} class="btn btn-sm btn-neutral gap-1.5">
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M21 15v4a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2v-4" />
                            <polyline points="7 10 12 15 17 10" />
                            <line x1="12" y1="15" x2="12" y2="3" />
                        </svg>
                        Download
                    </a>
                {/if}
                <button class="btn btn-sm btn-ghost text-white gap-1.5" on:click={() => (previewImageId = null)} type="button">
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M18 6 6 18M6 6l12 12" />
                    </svg>
                    Close
                </button>
            </div>
        </div>
    </div>
{/if}
