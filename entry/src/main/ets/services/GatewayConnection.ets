import webSocket from '@ohos.net.webSocket';
import { GatewayFrame, ConnectionConfig, ConnState, AgentEvent, ChatMessage } from '../model/GatewayTypes';

type FrameHandler = (frame: GatewayFrame) => void;
type StateHandler = (state: ConnState) => void;

export class GatewayConnection {
  private ws: webSocket.WebSocket | null = null;
  private config: ConnectionConfig;
  private state: ConnState = ConnState.DISCONNECTED;
  private eventHandlers: Map<string, Set<FrameHandler>> = new Map();
  private stateHandlers: Set<StateHandler> = new Set();
  private requestId: number = 0;
  private reconnectTimer: number = -1;
  private messageQueue: string[] = [];
  private sessionKey: string | null = null;
  private streamingContent: string = '';

  constructor(config?: Partial<ConnectionConfig>) {
    this.config = {
      url: 'ws://192.168.31.44:18789',
      autoReconnect: true,
      reconnectInterval: 3000,
      ...config,
    };
  }

  connect(): void {
    if (this.ws && (this.state === ConnState.CONNECTED || this.state === ConnState.CONNECTING)) {
      return;
    }

    this.setState(ConnState.CONNECTING);

    try {
      this.ws = webSocket.createWebSocket();
      this.ws.connect(this.config.url, (err) => {
        if (!err) {
          console.log('[GatewayConnection] WebSocket transport ready');
          // 等待 server 的 challenge 事件
        } else {
          console.error('[GatewayConnection] Connect failed:', err.message);
          this.setState(ConnState.DISCONNECTED);
          this.scheduleReconnect();
        }
      });

      this.ws.on('message', (err, data) => {
        if (!err && data) {
          try {
            const frame: GatewayFrame = JSON.parse(data.result as string) as GatewayFrame;
            this.handleFrame(frame);
          } catch (e) {
            console.error('[GatewayConnection] Parse error:', e);
          }
        }
      });

      this.ws.on('error', (err) => {
        console.error('[GatewayConnection] WebSocket error');
        this.setState(ConnState.DISCONNECTED);
      });

      this.ws.on('close', (_err, _code, _reason) => {
        console.log('[GatewayConnection] WebSocket closed');
        this.setState(ConnState.DISCONNECTED);
        if (this.config.autoReconnect) {
          this.scheduleReconnect();
        }
      });
    } catch (e) {
      console.error('[GatewayConnection] Create failed:', e);
      this.setState(ConnState.DISCONNECTED);
    }
  }

  disconnect(): void {
    if (this.reconnectTimer !== -1) {
      clearTimeout(this.reconnectTimer);
      this.reconnectTimer = -1;
    }
    if (this.ws) {
      this.ws.close();
      this.ws = null;
    }
    this.setState(ConnState.DISCONNECTED);
  }

  send(method: string, params?: ESObject): Promise<ESObject> {
    return new Promise((resolve, reject) => {
      const id = `req-${++this.requestId}`;
      const paramsWithSession = this.sessionKey
        ? { ...params, sessionKey: this.sessionKey } as ESObject
        : params;

      const frame: GatewayFrame = {
        type: 'req',
        id,
        method,
        params: paramsWithSession,
      };

      // 监听响应
      const handler = (responseFrame: GatewayFrame) => {
        if (responseFrame.id === id) {
          this.off('res', handler);
          if (responseFrame.ok) {
            resolve(responseFrame.payload || {});
          } else {
            reject(new Error(responseFrame.error?.message || 'Request failed'));
          }
        }
      };
      this.on('res', handler);

      const message = JSON.stringify(frame);
      if (this.state === ConnState.CONNECTED && this.ws) {
        this.ws.send(message);
      } else {
        this.messageQueue.push(message);
      }
    });
  }

  // 发送聊天消息（返回 streaming 内容的更新回调）
  sendAgent(message: string): void {
    // 添加用户消息到本地
    this.streamingContent = '';
    this.send('agent', { message: message, sessionKey: 'main' }).catch((e) => {
      console.error('[GatewayConnection] Agent send failed:', e);
    });
  }

  getState(): ConnState {
    return this.state;
  }

  getSessionKey(): string | null {
    return this.sessionKey;
  }

  on(event: string, handler: FrameHandler): void {
    if (!this.eventHandlers.has(event)) {
      this.eventHandlers.set(event, new Set());
    }
    this.eventHandlers.get(event)!.add(handler);
  }

  off(event: string, handler: FrameHandler): void {
    this.eventHandlers.get(event)?.delete(handler);
  }

  onStateChange(handler: StateHandler): void {
    this.stateHandlers.add(handler);
  }

  offStateChange(handler: StateHandler): void {
    this.stateHandlers.delete(handler);
  }

  private handleFrame(frame: GatewayFrame): void {
    // 处理 challenge → 自动发送 connect
    if (frame.type === 'event' && frame.event === 'challenge') {
      console.log('[GatewayConnection] Received challenge, sending connect');
      const connectFrame: GatewayFrame = {
        type: 'req',
        id: `connect-${Date.now()}`,
        method: 'connect',
        params: {
          client: {
            id: 'harmonyos-app',
            platform: 'harmonyos',
            version: '1.0.0',
            mode: 'operator',
          }
        }
      };
      this.ws?.send(JSON.stringify(connectFrame));
    }

    // 处理 connect 响应
    if (frame.type === 'res' && frame.ok && frame.payload?.sessionKey) {
      this.sessionKey = frame.payload.sessionKey as string;
      this.setState(ConnState.CONNECTED);
      // 发送队列中的消息
      while (this.messageQueue.length > 0) {
        const msg = this.messageQueue.shift();
        if (msg) this.ws?.send(msg);
      }
    }

    // 分发事件
    const eventType = frame.type === 'event' ? frame.event : frame.type;
    if (eventType) {
      const handlers = this.eventHandlers.get(eventType);
      if (handlers) {
        handlers.forEach(h => {
          try { h(frame); } catch (e) { console.error('[GatewayConnection] Handler error:', e); }
        });
      }
    }
  }

  private setState(newState: ConnState): void {
    this.state = newState;
    this.stateHandlers.forEach(h => {
      try { h(newState); } catch (e) { console.error('[GatewayConnection] State handler error:', e); }
    });
  }

  private scheduleReconnect(): void {
    if (this.reconnectTimer !== -1) return;
    this.reconnectTimer = setTimeout(() => {
      this.reconnectTimer = -1;
      console.log('[GatewayConnection] Reconnecting...');
      this.connect();
    }, this.config.reconnectInterval);
  }

  updateConfig(config: Partial<ConnectionConfig>): void {
    Object.assign(this.config, config);
  }

  getConfig(): ConnectionConfig {
    return { ...this.config };
  }
}
