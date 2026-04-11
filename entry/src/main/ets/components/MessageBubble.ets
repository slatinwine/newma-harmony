@Component
export struct MessageBubble {
  @Prop message: string;
  @Prop isUser: boolean = false;
  @Prop isSystem: boolean = false;
  @Prop isStreaming: boolean = false;

  build() {
    Row() {
      if (!this.isUser && !this.isSystem) {
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
      .backgroundColor(this.isSystem ? '#FFEBEE' : (this.isUser ? '#1976D2' : '#FFFFFF'))
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
