import webSocket from '@ohos.net.webSocket';
import {
  GatewayFrame,
  ConnectionConfig,
  ConnState,
  ClientInfo,
  ConnectPayload,
  AgentPayload,
  AgentMessage,
  ChatMessage
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
          const arr: number[] = [];
          for (let i = 0; i < view.length; i++) {
            arr.push(view[i]);
          }
          text = String.fromCharCode.apply(null, arr);
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

    this.ws.on('close', (err: Error, code: number, reason: string) => {
      console.log('[GW] socket closed');
      this.ws = null;
      this.connState = ConnState.DISCONNECTED;
      this.notifyState();
      if (this.autoReconnect) {
        this.tryReconnect();
      }
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
    const params: string = JSON.stringify({
      message: text,
      sessionKey: this.sessionId
    });
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
        id: 'harmonyos-app',
        platform: 'harmonyos',
        version: '1.0.0',
        mode: 'operator'
      };
      const connectFrame: string = JSON.stringify({
        type: 'req',
        id: `connect-${Date.now()}`,
        method: 'connect',
        params: JSON.stringify({ client: client })
      });
      if (this.ws !== null) {
        this.ws.send(connectFrame);
      }
      return;
    }

    // connect 响应 → 提取 sessionKey
    if (frame.type === 'res' && frame.ok === true && frame.payload !== undefined) {
      try {
        const payload: ConnectPayload = JSON.parse(frame.payload) as ConnectPayload;
        if (payload.sessionKey !== undefined && payload.sessionKey.length > 0) {
          this.sessionId = payload.sessionKey;
          this.connState = ConnState.CONNECTED;
          this.notifyState();
          // flush queue
          while (this.messageQueue.length > 0) {
            const msg = this.messageQueue.shift();
            if (msg !== undefined && this.ws !== null) {
              this.ws.send(msg);
            }
          }
        }
      } catch (e) {
        // ignore parse error
      }
      return;
    }

    // agent 事件
    if (frame.type === 'event' && frame.event === 'agent') {
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
