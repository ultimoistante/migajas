import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
    appId: 'com.migajas.app',
    appName: 'Migajas',
    webDir: 'dist',
    server: {
        androidScheme: 'http',
        // Allow navigation to any host — user configures backend URL at runtime
        allowNavigation: ['*']
    },
    plugins: {
        StatusBar: {
            style: 'DEFAULT',
            backgroundColor: '#0f172a'
        }
    }
};

export default config;
