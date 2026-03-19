<script lang="ts">
    import { onMount, onDestroy, createEventDispatcher, tick } from "svelte";
    import { Editor } from "@tiptap/core";
    import StarterKit from "@tiptap/starter-kit";
    import TaskList from "@tiptap/extension-task-list";
    import TaskItem from "@tiptap/extension-task-item";
    import Placeholder from "@tiptap/extension-placeholder";
    import Link from "@tiptap/extension-link";
    import Table from "@tiptap/extension-table";
    import TableRow from "@tiptap/extension-table-row";
    import TableHeader from "@tiptap/extension-table-header";
    import TableCell from "@tiptap/extension-table-cell";
    import { attachments as attachmentsApi, type Attachment, type Note } from "$lib/api/client";

    export let content: string = "";
    export let editable: boolean = true;
    export let placeholder: string = "Start writing…";
    export let noteId: string | null = null;
    export let allNotes: Note[] = [];
    export let attachments: Attachment[] = [];

    const dispatch = createEventDispatcher<{
        change: string;
        attachmentAdded: Attachment;
        attachmentDeleted: string;
        autoSave: void;
    }>();

    let editorEl: HTMLDivElement;
    let editor: Editor;
    let isInternalUpdate = false;

    // Emoji picker
    let showEmojiPicker = false;
    let emojiPickerEl: HTMLDivElement;
    let emojiPickerMounted = false;

    // Link input
    let showLinkInput = false;
    let linkUrl = "";

    // Note ref picker
    let showNoteRefPicker = false;
    let noteRefSearch = "";
    $: filteredNotes = allNotes.filter((n) => n.title.toLowerCase().includes(noteRefSearch.toLowerCase()));

    $: isInTable = editor?.isActive("table") ?? false;

    // File upload
    let fileInput: HTMLInputElement;
    let uploading = false;

    // Voice recording
    let isRecording = false;
    let recordingSeconds = 0;
    let mediaRecorder: MediaRecorder | null = null;
    let recordingChunks: Blob[] = [];
    let recordingTimer: ReturnType<typeof setInterval> | null = null;
    let mediaStream: MediaStream | null = null;

    // Blob URLs for media preview (requires auth header)
    let audioBlobUrls: Record<string, string> = {};
    let imageBlobUrls: Record<string, string> = {};
    let previewImageId: string | null = null;

    onMount(() => {
        editor = new Editor({
            element: editorEl,
            editable,
            extensions: [
                StarterKit,
                TaskList.configure({ HTMLAttributes: { class: "task-list" } }),
                TaskItem.configure({ nested: true }),
                Placeholder.configure({ placeholder }),
                Link.configure({
                    openOnClick: false,
                    autolink: true,
                    HTMLAttributes: { class: "note-link" },
                }),
                Table.configure({ resizable: false }),
                TableRow,
                TableHeader,
                TableCell,
            ],
            content: content || "",
            onTransaction: () => {
                editor = editor;
            },
            onUpdate: ({ editor }) => {
                isInternalUpdate = true;
                dispatch("change", editor.getHTML());
                setTimeout(() => (isInternalUpdate = false), 0);
            },
        });
    });

    onDestroy(() => {
        editor?.destroy();
        stopRecording();
        mediaStream?.getTracks().forEach((t) => t.stop());
        Object.values(audioBlobUrls).forEach((u) => URL.revokeObjectURL(u));
        Object.values(imageBlobUrls).forEach((u) => URL.revokeObjectURL(u));
    });

    $: if (editor && content !== undefined && !isInternalUpdate) {
        const current = editor.getHTML();
        if (current !== content) editor.commands.setContent(content, false);
    }

    $: if (editor) editor.setEditable(editable);

    // ── Blob URL loading ───────────────────────────────────────────────────────

    $: attachments.forEach((att) => {
        if (att.mime_type.startsWith("audio/") && !audioBlobUrls[att.id]) loadAudioBlobUrl(att.id);
        if (att.mime_type.startsWith("image/") && !imageBlobUrls[att.id]) loadImageBlobUrl(att.id);
    });

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

    // ── Emoji ───────────────────────────────────────────────────────────────────

    async function toggleEmojiPicker() {
        showEmojiPicker = !showEmojiPicker;
        if (showEmojiPicker && !emojiPickerMounted) {
            await tick();
            if (emojiPickerEl) {
                const { Picker } = await import("emoji-mart");
                const { default: data } = await import("@emoji-mart/data");
                new Picker({
                    data,
                    theme: "auto",
                    onEmojiSelect: (emoji: { native: string }) => {
                        editor?.chain().focus().insertContent(emoji.native).run();
                        showEmojiPicker = false;
                    },
                    parent: emojiPickerEl,
                });
                emojiPickerMounted = true;
            }
        }
    }

    // ── Link ────────────────────────────────────────────────────────────────────

    function toggleLink() {
        if (editor?.isActive("link")) {
            editor.chain().focus().unsetLink().run();
            showLinkInput = false;
        } else {
            linkUrl = editor?.getAttributes("link").href ?? "";
            showLinkInput = !showLinkInput;
        }
    }

    function applyLink() {
        const href = linkUrl.trim();
        if (!href) {
            editor?.chain().focus().unsetLink().run();
        } else {
            const fullHref = href.startsWith("http") ? href : "https://" + href;
            editor?.chain().focus().setLink({ href: fullHref }).run();
        }
        showLinkInput = false;
        linkUrl = "";
    }

    // ── Table ───────────────────────────────────────────────────────────────────

    function insertTable() {
        editor?.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run();
    }

    // ── Note ref ────────────────────────────────────────────────────────────────

    function insertNoteRef(note: Note) {
        const href = `#note-${note.id}`;
        const sel = editor?.state.selection;
        const hasSelection = sel && sel.from !== sel.to;
        if (hasSelection) {
            editor?.chain().focus().setLink({ href, title: note.title }).run();
        } else {
            editor
                ?.chain()
                .focus()
                .insertContent(`<a href="${href}">${note.title || "(Untitled)"}</a>`)
                .run();
        }
        showNoteRefPicker = false;
        noteRefSearch = "";
    }

    // ── File upload ─────────────────────────────────────────────────────────────

    async function handleFileSelected(event: Event) {
        const input = event.target as HTMLInputElement;
        const file = input.files?.[0];
        if (!file) return;
        input.value = "";
        await uploadFile(file);
    }

    async function uploadFile(file: File) {
        uploading = true;
        let targetNoteId = noteId;

        if (!targetNoteId) {
            dispatch("autoSave");
            const start = Date.now();
            while (!noteId && Date.now() - start < 5000) {
                await new Promise((r) => setTimeout(r, 100));
            }
            targetNoteId = noteId;
        }

        if (!targetNoteId) {
            uploading = false;
            alert("Please save the note first before attaching files.");
            return;
        }

        try {
            const att = await attachmentsApi.upload(targetNoteId, file);
            dispatch("attachmentAdded", att);
        } catch (e) {
            alert("Upload failed: " + (e instanceof Error ? e.message : "unknown error"));
        } finally {
            uploading = false;
        }
    }

    // ── Voice recording ─────────────────────────────────────────────────────────

    async function toggleRecording() {
        if (isRecording) {
            stopRecording();
        } else {
            await startRecording();
        }
    }

    async function startRecording() {
        try {
            mediaStream = await navigator.mediaDevices.getUserMedia({ audio: true });
        } catch {
            alert("Microphone access denied or not available.");
            return;
        }
        const mimeType = MediaRecorder.isTypeSupported("audio/webm;codecs=opus") ? "audio/webm;codecs=opus" : MediaRecorder.isTypeSupported("audio/ogg;codecs=opus") ? "audio/ogg;codecs=opus" : "audio/webm";

        recordingChunks = [];
        mediaRecorder = new MediaRecorder(mediaStream, { mimeType });
        mediaRecorder.ondataavailable = (e) => {
            if (e.data.size > 0) recordingChunks.push(e.data);
        };
        mediaRecorder.onstop = async () => {
            const ext = mimeType.includes("ogg") ? "ogg" : "webm";
            const blob = new Blob(recordingChunks, { type: mimeType });
            const ts = new Date().toISOString().replace(/[:.]/g, "-");
            const file = new File([blob], `recording-${ts}.${ext}`, { type: mimeType });
            await uploadFile(file);
        };
        mediaRecorder.start();
        isRecording = true;
        recordingSeconds = 0;
        recordingTimer = setInterval(() => (recordingSeconds += 1), 1000);
    }

    function stopRecording() {
        if (recordingTimer) clearInterval(recordingTimer);
        recordingTimer = null;
        if (mediaRecorder?.state !== "inactive") mediaRecorder?.stop();
        mediaStream?.getTracks().forEach((t) => t.stop());
        mediaStream = null;
        isRecording = false;
    }

    function formatSeconds(s: number): string {
        return `${Math.floor(s / 60)
            .toString()
            .padStart(2, "0")}:${(s % 60).toString().padStart(2, "0")}`;
    }

    // ── Attachment helpers ──────────────────────────────────────────────────────

    function fileIcon(mime: string): string {
        if (mime.startsWith("image/")) return "🖼️";
        if (mime.startsWith("audio/")) return "🎵";
        if (mime.startsWith("video/")) return "🎬";
        if (mime.includes("pdf")) return "📄";
        return "📎";
    }

    function formatSize(bytes: number): string {
        if (bytes < 1024) return bytes + " B";
        if (bytes < 1024 * 1024) return (bytes / 1024).toFixed(1) + " KB";
        return (bytes / (1024 * 1024)).toFixed(1) + " MB";
    }

    async function deleteAttachment(id: string) {
        try {
            await attachmentsApi.delete(id);
            if (audioBlobUrls[id]) {
                URL.revokeObjectURL(audioBlobUrls[id]);
                const { [id]: _, ...rest } = audioBlobUrls;
                audioBlobUrls = rest;
            }
            if (imageBlobUrls[id]) {
                URL.revokeObjectURL(imageBlobUrls[id]);
                const { [id]: _i, ...restI } = imageBlobUrls;
                imageBlobUrls = restI;
            }
            if (previewImageId === id) previewImageId = null;
            dispatch("attachmentDeleted", id);
        } catch (e) {
            alert("Delete failed: " + (e instanceof Error ? e.message : "unknown error"));
        }
    }
</script>

{#if editor}
    <!-- ── Toolbar (horizontally scrollable for mobile) ─────────────────────── -->
    <div class="toolbar-scroll">
        <div class="toolbar">
            <!-- Emoji -->
            <div class="relative">
                <button class="tb-btn" class:tb-active={showEmojiPicker} title="Emoji" on:click={toggleEmojiPicker} type="button">☺</button>
                {#if showEmojiPicker}
                    <!-- svelte-ignore a11y-no-static-element-interactions -->
                    <div class="emoji-popover" bind:this={emojiPickerEl} on:keydown={(e) => e.key === "Escape" && (showEmojiPicker = false)} />
                    <!-- svelte-ignore a11y-no-static-element-interactions -->
                    <div class="fixed inset-0 z-40" on:click={() => (showEmojiPicker = false)} on:keydown={() => {}} />
                {/if}
            </div>

            <span class="tb-sep" />

            <!-- Headings -->
            {#each [1, 2, 3] as level}
                <button class="tb-btn tb-label" class:tb-active={editor.isActive("heading", { level })} title="Heading {level}" on:click={() => editor?.chain().focus().toggleHeading({ level }).run()} type="button">H{level}</button>
            {/each}

            <span class="tb-sep" />

            <!-- Bold -->
            <button class="tb-btn tb-label" class:tb-active={editor.isActive("bold")} style="font-weight:700" title="Bold" on:click={() => editor?.chain().focus().toggleBold().run()} type="button">B</button>
            <!-- Italic -->
            <button class="tb-btn tb-label" class:tb-active={editor.isActive("italic")} style="font-style:italic" title="Italic" on:click={() => editor?.chain().focus().toggleItalic().run()} type="button">I</button>
            <!-- Strike -->
            <button class="tb-btn tb-label" class:tb-active={editor.isActive("strike")} style="text-decoration:line-through" title="Strikethrough" on:click={() => editor?.chain().focus().toggleStrike().run()} type="button">S</button>

            <span class="tb-sep" />

            <!-- Link -->
            <div class="relative">
                <button class="tb-btn" class:tb-active={editor.isActive("link")} title="Link" on:click={toggleLink} type="button">
                    <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" />
                        <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" />
                    </svg>
                </button>
                {#if showLinkInput}
                    <div class="link-popover">
                        <input class="link-input" placeholder="https://…" bind:value={linkUrl} on:keydown={(e) => e.key === "Enter" && applyLink()} autofocus />
                        <button class="link-ok" on:click={applyLink} type="button">OK</button>
                    </div>
                    <!-- svelte-ignore a11y-no-static-element-interactions -->
                    <div class="fixed inset-0 z-40" on:click={() => (showLinkInput = false)} on:keydown={() => {}} />
                {/if}
            </div>

            <span class="tb-sep" />

            <!-- Lists -->
            <button class="tb-btn" class:tb-active={editor.isActive("bulletList")} title="Bullet list" on:click={() => editor?.chain().focus().toggleBulletList().run()} type="button">
                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <line x1="9" y1="6" x2="20" y2="6" /><line x1="9" y1="12" x2="20" y2="12" /><line x1="9" y1="18" x2="20" y2="18" />
                    <circle cx="4" cy="6" r="1.5" fill="currentColor" stroke="none" />
                    <circle cx="4" cy="12" r="1.5" fill="currentColor" stroke="none" />
                    <circle cx="4" cy="18" r="1.5" fill="currentColor" stroke="none" />
                </svg>
            </button>
            <button class="tb-btn" class:tb-active={editor.isActive("orderedList")} title="Ordered list" on:click={() => editor?.chain().focus().toggleOrderedList().run()} type="button">
                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <line x1="10" y1="6" x2="21" y2="6" /><line x1="10" y1="12" x2="21" y2="12" /><line x1="10" y1="18" x2="21" y2="18" />
                    <path d="M4 6h1v4" stroke-linecap="round" /><path d="M4 10h2" stroke-linecap="round" />
                    <path d="M6 18H4c0-1 2-2 2-3s-1-1.5-2-1" stroke-linecap="round" />
                </svg>
            </button>
            <button class="tb-btn" class:tb-active={editor.isActive("taskList")} title="Task list" on:click={() => editor?.chain().focus().toggleTaskList().run()} type="button">
                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <rect x="3" y="5" width="6" height="6" rx="1" />
                    <path d="m4.5 8 1.5 1.5 3-3" stroke-linecap="round" stroke-linejoin="round" />
                    <line x1="12" y1="8" x2="21" y2="8" />
                    <rect x="3" y="15" width="6" height="6" rx="1" />
                    <line x1="12" y1="18" x2="21" y2="18" />
                </svg>
            </button>

            <span class="tb-sep" />

            <!-- Table -->
            <button class="tb-btn" class:tb-active={editor.isActive("table")} title="Insert table" on:click={insertTable} type="button">
                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <rect x="3" y="3" width="18" height="18" rx="2" />
                    <line x1="3" y1="9" x2="21" y2="9" /><line x1="3" y1="15" x2="21" y2="15" />
                    <line x1="9" y1="3" x2="9" y2="21" /><line x1="15" y1="3" x2="15" y2="21" />
                </svg>
            </button>

            <span class="tb-sep" />

            <!-- Code -->
            <button class="tb-btn tb-label tb-mono" class:tb-active={editor.isActive("code")} title="Inline code" on:click={() => editor?.chain().focus().toggleCode().run()} type="button">&lt;/&gt;</button>
            <button class="tb-btn tb-label tb-mono tb-small" class:tb-active={editor.isActive("codeBlock")} title="Code block" on:click={() => editor?.chain().focus().toggleCodeBlock().run()} type="button">```</button>

            <span class="tb-sep" />

            <!-- Blockquote -->
            <button class="tb-btn tb-label" class:tb-active={editor.isActive("blockquote")} title="Blockquote" on:click={() => editor?.chain().focus().toggleBlockquote().run()} type="button">❝</button>

            <!-- HR -->
            <button class="tb-btn tb-label" title="Horizontal rule" on:click={() => editor?.chain().focus().setHorizontalRule().run()} type="button">—</button>

            <span class="tb-spacer" />

            <!-- Undo / Redo -->
            <button class="tb-btn" title="Undo" disabled={!editor.can().undo()} on:click={() => editor?.chain().focus().undo().run()} type="button">
                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M3 7v6h6" /><path d="M21 17a9 9 0 0 0-9-9 9 9 0 0 0-6 2.3L3 13" />
                </svg>
            </button>
            <button class="tb-btn" title="Redo" disabled={!editor.can().redo()} on:click={() => editor?.chain().focus().redo().run()} type="button">
                <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M21 7v6h-6" /><path d="M3 17a9 9 0 0 1 9-9 9 9 0 0 1 6 2.3L21 13" />
                </svg>
            </button>
        </div>
    </div>

    <!-- ── Table context toolbar ─────────────────────────────────────────────── -->
    {#if isInTable}
        <div class="table-toolbar">
            <span class="table-label">Table:</span>
            <button class="tb-btn tb-small-label" on:click={() => editor?.chain().focus().addColumnBefore().run()} type="button">+Col←</button>
            <button class="tb-btn tb-small-label" on:click={() => editor?.chain().focus().addColumnAfter().run()} type="button">+Col→</button>
            <button class="tb-btn tb-small-label" on:click={() => editor?.chain().focus().deleteColumn().run()} type="button">−Col</button>
            <span class="tb-sep" />
            <button class="tb-btn tb-small-label" on:click={() => editor?.chain().focus().addRowBefore().run()} type="button">+Row↑</button>
            <button class="tb-btn tb-small-label" on:click={() => editor?.chain().focus().addRowAfter().run()} type="button">+Row↓</button>
            <button class="tb-btn tb-small-label" on:click={() => editor?.chain().focus().deleteRow().run()} type="button">−Row</button>
            <span class="tb-sep" />
            <button class="tb-btn tb-small-label danger" on:click={() => editor?.chain().focus().deleteTable().run()} type="button">✕ Table</button>
        </div>
    {/if}
{/if}

<!-- ── Editor area ────────────────────────────────────────────────────────── -->
<div bind:this={editorEl} class="editor-area" />

{#if editable}
    <!-- ── Bottom bar ─────────────────────────────────────────────────────────── -->
    <div class="bottom-bar">
        <!-- Note ref picker -->
        <div class="relative">
            <button class="bb-btn" class:tb-active={showNoteRefPicker} title="Link to another note" on:click={() => (showNoteRefPicker = !showNoteRefPicker)} type="button">
                <svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" />
                    <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" />
                </svg>
                Note
            </button>
            {#if showNoteRefPicker}
                <div class="ref-picker">
                    <div class="ref-search-wrap">
                        <input class="ref-search" placeholder="Search notes…" bind:value={noteRefSearch} autofocus />
                    </div>
                    <div class="ref-list">
                        {#if filteredNotes.length === 0}
                            <p class="ref-empty">No notes found</p>
                        {:else}
                            {#each filteredNotes as n}
                                <button class="ref-item" on:click={() => insertNoteRef(n)} type="button">{n.title || "(Untitled)"}</button>
                            {/each}
                        {/if}
                    </div>
                </div>
                <!-- svelte-ignore a11y-no-static-element-interactions -->
                <div class="fixed inset-0 z-40" on:click={() => (showNoteRefPicker = false)} on:keydown={() => {}} />
            {/if}
        </div>

        <!-- File upload -->
        <input type="file" class="hidden" bind:this={fileInput} on:change={handleFileSelected} />
        <button class="bb-btn" title="Attach file" on:click={() => fileInput.click()} type="button" disabled={uploading}>
            {#if uploading}
                Uploading…
            {:else}
                <svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="m21.44 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l8.57-8.57A4 4 0 1 1 18 8.84l-8.59 8.57a2 2 0 0 1-2.83-2.83l8.49-8.48" />
                </svg>
                File
            {/if}
        </button>

        <!-- Voice recording -->
        <button class="bb-btn" class:recording={isRecording} title={isRecording ? "Stop recording" : "Voice memo"} on:click={toggleRecording} type="button">
            <svg xmlns="http://www.w3.org/2000/svg" width="13" height="13" class:pulse={isRecording} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
                <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
                <line x1="12" y1="19" x2="12" y2="22" />
            </svg>
            {isRecording ? formatSeconds(recordingSeconds) : "Voice"}
        </button>

        <span class="flex-1" />
    </div>

    <!-- ── Attachments panel ──────────────────────────────────────────────────── -->
    {#if attachments.length > 0}
        <div class="att-panel">
            <p class="att-title">Attachments</p>
            {#each attachments as att (att.id)}
                <div class="att-row">
                    <span class="att-icon">{fileIcon(att.mime_type)}</span>
                    <div class="att-info">
                        <span class="att-name">{att.original_name}</span>
                        <span class="att-size">{formatSize(att.size)}</span>
                        {#if att.mime_type.startsWith("image/")}
                            {#if imageBlobUrls[att.id]}
                                <!-- svelte-ignore a11y-click-events-have-key-events -->
                                <!-- svelte-ignore a11y-no-noninteractive-element-interactions -->
                                <img src={imageBlobUrls[att.id]} alt={att.original_name} class="att-img" on:click={() => (previewImageId = att.id)} />
                            {:else}
                                <span class="att-loading">Loading…</span>
                            {/if}
                        {/if}
                        {#if att.mime_type.startsWith("audio/")}
                            {#if audioBlobUrls[att.id]}
                                <!-- svelte-ignore a11y-media-has-caption -->
                                <audio controls class="att-audio" src={audioBlobUrls[att.id]} />
                            {:else}
                                <span class="att-loading">Loading…</span>
                            {/if}
                        {/if}
                    </div>
                    <button class="att-del" title="Delete attachment" on:click={() => deleteAttachment(att.id)} type="button">🗑</button>
                </div>
            {/each}
        </div>
    {/if}
{/if}

<!-- ── Image lightbox ──────────────────────────────────────────────────────── -->
{#if previewImageId && imageBlobUrls[previewImageId]}
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <!-- svelte-ignore a11y-no-static-element-interactions -->
    <div class="lightbox" on:click={() => (previewImageId = null)}>
        <img src={imageBlobUrls[previewImageId]} alt="Preview" class="lightbox-img" />
    </div>
{/if}

<style>
    /* ── Toolbar ───────────────────────────────────────────────────────────────── */
    .toolbar-scroll {
        overflow-x: auto;
        -webkit-overflow-scrolling: touch;
        border-bottom: 1px solid var(--color-border);
        background: var(--color-surface);
        scrollbar-width: none;
    }
    .toolbar-scroll::-webkit-scrollbar {
        display: none;
    }
    .toolbar {
        display: flex;
        align-items: center;
        gap: 1px;
        padding: 6px 8px;
        min-width: max-content;
    }

    .tb-btn {
        min-width: 34px;
        height: 34px;
        border-radius: 7px;
        border: none;
        background: none;
        cursor: pointer;
        display: inline-flex;
        align-items: center;
        justify-content: center;
        padding: 0 6px;
        color: var(--color-text-primary);
        font-size: 14px;
        transition: background 0.12s;
        -webkit-tap-highlight-color: transparent;
        white-space: nowrap;
    }

    .tb-btn:active,
    .tb-btn:hover {
        background: var(--color-muted);
    }

    .tb-btn:disabled {
        opacity: 0.35;
    }

    .tb-active {
        background: var(--color-muted) !important;
        color: var(--color-accent);
    }

    .tb-label {
        font-size: 13px;
        font-weight: 600;
    }

    .tb-mono {
        font-family: monospace;
    }

    .tb-small {
        font-size: 11px;
    }

    .tb-small-label {
        font-size: 10px;
        padding: 0 4px;
        min-width: unset;
    }

    .tb-sep {
        width: 1px;
        height: 18px;
        background: var(--color-border);
        margin: 0 3px;
        flex-shrink: 0;
    }

    .tb-spacer {
        flex: 1;
        min-width: 8px;
    }

    /* ── Table toolbar ─────────────────────────────────────────────────────────── */
    .table-toolbar {
        display: flex;
        align-items: center;
        gap: 2px;
        padding: 4px 8px;
        border-bottom: 1px solid var(--color-border);
        background: var(--color-muted);
        overflow-x: auto;
        -webkit-overflow-scrolling: touch;
        scrollbar-width: none;
    }

    .table-label {
        font-size: 11px;
        color: var(--color-text-muted);
        margin-right: 2px;
        white-space: nowrap;
    }

    .tb-btn.danger {
        color: #dc2626;
    }

    /* ── Editor area ─────────────────────────────────────────────────────────── */
    .editor-area {
        padding: 12px 16px;
        min-height: 160px;
        color: var(--color-text-primary);
        font-size: 15px;
        line-height: 1.6;
    }

    .editor-area :global(.ProseMirror) {
        outline: none;
        min-height: 140px;
    }

    .editor-area :global(.ProseMirror p.is-editor-empty:first-child::before) {
        content: attr(data-placeholder);
        float: left;
        color: var(--color-text-muted);
        pointer-events: none;
        height: 0;
    }

    /* ── Bottom bar ──────────────────────────────────────────────────────────── */
    .bottom-bar {
        display: flex;
        align-items: center;
        gap: 4px;
        padding: 6px 10px;
        border-top: 1px solid var(--color-border);
        background: var(--color-surface);
        overflow-x: auto;
        -webkit-overflow-scrolling: touch;
        scrollbar-width: none;
    }

    .bb-btn {
        height: 32px;
        padding: 0 10px;
        border-radius: 8px;
        border: 1px solid var(--color-border);
        background: var(--color-surface);
        color: var(--color-text-primary);
        font-size: 12px;
        display: inline-flex;
        align-items: center;
        gap: 5px;
        cursor: pointer;
        white-space: nowrap;
        -webkit-tap-highlight-color: transparent;
    }

    .bb-btn:disabled {
        opacity: 0.5;
    }

    .bb-btn.recording {
        color: #dc2626;
        border-color: #dc2626;
    }

    .pulse {
        animation: pulse 1s infinite;
    }

    @keyframes pulse {
        0%,
        100% {
            opacity: 1;
        }
        50% {
            opacity: 0.4;
        }
    }

    /* ── Popover: link ───────────────────────────────────────────────────────── */
    .link-popover {
        position: absolute;
        bottom: calc(100% + 4px);
        left: 0;
        z-index: 50;
        display: flex;
        gap: 6px;
        background: var(--color-surface);
        border: 1px solid var(--color-border);
        border-radius: 10px;
        padding: 8px;
        box-shadow: 0 8px 24px rgba(0, 0, 0, 0.2);
        width: 260px;
    }

    .link-input {
        flex: 1;
        height: 36px;
        padding: 0 10px;
        border: 1px solid var(--color-border);
        border-radius: 8px;
        background: var(--color-bg);
        color: var(--color-text-primary);
        font-size: 14px;
        outline: none;
    }

    .link-ok {
        height: 36px;
        padding: 0 14px;
        border-radius: 8px;
        border: none;
        background: var(--color-accent);
        color: #fff;
        font-size: 14px;
        font-weight: 600;
        cursor: pointer;
    }

    /* ── Popover: emoji ──────────────────────────────────────────────────────── */
    .emoji-popover {
        position: absolute;
        top: calc(100% + 4px);
        left: 0;
        z-index: 50;
        box-shadow: 0 8px 24px rgba(0, 0, 0, 0.2);
    }

    /* ── Popover: note ref picker ────────────────────────────────────────────── */
    .ref-picker {
        position: absolute;
        bottom: calc(100% + 4px);
        left: 0;
        z-index: 50;
        background: var(--color-surface);
        border: 1px solid var(--color-border);
        border-radius: 12px;
        box-shadow: 0 8px 24px rgba(0, 0, 0, 0.2);
        width: 240px;
        display: flex;
        flex-direction: column;
        max-height: 220px;
    }

    .ref-search-wrap {
        padding: 8px;
        border-bottom: 1px solid var(--color-border);
    }

    .ref-search {
        width: 100%;
        height: 34px;
        padding: 0 10px;
        border: 1px solid var(--color-border);
        border-radius: 8px;
        background: var(--color-bg);
        color: var(--color-text-primary);
        font-size: 13px;
        outline: none;
        box-sizing: border-box;
    }

    .ref-list {
        overflow-y: auto;
        flex: 1;
    }

    .ref-item {
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

    .ref-item:active {
        background: var(--color-muted);
    }

    .ref-empty {
        font-size: 12px;
        color: var(--color-text-muted);
        text-align: center;
        padding: 12px;
        margin: 0;
    }

    /* ── Attachments panel ───────────────────────────────────────────────────── */
    .att-panel {
        border-top: 1px solid var(--color-border);
        padding: 10px 14px;
        display: flex;
        flex-direction: column;
        gap: 8px;
        background: var(--color-surface);
    }

    .att-title {
        font-size: 10px;
        font-weight: 700;
        text-transform: uppercase;
        letter-spacing: 0.06em;
        color: var(--color-text-muted);
        margin: 0;
    }

    .att-row {
        display: flex;
        align-items: flex-start;
        gap: 8px;
    }

    .att-icon {
        font-size: 18px;
        flex-shrink: 0;
        margin-top: 1px;
    }

    .att-info {
        flex: 1;
        min-width: 0;
        display: flex;
        flex-direction: column;
        gap: 3px;
    }

    .att-name {
        font-size: 13px;
        font-weight: 500;
        color: var(--color-text-primary);
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
    }

    .att-size {
        font-size: 11px;
        color: var(--color-text-muted);
    }

    .att-img {
        max-height: 100px;
        border-radius: 6px;
        object-fit: cover;
        cursor: pointer;
        align-self: flex-start;
    }

    .att-audio {
        width: 100%;
        margin-top: 2px;
    }

    .att-loading {
        font-size: 11px;
        color: var(--color-text-muted);
        font-style: italic;
    }

    .att-del {
        width: 32px;
        height: 32px;
        border-radius: 8px;
        border: none;
        background: none;
        cursor: pointer;
        font-size: 14px;
        display: flex;
        align-items: center;
        justify-content: center;
        opacity: 0.5;
        flex-shrink: 0;
        -webkit-tap-highlight-color: transparent;
    }

    .att-del:active {
        opacity: 1;
        background: rgba(239, 68, 68, 0.12);
    }

    /* ── Lightbox ────────────────────────────────────────────────────────────── */
    .lightbox {
        position: fixed;
        inset: 0;
        z-index: 200;
        background: rgba(0, 0, 0, 0.85);
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 20px;
        cursor: zoom-out;
    }

    .lightbox-img {
        max-width: 100%;
        max-height: 100%;
        border-radius: 10px;
        object-fit: contain;
    }

    /* ── Hidden file input ───────────────────────────────────────────────────── */
    :global(.hidden) {
        display: none !important;
    }

    /* ── TipTap prose styles ─────────────────────────────────────────────────── */
    .editor-area :global(h1) {
        font-size: 1.5em;
        font-weight: 700;
        margin: 0.5em 0 0.25em;
    }
    .editor-area :global(h2) {
        font-size: 1.25em;
        font-weight: 600;
        margin: 0.5em 0 0.25em;
    }
    .editor-area :global(h3) {
        font-size: 1.1em;
        font-weight: 600;
        margin: 0.4em 0 0.2em;
    }
    .editor-area :global(p) {
        margin: 0 0 0.5em;
    }
    .editor-area :global(ul),
    .editor-area :global(ol) {
        padding-left: 1.4em;
        margin: 0 0 0.5em;
    }
    .editor-area :global(li) {
        margin-bottom: 0.2em;
    }
    .editor-area :global(blockquote) {
        border-left: 3px solid var(--color-accent);
        padding-left: 0.75em;
        margin: 0.5em 0;
        color: var(--color-text-muted);
    }
    .editor-area :global(pre) {
        background: var(--color-code-bg, rgba(0, 0, 0, 0.1));
        border-radius: 6px;
        padding: 10px 12px;
        font-family: monospace;
        font-size: 13px;
        overflow-x: auto;
        margin: 0.5em 0;
    }
    .editor-area :global(code) {
        font-family: monospace;
        font-size: 0.9em;
        background: var(--color-code-bg, rgba(0, 0, 0, 0.1));
        border-radius: 3px;
        padding: 1px 4px;
    }
    .editor-area :global(pre code) {
        background: none;
        padding: 0;
    }
    .editor-area :global(a) {
        color: var(--color-accent);
        text-decoration: underline;
    }
    .editor-area :global(hr) {
        border: none;
        border-top: 1px solid var(--color-border);
        margin: 0.75em 0;
    }
    .editor-area :global(table) {
        border-collapse: collapse;
        width: 100%;
        margin: 0.5em 0;
    }
    .editor-area :global(th),
    .editor-area :global(td) {
        border: 1px solid var(--color-border);
        padding: 6px 10px;
        font-size: 13px;
    }
    .editor-area :global(th) {
        background: var(--color-muted);
        font-weight: 600;
    }
    .editor-area :global(.task-list) {
        list-style: none;
        padding-left: 0.5em;
    }
    .editor-area :global(.task-list li) {
        display: flex;
        align-items: flex-start;
        gap: 6px;
    }
    .editor-area :global(.task-list input[type="checkbox"]) {
        margin-top: 3px;
        width: 16px;
        height: 16px;
        flex-shrink: 0;
    }
</style>
