<script lang="ts">
    import { push } from "svelte-spa-router";
    import { authStore } from "$lib/stores/auth";
    import { allowSelfRegistration } from "$lib/stores/appState";
    import { clearServerUrl } from "$lib/serverConfig";

    let usernameOrEmail = "";
    let password = "";
    let showPassword = false;
    let loading = false;
    let error = "";

    async function submit() {
        error = "";
        loading = true;
        try {
            await authStore.login(usernameOrEmail, password);
            push("/");
        } catch (e: unknown) {
            error = e instanceof Error ? e.message : "Login failed";
        } finally {
            loading = false;
        }
    }
</script>

<div class="auth-screen">
    <button
        class="back-btn"
        on:click={async () => {
            await clearServerUrl();
            window.location.reload();
        }}
        aria-label="Change server"
    >
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" stroke-linecap="round" stroke-linejoin="round"><path d="M19 12H5" /><polyline points="12 19 5 12 12 5" /></svg>
        Server
    </button>
    <div class="auth-card">
        <div class="auth-logo">🍞</div>
        <h1 class="auth-title">Migajas</h1>
        <p class="auth-subtitle">Sign in to your account</p>

        <form on:submit|preventDefault={submit} class="auth-form">
            <div class="field">
                <label for="login-user" class="field-label">Username or email</label>
                <input id="login-user" type="text" class="field-input" placeholder="username or email" bind:value={usernameOrEmail} autocomplete="username" autocapitalize="none" autocorrect="off" spellcheck="false" required />
            </div>
            <div class="field">
                <label for="login-pass" class="field-label">Password</label>
                <div class="password-wrap">
                    {#if showPassword}
                        <input id="login-pass" type="text" class="field-input password-input" placeholder="••••••••" bind:value={password} autocomplete="current-password" required />
                    {:else}
                        <input id="login-pass" type="password" class="field-input password-input" placeholder="••••••••" bind:value={password} autocomplete="current-password" required />
                    {/if}
                    <button type="button" class="show-btn" on:click={() => (showPassword = !showPassword)} tabindex="-1" aria-label={showPassword ? "Hide password" : "Show password"}>
                        {#if showPassword}
                            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94" /><path d="M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19" /><line x1="1" y1="1" x2="23" y2="23" /></svg>
                        {:else}
                            <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z" /><circle cx="12" cy="12" r="3" /></svg>
                        {/if}
                    </button>
                </div>
            </div>

            {#if error}
                <p class="error-msg">⚠ {error}</p>
            {/if}

            <button type="submit" class="btn-primary" disabled={loading}>
                {loading ? "Signing in…" : "Sign in"}
            </button>
        </form>

        {#if $allowSelfRegistration}
            <p class="auth-footer-text">
                No account?
                <!-- svelte-ignore a11y-invalid-attribute -->
                <a href="javascript:void(0)" on:click={() => push("/register")} class="auth-link">Create one</a>
            </p>
        {/if}
    </div>
</div>

<style>
    .auth-screen {
        min-height: 100dvh;
        display: flex;
        align-items: center;
        justify-content: center;
        padding: 24px 20px;
        background: var(--color-bg);
        position: relative;
    }

    .back-btn {
        position: absolute;
        top: 16px;
        left: 16px;
        display: flex;
        align-items: center;
        gap: 5px;
        background: none;
        border: none;
        color: var(--color-text-muted);
        font-size: 14px;
        font-weight: 500;
        cursor: pointer;
        padding: 8px;
        border-radius: 8px;
        -webkit-tap-highlight-color: transparent;
    }

    .back-btn:hover {
        color: var(--color-text-primary);
        background: var(--color-muted);
    }

    .auth-card {
        width: 100%;
        max-width: 400px;
        display: flex;
        flex-direction: column;
        gap: 14px;
    }

    .auth-logo {
        font-size: 52px;
        text-align: center;
    }

    .auth-title {
        font-size: 26px;
        font-weight: 700;
        text-align: center;
        color: var(--color-text-primary);
        margin: 0;
    }

    .auth-subtitle {
        font-size: 14px;
        text-align: center;
        color: var(--color-text-muted);
        margin: 0;
    }

    .auth-form {
        display: flex;
        flex-direction: column;
        gap: 12px;
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

    .password-wrap {
        position: relative;
        display: flex;
        align-items: center;
    }

    .password-input {
        padding-right: 46px;
    }

    .show-btn {
        position: absolute;
        right: 0;
        top: 0;
        height: 46px;
        width: 46px;
        display: flex;
        align-items: center;
        justify-content: center;
        background: none;
        border: none;
        cursor: pointer;
        color: var(--color-text-muted);
        -webkit-tap-highlight-color: transparent;
        padding: 0;
    }

    .show-btn:hover {
        color: var(--color-text-primary);
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
        margin-top: 4px;
    }

    .btn-primary:disabled {
        opacity: 0.5;
    }

    .auth-footer-text {
        text-align: center;
        font-size: 14px;
        color: var(--color-text-muted);
        margin: 0;
    }

    .auth-link {
        color: var(--color-accent);
        font-weight: 600;
        text-decoration: none;
    }
</style>
