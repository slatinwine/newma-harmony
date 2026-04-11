import webSocket from '@ohos.net.webSocket';
import { GatewayFrame, ConnectionConfig, ConnState, ChatMessage, ParamsDict } from '../model/GatewayTypes';

// 类型定义
type FrameHandler = (frame: GatewayFrame) => void;
type StateHandler = (state: ConnState) => void;

interface PendingHandler {
  resolve: (value: ParamsDict) => void;
  reject: (error: Error) => void;
  timer: number;
}

// 默认配置
const DEFAULT_CONFIG: ConnectionConfig = {
  url: 'ws://192.168.31.44:18789',
  autoReconnect: true,
  reconnectInterval: 3000
};

export class GatewayConnection {
  private ws: webSocket.WebSocket | null = null;
  private config: ConnectionConfig;
  private state: ConnState = ConnState.DISCONNECTED;
  private eventHandlers: Map<string, Set<FrameHandler>> = new Map<string, Set<FrameHandler>>();
  private stateHandlers: Set<StateHandler> = new Set<StateHandler>();
  private requestId: number = 0;
  private reconnectTimer: number = -1;
  private messageQueue: string[] = [];
  private sessionKey: string | null = null;
  private pendingHandlers: Map<string, PendingHandler> = new Map<string, PendingHandler>();

  constructor(config?: Partial<ConnectionConfig>) {
    // 使用 Object.assign 替代 spread 操作符
    this.config = {} as ConnectionConfig;
    Object.assign(this.config, DEFAULT_CONFIG);
    if (config) {
      Object.assign(this.config, config);
    }
  }

  connect(): void {
    if (this.ws !== null && (this.state === ConnState.CONNECTED || this.state === ConnState.CONNECTING)) {
      return;
    }

    this.setState(ConnState.CONNECTING);

    try {
      this.ws = webSocket.createWebSocket();
      this.ws.connect(this.config.url, (err: Error) => {
        if (err === undefined || err === null) {
          console.log('[GatewayConnection] WebSocket transport ready');
          // 等待 server 的 challenge 事件
        } else {
          console.error('[GatewayConnection] Connect failed:', err.message);
          this.setState(ConnState.DISCONNECTED);
          this.scheduleReconnect();
        }
      });

      this.ws.on('message', (err: Error, data: webSocket.WebSocketMessage) => {
        if ((err === undefined || err === null) && data !== undefined && data !== null) {
          try {
            const frame: GatewayFrame = JSON.parse(data.result as string) as GatewayFrame;
            this.handleFrame(frame);
          } catch (e) {
            console.error('[GatewayConnection] Parse error:', e);
          }
        }
      });

      this.ws.on('error', (err: Error) => {
        console.error('[GatewayConnection] WebSocket error');
        this.setState(ConnState.DISCONNECTED);
      });

      this.ws.on('close', (_err: Error, _code: number, _reason: string) => {
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
    // 清理所有 pending 请求
    this.pendingHandlers.forEach((entry: PendingHandler, id: string) => {
      clearTimeout(entry.timer);
      entry.reject(new Error('Connection closed'));
    });
    this.pendingHandlers.clear();
    if (this.ws !== null) {
      this.ws.close();
      this.ws = null;
    }
    this.sessionKey = null;
    this.setState(ConnState.DISCONNECTED);
  }

  send(method: string, params?: ParamsDict, timeout: number = 30000): Promise<ParamsDict> {
    return new Promise((resolve: (value: ParamsDict) => void, reject: (error: Error) => void) => {
      const id: string = `req-${++this.requestId}`;

      // 创建带 session 的参数
      const paramsWithSession: ParamsDict = {};
      if (params !== undefined && params !== null) {
        Object.assign(paramsWithSession, params);
      }
      if (this.sessionKey !== null) {
        paramsWithSession['sessionKey'] = this.sessionKey;
      }

      const frame: GatewayFrame = {
        type: 'req',
        id: id,
        method: method,
        params: paramsWithSession
      };

      // 超时处理，防止内存泄漏
      const timer: number = setTimeout(() => {
        this.pendingHandlers.delete(id);
        reject(new Error(`Request ${method} timed out (${timeout}ms)`));
      }, timeout);

      // 监听响应
      const handler = (responseFrame: GatewayFrame): void => {
        if (responseFrame.id === id) {
          this.off('res', handler);
          this.pendingHandlers.delete(id);
          clearTimeout(timer);
          if (responseFrame.ok === true) {
            const payload: ParamsDict = (responseFrame.payload !== undefined && responseFrame.payload !== null)
              ? responseFrame.payload as ParamsDict
              : {};
            resolve(payload);
          } else {
            const errorMsg: string = responseFrame.error?.message ?? 'Request failed';
            reject(new Error(errorMsg));
          }
        }
      };

      this.on('res', handler);
      this.pendingHandlers.set(id, { resolve, reject, timer });

      const message: string = JSON.stringify(frame);
      if (this.state === ConnState.CONNECTED && this.ws !== null) {
        this.ws.send(message);
      } else {
        this.messageQueue.push(message);
      }
    });
  }

  // 发送聊天消息（返回 streaming 内容的更新回调）
  sendAgent(message: string): void {
    this.send('agent', { message: message } as ParamsDict)
      .catch((e: Error) => {
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
      this.eventHandlers.set(event, new Set<FrameHandler>());
    }
    const handlers = this.eventHandlers.get(event);
    if (handlers !== undefined) {
      handlers.add(handler);
    }
  }

  off(event: string, handler: FrameHandler): void {
    const handlers = this.eventHandlers.get(event);
    if (handlers !== undefined) {
      handlers.delete(handler);
    }
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
      const connectParams: ParamsDict = {
        client: {
          id: 'harmonyos-app',
          platform: 'harmonyos',
          version: '1.0.0',
          mode: 'operator'
        }
      };

      const connectFrame: GatewayFrame = {
        type: 'req',
        id: `connect-${Date.now()}`,
        method: 'connect',
        params: connectParams
      };

      if (this.ws !== null) {
        this.ws.send(JSON.stringify(connectFrame));
      }
    }

    // 处理 connect 响应
    if (frame.type === 'res' && frame.ok === true && frame.payload !== undefined && frame.payload !== null) {
      const sessionKey = frame.payload.sessionKey;
      if (typeof sessionKey === 'string') {
        this.sessionKey = sessionKey;
        this.setState(ConnState.CONNECTED);
        // 发送队列中的消息
        while (this.messageQueue.length > 0) {
          const msg = this.messageQueue.shift();
          if (msg !== undefined && this.ws !== null) {
            this.ws.send(msg);
          }
        }
      }
    }

    // 分发事件
    let eventType: string | undefined;
    if (frame.type === 'event') {
      eventType = frame.event;
    } else {
      eventType = frame.type;
    }

    if (eventType !== undefined) {
      const handlers = this.eventHandlers.get(eventType);
      if (handlers !== undefined) {
        handlers.forEach((h: FrameHandler) => {
          try {
            h(frame);
          } catch (e) {
            console.error('[GatewayConnection] Handler error:', e);
          }
        });
      }
    }
  }

  private setState(newState: ConnState): void {
    this.state = newState;
    this.stateHandlers.forEach((h: StateHandler) => {
      try {
        h(newState);
      } catch (e) {
        console.error('[GatewayConnection] State handler error:', e);
      }
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
    const result: ConnectionConfig = {
      url: this.config.url,
      autoReconnect: this.config.autoReconnect,
      reconnectInterval: this.config.reconnectInterval
    };
    return result;
  }
}