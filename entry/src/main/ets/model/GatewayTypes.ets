// Gateway 协议类型定义

// Gateway 帧
export interface GatewayFrame {
  type: 'req' | 'res' | 'event';
  id?: string;
  method?: string;
  event?: string;
  params?: ESObject;
  payload?: ESObject;
  ok?: boolean;
  error?: GatewayError;
}

export interface GatewayError {
  code: string;
  message: string;
  details?: ESObject;
}

// 聊天消息
export interface ChatMessage {
  role: 'user' | 'assistant' | 'system';
  content: string;
  timestamp: number;
  id?: string;
  isStreaming?: boolean;
}

// Agent 事件
export interface AgentEvent {
  runId: string;
  sessionKey: string;
  state: 'delta' | 'final' | 'aborted' | 'error';
  message?: ChatMessage;
  delta?: string;
  errorMessage?: string;
}

// 连接配置
export interface ConnectionConfig {
  url: string;
  autoReconnect: boolean;
  reconnectInterval: number;
}

// 连接状态
export enum ConnState {
  DISCONNECTED = 0,
  CONNECTING = 1,
  CONNECTED = 2,
}
