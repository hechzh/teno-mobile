# JWD SDK 接入记录

来源：用户提供的 `JWD-VTR录音卡协议&SDK_20261027/JwdVTRSample`，SDK 文档 v1.1.3；命令基线为 `JWD-VTR录音笔&app通信协议_20261022.xlsx` V1.1。

厂商原资料目录未修改。以下文件按原样复制到当前工程，原始代码与二进制归属厂商：

- `opusdecodelib/src/main/java/com/actions/asc/jni/ASCDecoder.java` → `app/src/main/java/com/actions/asc/jni/ASCDecoder.java`
- `opusdecodelib/src/main/jniLibs/arm64-v8a/*.so` → `app/src/main/jniLibs/arm64-v8a/`
- `opusdecodelib/src/main/jniLibs/armeabi-v7a/*.so` → `app/src/main/jniLibs/armeabi-v7a/`

逐文件 SHA256 对照见 `verification/jwd-0.2.0/vendor-file-hashes.json`。此交付用于用户的本地硬件内测；没有把厂商完整 Demo、旧逆向目录或本地私密配置放入源码包。

`JwdBle` 按 SDK 的 GATT UUID 和订阅顺序实现独立的串行通信层；`JwdProtocol` 使用 SDK `ProtocolClient` 相同的 ASCII 指令编码；`JwdService` 按 `ReplyParser` 和协议表接收状态与文件。没有把 SDK 中其他产品功能、固定绑定密钥或未使用的 Wi-Fi/OTA 代码引入 App。

接入时处理了 SDK 示例中的这些问题：

- 两个 CCCD 的成功回调全部完成后再授权；不在第二个通知仍写入时报告连接就绪。
- GATT 写操作串行，并按 Demo 注释保留约 850 ms 的指令间隔；连接/写入/授权均有超时。
- 断连清理状态，忽略旧 GATT 对象的迟到回调，取消传输后必须重连。
- 正确解析空闲 `MCU&RT&0`、`MCU&U&ERR`、充电态和文件列表计数。
- 收齐声明长度并收到 `MCU&OFF` 才结束；兼容结束指令先于末批音频到达，CRC 错误不得登记 draft。
- `JwdAudio` 复用厂商 `ASCDecoder.ASC_VI`，按 80 字节 Opus 包解码为 16 kHz、单声道 PCM16 WAV；每帧必须输出 320 个采样，不跳过坏帧，不用截断后的音频报告成功。

当前二进制只有 ARM64/ARMv7。验证环境为 API 35 模拟器的 ARM 转译，实机目标为用户的 Android 12。没有宣称原厂二进制兼容所有新版本 Android 或 16 KiB 页大小设备。

平台依据：[Android 蓝牙权限](https://developer.android.com/develop/connectivity/bluetooth/bt-permissions)、[connectedDevice 前台服务](https://developer.android.com/develop/background-work/services/fgs/service-types#connected-device)、[Android 原生库页大小要求](https://developer.android.com/guide/practices/page-sizes)。

## 0.2.1 识别与 PIN 诊断

设备名称候选来自 `app/src/main/java/com/jwd/recorder/constant/Constant.java` 和 `ui/scan/ScanBtFragment.kt`；名称只是线索，未确认服务时不显示连接按钮。兼容扫描使用原 Demo `BleManager.discover()` 的 `BluetoothAdapter.startDiscovery()`，仍在 App 内通过 GATT 核验服务，不调用 `createBond`。

只读 probe 完成服务发现后立即关闭 GATT，不订阅通知、不发送 `APP&SK`、不生成绑定密钥。系统可能对受保护的操作要求配对；新增 `ACTION_PAIRING_REQUEST` 监听只记录请求类型、流程阶段与服务核验状态，不读取 `EXTRA_PAIRING_KEY`，不猜测/填写/确认 PIN。平台参考：[Android 配对请求](https://developer.android.com/reference/android/bluetooth/BluetoothDevice#ACTION_PAIRING_REQUEST)、[广播服务 UUID](https://developer.android.com/reference/android/bluetooth/le/ScanRecord#getServiceUuids())。

SGMf91a73 不在所给 SDK 的名称示例中，但名称不同并不能单独证明它不是 JWD；保留展开其他设备后只读探测的入口。此修正没有证明用户实际录音卡的 PIN 问题已解决。
