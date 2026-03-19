<script lang="ts">
    import { location, push } from "svelte-spa-router";
    import { currentUser } from "$lib/stores/auth";

    const tabs = [
        { path: "/", icon: "🏠", label: "Notes" },
        { path: "/settings", icon: "⚙️", label: "Settings" },
    ] as const;

    $: adminTab = $currentUser?.is_admin ? [{ path: "/admin", icon: "🛡️", label: "Admin" } as const] : [];

    $: allTabs = [...tabs, ...adminTab];

    function navigate(path: string) {
        push(path);
    }
</script>

<nav class="bottom-tab-bar">
    {#each allTabs as tab}
        <button class="tab-btn" class:active={$location === tab.path} on:click={() => navigate(tab.path)} aria-label={tab.label}>
            <span class="tab-icon">{tab.icon}</span>
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
        font-size: 22px;
        line-height: 1;
    }

    .tab-label {
        font-size: 11px;
        font-weight: 500;
        letter-spacing: 0.02em;
    }
</style>
