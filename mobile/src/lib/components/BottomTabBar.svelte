<script lang="ts">
    import { location, push } from "svelte-spa-router";
    import { currentUser } from "$lib/stores/auth";

    const tabs = [
        { path: "/", label: "Notes" },
        { path: "/settings", label: "Settings" },
    ] as const;

    $: adminTab = $currentUser?.is_admin ? [{ path: "/admin", label: "Admin" } as const] : [];

    $: allTabs = [...tabs, ...adminTab];

    function navigate(path: string) {
        push(path);
    }
</script>

<nav class="bottom-tab-bar">
    {#each allTabs as tab}
        <button class="tab-btn" class:active={$location === tab.path} on:click={() => navigate(tab.path)} aria-label={tab.label}>
            <span class="tab-icon">
                {#if tab.path === "/"}
                    <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                        <polyline points="14 2 14 8 20 8" />
                        <line x1="16" y1="13" x2="8" y2="13" />
                        <line x1="16" y1="17" x2="8" y2="17" />
                    </svg>
                {:else if tab.path === "/settings"}
                    <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <circle cx="12" cy="12" r="3" />
                        <path d="M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1-2.83 2.83l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-4 0v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83-2.83l.06-.06A1.65 1.65 0 0 0 4.68 15a1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1 0-4h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 2.83-2.83l.06.06A1.65 1.65 0 0 0 9 4.68a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 4 0v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 2.83l-.06.06A1.65 1.65 0 0 0 19.4 9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 0 4h-.09a1.65 1.65 0 0 0-1.51 1z" />
                    </svg>
                {:else}
                    <svg xmlns="http://www.w3.org/2000/svg" width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round">
                        <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                    </svg>
                {/if}
            </span>
            <span class="tab-label">{tab.label}</span>
        </button>
    {/each}
</nav>

<style>
    .bottom-tab-bar {
        display: flex;
        align-items: stretch;
        background: var(--color-surface);
        border-top: 1px solid var(--color-border);
        padding-bottom: env(safe-area-inset-bottom, 0px);
        flex-shrink: 0;
    }

    .tab-btn {
        flex: 1;
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        padding: 8px 4px;
        min-height: 56px;
        gap: 3px;
        background: none;
        border: none;
        cursor: pointer;
        color: var(--color-text-muted);
        transition: color 0.15s ease;
        -webkit-tap-highlight-color: transparent;
    }

    .tab-btn.active {
        color: var(--color-accent);
    }

    .tab-icon {
        display: flex;
        align-items: center;
        justify-content: center;
        line-height: 1;
    }

    .tab-label {
        font-size: 11px;
        font-weight: 500;
        letter-spacing: 0.02em;
    }
</style>
