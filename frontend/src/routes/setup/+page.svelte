<script lang="ts">
    import { goto } from "$app/navigation";
    import { setup, ApiError } from "$lib/api/client";
    import { authStore } from "$lib/stores/auth";
    import { appInitialized } from "$lib/stores/appState";

    let username = "admin";
    let email = "";
    let password = "";
    let confirmPassword = "";
    let allowSelfReg = true;
    let loading = false;
    let error = "";

    async function initialize() {
        error = "";
        if (!username.trim() || !email.trim() || !password) {
            error = "All fields are required.";
            return;
        }
        if (password !== confirmPassword) {
            error = "Passwords do not match.";
            return;
        }
        if (password.length < 8) {
            error = "Password must be at least 8 characters.";
            return;
        }

        loading = true;
        try {
            await setup.initialize({
                username: username.trim(),
                email: email.trim(),
                password,
                allow_self_registration: allowSelfReg,
            });
            // Mark app as initialized BEFORE navigating so the layout guard allows it
            appInitialized.set(true);
            // Auto-login with the admin credentials just created
            await authStore.login(username.trim(), password);
            goto("/");
        } catch (e) {
            error = e instanceof ApiError ? e.message : "Initialization failed. Please try again.";
        } finally {
            loading = false;
        }
    }
</script>

<div class="min-h-screen flex items-center justify-center bg-muted p-4">
    <div class="rounded-lg border border-border shadow-sm bg-card shadow-xl w-full max-w-md">
        <div class="rounded-lg border border-border shadow-sm-body gap-6">
            <!-- Logo / title -->
            <div class="text-center">
                <div class="flex items-center justify-center gap-2 mb-2">
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-8 h-8 text-primary" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z" />
                        <polyline points="14 2 14 8 20 8" />
                        <line x1="16" y1="13" x2="8" y2="13" />
                        <line x1="16" y1="17" x2="8" y2="17" />
                        <polyline points="10 9 9 9 8 9" />
                    </svg>
                    <h1 class="text-2xl font-bold">migajas</h1>
                </div>
                <h2 class="text-lg font-semibold">First-time Setup</h2>
                <p class="text-sm text-foreground/80 mt-1">Create the administrator account to get started.</p>
            </div>

            <form on:submit|preventDefault={initialize} class="flex flex-col gap-4">
                <!-- Username -->
                <div class="form-control">
                    <label class="flex flex-col gap-1.5 pb-1" for="username">
                        <span class="flex flex-col gap-1.5-text font-medium">Username</span>
                    </label>
                    <input id="username" type="text" placeholder="admin" class="flex h-10 w-full rounded-md border border-border bg-background px-3 py-2 text-sm" bind:value={username} autocomplete="username" required />
                </div>

                <!-- Email -->
                <div class="form-control">
                    <label class="flex flex-col gap-1.5 pb-1" for="email">
                        <span class="flex flex-col gap-1.5-text font-medium">Email</span>
                    </label>
                    <input id="email" type="email" placeholder="admin@example.com" class="flex h-10 w-full rounded-md border border-border bg-background px-3 py-2 text-sm" bind:value={email} autocomplete="email" required />
                </div>

                <!-- Password -->
                <div class="form-control">
                    <label class="flex flex-col gap-1.5 pb-1" for="password">
                        <span class="flex flex-col gap-1.5-text font-medium">Password</span>
                    </label>
                    <input id="password" type="password" placeholder="At least 8 characters" class="flex h-10 w-full rounded-md border border-border bg-background px-3 py-2 text-sm" bind:value={password} autocomplete="new-password" required />
                </div>

                <!-- Confirm Password -->
                <div class="form-control">
                    <label class="flex flex-col gap-1.5 pb-1" for="confirm-password">
                        <span class="flex flex-col gap-1.5-text font-medium">Confirm password</span>
                    </label>
                    <input id="confirm-password" type="password" placeholder="Repeat password" class="flex h-10 w-full rounded-md border border-border bg-background px-3 py-2 text-sm" bind:value={confirmPassword} autocomplete="new-password" required />
                </div>

                <!-- Self-registration toggle -->
                <div class="divider my-0">User settings</div>
                <label class="flex flex-col gap-1.5 cursor-pointer justify-start gap-3 p-0">
                    <input type="checkbox" class="toggle toggle-primary toggle-sm" bind:checked={allowSelfReg} />
                    <span class="flex flex-col gap-1.5-text">Allow users to self-register</span>
                </label>
                <p class="text-xs text-muted-foreground -mt-2">If enabled, anyone can create an account. If disabled, only the admin can manage users.</p>

                {#if error}
                    <div class="bg-destructive text-destructive-foreground px-4 py-3 rounded-md text-sm">{error}</div>
                {/if}

                <button type="submit" class="h-10 px-4 py-2 bg-primary text-primary-foreground hover:bg-primary/90 rounded-md inline-flex items-center justify-center" disabled={loading}>
                    {#if loading}
                        <span class="loading loading-spinner loading-sm" />
                    {/if}
                    Initialize migajas
                </button>
            </form>
        </div>
    </div>
</div>
