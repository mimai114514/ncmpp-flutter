# NCM 解密器 Flutter 版 - 项目结构与功能总结

## 项目概述

本项目是一个 **网易云音乐 NCM 格式文件解密器**，使用 Flutter 框架开发，支持 **Windows** 和 **Android** 平台。项目基于开源项目 [ncmpp](https://github.com/Majjcom/ncmpp) 的解密逻辑改写。

---

## 技术栈

| 技术 | 用途 |
|------|------|
| **Flutter** | 跨平台 UI 框架 |
| **Dart SDK ^3.10.4** | 开发语言 |
| **pointycastle** | 纯 Dart AES 加密库 |
| **file_picker** | 文件/目录选择 |
| **permission_handler** | Android 权限管理 |
| **shared_preferences** | 设置持久化存储 |
| **url_launcher** | 打开外部应用/链接 |

---

## 项目结构

```
ncmpp-flutter/
├── lib/                          # Dart 源代码目录
│   ├── main.dart                 # 应用入口
│   ├── src/
│   │   ├── core/
│   │   │   └── ncm_dump.dart     # 解密核心（纯 Dart 实现）
│   │   ├── ffi/
│   │   │   └── ncm_decoder.dart  # 解密器服务封装
│   │   ├── models/
│   │   │   └── ncm_file.dart     # NCM 文件数据模型
│   │   ├── screens/
│   │   │   ├── home_screen.dart  # 主界面
│   │   │   └── settings_screen.dart # 设置页面
│   │   └── services/
│   │       └── settings_service.dart # 设置服务
│   └── widgets/
│       └── progress_card.dart    # 进度卡片组件
├── native/                       # 原生代码（已弃用，使用纯 Dart 实现）
│   ├── CMakeLists.txt
│   ├── ncm_ffi.cpp
│   ├── ncm_ffi.h
│   └── ncmlib/                   # C++ 解密库
├── android/                      # Android 平台配置
├── windows/                      # Windows 平台配置
├── pubspec.yaml                  # 项目依赖配置
└── README.md                     # 项目说明
```

---

## 核心模块详解

### 1. 解密核心 (`lib/src/core/ncm_dump.dart`)

**功能**：实现 NCM 文件的完整解密流程

**实现细节**：
- **纯 Dart 实现**：使用 `pointycastle` 库进行 AES-ECB 解密，无需原生依赖
- **解密流程**：
  1. 验证 NCM 文件魔数 (`CTENFDAM`)
  2. 读取并解密密钥数据（XOR 0x64 + AES-ECB）
  3. 构建 RC4 变种 KeyBox
  4. 读取并解密元数据（XOR 0x63 + Base64 + AES-ECB）
  5. 解密音频数据并写入输出文件

**关键类**：
- `NcmDump`：解密核心类
- `_ByteReader`：字节流读取器辅助类

---

### 2. 解密器服务 (`lib/src/ffi/ncm_decoder.dart`)

**功能**：提供高层封装，支持后台解密和批量处理

**特性**：
- **Isolate 后台解密**：使用 `compute()` 在独立 Isolate 中执行解密，避免阻塞 UI
- **批量处理**：支持目录扫描和并行解密（可配置并发数 1-16）
- **进度回调**：通过 Stream 实时报告解密进度

**关键类**：
- `NcmDecoder`：单例服务类
- `DecodeResult`：单个文件解密结果
- `BatchDecodeProgress`：批量解密进度信息

---

### 3. 数据模型 (`lib/src/models/ncm_file.dart`)

**功能**：定义 NCM 文件的数据结构

**字段**：
- `path`：文件路径
- `name`：文件名
- `status`：处理状态（pending/processing/success/failed）
- `outputPath`：输出路径
- `errorMessage`：错误信息

---

### 4. 主界面 (`lib/src/screens/home_screen.dart`)

**功能**：应用的主操作界面

**特性**：
- **响应式布局**：宽屏时并排显示输入/输出目录选择卡片
- **目录选择**：输入目录和输出目录选择
- **文件列表**：显示扫描到的 NCM 文件及其状态
- **进度显示**：实时显示解密进度
- **权限处理**：Android 存储权限请求（支持 Android 11+ MANAGE_EXTERNAL_STORAGE）
- **完成对话框**：
  - 显示解密统计（成功/失败数量、耗时）
  - 可选删除转换成功的源文件
  - 可打开音乐标签编辑器应用

---

### 5. 设置页面 (`lib/src/screens/settings_screen.dart`)

**功能**：应用设置界面

**设置项**：
- **解密线程数**：可调节 1-16 线程，默认为 CPU 核心数
- **关于信息**：显示应用版本和版权声明

---

### 6. 设置服务 (`lib/src/services/settings_service.dart`)

**功能**：设置的持久化存储和读取

**实现**：
- 使用 `shared_preferences` 进行本地存储
- 单例模式，应用启动时初始化
- 提供线程数的存取接口

---

### 7. 进度卡片组件 (`lib/widgets/progress_card.dart`)

**功能**：显示批量解密进度的可复用组件

**显示内容**：
- 进度条（已处理/总数）
- 成功/失败统计
- 当前处理的文件名

---

## 应用特性

- ✅ 批量选择输入文件夹，自动扫描所有 NCM 文件
- ✅ 自定义输出目录
- ✅ 实时显示解密进度
- ✅ 可配置并行解密线程数
- ✅ 支持删除转换成功的源文件
- ✅ 集成音乐标签编辑器快捷入口
- ✅ Material Design 3 界面
- ✅ 支持明暗主题自动切换
- ✅ 支持 Android 7.0+ 和 Windows

---

## 开发状态

> ⚠️ 应用还处于早期开发阶段，预计还将进行大量改动（包括更改安卓版包名）

---

## 许可证

遵循 MIT 许可证，与原 ncmpp 项目保持一致。
