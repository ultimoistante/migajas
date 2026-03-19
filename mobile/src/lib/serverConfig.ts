import { Preferences } from '@capacitor/preferences';

const SERVER_URL_KEY = 'migajas_server_url';

export async function getServerUrl(): Promise<string | null> {
    const { value } = await Preferences.get({ key: SERVER_URL_KEY });
    return value ? value.replace(/\/$/, '') : null;
}

export async function setServerUrl(url: string): Promise<void> {
    const normalized = url.trim().replace(/\/$/, '');
    await Preferences.set({ key: SERVER_URL_KEY, value: normalized });
}

export async function clearServerUrl(): Promise<void> {
    await Preferences.remove({ key: SERVER_URL_KEY });
}
