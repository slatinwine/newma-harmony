import { GatewayConnection } from '../services/GatewayConnection';
import { ChatService } from '../services/ChatService';
import { SettingsStore } from '../services/SettingsStore';
import { MessageBubble } from '../components/MessageBubble';
import { ConnectionStatus } from '../components/ConnectionStatus';
import { InputBar } from '../components/InputBar';
import { ChatMessage, ConnState, ToolCallMessage, ToolResultMessage } from '../model/GatewayTypes';
import { common } from '@kit.AbilityKit';

// Union type for all message types
type MessageItem = ChatMessage | ToolCallMessage | ToolResultMessage;

@Entry
@Component
struct Index {
  @State messages: MessageItem[] = [];
  @State connState: ConnState = ConnState.DISCONNECTED;
  @State streamingText: string = '';
  @State isStreaming: boolean = false;
  @State gatewayUrl: string = 'ws://192.168.31.44:18789';
  @State showSettings: boolean = false;
  @State settingsUrl: string = '';
  @State settingsAutoReconnect: boolean = true;

  private connection: GatewayConnection = new GatewayConnection();
  private chatService: ChatService = new ChatService(this.connection);
  private settingsStore: SettingsStore = new SettingsStore();
  private scroller: Scroller = new Scroller();
  private inited: boolean = false;

  async aboutToAppear(): Promise<void> {
    if (this.inited) {
      return;
    }
    this.inited = true;

    const uiContext = this.getUIContext();
    const hostContext = uiContext.getHostContext();
    if (hostContext !== undefined) {
      await this.settingsStore.init(hostContext as common.UIAbilityContext);
    }

    this.gatewayUrl = await this.settingsStore.getGatewayUrl();
    this.settingsUrl = this.gatewayUrl;
    this.settingsAutoReconnect = await this.settingsStore.getAutoReconnect();

    this.connection.updateUrl(this.gatewayUrl);
    this.connection.setAutoReconnect(this.settingsAutoReconnect);

    this.connection.onStateChange((state: ConnState): void => {
      this.connState = state;
    });

    this.chatService.onMessage((msg: ChatMessage): void => {
      const arr: MessageItem[] = [];
      for (let i = 0; i < this.messages.length; i++) {
        arr.push(this.messages[i]);
      }
      arr.push(msg);
      this.messages = arr;
      this.scrollToBottom();
    });

    this.chatService.onStream((delta: string, isFinal: boolean): void => {
      if (isFinal) {
        this.isStreaming = false;
        this.streamingText = '';
      } else {
        this.isStreaming = true;
        this.streamingText = this.streamingText + delta;
        this.scrollToBottom();
      }
    });

    // Handle tool call events
    this.chatService.onToolCall((toolCall: ToolCallMessage): void => {
      const arr: MessageItem[] = [];
      for (let i = 0; i < this.messages.length; i++) {
        arr.push(this.messages[i]);
      }
      arr.push(toolCall);
      this.messages = arr;
      this.scrollToBottom();
    });

    // Handle tool result events
    this.chatService.onToolResult((toolResult: ToolResultMessage): void => {
      const arr: MessageItem[] = [];
      for (let i = 0; i < this.messages.length; i++) {
        arr.push(this.messages[i]);
      }
      arr.push(toolResult);
      this.messages = arr;
      this.scrollToBottom();
    });

    this.connection.connect();
  }

  aboutToDisappear(): void {
    this.connection.disconnect();
  }

  scrollToBottom(): void {
    if (this.messages.length > 0) {
      this.scroller.scrollToIndex(this.messages.length - 1, true);
    }
  }

  build() {
    Stack() {
      Column() {
        // 顶部栏
        Row() {
          Text('Newma Chat')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor('#212121')

          Blank()

          Button() {
            Text('⚙')
              .fontSize(22)
          }
          .width(40)
          .height(40)
          .type(ButtonType.Circle)
          .backgroundColor(Color.Transparent)
          .onClick((): void => {
            this.showSettings = true;
            this.settingsUrl = this.connection.getUrl();
            this.settingsAutoReconnect = this.connection.isAutoReconnect();
          })
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 8 })
        .backgroundColor('#FFFFFF')

        // 连接状态
        ConnectionStatus({ state: this.connState as number, gatewayUrl: this.gatewayUrl })

        // 消息列表
        List({ space: 4 }) {
          ForEach(this.messages, (msg: MessageItem, index?: number) => {
            ListItem() {
              if (msg.role === 'tool_call') {
                const tc = msg as ToolCallMessage;
                MessageBubble({
                  message: tc.toolArgs,
                  isUser: false,
                  isSystem: false,
                  isToolCall: true,
                  toolName: tc.toolName
                })
              } else if (msg.role === 'tool_result') {
                const tr = msg as ToolResultMessage;
                MessageBubble({
                  message: tr.result,
                  isUser: false,
                  isSystem: false,
                  isToolResult: true,
                  toolName: tr.toolName
                })
              } else {
                const cm = msg as ChatMessage;
                MessageBubble({
                  message: cm.content,
                  isUser: cm.role === 'user',
                  isSystem: cm.role === 'system'
                })
              }
            }
          }, (msg: MessageItem, index?: number): string => {
            if (msg.id !== undefined) {
              return msg.id;
            }
            if (index !== undefined) {
              return `msg-${index}`;
            }
            return 'msg-unknown';
          })

          if (this.isStreaming && this.streamingText.length > 0) {
            ListItem() {
              MessageBubble({
                message: this.streamingText + '▊',
                isUser: false,
                isStreaming: true
              })
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Auto)
        .alignListItem(ListItemAlign.Start)
        .edgeEffect(EdgeEffect.Spring)
        .backgroundColor('#F5F5F5')

        // 输入栏
        InputBar({
          isEnabled: this.connState === ConnState.CONNECTED,
          onSend: (text: string): void => {
            this.chatService.sendMessage(text);
          }
        })
      }
      .width('100%')
      .height('100%')

    }
    .width('100%')
    .height('100%')

    // 设置弹窗 - 使用 bindSheet
    .bindSheet($$this.showSettings, this.SettingsPanelBuilder(), {
      height: SheetSize.FIT_CONTENT,
      dragBar: true,
      backgroundColor: Color.White,
      onDisappear: (): void => {
        // dismissed
      }
    })
  }

  @Builder
  SettingsPanelBuilder() {
    Column({ space: 16 }) {
        Row() {
          Text('设置')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
          Blank()
          Button() {
            Text('✕')
              .fontSize(20)
              .fontColor('#757575')
          }
          .type(ButtonType.Circle)
          .backgroundColor(Color.Transparent)
          .onClick((): void => {
            this.showSettings = false;
          })
        }
        .width('100%')
        .padding({ left: 20, right: 12, top: 16, bottom: 8 })

        Divider()

        Column({ space: 8 }) {
          Text('Gateway 地址')
            .fontSize(14)
            .fontColor('#757575')
          TextInput({ text: this.settingsUrl, placeholder: 'ws://host:port' })
            .width('100%')
            .fontSize(16)
            .onChange((value: string): void => {
              this.settingsUrl = value;
            })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 20, right: 20 })

        Row() {
          Text('自动重连')
            .fontSize(16)
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.settingsAutoReconnect })
            .onChange((isOn: boolean): void => {
              this.settingsAutoReconnect = isOn;
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20 })

        Button('清空聊天记录')
          .width('100%')
          .fontSize(16)
          .fontColor('#C62828')
          .backgroundColor('#FFEBEE')
          .margin({ left: 20, right: 20 })
          .onClick((): void => {
            this.chatService.clearMessages();
            this.messages = [];
          })

        Button('保存并重连')
          .width('100%')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .type(ButtonType.Capsule)
          .margin({ left: 20, right: 20, bottom: 20 })
          .onClick(async (): Promise<void> => {
            const url = this.settingsUrl.trim();
            if (url.length > 0) {
              await this.settingsStore.setGatewayUrl(url);
              await this.settingsStore.setAutoReconnect(this.settingsAutoReconnect);
              this.gatewayUrl = url;
              this.connection.updateUrl(url);
              this.connection.setAutoReconnect(this.settingsAutoReconnect);
              this.connection.disconnect();
              this.connection.connect();
            }
            this.showSettings = false;
          })

        Text('版本 1.0.0 · HarmonyOS 原生')
          .fontSize(12)
          .fontColor('#9E9E9E')
          .margin({ bottom: 20 })
      }
      .width('100%')
      .padding({ top: 4, left: 20, right: 20, bottom: 30 })
      .alignItems(HorizontalAlign.Start)
  }
}
