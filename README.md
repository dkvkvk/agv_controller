# AGV Controller — 仓储 AGV 蓝牙上位机

基于 Flutter 开发的 Android 蓝牙上位机，用于控制和监控 STM32G474 驱动的仓储 AGV 小车。

## 功能

| 页面 | 功能 |
|------|------|
| 🔗 蓝牙连接 | 扫描已配对设备 · 连接/断开 HC-05 · 连接状态指示 |
| 🎮 手动控制 | 虚拟摇杆 · 速度滑块 · 模式切换 · 紧急停止 |
| 📊 状态监控 | 5路传感器 · 四轮速度仪表盘 · 误差趋势图 · 运行状态 |
| ⚙️ 参数设置 | 调节 BASE_SPEED / TURN_GAIN / MAX_SPEED / MIN_SPEED · 读取/下发/保存预设 |
| 📝 调试终端 | 原始收发日志 · 快捷命令 · 自定义命令输入 |

## 硬件要求

- STM32G474VET6 + HC-05 蓝牙模块
- USART1, 9600bps, 8N1
- 通信协议：ASCII 文本，`\r\n` 结尾

## 构建 APK

本项目通过 **GitHub Actions** 自动构建。

1. 将代码推送到 GitHub 仓库
2. 进入 **Actions** 页面
3. 找到最新的 workflow run
4. 下载 **AGV-Controller-APK** artifact
5. 解压后安装 `app-release.apk` 到手机

也可以手动触发构建：Actions → Build AGV Controller APK → Run workflow

## 通信协议

```
C           — 切换运行/停止
M:0 / M:1   — 自动/手动模式
F:<speed>   — 前进
B:<speed>   — 后退
L:<spd>,<g> — 左转
R:<spd>,<g> — 右转
S           — 停止
V1~V4:<val> — 设置参数
Q           — 查询全状态(JSON)
QP/QS/QM    — 查询参数/传感器/模式
AR:1 / AR:0 — 自动上报 开/关
```

## 项目结构

```
agv_controller/
├── lib/
│   ├── main.dart              # 入口 + 主题
│   ├── models/
│   │   └── agv_state.dart     # AGV 状态数据模型
│   ├── services/
│   │   ├── bluetooth_service.dart  # 蓝牙连接管理
│   │   └── protocol_service.dart   # 协议解析/命令构建
│   ├── pages/
│   │   ├── connection_page.dart
│   │   ├── control_page.dart
│   │   ├── monitor_page.dart
│   │   ├── settings_page.dart
│   │   └── terminal_page.dart
│   └── widgets/
│       ├── joystick_widget.dart
│       ├── sensor_bar.dart
│       ├── speed_gauge.dart
│       ├── connection_indicator.dart
│       └── direction_pad.dart
├── pubspec.yaml
└── .github/workflows/build.yml
```
