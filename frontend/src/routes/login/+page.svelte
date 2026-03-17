<script lang="ts">
    import { authStore } from "$lib/stores/auth";
    import { goto } from "$app/navigation";
    import { allowSelfRegistration } from "$lib/stores/appState";

    export let params: Record<string, string> = {};

    let usernameOrEmail = "";
    let password = "";
    let loading = false;
    let error = "";

    async function submit() {
        error = "";
        loading = true;
        try {
            await authStore.login(usernameOrEmail, password);
            goto("/");
        } catch (e: unknown) {
            error = e instanceof Error ? e.message : "Login failed";
        } finally {
            loading = false;
        }
    }
</script>

<svelte:head>
    <title>Sign in — migajas</title>
</svelte:head>

<div class="min-h-screen flex items-center justify-center bg-muted p-4">
    <div class="rounded-xl border border-border bg-card w-full max-w-sm shadow-xl p-6 flex flex-col gap-5">
        <!-- Logo / brand -->
        <div class="flex flex-col items-center gap-2">
            <img src="/logo.svg" alt="migajas" class="h-12" />
            <p class="text-sm text-muted-foreground">Sign in to your account</p>
        </div>

        <form on:submit|preventDefault={submit} class="flex flex-col gap-3">
            <div class="flex flex-col gap-1.5">
                <label class="text-sm font-medium" for="login-username">Username or email</label>
                <input id="login-username" type="text" placeholder="username or email" class="h-10 w-full rounded-md border border-border bg-background px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/35" bind:value={usernameOrEmail} autocomplete="username" required />
            </div>

            <div class="flex flex-col gap-1.5">
                <label class="text-sm font-medium" for="login-password">Password</label>
                <input id="login-password" type="password" placeholder="••••••••" class="h-10 w-full rounded-md border border-border bg-background px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/35" bind:value={password} autocomplete="current-password" required />
            </div>

            {#if error}
                <div class="bg-destructive/10 border border-destructive/30 text-destructive px-3 py-2 rounded-md text-sm">{error}</div>
            {/if}

            <button type="submit" class="h-10 px-4 bg-primary text-primary-foreground hover:bg-primary/90 rounded-md inline-flex items-center justify-center gap-2 text-sm font-medium mt-1 disabled:opacity-50 transition-colors" disabled={loading}>
                {#if loading}
                    <span class="h-4 w-4 animate-spin rounded-full border-2 border-current border-r-transparent" />
                {/if}
                Sign in
            </button>
        </form>

        {#if $allowSelfRegistration}
            <p class="text-center text-sm text-muted-foreground">
                Don't have an account?
                <a href="/register" class="text-primary font-medium hover:underline">Create one</a>
            </p>
        {/if}
    </div>
</div>
