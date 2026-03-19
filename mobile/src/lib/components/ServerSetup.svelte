<script lang="ts">
    import { createEventDispatcher } from "svelte";
    import { setServerUrl } from "$lib/serverConfig";

    const dispatch = createEventDispatcher<{ configured: void }>();

    let url = "";
    let testing = false;
    let testResult: "ok" | "error" | null = null;
    let testMessage = "";
    let saving = false;
    let error = "";

    function normalizeUrl(raw: string): string {
        let u = raw.trim().replace(/\/+$/, "");
        if (!u.startsWith("http://") && !u.startsWith("https://")) {
            u = "http://" + u;
        }
        return u;
    }

    async function testConnection() {
        error = "";
        testResult = null;
        const base = normalizeUrl(url);
        if (!base) {
            error = "Please enter a server URL.";
            return;
        }
        testing = true;
        try {
            const res = await fetch(base + "/api/setup/status", { signal: AbortSignal.timeout(5000) });
            if (res.ok || res.status === 400) {
                testResult = "ok";
                testMessage = "Connected successfully!";
            } else {
                testResult = "error";
                testMessage = `Server responded with status ${res.status}`;
            }
        } catch (e) {
            testResult = "error";
            testMessage = "Could not reach the server. Check the URL and try again.";
        } finally {
            testing = false;
        }
    }

    async function save() {
        const base = normalizeUrl(url);
        if (!base) {
            error = "Please enter a server URL.";
            return;
        }
        saving = true;
        await setServerUrl(base);
        saving = false;
        dispatch("configured");
    }
</script>

<div class="setup-screen">
    <div class="setup-card">
        <div class="setup-icon">🍞</div>
        <h1 class="setup-title">Welcome to Migajas</h1>
        <p class="setup-subtitle">Enter the URL of your self-hosted Migajas server to get started.</p>

        <div class="field">
            <label for="server-url" class="field-label">Server URL</label>
            <input id="server-url" type="url" class="field-input" placeholder="https://your-server.example.com" bind:value={url} autocapitalize="none" autocorrect="off" spellcheck="false" inputmode="url" on:keydown={(e) => e.key === "Enter" && testConnection()} />
        </div>

        {#if error}
            <p class="msg msg-error">{error}</p>
        {/if}

        {#if testResult === "ok"}
            <p class="msg msg-ok">✓ {testMessage}</p>
        {:else if testResult === "error"}
            <p class="msg msg-error">✗ {testMessage}</p>
        {/if}

        <div class="actions">
            <button class="btn btn-secondary" on:click={testConnection} disabled={testing || !url.trim()}>
                {testing ? "Testing…" : "Test Connection"}
            </button>
            {#if testResult === "ok"}
                <button class="btn btn-primary" on:click={save} disabled={saving}>
                    {saving ? "Connecting…" : "Connect →"}
                </button>
            {/if}
        </div>
    </div>
</div>

<style>
    .setup-screen {
        display: flex;
        align-items: center;
        justify-content: center;
        min-height: 100dvh;
        padding: 24px 20px;
        background: var(--color-bg);
    }

    .setup-card {
        width: 100%;
        max-width: 420px;
        display: flex;
        flex-direction: column;
        gap: 16px;
    }

    .setup-icon {
        font-size: 56px;
        text-align: center;
    }

    .setup-title {
        font-size: 26px;
        font-weight: 700;
        text-align: center;
        color: var(--color-text-primary);
        margin: 0;
    }

    .setup-subtitle {
        font-size: 15px;
        text-align: center;
        color: var(--color-text-muted);
        margin: 0;
    }

    .field {
        display: flex;
        flex-direction: column;
        gap: 6px;
    }

    .field-label {
        font-size: 13px;
        font-weight: 600;
        color: var(--color-text-secondary);
        text-transform: uppercase;
        letter-spacing: 0.05em;
    }

    .field-input {
        width: 100%;
        padding: 12px 14px;
        border-radius: 10px;
        border: 1.5px solid var(--color-border);
        background: var(--color-surface);
        color: var(--color-text-primary);
        font-size: 16px;
        outline: none;
        transition: border-color 0.15s;
        box-sizing: border-box;
    }

    .field-input:focus {
        border-color: var(--color-accent);
    }

    .msg {
        font-size: 14px;
        padding: 10px 14px;
        border-radius: 8px;
        margin: 0;
    }

    .msg-ok {
        background: rgba(34, 197, 94, 0.15);
        color: #16a34a;
    }

    .msg-error {
        background: rgba(239, 68, 68, 0.15);
        color: #dc2626;
    }

    .actions {
        display: flex;
        flex-direction: column;
        gap: 10px;
        margin-top: 4px;
    }

    .btn {
        width: 100%;
        padding: 13px 16px;
        border-radius: 10px;
        border: none;
        font-size: 15px;
        font-weight: 600;
        cursor: pointer;
        transition: opacity 0.15s;
        -webkit-tap-highlight-color: transparent;
    }

    .btn:disabled {
        opacity: 0.5;
        cursor: default;
    }

    .btn-primary {
        background: var(--color-accent);
        color: #fff;
    }

    .btn-secondary {
        background: var(--color-surface);
        color: var(--color-text-primary);
        border: 1.5px solid var(--color-border);
    }
</style>
