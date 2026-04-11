@Component
export struct ConnectionStatus {
  @Prop state: number; // ConnState enum value
  @Prop gatewayUrl: string = '';

  build() {
    Row({ space: 8 }) {
      // 状态指示灯
      if (this.state === 2) {
        // Connected
        Circle({ width: 10, height: 10 })
          .fill('#4CAF50')
      } else if (this.state === 1) {
        // Connecting
        LoadingProgress()
          .width(16)
          .height(16)
          .color('#FF9800')
      } else {
        // Disconnected
        Circle({ width: 10, height: 10 })
          .fill('#F44336')
      }

      Text(this.state === 2 ? '已连接' : (this.state === 1 ? '连接中...' : '未连接'))
        .fontSize(14)
        .fontColor(this.state === 2 ? '#2E7D32' : (this.state === 1 ? '#E65100' : '#C62828'))
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 10, bottom: 10 })
    .backgroundColor(this.state === 2 ? '#E8F5E9' : (this.state === 1 ? '#FFF3E0' : '#FFEBEE'))
  }
}
