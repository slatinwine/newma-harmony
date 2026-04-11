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
  toolCalls?: ToolCallInfo[];
  toolResult?: ToolResultInfo;
}

export interface ToolCallInfo {
  id: string;
  name: string;
  args: ToolCallArgs;
}

export interface ToolCallArgs {
  query?: string;
  city?: string;
  expression?: string;
}

export interface ToolResultInfo {
  id: string;
  name: string;
  result: string;
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
  toolCalls?: ToolCallInfo[];
  toolResult?: ToolResultInfo;
}

export interface ToolCallMessage {
  role: string;
  toolName: string;
  toolArgs: string;
  timestamp: number;
  id: string;
}

export interface ToolResultMessage {
  role: string;
  toolName: string;
  result: string;
  timestamp: number;
  id: string;
}

export interface ConnectPayload {
  sessionKey: string;
}

export interface ConnectParams {
  client: ClientInfo;
}

export interface AgentParams {
  message: string;
  sessionKey: string | null;
}

export enum ConnState {
  DISCONNECTED = 0,
  CONNECTING = 1,
  CONNECTED = 2,
}
