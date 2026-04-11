import { preferences } from '@kit.ArkData';

const STORE_NAME = 'newma_chat_prefs';

export class SettingsStore {
  private store: preferences.Preferences | null = null;

  async init(context: Context): Promise<void> {
    try {
      this.store = await preferences.getPreferences(context, STORE_NAME);
    } catch (e) {
      console.error('[SettingsStore] Init failed:', e);
    }
  }

  async getGatewayUrl(): Promise<string> {
    if (!this.store) return 'ws://192.168.31.44:18789';
    return (await this.store.get('gateway_url', 'ws://192.168.31.44:18789')) as string;
  }

  async setGatewayUrl(url: string): Promise<void> {
    if (!this.store) return;
    await this.store.put('gateway_url', url);
    await this.store.flush();
  }

  async getAutoReconnect(): Promise<boolean> {
    if (!this.store) return true;
    return (await this.store.get('auto_reconnect', true)) as boolean;
  }

  async setAutoReconnect(enabled: boolean): Promise<void> {
    if (!this.store) return;
    await this.store.put('auto_reconnect', enabled);
    await this.store.flush();
  }
}
