// Gateway 协议类型定义

export interface GatewayFrame {
  type: string;
  id?: string;
  method?: string;
  event?: string;
  params?: string;
  payload?: string;
  ok?: boolean;
  error?: GatewayError;
}

export interface GatewayError {
  code: string;
  message: string;
}

export interface ChatMessage {
  role: string;
  content: string;
  timestamp: number;
  id?: string;
}

export interface ConnectionConfig {
  url: string;
  autoReconnect: boolean;
  reconnectInterval: number;
}

export interface ClientInfo {
  id: string;
  platform: string;
  version: string;
  mode: string;
}

export interface AgentEvent {
  runId: string;
  sessionKey: string;
  state: string;
  message?: string;
  delta?: string;
  errorMessage?: string;
}

export interface AgentMessage {
  role: string;
  content: string;
}

export interface AgentPayload {
  runId: string;
  sessionKey: string;
  state: string;
  delta?: string;
  message?: AgentMessage;
  errorMessage?: string;
}

export interface ConnectPayload {
  sessionKey: string;
}

export enum ConnState {
  DISCONNECTED = 0,
  CONNECTING = 1,
  CONNECTED = 2,
}
