<script lang="ts">
    import { push } from "svelte-spa-router";
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
            appInitialized.set(true);
            await authStore.login(username.trim(), password);
            push("/");
        } catch (e: unknown) {
            error = e instanceof ApiError ? e.message : "Initialization failed. Please try again.";
        } finally {
            loading = false;
        }
    }
</script>

<div class="setup-screen">
    <div class="setup-card">
        <div class="setup-header">
            <div class="setup-logo">🍞</div>
            <h1 class="setup-title">migajas</h1>
            <h2 class="setup-subtitle">First-time Setup</h2>
            <p class="setup-description">Create the administrator account to get started.</p>
        </div>

        <form on:submit|preventDefault={initialize} class="setup-form">
            <div class="field">
                <label for="s-username" class="field-label">Username</label>
                <input id="s-username" type="text" class="field-input" placeholder="admin" bind:value={username} autocomplete="username" autocapitalize="none" required />
            </div>

            <div class="field">
                <label for="s-email" class="field-label">Email</label>
                <input id="s-email" type="email" class="field-input" placeholder="admin@example.com" bind:value={email} autocomplete="email" required />
            </div>

            <div class="field">
                <label for="s-pass" class="field-label">Password</label>
                <input id="s-pass" type="password" class="field-input" placeholder="At least 8 characters" bind:value={password} autocomplete="new-password" required />
            </div>

            <div class="field">
                <label for="s-confirm" class="field-label">Confirm password</label>
                <input id="s-confirm" type="password" class="field-input" placeholder="Repeat password" bind:value={confirmPassword} autocomplete="new-password" required />
            </div>

            <div class="toggle-row">
                <label class="toggle-label" for="s-selfreg">
                    <input id="s-selfreg" type="checkbox" class="toggle-checkbox" bind:checked={allowSelfReg} />
                    <span class="toggle-text">Allow users to self-register</span>
                </label>
                <p class="toggle-hint">If enabled, anyone can create an account. If disabled, only the admin can manage users.</p>
            </div>

            {#if error}
                <p class="error-msg">{error}</p>
            {/if}

            <button type="submit" class="btn-primary" disabled={loading}>
                {loading ? "Setting up…" : "Initialize migajas"}
            </button>
        </form>
    </div>
</div>

<style>
    .setup-screen {
        min-height: 100dvh;
        display: flex;
        align-items: flex-start;
        justify-content: center;
        padding: 32px 20px 40px;
        background: var(--color-bg);
        overflow-y: auto;
    }

    .setup-card {
        width: 100%;
        max-width: 420px;
        display: flex;
        flex-direction: column;
        gap: 20px;
    }

    .setup-header {
        display: flex;
        flex-direction: column;
        align-items: center;
        gap: 6px;
    }

    .setup-logo {
        font-size: 52px;
    }

    .setup-title {
        font-size: 26px;
        font-weight: 700;
        color: var(--color-text-primary);
        margin: 0;
    }

    .setup-subtitle {
        font-size: 18px;
        font-weight: 600;
        color: var(--color-text-primary);
        margin: 0;
    }

    .setup-description {
        font-size: 14px;
        color: var(--color-text-muted);
        text-align: center;
        margin: 0;
    }

    .setup-form {
        display: flex;
        flex-direction: column;
        gap: 14px;
    }

    .field {
        display: flex;
        flex-direction: column;
        gap: 5px;
    }

    .field-label {
        font-size: 13px;
        font-weight: 600;
        color: var(--color-text-secondary);
    }

    .field-input {
        width: 100%;
        height: 46px;
        padding: 0 14px;
        border-radius: 10px;
        border: 1.5px solid var(--color-border);
        background: var(--color-surface);
        color: var(--color-text-primary);
        font-size: 16px;
        outline: none;
        box-sizing: border-box;
        transition: border-color 0.15s;
    }

    .field-input:focus {
        border-color: var(--color-accent);
    }

    .toggle-row {
        display: flex;
        flex-direction: column;
        gap: 6px;
        padding: 12px;
        background: var(--color-surface);
        border-radius: 10px;
        border: 1.5px solid var(--color-border);
    }

    .toggle-label {
        display: flex;
        align-items: center;
        gap: 10px;
        cursor: pointer;
    }

    .toggle-checkbox {
        width: 18px;
        height: 18px;
        accent-color: var(--color-accent);
        cursor: pointer;
        flex-shrink: 0;
    }

    .toggle-text {
        font-size: 14px;
        font-weight: 500;
        color: var(--color-text-primary);
    }

    .toggle-hint {
        font-size: 12px;
        color: var(--color-text-muted);
        margin: 0;
        line-height: 1.4;
    }

    .error-msg {
        font-size: 13px;
        color: #dc2626;
        background: rgba(239, 68, 68, 0.1);
        padding: 10px 14px;
        border-radius: 8px;
        margin: 0;
    }

    .btn-primary {
        width: 100%;
        height: 48px;
        border-radius: 12px;
        border: none;
        background: var(--color-accent);
        color: #fff;
        font-size: 16px;
        font-weight: 600;
        cursor: pointer;
        -webkit-tap-highlight-color: transparent;
        transition: opacity 0.15s;
    }

    .btn-primary:disabled {
        opacity: 0.5;
    }
</style>
