import { writable } from 'svelte/store';

/** True once the first-run setup has been completed. */
export const appInitialized = writable(true); // optimistic default
