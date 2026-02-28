<script lang="ts">
    import { createEventDispatcher } from "svelte";
    import { notes as notesApi } from "$lib/api/client";
    import { notesStore } from "$lib/stores/notes";
    import type { Note } from "$lib/api/client";

    export let note: Note | null = null;
    export let open: boolean = false;

    const dispatch = createEventDispatcher<{ unlocked: Note; close: void }>();

    let credential = "";
    let loading = false;
    let error = "";

    $: if (open) {
        credential = "";
        error = "";
    }

    async function unlock() {
        if (!note) return;
        error = "";
        loading = true;
        try {
            const unlocked = await notesApi.unlock(note.id, credential);
            // Do NOT update the store — the card stays locked on the home page.
            // The decrypted content is only available inside the modal that opens next.
            dispatch("unlocked", unlocked);
        } catch (e: unknown) {
            error = e instanceof Error ? e.message : "Invalid credential";
        } finally {
            loading = false;
        }
    }

    function close() {
        dispatch("close");
    }
</script>

{#if open && note}
    <div class="fixed inset-0 bg-black/60 z-50 flex items-center justify-center p-4" on:click={close} on:keydown={(e) => e.key === "Escape" && close()} role="dialog" aria-modal="true">
        <div class="bg-base-100 rounded-2xl shadow-2xl w-full max-w-sm p-6 flex flex-col gap-4" on:click|stopPropagation on:keydown|stopPropagation>
            <div class="flex flex-col items-center gap-2 text-center">
                <div class="w-14 h-14 bg-warning/20 rounded-full flex items-center justify-center">
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-7 h-7 text-warning" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <rect x="3" y="11" width="18" height="11" rx="2" ry="2" /><path d="M7 11V7a5 5 0 0 1 10 0v4" />
                    </svg>
                </div>
                <h2 class="text-lg font-bold">Unlock secret note</h2>
                <p class="text-sm text-base-content/60">
                    Enter your vault PIN or vault password to decrypt "<strong>{note.title || "Untitled"}</strong>"
                </p>
            </div>

            <input type="password" placeholder="Vault PIN or password" class="input input-bordered w-full" bind:value={credential} autocomplete="off" on:keydown={(e) => e.key === "Enter" && unlock()} />

            {#if error}
                <div class="alert alert-error text-sm py-2">{error}</div>
            {/if}

            <div class="flex gap-2">
                <button class="btn btn-ghost flex-1" on:click={close} type="button">Cancel</button>
                <button class="btn btn-warning flex-1" on:click={unlock} disabled={loading || !credential} type="button">
                    {#if loading}
                        <span class="loading loading-spinner loading-sm" />
                    {:else}
                        Unlock
                    {/if}
                </button>
            </div>
        </div>
    </div>
{/if}
