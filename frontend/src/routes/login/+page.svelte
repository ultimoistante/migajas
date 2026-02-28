<script lang="ts">
    import { authStore } from "$lib/stores/auth";
    import { goto } from "$app/navigation";

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
                <div class="w-12 h-12 bg-primary rounded-2xl flex items-center justify-center">
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-7 h-7 text-primary-content" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" /><polyline points="14 2 14 8 20 8" /><line x1="16" y1="13" x2="8" y2="13" /><line x1="16" y1="17" x2="8" y2="17" /><polyline points="10 9 9 9 8 9" />
                    </svg>
                </div>
                <h1 class="text-2xl font-bold">migajas</h1>
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

            <p class="text-center text-sm text-base-content/60">
                Don't have an account?
                <a href="/register" class="link link-primary font-medium">Create one</a>
            </p>
        </div>
    </div>
</div>
