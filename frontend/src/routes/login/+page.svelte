<script lang="ts">
    import { authStore } from "$lib/stores/auth";
    import { goto } from "$app/navigation";
    import { allowSelfRegistration } from "$lib/stores/appState";

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

<div class="min-h-screen flex items-center justify-center bg-base-200 p-4">
    <div class="card bg-base-100 w-full max-w-sm shadow-xl">
        <div class="card-body gap-5">
            <!-- Logo / brand -->
            <div class="flex flex-col items-center gap-2 mb-2">
                <img src="/logo.svg" alt="migajas" class="h-12" />
                <p class="text-sm text-base-content/60">Sign in to your account</p>
            </div>

            <form on:submit|preventDefault={submit} class="flex flex-col gap-3">
                <label class="form-control">
                    <div class="label py-1">
                        <span class="label-text">Username or email</span>
                    </div>
                    <input type="text" placeholder="username or email" class="input input-bordered" bind:value={usernameOrEmail} autocomplete="username" required />
                </label>

                <label class="form-control">
                    <div class="label py-1">
                        <span class="label-text">Password</span>
                    </div>
                    <input type="password" placeholder="••••••••" class="input input-bordered" bind:value={password} autocomplete="current-password" required />
                </label>

                {#if error}
                    <div class="alert alert-error text-sm py-2">{error}</div>
                {/if}

                <button type="submit" class="btn btn-primary mt-1" disabled={loading}>
                    {#if loading}<span class="loading loading-spinner loading-sm" />{/if}
                    Sign in
                </button>
            </form>

            {#if $allowSelfRegistration}
                <p class="text-center text-sm text-base-content/60">
                    Don't have an account?
                    <a href="/register" class="link link-primary font-medium">Create one</a>
                </p>
            {/if}
        </div>
    </div>
</div>
