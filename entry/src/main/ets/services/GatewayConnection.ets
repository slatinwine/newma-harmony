import webSocket from '@ohos.net.webSocket';
import {
  GatewayFrame,
  ConnectionConfig,
  ConnState,
  ClientInfo,
  ConnectParams,
  AgentParams
} from '../model/GatewayTypes';

type FrameHandler = (frame: GatewayFrame) => void;
type StateHandler = (state: ConnState) => void;

const DEFAULT_URL: string = 'ws://192.168.31.44:18789';

export class GatewayConnection {
  private ws: webSocket.WebSocket | null = null;
  private url: string = DEFAULT_URL;
  private autoReconnect: boolean = true;
  private reconnectInterval: number = 3000;
  private connState: ConnState = ConnState.DISCONNECTED;
  private sessionId: string | null = null;

  private agentHandlers: FrameHandler[] = [];
  private stateChangeHandlers: StateHandler[] = [];
  private messageQueue: string[] = [];
  private reconnectTimerId: number = -1;
  private reqCounter: number = 0;

  constructor(url?: string) {
    if (url !== undefined && url !== null && url.length > 0) {
      this.url = url;
    }
  }

  connect(): void {
    if (this.ws !== null) {
      return;
    }
    this.connState = ConnState.CONNECTING;
    this.notifyState();

    this.ws = webSocket.createWebSocket();

    this.ws.on('open', (err: Error) => {
      if (err === undefined || err === null) {
        console.log('[GW] transport open');
      } else {
        console.error('[GW] open error:', err.message);
        this.connState = ConnState.DISCONNECTED;
        this.notifyState();
        this.tryReconnect();
      }
    });

    this.ws.on('message', (err: Error, data: string | ArrayBuffer) => {
      if (err !== undefined && err !== null) {
        return;
      }
      try {
        let text: string = '';
        if (typeof data === 'string') {
          text = data;
        } else {
          const view = new Uint8Array(data as ArrayBuffer);
          for (let i = 0; i < view.length; i++) {
            text += String.fromCharCode(view[i]);
          }
        }
        if (text.length > 0) {
          this.onFrameReceived(text);
        }
      } catch (e) {
        console.error('[GW] parse error:', e);
      }
    });

    this.ws.on('error', (err: Error) => {
      console.error('[GW] socket error');
      this.connState = ConnState.DISCONNECTED;
      this.notifyState();
    });

    this.ws.connect(this.url, (err: Error) => {
      if (err !== undefined && err !== null) {
        console.error('[GW] connect failed:', err.message);
        this.connState = ConnState.DISCONNECTED;
        this.notifyState();
        this.tryReconnect();
      }
    });
  }

  disconnect(): void {
    if (this.reconnectTimerId !== -1) {
      clearTimeout(this.reconnectTimerId);
      this.reconnectTimerId = -1;
    }
    if (this.ws !== null) {
      this.ws.close();
      this.ws = null;
    }
    this.sessionId = null;
    this.connState = ConnState.DISCONNECTED;
    this.notifyState();
  }

  sendAgent(text: string): void {
    const params: AgentParams = { message: text, sessionKey: this.sessionId };
    const frame: string = JSON.stringify({
      type: 'req',
      id: `req-${++this.reqCounter}`,
      method: 'agent',
      params: params
    });
    this.sendRaw(frame);
  }

  getState(): ConnState {
    return this.connState;
  }

  getSessionId(): string | null {
    return this.sessionId;
  }

  updateUrl(url: string): void {
    this.url = url;
  }

  setAutoReconnect(auto: boolean): void {
    this.autoReconnect = auto;
  }

  getUrl(): string {
    return this.url;
  }

  isAutoReconnect(): boolean {
    return this.autoReconnect;
  }

  onAgent(handler: FrameHandler): void {
    this.agentHandlers.push(handler);
  }

  onStateChange(handler: StateHandler): void {
    this.stateChangeHandlers.push(handler);
  }

  private sendRaw(data: string): void {
    if (this.connState === ConnState.CONNECTED && this.ws !== null) {
      this.ws.send(data);
    } else {
      this.messageQueue.push(data);
    }
  }

  private tryReconnect(): void {
    if (this.reconnectTimerId !== -1) {
      return;
    }
    this.reconnectTimerId = setTimeout((): void => {
      this.reconnectTimerId = -1;
      console.log('[GW] reconnecting...');
      this.ws = null;
      this.connect();
    }, this.reconnectInterval);
  }

  private notifyState(): void {
    const s: ConnState = this.connState;
    for (let i = 0; i < this.stateChangeHandlers.length; i++) {
      try {
        this.stateChangeHandlers[i](s);
      } catch (e) {
        // ignore
      }
    }
  }

  private onFrameReceived(raw: string): void {
    let frame: GatewayFrame;
    try {
      frame = JSON.parse(raw) as GatewayFrame;
    } catch (e) {
      return;
    }

    // challenge → 发 connect
    if (frame.type === 'event' && frame.event === 'challenge') {
      const client: ClientInfo = {
        id: 'mobile-app',
        platform: 'harmonyos',
        version: '1.0.0',
        mode: 'operator'
      };
      const params: ConnectParams = {
        client: { id: 'mobile-app', platform: 'harmonyos', version: '1.0.0', mode: 'operator' }
      };
      const connectFrame: string = JSON.stringify({
        type: 'req',
        id: `connect-${Date.now()}`,
        method: 'connect',
        params: params
      });
      if (this.ws !== null) {
        this.ws.send(connectFrame);
      }
      return;
    }

    // connect 响应 → 从原始 JSON 提取 sessionKey
    if (frame.type === 'res' && frame.ok === true) {
      try {
        const key: string = '"sessionKey":"';
        const keyIdx: number = raw.indexOf(key);
        if (keyIdx !== -1) {
          const start: number = keyIdx + key.length;
          const endIdx: number = raw.indexOf('"', start);
          if (endIdx !== -1) {
            const sessionKey: string = raw.substring(start, endIdx);
            this.sessionId = sessionKey;
            this.connState = ConnState.CONNECTED;
            this.notifyState();
            while (this.messageQueue.length > 0) {
              const msg = this.messageQueue.shift();
              if (msg !== undefined && this.ws !== null) {
                this.ws.send(msg);
              }
            }
          }
        }
      } catch (e) {
        // ignore
      }
      return;
    }

    // agent 事件 — payload 是对象，从 raw 提取并序列化为 string
    if (frame.type === 'event' && frame.event === 'agent') {
      // 从 raw 中提取 payload 对象，重新序列化为 string
      const payloadKey: string = '"payload":';
      const payloadIdx: number = raw.indexOf(payloadKey);
      if (payloadIdx !== -1) {
        let start: number = payloadIdx + payloadKey.length;
        while (start < raw.length && raw.charAt(start) === ' ') {
          start++;
        }
        if (start < raw.length && raw.charAt(start) === '{') {
          // 找到 payload 对象的闭合 }
          let depth: number = 0;
          let end: number = -1;
          for (let i: number = start; i < raw.length; i++) {
            if (raw.charAt(i) === '{') {
              depth++;
            } else if (raw.charAt(i) === '}') {
              depth--;
              if (depth === 0) {
                end = i;
                break;
              }
            }
          }
          if (end !== -1) {
            // payload 对象本身序列化为 string（去掉外层引号的话不需要）
            // 直接用 payload 子串作为 payloadStr 传给 ChatService
            frame.payload = raw.substring(start, end + 1);
          }
        }
      }
      const handlers = this.agentHandlers;
      for (let i = 0; i < handlers.length; i++) {
        try {
          handlers[i](frame);
        } catch (e) {
          // ignore
        }
      }
    }
  }
}
