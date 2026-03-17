<script lang="ts">
    import { auth as authApi } from "$lib/api/client";
    import { authStore, currentUser } from "$lib/stores/auth";
    import { resolvedTheme, theme } from "$lib/stores/theme";

    // Vault setup state
    let vaultType: "pin" | "password" = "pin";
    let oldCredential = "";
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
        if ($currentUser?.has_vault && !oldCredential) {
            vaultError = "Current credential is required to update the vault";
            return;
        }
        vaultLoading = true;
        try {
            if ($currentUser?.has_vault) {
                await authApi.rotateVault(vaultType, oldCredential, vaultCredential);
                vaultSuccess = "Vault credential updated. All secret notes have been re-encrypted.";
            } else {
                await authApi.setupVault(vaultType, vaultCredential);
                vaultSuccess = "Vault credential saved successfully!";
            }
            oldCredential = "";
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

<div class="min-h-screen dashboard-shell">
    <!-- Header -->
    <nav class="glass-nav flex items-center h-14 border-b border-border px-4 gap-3">
        <a href="/" class="h-9 px-3 rounded-md hover:bg-muted text-sm inline-flex items-center justify-center gap-1">
            <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <path d="m15 18-6-6 6-6" />
            </svg>
            Back
        </a>
        <span class="font-semibold text-base">Settings</span>
    </nav>

    <main class="max-w-xl mx-auto px-4 py-8 flex flex-col gap-5">
        <!-- Account info -->
        <section class="glass-panel rounded-xl overflow-hidden">
            <div class="px-4 py-3 border-b border-border">
                <h2 class="text-sm font-semibold text-muted-foreground uppercase tracking-wide">Account</h2>
            </div>
            <div class="px-4 py-4 flex items-center gap-3">
                <div class="h-10 w-10 rounded-full bg-primary/20 border border-primary/40 flex items-center justify-center text-primary font-bold text-sm shrink-0">
                    {$currentUser?.username?.[0]?.toUpperCase() ?? "?"}
                </div>
                <div>
                    <p class="font-semibold text-sm">{$currentUser?.username}</p>
                    <p class="text-xs text-muted-foreground">{$currentUser?.email}</p>
                </div>
            </div>
        </section>

        <!-- Theme -->
        <section class="glass-panel rounded-xl overflow-hidden">
            <div class="px-4 py-3 border-b border-border">
                <h2 class="text-sm font-semibold text-muted-foreground uppercase tracking-wide">Appearance</h2>
            </div>
            <div class="px-4 py-4 flex flex-col gap-3">
                <div class="flex items-center justify-between gap-4">
                    <div>
                        <p class="text-sm font-medium">Theme</p>
                        <p class="text-xs text-muted-foreground">Choose light, dark, or follow your system preference</p>
                    </div>
                    <div class="flex items-center rounded-lg border border-border overflow-hidden shrink-0">
                        <button class="h-8 px-3 text-xs inline-flex items-center gap-1.5 border-r border-border transition-colors" class:bg-primary={$theme === "light"} class:text-primary-foreground={$theme === "light"} class:hover:bg-muted={$theme !== "light"} on:click={() => theme.set("light")} type="button">
                            <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <circle cx="12" cy="12" r="5" /><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42" />
                            </svg>
                            Light
                        </button>
                        <button class="h-8 px-3 text-xs inline-flex items-center gap-1.5 border-r border-border transition-colors" class:bg-primary={$theme === "dark"} class:text-primary-foreground={$theme === "dark"} class:hover:bg-muted={$theme !== "dark"} on:click={() => theme.set("dark")} type="button">
                            <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
                            </svg>
                            Dark
                        </button>
                        <button class="h-8 px-3 text-xs inline-flex items-center gap-1.5 transition-colors" class:bg-primary={$theme === "system"} class:text-primary-foreground={$theme === "system"} class:hover:bg-muted={$theme !== "system"} on:click={() => theme.set("system")} type="button">
                            <svg xmlns="http://www.w3.org/2000/svg" class="w-3.5 h-3.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <rect x="3" y="4" width="18" height="12" rx="2" />
                                <path d="M8 20h8M12 16v4" />
                            </svg>
                            System
                        </button>
                    </div>
                </div>
                {#if $theme === "system"}
                    <p class="text-xs text-muted-foreground">System mode active — current effective theme: <strong>{$resolvedTheme}</strong>.</p>
                {/if}
            </div>
        </section>

        <!-- Vault / Secret notes -->
        <section class="glass-panel rounded-xl overflow-hidden">
            <div class="px-4 py-3 border-b border-border flex items-center justify-between gap-2">
                <h2 class="text-sm font-semibold text-muted-foreground uppercase tracking-wide">Secret notes vault</h2>
                {#if $currentUser?.has_vault}
                    <span class="text-xs px-2 py-0.5 rounded-full bg-green-500/15 text-green-600 dark:text-green-400 border border-green-500/25">Configured</span>
                {:else}
                    <span class="text-xs px-2 py-0.5 rounded-full bg-yellow-500/15 text-yellow-700 dark:text-yellow-400 border border-yellow-500/25">Not set</span>
                {/if}
            </div>
            <div class="px-4 py-4 flex flex-col gap-4">
                <p class="text-sm text-muted-foreground">
                    Set a PIN or vault password to encrypt your secret notes. This is <strong class="text-foreground">separate</strong> from your login password.
                </p>

                <!-- Info banner -->
                {#if $currentUser?.has_vault}
                    <div class="flex gap-2.5 rounded-lg bg-green-500/10 border border-green-500/25 px-3 py-2.5 text-xs text-green-700 dark:text-green-400">
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 shrink-0 mt-0.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                        </svg>
                        <span>Changing your credential will automatically re-encrypt all your secret notes with the new key. Enter your current credential to authorise this operation.</span>
                    </div>
                {:else}
                    <div class="flex gap-2.5 rounded-lg bg-blue-500/10 border border-blue-400/25 px-3 py-2.5 text-xs text-blue-700 dark:text-blue-300">
                        <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4 shrink-0 mt-0.5" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                            <circle cx="12" cy="12" r="10" /><path d="M12 16v-4m0-4h.01" />
                        </svg>
                        <span>Set a PIN or vault password to encrypt your secret notes. This credential is used to derive the encryption key — keep it safe.</span>
                    </div>
                {/if}

                <!-- Credential type toggle -->
                <div class="flex items-center gap-3">
                    <span class="text-xs font-medium text-muted-foreground shrink-0">Credential type</span>
                    <div class="flex items-center rounded-lg border border-border overflow-hidden">
                        <button class="h-7 px-3 text-xs transition-colors border-r border-border" class:bg-primary={vaultType === "pin"} class:text-primary-foreground={vaultType === "pin"} class:hover:bg-muted={vaultType !== "pin"} on:click={() => (vaultType = "pin")} type="button">Numeric PIN</button>
                        <button class="h-7 px-3 text-xs transition-colors" class:bg-primary={vaultType === "password"} class:text-primary-foreground={vaultType === "password"} class:hover:bg-muted={vaultType !== "password"} on:click={() => (vaultType = "password")} type="button">Password</button>
                    </div>
                </div>

                <!-- Current credential (only when updating) -->
                {#if $currentUser?.has_vault}
                    <div class="flex flex-col gap-1.5">
                        <label class="text-xs font-medium text-muted-foreground" for="vault-old-cred">
                            Current {vaultType === "pin" ? "PIN" : "vault password"}
                        </label>
                        <input id="vault-old-cred" type="password" placeholder={vaultType === "pin" ? "••••" : "••••••••"} class="h-10 w-full rounded-md border border-border bg-card px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/35" bind:value={oldCredential} autocomplete="current-password" inputmode={vaultType === "pin" ? "numeric" : "text"} />
                    </div>
                {/if}

                <!-- New PIN / password input -->
                <div class="flex flex-col gap-1.5">
                    <label class="text-xs font-medium text-muted-foreground" for="vault-cred">
                        {$currentUser?.has_vault ? (vaultType === "pin" ? "New PIN (4-8 digits)" : "New vault password") : vaultType === "pin" ? "PIN (4-8 digits)" : "Vault password"}
                    </label>
                    <input id="vault-cred" type="password" placeholder={vaultType === "pin" ? "••••" : "••••••••"} class="h-10 w-full rounded-md border border-border bg-card px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/35" bind:value={vaultCredential} autocomplete="off" inputmode={vaultType === "pin" ? "numeric" : "text"} />
                </div>

                <!-- Confirm input -->
                <div class="flex flex-col gap-1.5">
                    <label class="text-xs font-medium text-muted-foreground" for="vault-confirm">
                        Confirm {$currentUser?.has_vault ? "new " : ""}{vaultType === "pin" ? "PIN" : "vault password"}
                    </label>
                    <input id="vault-confirm" type="password" placeholder={vaultType === "pin" ? "••••" : "••••••••"} class="h-10 w-full rounded-md border border-border bg-card px-3 py-2 text-sm text-foreground placeholder:text-muted-foreground focus:outline-none focus:ring-2 focus:ring-primary/35" bind:value={vaultConfirm} autocomplete="off" inputmode={vaultType === "pin" ? "numeric" : "text"} />
                </div>

                {#if vaultError}
                    <div class="rounded-md bg-destructive/10 border border-destructive/30 text-destructive px-3 py-2 text-sm">{vaultError}</div>
                {/if}
                {#if vaultSuccess}
                    <div class="rounded-md bg-green-500/10 border border-green-500/30 text-green-700 dark:text-green-400 px-3 py-2 text-sm">{vaultSuccess}</div>
                {/if}

                <button class="h-10 px-4 bg-primary text-primary-foreground hover:bg-primary/90 rounded-md inline-flex items-center justify-center text-sm font-medium disabled:opacity-50 transition-colors self-start" on:click={saveVault} disabled={vaultLoading || !vaultCredential || !vaultConfirm || ($currentUser?.has_vault && !oldCredential)} type="button">
                    {#if vaultLoading}
                        <span class="mr-2 h-4 w-4 animate-spin rounded-full border-2 border-current border-r-transparent" />
                    {/if}
                    {$currentUser?.has_vault ? "Update vault credential" : "Set vault credential"}
                </button>
            </div>
        </section>
    </main>
</div>
