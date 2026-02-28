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

    // ── Props ─────────────────────────────────────────────────────────────────
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

    // ── Emoji picker ──────────────────────────────────────────────────────────
    let showEmojiPicker = false;
    let emojiPickerEl: HTMLDivElement;
    let emojiPickerMounted = false;

    // ── Link input ────────────────────────────────────────────────────────────
    let showLinkInput = false;
    let linkUrl = "";

    // ── Note ref picker ───────────────────────────────────────────────────────
    let showNoteRefPicker = false;
    let noteRefSearch = "";
    $: filteredNotes = allNotes.filter((n) => n.title.toLowerCase().includes(noteRefSearch.toLowerCase()));

    // ── Table context toolbar ─────────────────────────────────────────────────
    $: isInTable = editor?.isActive("table") ?? false;

    // ── File upload ───────────────────────────────────────────────────────────
    let fileInput: HTMLInputElement;
    let uploading = false;

    // ── Voice recording ───────────────────────────────────────────────────────
    let isRecording = false;
    let recordingSeconds = 0;
    let mediaRecorder: MediaRecorder | null = null;
    let recordingChunks: Blob[] = [];
    let recordingTimer: ReturnType<typeof setInterval> | null = null;
    let mediaStream: MediaStream | null = null;

    // ─────────────────────────────────────────────────────────────────────────

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
                editor = editor; // force Svelte reactivity
            },
            onUpdate: ({ editor }) => {
                isInternalUpdate = true;
                dispatch("change", editor.getHTML());
                setTimeout(() => {
                    isInternalUpdate = false;
                }, 0);
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

    // Sync external content changes
    $: if (editor && content !== undefined && !isInternalUpdate) {
        const current = editor.getHTML();
        if (current !== content) {
            editor.commands.setContent(content, false);
        }
    }

    // Sync editable prop
    $: if (editor) editor.setEditable(editable);

    // ── Emoji ─────────────────────────────────────────────────────────────────

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

    // ── Link ──────────────────────────────────────────────────────────────────

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

    // ── Table ─────────────────────────────────────────────────────────────────

    function insertTable() {
        editor?.chain().focus().insertTable({ rows: 3, cols: 3, withHeaderRow: true }).run();
    }

    // ── Note reference ────────────────────────────────────────────────────────

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

    // ── File upload ───────────────────────────────────────────────────────────

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
            // Wait up to 5 s for the parent to populate noteId via prop update
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

    // ── Voice recording ───────────────────────────────────────────────────────

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
        const m = Math.floor(s / 60)
            .toString()
            .padStart(2, "0");
        const sec = (s % 60).toString().padStart(2, "0");
        return `${m}:${sec}`;
    }

    // ── Blob URLs (authenticated fetch → object URL for media preview) ─────────
    let audioBlobUrls: Record<string, string> = {};
    let imageBlobUrls: Record<string, string> = {};
    let previewImageId: string | null = null;

    async function loadAudioBlobUrl(id: string) {
        try {
            audioBlobUrls = { ...audioBlobUrls, [id]: await attachmentsApi.fetchBlobUrl(id) };
        } catch {
            // silently fail — controls remain inactive
        }
    }

    async function loadImageBlobUrl(id: string) {
        try {
            imageBlobUrls = { ...imageBlobUrls, [id]: await attachmentsApi.fetchBlobUrl(id) };
        } catch {
            // silently fail
        }
    }

    $: attachments.forEach((att) => {
        if (att.mime_type.startsWith("audio/") && !audioBlobUrls[att.id]) {
            loadAudioBlobUrl(att.id);
        }
        if (att.mime_type.startsWith("image/") && !imageBlobUrls[att.id]) {
            loadImageBlobUrl(att.id);
        }
    });

    // ── Attachment helpers ────────────────────────────────────────────────────

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
            // Revoke blob URLs if loaded
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
    <!-- ── Top Toolbar ─────────────────────────────────────────────────────── -->
    <div class="flex flex-wrap items-center gap-0.5 px-2 py-1.5 border-b border-base-300 bg-base-100">
        <!-- Emoji -->
        <div class="relative">
            <button class="btn btn-ghost btn-xs px-2 text-base leading-none" class:btn-active={showEmojiPicker} title="Insert emoji" on:click={toggleEmojiPicker} type="button">☺</button>
            {#if showEmojiPicker}
                <!-- svelte-ignore a11y-no-static-element-interactions -->
                <div class="absolute left-0 top-8 z-50 shadow-2xl" bind:this={emojiPickerEl} on:keydown={(e) => e.key === "Escape" && (showEmojiPicker = false)} />
                <!-- svelte-ignore a11y-no-static-element-interactions -->
                <div class="fixed inset-0 z-40" on:click={() => (showEmojiPicker = false)} on:keydown={() => {}} />
            {/if}
        </div>

        <span class="w-px h-5 bg-base-300 mx-0.5" />

        <!-- Headings -->
        {#each [1, 2, 3] as level}
            <button class="btn btn-ghost btn-xs px-1.5 font-bold" class:btn-active={editor.isActive("heading", { level })} title="Heading {level}" on:click={() => editor?.chain().focus().toggleHeading({ level }).run()} type="button">H{level}</button>
        {/each}

        <span class="w-px h-5 bg-base-300 mx-0.5" />

        <!-- Bold -->
        <button class="btn btn-ghost btn-xs px-1.5 font-bold" class:btn-active={editor.isActive("bold")} title="Bold" on:click={() => editor?.chain().focus().toggleBold().run()} type="button">B</button>

        <!-- Italic -->
        <button class="btn btn-ghost btn-xs px-1.5 italic font-semibold" class:btn-active={editor.isActive("italic")} title="Italic" on:click={() => editor?.chain().focus().toggleItalic().run()} type="button">I</button>

        <!-- Strikethrough -->
        <button class="btn btn-ghost btn-xs px-1.5 line-through" class:btn-active={editor.isActive("strike")} title="Strikethrough" on:click={() => editor?.chain().focus().toggleStrike().run()} type="button">S</button>

        <span class="w-px h-5 bg-base-300 mx-0.5" />

        <!-- Link -->
        <div class="relative">
            <button class="btn btn-ghost btn-xs px-1.5" class:btn-active={editor.isActive("link")} title="Link" on:click={toggleLink} type="button">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" />
                    <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" />
                </svg>
            </button>
            {#if showLinkInput}
                <div class="absolute left-0 top-8 z-50 flex gap-1 bg-base-100 border border-base-300 rounded-xl shadow-xl p-2 w-64">
                    <input class="input input-bordered input-xs flex-1" placeholder="https://…" bind:value={linkUrl} on:keydown={(e) => e.key === "Enter" && applyLink()} autofocus />
                    <button class="btn btn-primary btn-xs" on:click={applyLink} type="button">OK</button>
                </div>
                <!-- svelte-ignore a11y-no-static-element-interactions -->
                <div class="fixed inset-0 z-40" on:click={() => (showLinkInput = false)} on:keydown={() => {}} />
            {/if}
        </div>

        <span class="w-px h-5 bg-base-300 mx-0.5" />

        <!-- Bullet list -->
        <button class="btn btn-ghost btn-xs px-1.5" class:btn-active={editor.isActive("bulletList")} title="Bullet list" on:click={() => editor?.chain().focus().toggleBulletList().run()} type="button">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="9" y1="6" x2="20" y2="6" /><line x1="9" y1="12" x2="20" y2="12" /><line x1="9" y1="18" x2="20" y2="18" />
                <circle cx="4" cy="6" r="1.5" fill="currentColor" stroke="none" />
                <circle cx="4" cy="12" r="1.5" fill="currentColor" stroke="none" />
                <circle cx="4" cy="18" r="1.5" fill="currentColor" stroke="none" />
            </svg>
        </button>

        <!-- Ordered list -->
        <button class="btn btn-ghost btn-xs px-1.5" class:btn-active={editor.isActive("orderedList")} title="Ordered list" on:click={() => editor?.chain().focus().toggleOrderedList().run()} type="button">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <line x1="10" y1="6" x2="21" y2="6" /><line x1="10" y1="12" x2="21" y2="12" /><line x1="10" y1="18" x2="21" y2="18" />
                <path d="M4 6h1v4" stroke-linecap="round" /><path d="M4 10h2" stroke-linecap="round" />
                <path d="M6 18H4c0-1 2-2 2-3s-1-1.5-2-1" stroke-linecap="round" />
            </svg>
        </button>

        <!-- Task list -->
        <button class="btn btn-ghost btn-xs px-1.5" class:btn-active={editor.isActive("taskList")} title="Task list (to-do)" on:click={() => editor?.chain().focus().toggleTaskList().run()} type="button">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <rect x="3" y="5" width="6" height="6" rx="1" />
                <path d="m4.5 8 1.5 1.5 3-3" stroke-linecap="round" stroke-linejoin="round" />
                <line x1="12" y1="8" x2="21" y2="8" />
                <rect x="3" y="15" width="6" height="6" rx="1" />
                <line x1="12" y1="18" x2="21" y2="18" />
            </svg>
        </button>

        <span class="w-px h-5 bg-base-300 mx-0.5" />

        <!-- Table -->
        <button class="btn btn-ghost btn-xs px-1.5" class:btn-active={editor.isActive("table")} title="Insert table" on:click={insertTable} type="button">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <rect x="3" y="3" width="18" height="18" rx="2" />
                <line x1="3" y1="9" x2="21" y2="9" />
                <line x1="3" y1="15" x2="21" y2="15" />
                <line x1="9" y1="3" x2="9" y2="21" />
                <line x1="15" y1="3" x2="15" y2="21" />
            </svg>
        </button>

        <span class="w-px h-5 bg-base-300 mx-0.5" />

        <!-- Inline code -->
        <button class="btn btn-ghost btn-xs px-1.5 font-mono" class:btn-active={editor.isActive("code")} title="Inline code" on:click={() => editor?.chain().focus().toggleCode().run()} type="button">&lt;/&gt;</button>

        <!-- Code block -->
        <button class="btn btn-ghost btn-xs px-1.5 font-mono text-xs" class:btn-active={editor.isActive("codeBlock")} title="Code block" on:click={() => editor?.chain().focus().toggleCodeBlock().run()} type="button">```</button>

        <span class="w-px h-5 bg-base-300 mx-0.5" />

        <!-- Blockquote -->
        <button class="btn btn-ghost btn-xs px-1.5" class:btn-active={editor.isActive("blockquote")} title="Blockquote" on:click={() => editor?.chain().focus().toggleBlockquote().run()} type="button">❝</button>

        <!-- Horizontal rule -->
        <button class="btn btn-ghost btn-xs px-1.5" title="Horizontal rule" on:click={() => editor?.chain().focus().setHorizontalRule().run()} type="button">—</button>

        <!-- Spacer -->
        <span class="flex-1" />

        <!-- Undo -->
        <button class="btn btn-ghost btn-xs px-1.5" title="Undo" disabled={!editor.can().undo()} on:click={() => editor?.chain().focus().undo().run()} type="button">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M3 7v6h6" /><path d="M21 17a9 9 0 0 0-9-9 9 9 0 0 0-6 2.3L3 13" />
            </svg>
        </button>

        <!-- Redo -->
        <button class="btn btn-ghost btn-xs px-1.5" title="Redo" disabled={!editor.can().redo()} on:click={() => editor?.chain().focus().redo().run()} type="button">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M21 7v6h-6" /><path d="M3 17a9 9 0 0 1 9-9 9 9 0 0 1 6 2.3L21 13" />
            </svg>
        </button>
    </div>

    <!-- ── Table context toolbar ──────────────────────────────────────────── -->
    {#if isInTable}
        <div class="flex flex-wrap items-center gap-0.5 px-2 py-1 border-b border-base-300 bg-base-200">
            <span class="text-base-content/40 text-xs mr-1">Table:</span>
            <button class="btn btn-ghost btn-xs px-1.5" on:click={() => editor?.chain().focus().addColumnBefore().run()} type="button">+Col←</button>
            <button class="btn btn-ghost btn-xs px-1.5" on:click={() => editor?.chain().focus().addColumnAfter().run()} type="button">+Col→</button>
            <button class="btn btn-ghost btn-xs px-1.5" on:click={() => editor?.chain().focus().deleteColumn().run()} type="button">−Col</button>
            <span class="w-px h-4 bg-base-300 mx-0.5" />
            <button class="btn btn-ghost btn-xs px-1.5" on:click={() => editor?.chain().focus().addRowBefore().run()} type="button">+Row↑</button>
            <button class="btn btn-ghost btn-xs px-1.5" on:click={() => editor?.chain().focus().addRowAfter().run()} type="button">+Row↓</button>
            <button class="btn btn-ghost btn-xs px-1.5" on:click={() => editor?.chain().focus().deleteRow().run()} type="button">−Row</button>
            <span class="w-px h-4 bg-base-300 mx-0.5" />
            <button class="btn btn-ghost btn-xs px-1.5 text-error" on:click={() => editor?.chain().focus().deleteTable().run()} type="button">✕ Table</button>
        </div>
    {/if}
{/if}

<!-- ── Editor area ────────────────────────────────────────────────────────── -->
<div bind:this={editorEl} class="prose prose-sm max-w-none px-4 py-3 min-h-[160px] focus-within:outline-none [&_.ProseMirror]:outline-none [&_.ProseMirror]:min-h-[140px]" />

{#if editable}
    <!-- ── Bottom Bar ─────────────────────────────────────────────────────── -->
    <div class="flex items-center gap-1 px-3 py-1.5 border-t border-base-300 bg-base-100">
        <!-- Note reference picker -->
        <div class="relative">
            <button class="btn btn-ghost btn-xs gap-1.5" class:btn-active={showNoteRefPicker} title="Link to another note" on:click={() => (showNoteRefPicker = !showNoteRefPicker)} type="button">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="M10 13a5 5 0 0 0 7.54.54l3-3a5 5 0 0 0-7.07-7.07l-1.72 1.71" />
                    <path d="M14 11a5 5 0 0 0-7.54-.54l-3 3a5 5 0 0 0 7.07 7.07l1.71-1.71" />
                </svg>
                Note
            </button>
            {#if showNoteRefPicker}
                <div class="absolute bottom-9 left-0 z-50 bg-base-100 border border-base-300 rounded-xl shadow-xl w-64 flex flex-col max-h-60">
                    <div class="p-2 border-b border-base-200">
                        <input class="input input-bordered input-xs w-full" placeholder="Search notes…" bind:value={noteRefSearch} autofocus />
                    </div>
                    <div class="overflow-y-auto flex-1">
                        {#if filteredNotes.length === 0}
                            <p class="text-xs text-base-content/40 p-3 text-center">No notes found</p>
                        {:else}
                            {#each filteredNotes as n}
                                <button class="w-full text-left px-3 py-1.5 text-sm hover:bg-base-200 transition-colors" on:click={() => insertNoteRef(n)} type="button">{n.title || "(Untitled)"}</button>
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
        <button class="btn btn-ghost btn-xs gap-1.5" title="Attach file" on:click={() => fileInput.click()} type="button" disabled={uploading}>
            {#if uploading}
                <span class="loading loading-spinner loading-xs" />
                Uploading…
            {:else}
                <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="m21.44 11.05-9.19 9.19a6 6 0 0 1-8.49-8.49l8.57-8.57A4 4 0 1 1 18 8.84l-8.59 8.57a2 2 0 0 1-2.83-2.83l8.49-8.48" />
                </svg>
                File
            {/if}
        </button>

        <!-- Voice recording -->
        <button class="btn btn-ghost btn-xs gap-1.5" class:text-error={isRecording} title={isRecording ? "Stop recording" : "Record voice memo"} on:click={toggleRecording} type="button">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" class:animate-pulse={isRecording} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="M12 2a3 3 0 0 0-3 3v7a3 3 0 0 0 6 0V5a3 3 0 0 0-3-3Z" />
                <path d="M19 10v2a7 7 0 0 1-14 0v-2" />
                <line x1="12" y1="19" x2="12" y2="22" />
            </svg>
            {#if isRecording}
                {formatSeconds(recordingSeconds)}
            {:else}
                Voice
            {/if}
        </button>

        <span class="flex-1" />
    </div>

    <!-- ── Attachments panel ──────────────────────────────────────────────── -->
    {#if attachments.length > 0}
        <div class="border-t border-base-300 px-3 py-2 flex flex-col gap-2">
            <p class="text-xs font-semibold text-base-content/40 uppercase tracking-wide">Attachments</p>
            {#each attachments as att (att.id)}
                <div class="flex items-start gap-2 text-sm">
                    <span class="text-base mt-0.5 shrink-0">{fileIcon(att.mime_type)}</span>
                    <div class="flex-1 min-w-0">
                        <a href={attachmentsApi.contentUrl(att.id)} class="text-sm font-medium hover:underline truncate block" download={att.original_name} target="_blank" rel="noopener">{att.original_name}</a>
                        <span class="text-xs text-base-content/40">{formatSize(att.size)}</span>
                        {#if att.mime_type.startsWith("image/")}
                            {#if imageBlobUrls[att.id]}
                                <!-- svelte-ignore a11y-click-events-have-key-events -->
                                <!-- svelte-ignore a11y-no-noninteractive-element-interactions -->
                                <img src={imageBlobUrls[att.id]} alt={att.original_name} class="mt-1 max-h-24 rounded cursor-pointer object-cover hover:opacity-80 transition-opacity" on:click={() => (previewImageId = att.id)} />
                            {:else}
                                <div class="flex items-center gap-1 mt-1 text-xs text-base-content/40">
                                    <span class="loading loading-spinner loading-xs" />
                                    Loading image…
                                </div>
                            {/if}
                        {/if}
                        {#if att.mime_type.startsWith("audio/")}
                            {#if audioBlobUrls[att.id]}
                                <!-- svelte-ignore a11y-media-has-caption -->
                                <audio controls class="w-full mt-1" src={audioBlobUrls[att.id]} />
                            {:else}
                                <div class="flex items-center gap-1 mt-1 text-xs text-base-content/40">
                                    <span class="loading loading-spinner loading-xs" />
                                    Loading audio…
                                </div>
                            {/if}
                        {/if}
                    </div>
                    <button class="btn btn-ghost btn-xs btn-circle text-error shrink-0" title="Delete attachment" on:click={() => deleteAttachment(att.id)} type="button">
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M18 6 6 18M6 6l12 12" />
                        </svg>
                    </button>
                </div>
            {/each}
        </div>
    {/if}
{/if}

{#if previewImageId && imageBlobUrls[previewImageId]}
    {@const previewAtt = attachments.find((a) => a.id === previewImageId)}
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

<style>
    :global(.ProseMirror p.is-editor-empty:first-child::before) {
        content: attr(data-placeholder);
        float: left;
        color: oklch(var(--bc) / 0.3);
        pointer-events: none;
        height: 0;
    }
    :global(.task-list) {
        list-style: none;
        padding-left: 0;
    }
    :global(.task-list li) {
        display: flex;
        align-items: flex-start;
        gap: 0.4rem;
    }
    :global(.task-list li > label) {
        display: flex;
        align-items: center;
        gap: 0.4rem;
        cursor: pointer;
        margin-top: 0.1rem;
    }
    :global(.ProseMirror table) {
        border-collapse: collapse;
        width: 100%;
        margin: 0.5rem 0;
        table-layout: fixed;
    }
    :global(.ProseMirror table td, .ProseMirror table th) {
        border: 1px solid oklch(var(--bc) / 0.2);
        padding: 0.3rem 0.5rem;
        min-width: 2rem;
        vertical-align: top;
    }
    :global(.ProseMirror table th) {
        background: oklch(var(--b2));
        font-weight: 600;
    }
    :global(.ProseMirror .note-link) {
        color: oklch(var(--p));
        text-decoration: underline;
        cursor: pointer;
    }
    :global(.selectedCell) {
        background: oklch(var(--p) / 0.1);
    }
</style>
