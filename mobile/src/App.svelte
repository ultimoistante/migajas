<script lang="ts">
    import { onMount } from "svelte";
    import Router, { push, location } from "svelte-spa-router";
    import { App as CapApp } from "@capacitor/app";
    import { StatusBar, Style } from "@capacitor/status-bar";

    import { getServerUrl } from "$lib/serverConfig";
    import { authStore, isAuthenticated } from "$lib/stores/auth";
    import { appInitialized, allowSelfRegistration } from "$lib/stores/appState";
    import { themeStore } from "$lib/stores/theme";
    import { setup } from "$lib/api/client";

    import ServerSetup from "$lib/components/ServerSetup.svelte";
    import BottomTabBar from "$lib/components/BottomTabBar.svelte";

    import HomeRoute from "./routes/HomeRoute.svelte";
    import LoginRoute from "./routes/LoginRoute.svelte";
    import RegisterRoute from "./routes/RegisterRoute.svelte";
    import SetupRoute from "./routes/SetupRoute.svelte";
    import SettingsRoute from "./routes/SettingsRoute.svelte";
    import AdminRoute from "./routes/AdminRoute.svelte";

    const routes = {
        "/": HomeRoute,
        "/login": LoginRoute,
        "/register": RegisterRoute,
        "/setup": SetupRoute,
        "/settings": SettingsRoute,
        "/admin": AdminRoute,
    };

    let showServerSetup = false;
    let appReady = false;

    const TAB_ROUTES = ["/", "/settings", "/admin"];
    $: showTabBar = $isAuthenticated && TAB_ROUTES.includes($location);

    // Theme → StatusBar style sync
    $: if (typeof window !== "undefined") {
        const resolved = $themeStore;
        StatusBar.setStyle({ style: resolved === "dark" ? Style.Dark : Style.Light }).catch(() => {});
    }

    onMount(async () => {
        // 1. Check server URL is configured
        const url = await getServerUrl();
        if (!url) {
            showServerSetup = true;
            return;
        }

        // 2. Check first-run setup status
        try {
            const status = await setup.status();
            $appInitialized = status.initialized;
            $allowSelfRegistration = status.allow_self_registration;
            if (!status.initialized) {
                push("/setup");
                appReady = true;
                return;
            }
        } catch {
            // Server might be unreachable — still proceed so user can reconfigure URL
            $appInitialized = false;
        }

        // 3. Try to restore auth session
        await authStore.init();

        if (!$isAuthenticated) {
            push("/login");
        }

        appReady = true;

        // Android back button handler
        await CapApp.addListener("backButton", ({ canGoBack }) => {
            if (canGoBack) {
                window.history.back();
            } else {
                CapApp.exitApp();
            }
        });
    });

    function onServerConfigured() {
        showServerSetup = false;
        // Restart init flow
        appReady = false;
        initApp();
    }

    async function initApp() {
        try {
            const status = await setup.status();
            $appInitialized = status.initialized;
            $allowSelfRegistration = status.allow_self_registration;
            if (!status.initialized) {
                push("/setup");
                appReady = true;
                return;
            }
        } catch {
            $appInitialized = false;
        }
        await authStore.init();
        if (!$isAuthenticated) push("/login");
        appReady = true;
    }
</script>

{#if showServerSetup}
    <ServerSetup on:configured={onServerConfigured} />
{:else if appReady}
    <div class="app-shell">
        <div class="router-view" class:has-tabbar={showTabBar}>
            <Router {routes} />
        </div>
        {#if showTabBar}
            <BottomTabBar />
        {/if}
    </div>
{:else}
    <!-- Initial loading splash -->
    <div class="splash">
        <div class="splash-logo">🍞</div>
        <p class="splash-text">Migajas</p>
    </div>
{/if}

<style>
    .app-shell {
        display: flex;
        flex-direction: column;
        height: 100dvh;
        overflow: hidden;
    }

    .router-view {
        flex: 1;
        overflow-y: auto;
        -webkit-overflow-scrolling: touch;
    }

    .router-view.has-tabbar {
        padding-bottom: 0;
    }

    .splash {
        display: flex;
        flex-direction: column;
        align-items: center;
        justify-content: center;
        height: 100dvh;
        gap: 12px;
    }

    .splash-logo {
        font-size: 64px;
    }

    .splash-text {
        font-size: 24px;
        font-weight: 700;
        color: var(--color-text-primary);
        letter-spacing: 0.05em;
    }
</style>
