<script lang="ts">
    import { createEventDispatcher } from "svelte";
    import type { Note } from "$lib/api/client";

    export let note: Note;

    const dispatch = createEventDispatcher<{
        open: Note;
        delete: string;
        togglePin: string;
    }>();

    const NOTE_ACCENT: Record<string, string> = {
        yellow: "#f59e0b",
        blue: "#60a5fa",
        green: "#4ade80",
        pink: "#f472b6",
        purple: "#c084fc",
    };

    function resolveAccentColor(rawColor: string | null | undefined): string {
        if (!rawColor) return "";
        const n = rawColor.trim().toLowerCase();
        if (NOTE_ACCENT[n]) return NOTE_ACCENT[n];
        if (n.startsWith("#") || n.startsWith("rgb") || n.startsWith("hsl")) return n;
        return "";
    }

    $: accentColor = resolveAccentColor(note.color);

    function fmtDate(iso: string): string {
        const d = new Date(iso);
        const p = (n: number) => String(n).padStart(2, "0");
        return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}`;
    }

    let pressTimer: ReturnType<typeof setTimeout> | null = null;
    let longPressed = false;

    function onTouchStart() {
        longPressed = false;
        pressTimer = setTimeout(() => {
            longPressed = true;
        }, 500);
    }

    function onTouchEnd() {
        if (pressTimer) clearTimeout(pressTimer);
    }

    function onCardClick() {
        if (!longPressed) dispatch("open", note);
    }
</script>

<!-- svelte-ignore a11y-click-events-have-key-events -->
<!-- svelte-ignore a11y-no-static-element-interactions -->
<div class="note-card" style={accentColor ? `--accent: ${accentColor}` : ""} on:touchstart={onTouchStart} on:touchend={onTouchEnd} on:click={onCardClick}>
    {#if accentColor}
        <div class="note-accent-bar" />
    {/if}

    <div class="note-body">
        <!-- Header -->
        <div class="note-header">
            <h3 class="note-title">{note.title || "Untitled"}</h3>
            <div class="note-actions">
                <button class="action-btn" class:pinned={note.is_pinned} title={note.is_pinned ? "Unpin" : "Pin"} on:click|stopPropagation={() => dispatch("togglePin", note.id)} type="button" aria-label={note.is_pinned ? "Unpin note" : "Pin note"}> 📌 </button>
                <button class="action-btn danger" title="Delete" on:click|stopPropagation={() => dispatch("delete", note.id)} type="button" aria-label="Delete note"> 🗑 </button>
            </div>
        </div>

        <!-- Preview / lock -->
        {#if note.is_secret && note.is_locked}
            <div class="note-locked">
                <svg xmlns="http://www.w3.org/2000/svg" class="lock-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                    <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                    <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                </svg>
            </div>
        {:else if note.body}
            <div class="note-preview prose-preview">
                {@html note.body}
            </div>
        {:else}
            <p class="note-empty">Empty note</p>
        {/if}

        <!-- Footer -->
        <div class="note-footer">
            {#if (note.tags ?? []).length > 0}
                <div class="tag-row">
                    {#each note.tags ?? [] as tag (tag.id)}
                        <span class="tag-chip">{tag.emoji}{tag.name}</span>
                    {/each}
                </div>
            {/if}
            <div class="badge-row">
                {#if note.is_pinned}
                    <span class="badge badge-pin">Pinned</span>
                {/if}
                {#if note.is_secret}
                    <span class="badge badge-secret">🔒 Secret</span>
                {/if}
                {#if note.attachment_count > 0}
                    <span class="badge badge-attach">📎 {note.attachment_count}</span>
                {/if}
                <span class="note-date">{fmtDate(note.updated_at)}</span>
            </div>
        </div>
    </div>
</div>

<style>
    .note-card {
        position: relative;
        overflow: hidden;
        border-radius: 14px;
        background: var(--color-surface);
        border: 1px solid var(--color-border);
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
        transition: box-shadow 0.15s ease;
    }

    .note-card:active {
        box-shadow: 0 2px 16px rgba(0, 0, 0, 0.18);
    }

    .note-accent-bar {
        position: absolute;
        inset-inline: 0;
        top: 0;
        height: 3px;
        background: var(--accent);
        opacity: 0.85;
    }

    .note-body {
        padding: 12px 12px 10px;
        display: flex;
        flex-direction: column;
        gap: 8px;
        min-height: 140px;
    }

    .note-header {
        display: flex;
        align-items: flex-start;
        gap: 6px;
        border-bottom: 1px solid var(--color-border);
        padding-bottom: 8px;
    }

    .note-title {
        flex: 1;
        font-size: 14px;
        font-weight: 600;
        color: var(--color-text-primary);
        line-height: 1.3;
        margin: 0;
        overflow: hidden;
        display: -webkit-box;
        -webkit-line-clamp: 2;
        -webkit-box-orient: vertical;
    }

    .note-actions {
        display: flex;
        gap: 2px;
        flex-shrink: 0;
    }

    .action-btn {
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
        transition:
            opacity 0.15s,
            background 0.15s;
        -webkit-tap-highlight-color: transparent;
    }

    .action-btn:active {
        background: var(--color-muted);
        opacity: 1;
    }

    .action-btn.pinned {
        opacity: 1;
    }

    .action-btn.danger:active {
        background: rgba(239, 68, 68, 0.15);
    }

    .note-locked {
        display: flex;
        align-items: center;
        justify-content: center;
        flex: 1;
        opacity: 0.25;
    }

    .lock-icon {
        width: 40px;
        height: 40px;
    }

    .note-preview {
        flex: 1;
        font-size: 12px;
        color: var(--color-text-secondary);
        line-height: 1.5;
        overflow: hidden;
        max-height: 72px;
        pointer-events: none;
    }

    /* Strip most tiptap/prose formatting in preview */
    .note-preview :global(h1),
    .note-preview :global(h2),
    .note-preview :global(h3) {
        font-size: 13px;
        font-weight: 600;
        margin: 0 0 2px;
    }

    .note-preview :global(p) {
        margin: 0 0 2px;
    }

    .note-preview :global(ul),
    .note-preview :global(ol) {
        margin: 0;
        padding-left: 14px;
    }

    .note-empty {
        flex: 1;
        font-size: 12px;
        font-style: italic;
        color: var(--color-text-muted);
        margin: 0;
    }

    .note-footer {
        margin-top: auto;
        display: flex;
        flex-direction: column;
        gap: 4px;
    }

    .tag-row {
        display: flex;
        flex-wrap: wrap;
        gap: 4px;
    }

    .tag-chip {
        font-size: 11px;
        padding: 2px 8px;
        border-radius: 20px;
        background: rgba(34, 211, 238, 0.1);
        border: 1px solid rgba(34, 211, 238, 0.3);
        color: var(--color-accent);
        max-width: 110px;
        overflow: hidden;
        text-overflow: ellipsis;
        white-space: nowrap;
    }

    .badge-row {
        display: flex;
        align-items: center;
        gap: 4px;
        flex-wrap: wrap;
    }

    .badge {
        font-size: 10px;
        padding: 2px 6px;
        border-radius: 20px;
        border: 1px solid transparent;
    }

    .badge-pin {
        background: rgba(34, 211, 238, 0.15);
        color: var(--color-accent);
        border-color: rgba(34, 211, 238, 0.3);
    }

    .badge-secret {
        background: rgba(245, 158, 11, 0.15);
        color: #d97706;
        border-color: rgba(245, 158, 11, 0.3);
    }

    .badge-attach {
        background: rgba(249, 115, 22, 0.15);
        color: #ea580c;
        border-color: rgba(249, 115, 22, 0.3);
    }

    .note-date {
        font-size: 10px;
        color: var(--color-text-muted);
        margin-left: auto;
    }
</style>
