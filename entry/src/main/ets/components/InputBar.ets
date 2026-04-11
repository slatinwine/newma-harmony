@Component
export struct InputBar {
  @State inputText: string = '';
  @Prop isEnabled: boolean = false;
  onSend?: (text: string) => void;

  build() {
    Row({ space: 8 }) {
      TextInput({ placeholder: '输入消息...', text: this.inputText })
        .layoutWeight(1)
        .height(44)
        .borderRadius(22)
        .backgroundColor('#F5F5F5')
        .placeholderColor('#9E9E9E')
        .fontSize(16)
        .padding({ left: 16, right: 16 })
        .onChange((value: string) => {
          this.inputText = value;
        })
        .onSubmit(() => {
          this.doSend();
        })

      Button('发送')
        .width(64)
        .height(40)
        .fontSize(15)
        .fontWeight(FontWeight.Medium)
        .borderRadius(20)
        .type(ButtonType.Capsule)
        .backgroundColor(this.isEnabled && this.inputText.length > 0 ? '#1976D2' : '#BDBDBD')
        .fontColor(Color.White)
        .enabled(this.isEnabled && this.inputText.length > 0)
        .onClick(() => {
          this.doSend();
        })
    }
    .width('100%')
    .padding({ left: 12, right: 12, top: 8, bottom: 8 })
    .backgroundColor('#FFFFFF')
    .shadow({
      radius: 4,
      color: '#00000012',
      offsetX: 0,
      offsetY: -2,
    })
  }

  private doSend(): void {
    const text = this.inputText.trim();
    if (text.length > 0 && this.isEnabled) {
      if (this.onSend) {
        this.onSend(text);
      }
      this.inputText = '';
    }
  }
}
