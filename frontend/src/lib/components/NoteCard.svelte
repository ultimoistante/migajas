<script lang="ts">
    import { createEventDispatcher } from "svelte";
    import type { Note } from "$lib/api/client";

    export let note: Note;

    const dispatch = createEventDispatcher<{
        open: Note;
        delete: string;
        togglePin: string;
    }>();

    const NOTE_TOP_BORDER: Record<string, string> = {
        yellow: "#f59e0b",
        blue: "#60a5fa",
        green: "#4ade80",
        pink: "#f472b6",
        purple: "#c084fc",
    };

    $: topBorder = note.color && NOTE_TOP_BORDER[note.color] ? `border-top: 3px solid ${NOTE_TOP_BORDER[note.color]};` : "";

    function fmtDate(iso: string): string {
        const d = new Date(iso);
        const p = (n: number) => String(n).padStart(2, "0");
        return `${d.getFullYear()}-${p(d.getMonth() + 1)}-${p(d.getDate())} ${p(d.getHours())}:${p(d.getMinutes())}:${p(d.getSeconds())}`;
    }
</script>

<div class="card border border-base-300 shadow-sm hover:shadow-md transition-shadow cursor-pointer group bg-base-100" style={topBorder} on:click={() => dispatch("open", note)} on:keydown={(e) => e.key === "Enter" && dispatch("open", note)} role="button" tabindex="0">
    <div class="card-body p-4 gap-2 min-h-[200px]">
        <!-- Header row -->
        <div class="flex items-start justify-between gap-2">
            <h3 class="font-semibold text-base leading-tight line-clamp-2 flex-1">
                {note.title || "Untitled"}
            </h3>
            <div class="flex items-center gap-1 opacity-0 group-hover:opacity-100 transition-opacity">
                <!-- Pin -->
                <button class="btn btn-ghost btn-xs" title={note.is_pinned ? "Unpin" : "Pin"} on:click|stopPropagation={() => dispatch("togglePin", note.id)} type="button">
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" class:text-primary={note.is_pinned} viewBox="0 0 24 24" fill={note.is_pinned ? "currentColor" : "none"} stroke="currentColor" stroke-width="2">
                        <path d="M12 2a1 1 0 0 1 1 1v1h4a1 1 0 0 1 .7 1.7l-2.7 2.7.3 4.6L18 14a1 1 0 0 1-1 1h-4v6a1 1 0 1 1-2 0v-6H7a1 1 0 0 1-1-1l2.7-1 .3-4.6L6.3 5.7A1 1 0 0 1 7 4h4V3a1 1 0 0 1 1-1z" />
                    </svg>
                </button>
                <!-- Delete -->
                <button class="btn btn-ghost btn-xs text-error" title="Delete" on:click|stopPropagation={() => dispatch("delete", note.id)} type="button">
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <polyline points="3 6 5 6 21 6" /><path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a1 1 0 0 1 1-1h4a1 1 0 0 1 1 1v2" />
                    </svg>
                </button>
            </div>
        </div>

        <!-- Body preview or lock icon -->
        {#if note.is_secret && note.is_locked}
            <div class="flex flex-col items-center justify-center flex-1 text-base-content/30">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-12 h-12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
                    <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                    <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                </svg>
            </div>
        {:else if note.body}
            <div class="prose prose-sm max-w-none overflow-hidden max-h-[90px] pointer-events-none text-base-content/80 flex-1">
                {@html note.body}
            </div>
        {:else}
            <p class="text-sm text-base-content/40 italic flex-1">Empty note</p>
        {/if}

        <!-- Footer badges -->
        <div class="flex items-center gap-1.5 mt-auto flex-wrap">
            {#if note.is_pinned}
                <span class="badge badge-primary badge-xs">Pinned</span>
            {/if}
            {#if note.is_secret}
                <span class="badge badge-warning badge-xs gap-1">
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-2.5 h-2.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                        <rect x="3" y="11" width="18" height="11" rx="2" ry="2" /><path d="M7 11V7a5 5 0 0 1 10 0v4" />
                    </svg>
                    Secret
                </span>
            {/if}
            {#if note.attachment_count > 0}
                <span class="badge badge-xs gap-1 bg-orange-500 text-white border-orange-500">
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-2.5 h-2.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
                        <path d="M21.44 11.05l-9.19 9.19a6 6 0 0 1-8.49-8.49l9.19-9.19a4 4 0 0 1 5.66 5.66l-9.2 9.19a2 2 0 0 1-2.83-2.83l8.49-8.48" />
                    </svg>
                    {note.attachment_count}
                </span>
            {/if}
            <span class="text-xs text-base-content/40 ml-auto">
                {fmtDate(note.updated_at)}
            </span>
        </div>
    </div>
</div>
