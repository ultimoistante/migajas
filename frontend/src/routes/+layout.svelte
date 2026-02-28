<script lang="ts">
    import "../app.css";
    import { onMount } from "svelte";
    import { goto } from "$app/navigation";
    import { page } from "$app/stores";
    import { authStore, isAuthenticated } from "$lib/stores/auth";
    import { theme } from "$lib/stores/theme";
    import { setup } from "$lib/api/client";
    import { appInitialized } from "$lib/stores/appState";

    const PUBLIC_ROUTES = ["/login", "/register"];

    let setupChecked = false;

    onMount(async () => {
        try {
            const status = await setup.status();
            appInitialized.set(status.initialized);
        } catch {
            appInitialized.set(true); // if check fails, don't block the app
        }
        setupChecked = true;
        await authStore.init();
    });

    // Route guard
    $: {
        const path = $page.url.pathname;
        const isSetupRoute = path.startsWith("/setup");
        const isPublic = PUBLIC_ROUTES.some((r) => path.startsWith(r));

        if (setupChecked) {
            if (!$appInitialized) {
                // App not set up yet — only /setup is allowed
                if (!isSetupRoute) goto("/setup");
            } else if (!$authStore.loading) {
                // App is initialized — /setup is no longer accessible
                if (isSetupRoute) {
                    goto($isAuthenticated ? "/" : "/login");
                } else if (!$isAuthenticated && !isPublic) {
                    goto("/login");
                } else if ($isAuthenticated && isPublic) {
                    goto("/");
                }
            }
        }
    }
</script>

<div data-theme={$theme} class="min-h-screen bg-base-200 text-base-content transition-colors duration-200">
    {#if !setupChecked || (!$appInitialized && !$page.url.pathname.startsWith("/setup")) || $authStore.loading}
        <div class="flex items-center justify-center min-h-screen">
            <span class="loading loading-spinner loading-lg text-primary" />
        </div>
    {:else}
        <slot />
    {/if}
</div>
