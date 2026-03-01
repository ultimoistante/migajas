<script lang="ts">
    import { auth as authApi } from "$lib/api/client";
    import { goto } from "$app/navigation";

    let username = "";
    let email = "";
    let password = "";
    let confirmPassword = "";
    let loading = false;
    let error = "";
    let success = false;

    async function submit() {
        error = "";
        if (password !== confirmPassword) {
            error = "Passwords do not match";
            return;
        }
        loading = true;
        try {
            await authApi.register(username, email, password);
            success = true;
            setTimeout(() => goto("/login"), 1500);
        } catch (e: unknown) {
            error = e instanceof Error ? e.message : "Registration failed";
        } finally {
            loading = false;
        }
    }
</script>

<svelte:head>
    <title>Create account — migajas</title>
</svelte:head>

<div class="min-h-screen flex items-center justify-center bg-base-200 p-4">
    <div class="card bg-base-100 w-full max-w-sm shadow-xl">
        <div class="card-body gap-5">
            <div class="flex flex-col items-center gap-2 mb-2">
                <img src="/logo.svg" alt="migajas" class="h-12" />
                <h1 class="text-2xl font-bold">Create account</h1>
                <p class="text-sm text-base-content/60">Join migajas today</p>
            </div>

            {#if success}
                <div class="alert alert-success">
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-5 h-5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M22 11.08V12a10 10 0 1 1-5.93-9.14" /><polyline points="22 4 12 14.01 9 11.01" />
                    </svg>
                    Account created! Redirecting to login…
                </div>
            {:else}
                <form on:submit|preventDefault={submit} class="flex flex-col gap-3">
                    <label class="form-control">
                        <div class="label py-1"><span class="label-text">Username</span></div>
                        <input type="text" placeholder="johndoe" class="input input-bordered" bind:value={username} autocomplete="username" required />
                    </label>

                    <label class="form-control">
                        <div class="label py-1"><span class="label-text">Email</span></div>
                        <input type="email" placeholder="john@example.com" class="input input-bordered" bind:value={email} autocomplete="email" required />
                    </label>

                    <label class="form-control">
                        <div class="label py-1"><span class="label-text">Password</span></div>
                        <input type="password" placeholder="Min. 8 characters" class="input input-bordered" bind:value={password} autocomplete="new-password" required />
                    </label>

                    <label class="form-control">
                        <div class="label py-1"><span class="label-text">Confirm password</span></div>
                        <input type="password" placeholder="Repeat password" class="input input-bordered" bind:value={confirmPassword} autocomplete="new-password" required />
                    </label>

                    {#if error}
                        <div class="alert alert-error text-sm py-2">{error}</div>
                    {/if}

                    <button type="submit" class="btn btn-primary mt-1" disabled={loading}>
                        {#if loading}<span class="loading loading-spinner loading-sm" />{/if}
                        Create account
                    </button>
                </form>

                <p class="text-center text-sm text-base-content/60">
                    Already have an account?
                    <a href="/login" class="link link-primary font-medium">Sign in</a>
                </p>
            {/if}
        </div>
    </div>
</div>
