import { GatewayConnection } from './GatewayConnection';
import { GatewayFrame, ChatMessage, AgentEvent, ConnState } from '../model/GatewayTypes';

type MessageHandler = (message: ChatMessage) => void;
type StreamHandler = (delta: string, isFinal: boolean) => void;

export class ChatService {
  private connection: GatewayConnection;
  private messageHandlers: Set<MessageHandler> = new Set();
  private streamHandlers: Set<StreamHandler> = new Set();
  private messages: ChatMessage[] = [];

  constructor(connection: GatewayConnection) {
    this.connection = connection;

    // 监听 agent 事件
    this.connection.on('agent', (frame: GatewayFrame) => {
      const payload = frame.payload as AgentEvent;
      if (!payload) return;

      if (payload.state === 'delta' && payload.delta) {
        // 流式内容
        this.streamHandlers.forEach(h => h(payload.delta!, false));
      } else if (payload.state === 'final') {
        this.streamHandlers.forEach(h => h('', true));
        if (payload.message) {
          const msg: ChatMessage = {
            role: 'assistant',
            content: payload.message.content,
            timestamp: Date.now(),
            id: payload.runId,
          };
          this.messages.push(msg);
          this.messageHandlers.forEach(h => h(msg));
        }
      } else if (payload.state === 'error') {
        const errMsg: ChatMessage = {
          role: 'system',
          content: `错误: ${payload.errorMessage || '未知错误'}`,
          timestamp: Date.now(),
          id: `err-${Date.now()}`,
        };
        this.messages.push(errMsg);
        this.messageHandlers.forEach(h => h(errMsg));
        this.streamHandlers.forEach(h => h('', true));
      }
    });
  }

  async sendMessage(content: string): Promise<void> {
    // 本地添加用户消息
    const userMsg: ChatMessage = {
      role: 'user',
      content,
      timestamp: Date.now(),
      id: `user-${Date.now()}`,
    };
    this.messages.push(userMsg);
    this.messageHandlers.forEach(h => h(userMsg));

    // 通过 Gateway 发送
    this.connection.sendAgent(content);
  }

  onMessage(handler: MessageHandler): void {
    this.messageHandlers.add(handler);
  }

  offMessage(handler: MessageHandler): void {
    this.messageHandlers.delete(handler);
  }

  onStream(handler: StreamHandler): void {
    this.streamHandlers.add(handler);
  }

  offStream(handler: StreamHandler): void {
    this.streamHandlers.delete(handler);
  }

  getMessages(): ChatMessage[] {
    return [...this.messages];
  }

  clearMessages(): void {
    this.messages = [];
  }
}
