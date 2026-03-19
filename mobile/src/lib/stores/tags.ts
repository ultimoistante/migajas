import { writable } from 'svelte/store';
import { tags as tagsApi, type Tag } from '$lib/api/client';

function createTagsStore() {
    const { subscribe, set, update } = writable<Tag[]>([]);

    return {
        subscribe,

        async load() {
            const data = await tagsApi.list();
            set(data);
        },

        async create(name: string, emoji: string): Promise<Tag> {
            const tag = await tagsApi.create(name, emoji);
            update((ts) => [...ts, tag].sort((a, b) => a.name.localeCompare(b.name)));
            return tag;
        },

        async updateTag(id: string, payload: { name?: string; emoji?: string }): Promise<Tag> {
            const tag = await tagsApi.update(id, payload);
            update((ts) => ts.map((t) => (t.id === id ? tag : t)));
            return tag;
        },

        async remove(id: string) {
            await tagsApi.delete(id);
            update((ts) => ts.filter((t) => t.id !== id));
        },

        reset() {
            set([]);
        }
    };
}

export const tagsStore = createTagsStore();

/** The tag currently selected as a filter; null means "all notes". */
export const selectedTagId = writable<string | null>(null);
