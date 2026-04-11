import { GatewayConnection } from '../services/GatewayConnection';
import { ChatService } from '../services/ChatService';
import { SettingsStore } from '../services/SettingsStore';
import { MessageBubble } from '../components/MessageBubble';
import { ConnectionStatus } from '../components/ConnectionStatus';
import { InputBar } from '../components/InputBar';
import { ChatMessage, ConnState } from '../model/GatewayTypes';

@Entry
@Component
struct Index {
  @State messages: ChatMessage[] = [];
  @State connState: ConnState = ConnState.DISCONNECTED;
  @State streamingText: string = '';
  @State isStreaming: boolean = false;
  @State gatewayUrl: string = 'ws://192.168.31.44:18789';
  @State showSettings: boolean = false;
  @State settingsUrl: string = '';
  @State settingsAutoReconnect: boolean = true;
  @State scrollOffset: number = 0;

  private connection: GatewayConnection = new GatewayConnection();
  private chatService: ChatService = new ChatService(this.connection);
  private settingsStore: SettingsStore = new SettingsStore();
  private scroller: Scroller = new Scroller();
  private aboutToAppearCalled: boolean = false;

  async aboutToAppear(): Promise<void> {
    if (this.aboutToAppearCalled) return;
    this.aboutToAppearCalled = true;

    // 初始化设置存储
    await this.settingsStore.init(getContext(this));

    // 读取保存的配置
    this.gatewayUrl = await this.settingsStore.getGatewayUrl();
    this.settingsUrl = this.gatewayUrl;
    this.settingsAutoReconnect = await this.settingsStore.getAutoReconnect();

    // 更新连接配置
    this.connection.updateConfig({
      url: this.gatewayUrl,
      autoReconnect: this.settingsAutoReconnect,
    });

    // 监听连接状态
    this.connection.onStateChange((state: ConnState) => {
      this.connState = state;
    });

    // 监听消息
    this.chatService.onMessage((msg: ChatMessage) => {
      this.messages = [...this.messages, msg];
      this.scrollToBottom();
    });

    // 监听流式输出
    this.chatService.onStream((delta: string, isFinal: boolean) => {
      if (isFinal) {
        this.isStreaming = false;
        this.streamingText = '';
      } else {
        this.isStreaming = true;
        this.streamingText += delta;
        this.scrollToBottom();
      }
    });

    // 自动连接
    this.connection.connect();
  }

  aboutToDisappear(): void {
    this.connection.disconnect();
  }

  scrollToBottom(): void {
    this.scroller.scrollToIndex(this.messages.length - 1, true);
  }

  build() {
    Stack() {
      // 主界面
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
          .onClick(() => {
            this.showSettings = true;
            this.settingsUrl = this.connection.getConfig().url;
            this.settingsAutoReconnect = this.connection.getConfig().autoReconnect;
          })
        }
        .width('100%')
        .height(56)
        .padding({ left: 16, right: 8 })
        .backgroundColor('#FFFFFF')

        // 连接状态
        ConnectionStatus({ state: this.connState as number, gatewayUrl: this.gatewayUrl })

        // 消息列表
        List({ space: 4, initialIndex: 0 }) {
          ForEach(this.messages, (msg: ChatMessage, index?: number) => {
            ListItem() {
              MessageBubble({
                message: msg.content,
                isUser: msg.role === 'user',
                isSystem: msg.role === 'system',
              })
            }
          }, (msg: ChatMessage, index?: number) => msg.id || index?.toString() || '')

          // 流式消息气泡
          if (this.isStreaming && this.streamingText.length > 0) {
            ListItem() {
              MessageBubble({
                message: this.streamingText + '▊',
                isUser: false,
                isStreaming: true,
              })
            }
          }
        }
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Auto)
        .scroller(this.scroller)
        .alignListItem(ListItemAlign.Start)
        .edgeEffect(EdgeEffect.Spring)
        .backgroundColor('#F5F5F5')

        // 输入栏
        InputBar({
          isEnabled: this.connState === ConnState.CONNECTED,
          onSend: (text: string) => {
            this.chatService.sendMessage(text);
          }
        })
      }
      .width('100%')
      .height('100%')

      // 设置弹窗
      if (this.showSettings) {
        this.SettingsPanel()
      }
    }
    .width('100%')
    .height('100%')
  }

  @Builder
  SettingsPanel() {
    Column() {
      // 遮罩
      Column()
        .width('100%')
        .height('100%')
        .backgroundColor('#80000000')
        .onClick(() => {
          this.showSettings = false;
        })

      // 设置面板（从底部弹出）
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
          .onClick(() => {
            this.showSettings = false;
          })
        }
        .width('100%')
        .padding({ left: 20, right: 12, top: 16, bottom: 8 })

        Divider()

        // Gateway URL
        Column({ space: 8 }) {
          Text('Gateway 地址')
            .fontSize(14)
            .fontColor('#757575')
          TextInput({ text: this.settingsUrl, placeholder: 'ws://host:port' })
            .width('100%')
            .fontSize(16)
            .onChange((value: string) => {
              this.settingsUrl = value;
            })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 20, right: 20 })

        // 自动重连开关
        Row() {
          Text('自动重连')
            .fontSize(16)
            .layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.settingsAutoReconnect })
            .onChange((isOn: boolean) => {
              this.settingsAutoReconnect = isOn;
            })
        }
        .width('100%')
        .padding({ left: 20, right: 20 })

        // 清空聊天
        Button('清空聊天记录')
          .width('100%')
          .fontSize(16)
          .fontColor('#C62828')
          .backgroundColor('#FFEBEE')
          .margin({ left: 20, right: 20 })
          .onClick(() => {
            this.chatService.clearMessages();
            this.messages = [];
          })

        // 保存并重连
        Button('保存并重连')
          .width('100%')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .type(ButtonType.Capsule)
          .margin({ left: 20, right: 20, bottom: 20 })
          .onClick(async () => {
            const url = this.settingsUrl.trim();
            if (url.length > 0) {
              await this.settingsStore.setGatewayUrl(url);
              await this.settingsStore.setAutoReconnect(this.settingsAutoReconnect);
              this.gatewayUrl = url;
              this.connection.updateConfig({
                url: url,
                autoReconnect: this.settingsAutoReconnect,
              });
              this.connection.disconnect();
              this.connection.connect();
            }
            this.showSettings = false;
          })

        // 版本信息
        Text('版本 1.0.0 · HarmonyOS 原生')
          .fontSize(12)
          .fontColor('#9E9E9E')
          .margin({ bottom: 20 })
      }
      .width('100%')
      .borderRadius({ topLeft: 20, topRight: 20 })
      .backgroundColor('#FFFFFF')
      .padding({ top: 4 })
      .alignItems(HorizontalAlign.Center)
    }
    .width('100%')
    .height('100%')
    .position({ x: 0, y: 0 })
  }
}
