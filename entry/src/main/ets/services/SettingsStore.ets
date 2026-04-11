import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME: string = 'newma_chat_prefs';
const DEFAULT_GATEWAY_URL: string = 'ws://192.168.31.44:18789';
const DEFAULT_AUTO_RECONNECT: boolean = true;

export class SettingsStore {
  private store: preferences.Preferences | null = null;

  async init(context: common.UIAbilityContext): Promise<void> {
    try {
      this.store = await preferences.getPreferences(context, STORE_NAME);
    } catch (e) {
      console.error('[SettingsStore] Init failed:', e);
    }
  }

  async getGatewayUrl(): Promise<string> {
    if (this.store === null) {
      return DEFAULT_GATEWAY_URL;
    }
    try {
      const val: preferences.ValueType = await this.store.get('gateway_url', DEFAULT_GATEWAY_URL);
      if (typeof val === 'string') {
        return val;
      }
      return DEFAULT_GATEWAY_URL;
    } catch (e) {
      console.error('[SettingsStore] Get gateway URL failed:', e);
      return DEFAULT_GATEWAY_URL;
    }
  }

  async setGatewayUrl(url: string): Promise<void> {
    if (this.store === null) {
      return;
    }
    try {
      await this.store.put('gateway_url', url);
      await this.store.flush();
    } catch (e) {
      console.error('[SettingsStore] Set gateway URL failed:', e);
    }
  }

  async getAutoReconnect(): Promise<boolean> {
    if (this.store === null) {
      return DEFAULT_AUTO_RECONNECT;
    }
    try {
      const val: preferences.ValueType = await this.store.get('auto_reconnect', DEFAULT_AUTO_RECONNECT);
      if (typeof val === 'boolean') {
        return val;
      }
      return DEFAULT_AUTO_RECONNECT;
    } catch (e) {
      console.error('[SettingsStore] Get auto reconnect failed:', e);
      return DEFAULT_AUTO_RECONNECT;
    }
  }

  async setAutoReconnect(enabled: boolean): Promise<void> {
    if (this.store === null) {
      return;
    }
    try {
      await this.store.put('auto_reconnect', enabled);
      await this.store.flush();
    } catch (e) {
      console.error('[SettingsStore] Set auto reconnect failed:', e);
    }
  }
}
