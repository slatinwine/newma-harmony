// Gateway 协议类型定义

// 字典类型替代 ESObject
export type StringDict = Record<string, string | number | boolean | null | undefined>;
export type ParamsDict = Record<string, StringDict | string | number | boolean | null | undefined>;

// Gateway 帧
export interface GatewayFrame {
  type: 'req' | 'res' | 'event';
  id?: string;
  method?: string;
  event?: string;
  params?: ParamsDict;
  payload?: PayloadDict;
  ok?: boolean;
  error?: GatewayError;
}

export interface PayloadDict {
  [key: string]: string | number | boolean | null | undefined | StringDict;
  sessionKey?: string;
  runId?: string;
  state?: string;
  delta?: string;
  message?: ChatMessage;
  errorMessage?: string;
}

export interface GatewayError {
  code: string;
  message: string;
  details?: ParamsDict;
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

// 连接状态枚举
export enum ConnState {
  DISCONNECTED = 0,
  CONNECTING = 1,
  CONNECTED = 2,
}
