<script lang="ts">
    import { auth as authApi } from "$lib/api/client";
    import { authStore, currentUser } from "$lib/stores/auth";
    import { theme } from "$lib/stores/theme";

    // Vault setup state
    let vaultType: "pin" | "password" = "pin";
    let vaultCredential = "";
    let vaultConfirm = "";
    let vaultLoading = false;
    let vaultError = "";
    let vaultSuccess = "";

    async function saveVault() {
        vaultError = "";
        vaultSuccess = "";
        if (vaultCredential !== vaultConfirm) {
            vaultError = "Credentials do not match";
            return;
        }
        if (vaultType === "pin") {
            if (!/^\d{4,8}$/.test(vaultCredential)) {
                vaultError = "PIN must be 4-8 digits";
                return;
            }
        } else if (vaultCredential.length < 6) {
            vaultError = "Vault password must be at least 6 characters";
            return;
        }
        vaultLoading = true;
        try {
            await authApi.setupVault(vaultType, vaultCredential);
            vaultSuccess = "Vault credential saved successfully!";
            vaultCredential = "";
            vaultConfirm = "";
            // Refresh user info to reflect has_vault
            const user = await authApi.me();
            authStore.setUser(user);
        } catch (e: unknown) {
            vaultError = e instanceof Error ? e.message : "Failed to save vault credential";
        } finally {
            vaultLoading = false;
        }
    }
</script>

<svelte:head>
    <title>Settings — migajas</title>
</svelte:head>

<div class="min-h-screen bg-base-200">
    <!-- Header -->
    <nav class="navbar bg-base-100 border-b border-base-300 px-4">
        <div class="flex-none">
            <a href="/" class="btn btn-ghost btn-sm gap-1">
                <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                    <path d="m15 18-6-6 6-6" />
                </svg>
                Back
            </a>
        </div>
        <div class="flex-1 px-2 font-semibold">Settings</div>
    </nav>

    <main class="max-w-xl mx-auto px-4 py-8 flex flex-col gap-6">
        <!-- Account info -->
        <div class="card bg-base-100 shadow">
            <div class="card-body gap-3">
                <h2 class="card-title text-base">Account</h2>
                <div class="flex items-center gap-3">
                    <div class="avatar placeholder">
                        <div class="bg-primary text-primary-content rounded-full w-10">
                            <span class="font-bold">{$currentUser?.username?.[0]?.toUpperCase() ?? "?"}</span>
                        </div>
                    </div>
                    <div>
                        <p class="font-semibold">{$currentUser?.username}</p>
                        <p class="text-sm text-base-content/60">{$currentUser?.email}</p>
                    </div>
                </div>
            </div>
        </div>

        <!-- Theme -->
        <div class="card bg-base-100 shadow">
            <div class="card-body gap-3">
                <h2 class="card-title text-base">Appearance</h2>
                <div class="flex items-center justify-between">
                    <div>
                        <p class="font-medium">Theme</p>
                        <p class="text-sm text-base-content/60">Choose between light and dark mode</p>
                    </div>
                    <div class="join">
                        <button class="join-item btn btn-sm" class:btn-primary={$theme === "light"} on:click={() => theme.set("light")} type="button">
                            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <circle cx="12" cy="12" r="5" /><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42" />
                            </svg>
                            Light
                        </button>
                        <button class="join-item btn btn-sm" class:btn-primary={$theme === "dark"} on:click={() => theme.set("dark")} type="button">
                            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
                            </svg>
                            Dark
                        </button>
                    </div>
                </div>
            </div>
        </div>

        <!-- Vault / Secret notes -->
        <div class="card bg-base-100 shadow">
            <div class="card-body gap-4">
                <div>
                    <h2 class="card-title text-base">Secret notes vault</h2>
                    <p class="text-sm text-base-content/60 mt-0.5">
                        Set a PIN or vault password to encrypt your secret notes. This is <strong>separate</strong> from your login password.
                        {#if $currentUser?.has_vault}
                            <span class="badge badge-success badge-sm ml-1">Configured</span>
                        {:else}
                            <span class="badge badge-warning badge-sm ml-1">Not set</span>
                        {/if}
                    </p>
                </div>

                <div class="alert alert-info text-sm">
                    <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 shrink-0" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                        <circle cx="12" cy="12" r="10" /><path d="M12 16v-4m0-4h.01" />
                    </svg>
                    <span>
                        Your vault credential is used to encrypt and decrypt secret notes. If you change it, existing secret notes <strong>cannot</strong> be decrypted with the old credential.
                    </span>
                </div>

                <!-- Type toggle -->
                <div class="flex items-center gap-3">
                    <span class="text-sm font-medium">Credential type:</span>
                    <div class="join">
                        <button class="join-item btn btn-sm" class:btn-primary={vaultType === "pin"} on:click={() => (vaultType = "pin")} type="button">Numeric PIN</button>
                        <button class="join-item btn btn-sm" class:btn-primary={vaultType === "password"} on:click={() => (vaultType = "password")} type="button">Password</button>
                    </div>
                </div>

                <label class="form-control">
                    <div class="label py-1">
                        <span class="label-text">{vaultType === "pin" ? "PIN (4-8 digits)" : "Vault password"}</span>
                    </div>
                    <input type="password" placeholder={vaultType === "pin" ? "••••" : "••••••••"} class="input input-bordered" bind:value={vaultCredential} autocomplete="off" inputmode={vaultType === "pin" ? "numeric" : "text"} />
                </label>

                <label class="form-control">
                    <div class="label py-1">
                        <span class="label-text">Confirm {vaultType === "pin" ? "PIN" : "vault password"}</span>
                    </div>
                    <input type="password" placeholder={vaultType === "pin" ? "••••" : "••••••••"} class="input input-bordered" bind:value={vaultConfirm} autocomplete="off" inputmode={vaultType === "pin" ? "numeric" : "text"} />
                </label>

                {#if vaultError}
                    <div class="alert alert-error text-sm py-2">{vaultError}</div>
                {/if}
                {#if vaultSuccess}
                    <div class="alert alert-success text-sm py-2">{vaultSuccess}</div>
                {/if}

                <button class="btn btn-primary" on:click={saveVault} disabled={vaultLoading || !vaultCredential || !vaultConfirm} type="button">
                    {#if vaultLoading}<span class="loading loading-spinner loading-sm" />{/if}
                    {$currentUser?.has_vault ? "Update vault credential" : "Set vault credential"}
                </button>
            </div>
        </div>
    </main>
</div>
