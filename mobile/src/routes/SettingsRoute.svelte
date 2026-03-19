<script lang="ts">
    import { auth as authApi } from "$lib/api/client";
    import { authStore, currentUser } from "$lib/stores/auth";
    import { resolvedTheme, theme } from "$lib/stores/theme";
    import { getServerUrl, setServerUrl } from "$lib/serverConfig";
    import ServerSetup from "$lib/components/ServerSetup.svelte";

    // Vault
    let vaultType: "pin" | "password" = "pin";
    let oldCredential = "";
    let vaultCredential = "";
    let vaultConfirm = "";
    let vaultLoading = false;
    let vaultError = "";
    let vaultSuccess = "";

    // Server URL editing
    let editingServer = false;
    let serverUrl = "";
    getServerUrl().then((u) => {
        serverUrl = u ?? "";
    });

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
            const user = await authApi.me();
            authStore.setUser(user);
        } catch (e: unknown) {
            vaultError = e instanceof Error ? e.message : "Failed to save vault credential";
        } finally {
            vaultLoading = false;
        }
    }

    function handleServerConfigured(e: CustomEvent<string>) {
        serverUrl = e.detail;
        setServerUrl(e.detail);
        editingServer = false;
    }
</script>

{#if editingServer}
    <ServerSetup on:configured={handleServerConfigured} />
{:else}
    <div class="settings-screen">
        <header class="settings-header">
            <h1 class="settings-title">Settings</h1>
        </header>

        <div class="settings-body">
            <!-- Account -->
            <section class="card">
                <div class="card-header">
                    <h2 class="section-label">Account</h2>
                </div>
                <div class="account-row">
                    <div class="account-avatar">
                        {$currentUser?.username?.[0]?.toUpperCase() ?? "?"}
                    </div>
                    <div>
                        <p class="account-name">{$currentUser?.username}</p>
                        <p class="account-email">{$currentUser?.email}</p>
                    </div>
                </div>
            </section>

            <!-- Appearance -->
            <section class="card">
                <div class="card-header">
                    <h2 class="section-label">Appearance</h2>
                </div>
                <div class="card-body">
                    <div class="row-between">
                        <div>
                            <p class="row-title">Theme</p>
                            <p class="row-desc">Light, dark, or follow system</p>
                        </div>
                        <div class="theme-toggle">
                            <button class="theme-btn" class:active={$theme === "light"} on:click={() => theme.set("light")} type="button">
                                <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <circle cx="12" cy="12" r="5" /><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42" />
                                </svg>
                            </button>
                            <button class="theme-btn" class:active={$theme === "dark"} on:click={() => theme.set("dark")} type="button">
                                <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z" />
                                </svg>
                            </button>
                            <button class="theme-btn" class:active={$theme === "system"} on:click={() => theme.set("system")} type="button">
                                <svg xmlns="http://www.w3.org/2000/svg" class="w-4 h-4" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                    <rect x="3" y="4" width="18" height="12" rx="2" />
                                    <path d="M8 20h8M12 16v4" />
                                </svg>
                            </button>
                        </div>
                    </div>
                    {#if $theme === "system"}
                        <p class="hint-text">System mode active — current effective theme: <strong>{$resolvedTheme}</strong>.</p>
                    {/if}
                </div>
            </section>

            <!-- Secret notes vault -->
            <section class="card">
                <div class="card-header row-between">
                    <h2 class="section-label">Secret notes vault</h2>
                    {#if $currentUser?.has_vault}
                        <span class="badge badge-green">Configured</span>
                    {:else}
                        <span class="badge badge-yellow">Not set</span>
                    {/if}
                </div>
                <div class="card-body">
                    <p class="body-text">
                        Set a PIN or vault password to encrypt your secret notes. This is
                        <strong>separate</strong> from your login password.
                    </p>

                    {#if $currentUser?.has_vault}
                        <div class="info-banner info-green">
                            <svg xmlns="http://www.w3.org/2000/svg" class="info-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z" />
                            </svg>
                            <span>Changing your credential will automatically re-encrypt all secret notes. Enter your current credential to authorise.</span>
                        </div>
                    {:else}
                        <div class="info-banner info-blue">
                            <svg xmlns="http://www.w3.org/2000/svg" class="info-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                                <circle cx="12" cy="12" r="10" /><path d="M12 16v-4m0-4h.01" />
                            </svg>
                            <span>Set a PIN or vault password to encrypt your secret notes. Keep it safe — it derives the encryption key.</span>
                        </div>
                    {/if}

                    <!-- Credential type -->
                    <div class="cred-type-row">
                        <span class="row-label">Credential type</span>
                        <div class="segmented">
                            <button class="seg-btn" class:active={vaultType === "pin"} on:click={() => (vaultType = "pin")} type="button">Numeric PIN</button>
                            <button class="seg-btn" class:active={vaultType === "password"} on:click={() => (vaultType = "password")} type="button">Password</button>
                        </div>
                    </div>

                    {#if $currentUser?.has_vault}
                        <div class="field">
                            <label class="field-label" for="vault-old">
                                Current {vaultType === "pin" ? "PIN" : "vault password"}
                            </label>
                            <input id="vault-old" type="password" class="field-input" placeholder={vaultType === "pin" ? "••••" : "••••••••"} bind:value={oldCredential} autocomplete="current-password" inputmode={vaultType === "pin" ? "numeric" : "text"} />
                        </div>
                    {/if}

                    <div class="field">
                        <label class="field-label" for="vault-new">
                            {$currentUser?.has_vault ? (vaultType === "pin" ? "New PIN (4-8 digits)" : "New vault password") : vaultType === "pin" ? "PIN (4-8 digits)" : "Vault password"}
                        </label>
                        <input id="vault-new" type="password" class="field-input" placeholder={vaultType === "pin" ? "••••" : "••••••••"} bind:value={vaultCredential} autocomplete="off" inputmode={vaultType === "pin" ? "numeric" : "text"} />
                    </div>

                    <div class="field">
                        <label class="field-label" for="vault-confirm">
                            Confirm {$currentUser?.has_vault ? "new " : ""}{vaultType === "pin" ? "PIN" : "vault password"}
                        </label>
                        <input id="vault-confirm" type="password" class="field-input" placeholder={vaultType === "pin" ? "••••" : "••••••••"} bind:value={vaultConfirm} autocomplete="off" inputmode={vaultType === "pin" ? "numeric" : "text"} />
                    </div>

                    {#if vaultError}
                        <div class="alert alert-error">{vaultError}</div>
                    {/if}
                    {#if vaultSuccess}
                        <div class="alert alert-success">{vaultSuccess}</div>
                    {/if}

                    <button class="btn-primary" on:click={saveVault} disabled={vaultLoading || !vaultCredential || !vaultConfirm || ($currentUser?.has_vault && !oldCredential)} type="button">
                        {#if vaultLoading}
                            <span class="spinner" />
                        {/if}
                        {$currentUser?.has_vault ? "Update vault credential" : "Set vault credential"}
                    </button>
                </div>
            </section>

            <!-- Server -->
            <section class="card">
                <div class="card-header">
                    <h2 class="section-label">Server</h2>
                </div>
                <div class="card-body">
                    <div class="row-between">
                        <div class="server-url-text">
                            <p class="row-title">Server URL</p>
                            <p class="row-desc url-value">{serverUrl || "(not configured)"}</p>
                        </div>
                        <button class="btn-ghost-sm" on:click={() => (editingServer = true)} type="button">Change</button>
                    </div>
                </div>
            </section>
        </div>
    </div>
{/if}

<style>
    .settings-screen {
        min-height: 100dvh;
        background: var(--color-bg);
        display: flex;
        flex-direction: column;
        padding-bottom: calc(70px + env(safe-area-inset-bottom));
    }

    .settings-header {
        padding: 16px 16px 8px;
        border-bottom: 1px solid var(--color-border);
    }

    .settings-title {
        font-size: 22px;
        font-weight: 700;
        color: var(--color-text-primary);
        margin: 0;
    }

    .settings-body {
        display: flex;
        flex-direction: column;
        gap: 16px;
        padding: 16px;
    }

    .card {
        background: var(--color-surface);
        border-radius: 14px;
        border: 1px solid var(--color-border);
        overflow: hidden;
    }

    .card-header {
        padding: 12px 16px;
        border-bottom: 1px solid var(--color-border);
        display: flex;
        align-items: center;
        justify-content: space-between;
    }

    .section-label {
        font-size: 11px;
        font-weight: 700;
        letter-spacing: 0.06em;
        text-transform: uppercase;
        color: var(--color-text-muted);
        margin: 0;
    }

    .card-body {
        padding: 14px 16px;
        display: flex;
        flex-direction: column;
        gap: 12px;
    }

    .account-row {
        padding: 14px 16px;
        display: flex;
        align-items: center;
        gap: 12px;
    }

    .account-avatar {
        width: 40px;
        height: 40px;
        border-radius: 50%;
        background: rgba(var(--accent-rgb, 99, 102, 241), 0.2);
        border: 1.5px solid rgba(var(--accent-rgb, 99, 102, 241), 0.4);
        display: flex;
        align-items: center;
        justify-content: center;
        font-size: 16px;
        font-weight: 700;
        color: var(--color-accent);
        flex-shrink: 0;
    }

    .account-name {
        font-size: 15px;
        font-weight: 600;
        color: var(--color-text-primary);
        margin: 0;
    }

    .account-email {
        font-size: 13px;
        color: var(--color-text-muted);
        margin: 0;
    }

    .row-between {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 12px;
    }

    .row-title {
        font-size: 14px;
        font-weight: 500;
        color: var(--color-text-primary);
        margin: 0;
    }

    .row-desc {
        font-size: 12px;
        color: var(--color-text-muted);
        margin: 0;
        margin-top: 2px;
    }

    .theme-toggle {
        display: flex;
        border: 1.5px solid var(--color-border);
        border-radius: 8px;
        overflow: hidden;
        flex-shrink: 0;
    }

    .theme-btn {
        width: 38px;
        height: 34px;
        display: flex;
        align-items: center;
        justify-content: center;
        border: none;
        background: transparent;
        color: var(--color-text-muted);
        cursor: pointer;
        transition:
            background 0.15s,
            color 0.15s;
        -webkit-tap-highlight-color: transparent;
    }

    .theme-btn:not(:last-child) {
        border-right: 1.5px solid var(--color-border);
    }

    .theme-btn.active {
        background: var(--color-accent);
        color: #fff;
    }

    .hint-text {
        font-size: 12px;
        color: var(--color-text-muted);
        margin: 0;
    }

    .badge {
        font-size: 11px;
        padding: 2px 8px;
        border-radius: 100px;
        font-weight: 600;
    }

    .badge-green {
        background: rgba(34, 197, 94, 0.15);
        color: #16a34a;
        border: 1px solid rgba(34, 197, 94, 0.25);
    }

    .badge-yellow {
        background: rgba(234, 179, 8, 0.15);
        color: #a16207;
        border: 1px solid rgba(234, 179, 8, 0.25);
    }

    .body-text {
        font-size: 13px;
        color: var(--color-text-secondary);
        margin: 0;
        line-height: 1.5;
    }

    .info-banner {
        display: flex;
        gap: 10px;
        border-radius: 10px;
        padding: 10px 12px;
        font-size: 12px;
        line-height: 1.4;
    }

    .info-icon {
        width: 16px;
        height: 16px;
        flex-shrink: 0;
        margin-top: 1px;
    }

    .info-green {
        background: rgba(34, 197, 94, 0.1);
        border: 1px solid rgba(34, 197, 94, 0.25);
        color: #16a34a;
    }

    .info-blue {
        background: rgba(59, 130, 246, 0.1);
        border: 1px solid rgba(59, 130, 246, 0.25);
        color: #1d4ed8;
    }

    .cred-type-row {
        display: flex;
        align-items: center;
        justify-content: space-between;
        gap: 12px;
    }

    .row-label {
        font-size: 12px;
        font-weight: 600;
        color: var(--color-text-muted);
        flex-shrink: 0;
    }

    .segmented {
        display: flex;
        border: 1.5px solid var(--color-border);
        border-radius: 8px;
        overflow: hidden;
    }

    .seg-btn {
        height: 30px;
        padding: 0 12px;
        font-size: 12px;
        border: none;
        background: transparent;
        color: var(--color-text-secondary);
        cursor: pointer;
        transition:
            background 0.15s,
            color 0.15s;
        -webkit-tap-highlight-color: transparent;
    }

    .seg-btn:not(:last-child) {
        border-right: 1.5px solid var(--color-border);
    }

    .seg-btn.active {
        background: var(--color-accent);
        color: #fff;
    }

    .field {
        display: flex;
        flex-direction: column;
        gap: 5px;
    }

    .field-label {
        font-size: 12px;
        font-weight: 600;
        color: var(--color-text-muted);
    }

    .field-input {
        width: 100%;
        height: 44px;
        padding: 0 14px;
        border-radius: 10px;
        border: 1.5px solid var(--color-border);
        background: var(--color-bg);
        color: var(--color-text-primary);
        font-size: 16px;
        outline: none;
        box-sizing: border-box;
        transition: border-color 0.15s;
    }

    .field-input:focus {
        border-color: var(--color-accent);
    }

    .alert {
        font-size: 13px;
        padding: 10px 12px;
        border-radius: 8px;
        line-height: 1.4;
    }

    .alert-error {
        background: rgba(239, 68, 68, 0.1);
        border: 1px solid rgba(239, 68, 68, 0.3);
        color: #dc2626;
    }

    .alert-success {
        background: rgba(34, 197, 94, 0.1);
        border: 1px solid rgba(34, 197, 94, 0.3);
        color: #16a34a;
    }

    .btn-primary {
        display: flex;
        align-items: center;
        justify-content: center;
        gap: 8px;
        height: 46px;
        border-radius: 12px;
        border: none;
        background: var(--color-accent);
        color: #fff;
        font-size: 15px;
        font-weight: 600;
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
        transition: opacity 0.15s;
        align-self: flex-start;
        padding: 0 20px;
    }

    .btn-primary:disabled {
        opacity: 0.45;
        cursor: not-allowed;
    }

    .spinner {
        display: inline-block;
        width: 16px;
        height: 16px;
        border: 2px solid currentColor;
        border-right-color: transparent;
        border-radius: 50%;
        animation: spin 0.6s linear infinite;
    }

    @keyframes spin {
        to {
            transform: rotate(360deg);
        }
    }

    .server-url-text {
        min-width: 0;
        flex: 1;
    }

    .url-value {
        word-break: break-all;
    }

    .btn-ghost-sm {
        height: 32px;
        padding: 0 12px;
        border-radius: 8px;
        border: 1.5px solid var(--color-border);
        background: transparent;
        color: var(--color-text-primary);
        font-size: 13px;
        font-weight: 500;
        cursor: pointer;
        flex-shrink: 0;
        -webkit-tap-highlight-color: transparent;
    }
</style>
