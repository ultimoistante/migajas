import { writable } from 'svelte/store';

/** True once the first-run setup has been completed. */
export const appInitialized = writable(true); // optimistic default

/** Whether users are allowed to self-register. */
export const allowSelfRegistration = writable(false);
