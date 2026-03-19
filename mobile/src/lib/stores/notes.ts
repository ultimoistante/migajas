import { writable } from 'svelte/store';
import {
    notes as notesApi,
    type Note,
    type CreateNotePayload,
    type UpdateNotePayload
} from '$lib/api/client';

function createNotesStore() {
    const { subscribe, set, update } = writable<Note[]>([]);

    return {
        subscribe,
        async load() {
            const all = await notesApi.list();
            set(all);
        },
        async create(payload: CreateNotePayload) {
            const note = await notesApi.create(payload);
            update((notes) => [note, ...notes]);
            return note;
        },
        async update(id: string, payload: UpdateNotePayload) {
            const updated = await notesApi.update(id, payload);
            update((notes) => notes.map((n) => (n.id === id ? updated : n)));
            return updated;
        },
        async delete(id: string) {
            await notesApi.delete(id);
            update((notes) => notes.filter((n) => n.id !== id));
        },
        setUnlocked(unlocked: Note) {
            update((notes) => notes.map((n) => (n.id === unlocked.id ? unlocked : n)));
        },
        patchTagInNotes(updatedTag: { id: string; name: string; emoji: string }) {
            update((notes) =>
                notes.map((n) => ({
                    ...n,
                    tags: n.tags?.map((t) => (t.id === updatedTag.id ? { ...t, ...updatedTag } : t)) ?? []
                }))
            );
        },
        removeTagFromNotes(tagId: string) {
            update((notes) =>
                notes.map((n) => ({
                    ...n,
                    tags: n.tags?.filter((t) => t.id !== tagId) ?? []
                }))
            );
        },
        patchAttachmentCount(id: string, delta: number) {
            update((notes) =>
                notes.map((n) =>
                    n.id === id ? { ...n, attachment_count: (n.attachment_count ?? 0) + delta } : n
                )
            );
        },
        reset() {
            set([]);
        }
    };
}

export const notesStore = createNotesStore();
