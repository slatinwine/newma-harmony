@Component
export struct MessageBubble {
  @Prop message: string;
  @Prop isUser: boolean = false;
  @Prop isSystem: boolean = false;
  @Prop isStreaming: boolean = false;
  @Prop isToolCall: boolean = false;
  @Prop isToolResult: boolean = false;
  @Prop toolName: string = '';

  // Get display text for tool call
  getToolCallText(): string {
    if (this.toolName === 'web_search') {
      return '正在搜索网络...';
    } else if (this.toolName === 'get_weather') {
      return '正在获取天气...';
    } else if (this.toolName === 'calculator') {
      return '正在计算...';
    }
    return `正在调用 ${this.toolName}...`;
  }

  // Get icon for tool
  getToolIcon(): string {
    if (this.isToolCall) {
      return '🔧';
    } else if (this.isToolResult) {
      return '✅';
    }
    return '🤖';
  }

  build() {
    Row() {
      // Tool call/result or assistant icon
      if (this.isToolCall || this.isToolResult) {
        Column() {
          Text(this.getToolIcon())
            .fontSize(18)
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor(this.isToolCall ? '#FFF3E0' : '#E8F5E9')
        .justifyContent(FlexAlign.Center)
        .margin({ right: 8 })
      } else if (!this.isUser && !this.isSystem) {
        Column() {
          Text('🤖')
            .fontSize(20)
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor('#E8EAF6')
        .justifyContent(FlexAlign.Center)
        .margin({ right: 8 })
      }

      Column() {
        if (this.isSystem) {
          Text(this.message)
            .fontSize(13)
            .fontColor('#C62828')
            .textAlign(TextAlign.Center)
        } else if (this.isToolCall) {
          Text(this.getToolCallText())
            .fontSize(14)
            .fontColor('#E65100')
            .fontWeight(FontWeight.Medium)
          if (this.message.length > 0) {
            Text(this.message)
              .fontSize(12)
              .fontColor('#757575')
              .margin({ top: 4 })
          }
        } else if (this.isToolResult) {
          Text(this.message)
            .fontSize(14)
            .fontColor('#212121')
            .lineHeight(22)
            .wordBreak(WordBreak.BREAK_ALL)
        } else {
          Text(this.message)
            .fontSize(16)
            .fontColor(this.isUser ? '#FFFFFF' : '#212121')
            .lineHeight(24)
            .wordBreak(WordBreak.BREAK_ALL)
        }
      }
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .constraintSize({ maxWidth: '75%' })
      .borderRadius(this.isUser ? { topLeft: 4, topRight: 16, bottomLeft: 16, bottomRight: 16 } :
        { topLeft: 16, topRight: 4, bottomLeft: 16, bottomRight: 16 })
      .backgroundColor(this.isSystem ? '#FFEBEE' :
        (this.isUser ? '#1976D2' :
          (this.isToolCall ? '#FFF3E0' :
            (this.isToolResult ? '#E8F5E9' : '#FFFFFF'))))
      .shadow({ radius: 2, color: '#1A000000', offsetX: 0, offsetY: 1 })
      .alignItems(this.isUser ? HorizontalAlign.End : HorizontalAlign.Start)

      if (this.isUser) {
        Column() {
          Text('👤')
            .fontSize(20)
        }
        .width(36)
        .height(36)
        .borderRadius(18)
        .backgroundColor('#BBDEFB')
        .justifyContent(FlexAlign.Center)
        .margin({ left: 8 })
      }
    }
    .width('100%')
    .justifyContent(this.isUser ? FlexAlign.End : FlexAlign.Start)
    .padding({ left: 12, right: 12, top: 4, bottom: 4 })
  }
}
