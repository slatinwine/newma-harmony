import { GatewayConnection } from './GatewayConnection';
import { GatewayFrame, ChatMessage, AgentEvent, ConnState } from '../model/GatewayTypes';

// 类型定义
type MessageHandler = (message: ChatMessage) => void;
type StreamHandler = (delta: string, isFinal: boolean) => void;

export class ChatService {
  private connection: GatewayConnection;
  private messageHandlers: Set<MessageHandler> = new Set<MessageHandler>();
  private streamHandlers: Set<StreamHandler> = new Set<StreamHandler>();
  private messages: ChatMessage[] = [];

  constructor(connection: GatewayConnection) {
    this.connection = connection;

    // 监听 agent 事件
    this.connection.on('agent', (frame: GatewayFrame) => {
      if (frame.payload === undefined || frame.payload === null) {
        return;
      }

      const payload = frame.payload as AgentEvent;
      if (!payload) return;

      if (payload.state === 'delta' && payload.delta !== undefined && payload.delta !== null) {
        // 流式内容
        this.streamHandlers.forEach((h: StreamHandler) => {
          h(payload.delta!, false);
        });
      } else if (payload.state === 'final') {
        this.streamHandlers.forEach((h: StreamHandler) => {
          h('', true);
        });
        if (payload.message !== undefined && payload.message !== null) {
          const msg: ChatMessage = {
            role: 'assistant',
            content: payload.message.content,
            timestamp: Date.now(),
            id: payload.runId
          };
          this.messages.push(msg);
          this.messageHandlers.forEach((h: MessageHandler) => {
            h(msg);
          });
        }
      } else if (payload.state === 'error') {
        const errorMsg: string = payload.errorMessage ?? '未知错误';
        const errMsg: ChatMessage = {
          role: 'system',
          content: `错误: ${errorMsg}`,
          timestamp: Date.now(),
          id: `err-${Date.now()}`
        };
        this.messages.push(errMsg);
        this.messageHandlers.forEach((h: MessageHandler) => {
          h(errMsg);
        });
        this.streamHandlers.forEach((h: StreamHandler) => {
          h('', true);
        });
      }
    });
  }

  async sendMessage(content: string): Promise<void> {
    // 本地添加用户消息
    const userMsg: ChatMessage = {
      role: 'user',
      content: content,
      timestamp: Date.now(),
      id: `user-${Date.now()}`
    };
    this.messages.push(userMsg);
    this.messageHandlers.forEach((h: MessageHandler) => {
      h(userMsg);
    });

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
    // 创建数组副本
    const result: ChatMessage[] = [];
    for (let i = 0; i < this.messages.length; i++) {
      result.push(this.messages[i]);
    }
    return result;
  }

  clearMessages(): void {
    this.messages = [];
  }
}