import { GatewayConnection } from './GatewayConnection';
import {
  GatewayFrame,
  ChatMessage,
  ConnState,
  ToolCallMessage,
  ToolResultMessage
} from '../model/GatewayTypes';

type MessageHandler = (message: ChatMessage) => void;
type StreamHandler = (delta: string, isFinal: boolean) => void;
type ToolCallHandler = (toolCall: ToolCallMessage) => void;
type ToolResultHandler = (toolResult: ToolResultMessage) => void;

export class ChatService {
  private connection: GatewayConnection;
  private messageHandlers: MessageHandler[] = [];
  private streamHandlers: StreamHandler[] = [];
  private toolCallHandlers: ToolCallHandler[] = [];
  private toolResultHandlers: ToolResultHandler[] = [];
  private messages: ChatMessage[] = [];

  constructor(connection: GatewayConnection) {
    this.connection = connection;

    this.connection.onAgent((frame: GatewayFrame): void => {
      if (frame.payload === undefined || frame.payload === null) {
        return;
      }
      try {
        const payloadStr: string = frame.payload;
        const state = this.extractField(payloadStr, 'state');
        if (state === 'delta') {
          const delta = this.extractField(payloadStr, 'delta');
          if (delta !== null && delta.length > 0) {
            for (let i = 0; i < this.streamHandlers.length; i++) {
              this.streamHandlers[i](delta, false);
            }
          }
        } else if (state === 'final') {
          for (let i = 0; i < this.streamHandlers.length; i++) {
            this.streamHandlers[i]('', true);
          }
          const msgContent = this.extractNestedField(payloadStr, 'message', 'content');
          const runId = this.extractField(payloadStr, 'runId');
          if (msgContent !== null) {
            const msg: ChatMessage = {
              role: 'assistant',
              content: msgContent,
              timestamp: Date.now(),
              id: runId !== null ? runId : `ai-${Date.now()}`
            };
            this.messages.push(msg);
            for (let i = 0; i < this.messageHandlers.length; i++) {
              this.messageHandlers[i](msg);
            }
          }
        } else if (state === 'error') {
          const errMsg = this.extractField(payloadStr, 'errorMessage');
          const text = errMsg !== null ? errMsg : '未知错误';
          const err: ChatMessage = {
            role: 'system',
            content: `错误: ${text}`,
            timestamp: Date.now(),
            id: `err-${Date.now()}`
          };
          this.messages.push(err);
          for (let i = 0; i < this.messageHandlers.length; i++) {
            this.messageHandlers[i](err);
          }
          for (let i = 0; i < this.streamHandlers.length; i++) {
            this.streamHandlers[i]('', true);
          }
        } else if (state === 'tool_call') {
          // Handle tool_call event
          const toolCallInfo = this.extractToolCalls(payloadStr);
          if (toolCallInfo !== null) {
            const toolCall: ToolCallMessage = {
              role: 'tool_call',
              toolName: toolCallInfo.name,
              toolArgs: toolCallInfo.args,
              timestamp: Date.now(),
              id: toolCallInfo.id
            };
            for (let i = 0; i < this.toolCallHandlers.length; i++) {
              this.toolCallHandlers[i](toolCall);
            }
          }
        } else if (state === 'tool_result') {
          // Handle tool_result event
          const toolResultInfo = this.extractToolResult(payloadStr);
          if (toolResultInfo !== null) {
            const toolResult: ToolResultMessage = {
              role: 'tool_result',
              toolName: toolResultInfo.name,
              result: toolResultInfo.result,
              timestamp: Date.now(),
              id: toolResultInfo.id
            };
            for (let i = 0; i < this.toolResultHandlers.length; i++) {
              this.toolResultHandlers[i](toolResult);
            }
          }
        }
      } catch (e) {
        console.error('[ChatService] parse error:', e);
      }
    });
  }

  sendMessage(content: string): void {
    const userMsg: ChatMessage = {
      role: 'user',
      content: content,
      timestamp: Date.now(),
      id: `user-${Date.now()}`
    };
    this.messages.push(userMsg);
    for (let i = 0; i < this.messageHandlers.length; i++) {
      this.messageHandlers[i](userMsg);
    }
    this.connection.sendAgent(content);
  }

  onMessage(handler: MessageHandler): void {
    this.messageHandlers.push(handler);
  }

  offMessage(handler: MessageHandler): void {
    const idx: number = this.messageHandlers.indexOf(handler);
    if (idx >= 0) {
      this.messageHandlers.splice(idx, 1);
    }
  }

  onStream(handler: StreamHandler): void {
    this.streamHandlers.push(handler);
  }

  offStream(handler: StreamHandler): void {
    const idx: number = this.streamHandlers.indexOf(handler);
    if (idx >= 0) {
      this.streamHandlers.splice(idx, 1);
    }
  }

  getMessages(): ChatMessage[] {
    const result: ChatMessage[] = [];
    for (let i = 0; i < this.messages.length; i++) {
      result.push(this.messages[i]);
    }
    return result;
  }

  clearMessages(): void {
    this.messages = [];
  }

  onToolCall(handler: ToolCallHandler): void {
    this.toolCallHandlers.push(handler);
  }

  offToolCall(handler: ToolCallHandler): void {
    const idx: number = this.toolCallHandlers.indexOf(handler);
    if (idx >= 0) {
      this.toolCallHandlers.splice(idx, 1);
    }
  }

  onToolResult(handler: ToolResultHandler): void {
    this.toolResultHandlers.push(handler);
  }

  offToolResult(handler: ToolResultHandler): void {
    const idx: number = this.toolResultHandlers.indexOf(handler);
    if (idx >= 0) {
      this.toolResultHandlers.splice(idx, 1);
    }
  }

  // Extract tool call information from payload
  private extractToolCalls(payload: string): { id: string; name: string; args: string } | null {
    // Extract toolCalls array
    const toolCallsKey = '"toolCalls"';
    const toolCallsIdx = payload.indexOf(toolCallsKey);
    if (toolCallsIdx < 0) {
      return null;
    }
    const arrayStart = payload.indexOf('[', toolCallsIdx);
    if (arrayStart < 0) {
      return null;
    }
    // Find matching closing bracket
    let depth = 0;
    let arrayEnd = -1;
    for (let i = arrayStart; i < payload.length; i++) {
      if (payload.charAt(i) === '[') {
        depth++;
      } else if (payload.charAt(i) === ']') {
        depth--;
        if (depth === 0) {
          arrayEnd = i;
          break;
        }
      }
    }
    if (arrayEnd < 0) {
      return null;
    }
    const arrayStr = payload.substring(arrayStart, arrayEnd + 1);
    // Extract first tool call info
    const id = this.extractField(arrayStr, 'id');
    const name = this.extractField(arrayStr, 'name');
    // Extract args (nested in args object)
    let args: string = '';
    const argsKey = '"args"';
    const argsIdx = arrayStr.indexOf(argsKey);
    if (argsIdx >= 0) {
      const braceStart = arrayStr.indexOf('{', argsIdx + argsKey.length);
      if (braceStart >= 0) {
        let braceDepth = 0;
        let braceEnd = -1;
        for (let i = braceStart; i < arrayStr.length; i++) {
          if (arrayStr.charAt(i) === '{') {
            braceDepth++;
          } else if (arrayStr.charAt(i) === '}') {
            braceDepth--;
            if (braceDepth === 0) {
              braceEnd = i;
              break;
            }
          }
        }
        if (braceEnd >= 0) {
          args = arrayStr.substring(braceStart, braceEnd + 1);
        }
      }
    }
    if (id !== null && name !== null) {
      return { id, name, args };
    }
    return null;
  }

  // Extract tool result information from payload
  private extractToolResult(payload: string): { id: string; name: string; result: string } | null {
    const toolResultKey = '"toolResult"';
    const toolResultIdx = payload.indexOf(toolResultKey);
    if (toolResultIdx < 0) {
      return null;
    }
    const braceStart = payload.indexOf('{', toolResultIdx + toolResultKey.length);
    if (braceStart < 0) {
      return null;
    }
    // Find matching closing brace
    let depth = 0;
    let braceEnd = -1;
    for (let i = braceStart; i < payload.length; i++) {
      if (payload.charAt(i) === '{') {
        depth++;
      } else if (payload.charAt(i) === '}') {
        depth--;
        if (depth === 0) {
          braceEnd = i;
          break;
        }
      }
    }
    if (braceEnd < 0) {
      return null;
    }
    const objStr = payload.substring(braceStart, braceEnd + 1);
    const id = this.extractField(objStr, 'id');
    const name = this.extractField(objStr, 'name');
    const result = this.extractField(objStr, 'result');
    if (id !== null && name !== null && result !== null) {
      return { id, name, result };
    }
    return null;
  }

  private extractField(json: string, field: string): string | null {
    const key = `"${field}"`;
    const keyIdx = json.indexOf(key);
    if (keyIdx < 0) {
      return null;
    }
    const colonIdx = json.indexOf(':', keyIdx + key.length);
    if (colonIdx < 0) {
      return null;
    }
    let start = colonIdx + 1;
    while (start < json.length && (json.charAt(start) === ' ' || json.charAt(start) === '\t')) {
      start++;
    }
    if (start >= json.length) {
      return null;
    }
    if (json.charAt(start) === '"') {
      start++;
      const end = json.indexOf('"', start);
      if (end < 0) {
        return null;
      }
      return json.substring(start, end);
    }
    return null;
  }

  private extractNestedField(json: string, obj: string, field: string): string | null {
    const objKey = `"${obj}"`;
    const objIdx = json.indexOf(objKey);
    if (objIdx < 0) {
      return null;
    }
    const braceIdx = json.indexOf('{', objIdx + objKey.length);
    if (braceIdx < 0) {
      return null;
    }
    // 找到匹配的闭合 }
    let depth = 0;
    let end = -1;
    for (let i = braceIdx; i < json.length; i++) {
      if (json.charAt(i) === '{') {
        depth++;
      } else if (json.charAt(i) === '}') {
        depth--;
        if (depth === 0) {
          end = i;
          break;
        }
      }
    }
    if (end < 0) {
      return null;
    }
    const sub = json.substring(braceIdx, end + 1);
    return this.extractField(sub, field);
  }
}
