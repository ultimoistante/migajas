<script lang="ts">
    import { createEventDispatcher } from "svelte";
    import { notes as notesApi } from "$lib/api/client";
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
    <!-- svelte-ignore a11y-click-events-have-key-events -->
    <!-- svelte-ignore a11y-no-static-element-interactions -->
    <div class="modal-backdrop" on:click={close} role="dialog" aria-modal="true">
        <!-- svelte-ignore a11y-click-events-have-key-events -->
        <!-- svelte-ignore a11y-no-static-element-interactions -->
        <div class="modal-card" on:click|stopPropagation>
            <div class="modal-icon-row">
                <div class="lock-icon-wrap">
                    <svg xmlns="http://www.w3.org/2000/svg" class="lock-svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <rect x="3" y="11" width="18" height="11" rx="2" ry="2" />
                        <path d="M7 11V7a5 5 0 0 1 10 0v4" />
                    </svg>
                </div>
                <h2 class="modal-title">Unlock secret note</h2>
                <p class="modal-desc">Enter your vault PIN or password to decrypt <strong>{note.title || "Untitled"}</strong></p>
            </div>

            <input type="password" class="cred-input" placeholder="Vault PIN or password" bind:value={credential} autocomplete="off" on:keydown={(e) => e.key === "Enter" && unlock()} />

            {#if error}
                <p class="error-msg">{error}</p>
            {/if}

            <div class="modal-actions">
                <button class="btn-cancel" on:click={close} type="button">Cancel</button>
                <button class="btn-unlock" on:click={unlock} disabled={loading || !credential} type="button">
                    {loading ? "Unlocking…" : "Unlock"}
                </button>
            </div>
        </div>
    </div>
{/if}

<style>
    .modal-backdrop {
        position: fixed;
        inset: 0;
        background: rgba(0, 0, 0, 0.6);
        z-index: 100;
        display: flex;
        align-items: flex-end;
        justify-content: center;
        padding: 0 0 env(safe-area-inset-bottom, 0px);
    }

    .modal-card {
        width: 100%;
        max-width: 500px;
        background: var(--color-surface);
        border-radius: 20px 20px 0 0;
        padding: 24px 20px;
        display: flex;
        flex-direction: column;
        gap: 16px;
    }

    .modal-icon-row {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 8px;
        text-align: center;
    }

    .lock-icon-wrap {
        width: 56px;
        height: 56px;
        border-radius: 50%;
        background: rgba(245, 158, 11, 0.15);
        display: flex;
        align-items: center;
        justify-content: center;
    }

    .lock-svg {
        width: 28px;
        height: 28px;
        color: #d97706;
    }

    .modal-title {
        font-size: 18px;
        font-weight: 700;
        color: var(--color-text-primary);
        margin: 0;
    }

    .modal-desc {
        font-size: 14px;
        color: var(--color-text-secondary);
        margin: 0;
    }

    .cred-input {
        width: 100%;
        padding: 13px 14px;
        border-radius: 10px;
        border: 1.5px solid var(--color-border);
        background: var(--color-bg);
        color: var(--color-text-primary);
        font-size: 16px;
        outline: none;
        box-sizing: border-box;
        transition: border-color 0.15s;
    }

    .cred-input:focus {
        border-color: var(--color-accent);
    }

    .error-msg {
        font-size: 13px;
        color: #dc2626;
        background: rgba(239, 68, 68, 0.12);
        padding: 10px 14px;
        border-radius: 8px;
        margin: 0;
    }

    .modal-actions {
        display: flex;
        gap: 10px;
    }

    .btn-cancel,
    .btn-unlock {
        flex: 1;
        padding: 13px;
        border-radius: 10px;
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

    .btn-unlock {
        background: #d97706;
        color: #fff;
    }

    .btn-unlock:disabled {
        opacity: 0.5;
    }
</style>
