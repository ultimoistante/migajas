<script lang="ts">
    import { push } from "svelte-spa-router";
    import { auth as authApi } from "$lib/api/client";

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
            await authApi.register({ username, email, password });
            success = true;
            setTimeout(() => push("/login"), 1500);
        } catch (e: unknown) {
            error = e instanceof Error ? e.message : "Registration failed";
        } finally {
            loading = false;
        }
    }
</script>

<div class="auth-screen">
    <div class="auth-card">
        <div class="auth-logo">🍞</div>
        <h1 class="auth-title">Create account</h1>
        <p class="auth-subtitle">Join Migajas</p>

        {#if success}
            <div class="success-banner">Account created! Redirecting to sign in…</div>
        {:else}
            <form on:submit|preventDefault={submit} class="auth-form">
                <div class="field">
                    <label for="reg-username" class="field-label">Username</label>
                    <input id="reg-username" type="text" class="field-input" placeholder="username" bind:value={username} autocomplete="username" autocapitalize="none" required />
                </div>
                <div class="field">
                    <label for="reg-email" class="field-label">Email</label>
                    <input id="reg-email" type="email" class="field-input" placeholder="you@example.com" bind:value={email} autocomplete="email" required />
                </div>
                <div class="field">
                    <label for="reg-pass" class="field-label">Password</label>
                    <input id="reg-pass" type="password" class="field-input" placeholder="••••••••" bind:value={password} autocomplete="new-password" required />
                </div>
                <div class="field">
                    <label for="reg-confirm" class="field-label">Confirm password</label>
                    <input id="reg-confirm" type="password" class="field-input" placeholder="••••••••" bind:value={confirmPassword} autocomplete="new-password" required />
                </div>

                {#if error}
                    <p class="error-msg">{error}</p>
                {/if}

                <button type="submit" class="btn-primary" disabled={loading}>
                    {loading ? "Creating account…" : "Create account"}
                </button>
            </form>
        {/if}

        <p class="auth-footer-text">
            Already have an account?
            <!-- svelte-ignore a11y-invalid-attribute -->
            <a href="javascript:void(0)" on:click={() => push("/login")} class="auth-link">Sign in</a>
        </p>
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

    .success-banner {
        background: rgba(34, 197, 94, 0.15);
        color: #16a34a;
        border-radius: 10px;
        padding: 16px;
        text-align: center;
        font-size: 15px;
        font-weight: 600;
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
