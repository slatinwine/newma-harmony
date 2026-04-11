# HarmonyNewma

Newma AI 聊天助手的原生鸿蒙实现。

## 架构

```
┌─────────────────┐         WebSocket         ┌──────────────────┐
│  HarmonyOS App  │ ◄─────────────────────► │   Gateway Server  │
│  (ArkTS)        │                            │  (Port 18789)    │
└─────────────────┘                            └────────┬─────────┘
                                                         │
                                                         ▼
                                                  ┌─────────────┐
                                                  │  AI Backend  │
                                                  │  (Newma/API) │
                                                  └─────────────┘
```

## 项目结构

```
harmonynewma/
├── entry/src/main/ets/
│   ├── entryability/EntryAbility.ets   # 应用入口
│   ├── pages/Index.ets                # 主聊天页面
│   ├── services/
│   │   ├── GatewayConnection.ets      # WebSocket 连接管理
│   │   ├── ChatService.ets            # 聊天业务逻辑
│   │   └── SettingsStore.ets          # 设置持久化
│   ├── components/
│   │   ├── MessageBubble.ets          # 消息气泡
│   │   ├── ConnectionStatus.ets       # 连接状态指示器
│   │   └── InputBar.ets               # 输入栏
│   └── model/GatewayTypes.ets         # 类型定义
```

## 开发

1. 用 DevEco Studio 打开项目
2. 连接鸿蒙设备或启动模拟器
3. 运行

## 协议

与 mobilenewma 的 Gateway 使用相同的 WebSocket 协议：
- challenge → connect 握手
- req/res 请求响应
- event 流式推送
