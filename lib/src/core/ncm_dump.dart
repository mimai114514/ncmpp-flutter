/// NCM 文件解密器 - 纯 Dart 实现
/// 无需原生依赖，使用 pointycastle 进行 AES 解密

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:pointycastle/pointycastle.dart';

/// NCM 解密核心类
class NcmDump {
  // 加密密钥（十六进制）
  static const String _coreKeyHex = '687A4852416D736F356B496E62617857';
  static const String _metaKeyHex = '2331346C6A6B5F215C5D2630553C2728';

  // NCM 文件魔数
  static final Uint8List _ncmMagic = Uint8List.fromList([
    0x43, 0x54, 0x45, 0x4E, 0x46, 0x44, 0x41, 0x4D, // CTENFDAM
  ]);

  late Uint8List _coreKey;
  late Uint8List _metaKey;

  NcmDump() {
    _coreKey = _hexToBytes(_coreKeyHex);
    _metaKey = _hexToBytes(_metaKeyHex);
  }

  /// 解密 NCM 文件
  /// 返回 (成功, 输出路径, 错误信息)
  Future<(bool, String, String?)> decode(
    String inputPath,
    String outputDir,
  ) async {
    try {
      final file = File(inputPath);
      if (!await file.exists()) {
        return (false, '', '文件不存在: $inputPath');
      }

      final bytes = await file.readAsBytes();
      final reader = _ByteReader(bytes);

      // 验证魔数
      final magic = reader.read(8);
      if (!_listEquals(magic, _ncmMagic)) {
        return (false, '', '无效的 NCM 文件格式');
      }

      // 跳过 2 字节
      reader.skip(2);

      // 读取并解密密钥
      final keyLength = reader.readLittleEndianUint32();
      final keyData = reader.read(keyLength);

      // XOR 0x64
      for (var i = 0; i < keyData.length; i++) {
        keyData[i] ^= 0x64;
      }

      // AES-ECB 解密
      final decryptedKey = _aesEcbDecrypt(keyData, _coreKey);
      final unpaddedKey = _pkcs7Unpad(decryptedKey);

      // 跳过 "neteasecloudmusic" 前缀 (17 bytes)
      final keyBox = _buildKeyBox(unpaddedKey.sublist(17));

      // 读取元数据
      final metaLength = reader.readLittleEndianUint32();
      final metaData = reader.read(metaLength);

      // XOR 0x63
      for (var i = 0; i < metaData.length; i++) {
        metaData[i] ^= 0x63;
      }

      // 跳过 "163 key(Don't modify):" 前缀 (22 bytes)，Base64 解码
      final metaBase64 = utf8.decode(metaData.sublist(22));
      final metaEncrypted = base64.decode(metaBase64);

      // AES-ECB 解密元数据
      final metaDecrypted = _aesEcbDecrypt(metaEncrypted, _metaKey);
      final metaUnpadded = _pkcs7Unpad(metaDecrypted);

      // 跳过 "music:" 前缀 (6 bytes)，解析 JSON
      final metaJson = utf8.decode(metaUnpadded.sublist(6));
      final metadata = json.decode(metaJson) as Map<String, dynamic>;

      // 跳过 CRC 和专辑图片
      reader.skip(4 + 5);
      final imageLength = reader.readLittleEndianUint32();
      reader.skip(imageLength);

      // 获取输出格式
      final format = metadata['format'] as String? ?? 'mp3';

      // 构建输出路径
      final inputFileName = inputPath.split(RegExp(r'[/\\]')).last;
      final baseName = inputFileName.replaceAll(
        RegExp(r'\.ncm$', caseSensitive: false),
        '',
      );
      var outputPath = outputDir;
      if (!outputPath.endsWith('/') && !outputPath.endsWith('\\')) {
        outputPath += Platform.pathSeparator;
      }
      outputPath += '$baseName.$format';

      // 解密音频数据
      final audioData = reader.readRemaining();
      for (var i = 0; i < audioData.length; i++) {
        final j = (i + 1) & 0xff;
        audioData[i] ^=
            keyBox[(keyBox[j] + keyBox[(keyBox[j] + j) & 0xff]) & 0xff];
      }

      // 写入文件
      final outputFile = File(outputPath);
      await outputFile.writeAsBytes(audioData);

      return (true, outputPath, null);
    } catch (e) {
      return (false, '', '解密失败: $e');
    }
  }

  /// 流式解密 NCM 文件
  /// 使用流式 I/O 减少内存占用，适合大文件
  /// [bufferSize] 缓冲区大小，默认 64KB
  /// [flushInterval] 刷新间隔，每 N 个块刷新一次，默认 8
  /// 返回 (成功, 输出路径, 错误信息)
  Future<(bool, String, String?)> decodeStreaming(
    String inputPath,
    String outputDir, {
    int bufferSize = 65536, // 64KB 缓冲区
    int flushInterval = 8, // 每 8 块刷新一次
  }) async {
    RandomAccessFile? raf;
    IOSink? outputSink;

    try {
      final file = File(inputPath);
      if (!await file.exists()) {
        return (false, '', '文件不存在: $inputPath');
      }

      raf = await file.open(mode: FileMode.read);

      // 验证魔数
      final magic = await raf.read(8);
      if (!_listEquals(Uint8List.fromList(magic), _ncmMagic)) {
        await raf.close();
        return (false, '', '无效的 NCM 文件格式');
      }

      // 跳过 2 字节
      await raf.setPosition(await raf.position() + 2);

      // 读取并解密密钥
      final keyLengthBytes = await raf.read(4);
      final keyLength = _readLittleEndianUint32(
        Uint8List.fromList(keyLengthBytes),
      );
      final keyData = Uint8List.fromList(await raf.read(keyLength));

      // XOR 0x64
      for (var i = 0; i < keyData.length; i++) {
        keyData[i] ^= 0x64;
      }

      // AES-ECB 解密
      final decryptedKey = _aesEcbDecrypt(keyData, _coreKey);
      final unpaddedKey = _pkcs7Unpad(decryptedKey);

      // 跳过 "neteasecloudmusic" 前缀 (17 bytes)
      final keyBox = _buildKeyBox(unpaddedKey.sublist(17));

      // 读取元数据
      final metaLengthBytes = await raf.read(4);
      final metaLength = _readLittleEndianUint32(
        Uint8List.fromList(metaLengthBytes),
      );
      final metaData = Uint8List.fromList(await raf.read(metaLength));

      // XOR 0x63
      for (var i = 0; i < metaData.length; i++) {
        metaData[i] ^= 0x63;
      }

      // 跳过 "163 key(Don't modify):" 前缀 (22 bytes)，Base64 解码
      final metaBase64 = utf8.decode(metaData.sublist(22));
      final metaEncrypted = base64.decode(metaBase64);

      // AES-ECB 解密元数据
      final metaDecrypted = _aesEcbDecrypt(metaEncrypted, _metaKey);
      final metaUnpadded = _pkcs7Unpad(metaDecrypted);

      // 跳过 "music:" 前缀 (6 bytes)，解析 JSON
      final metaJson = utf8.decode(metaUnpadded.sublist(6));
      final metadata = json.decode(metaJson) as Map<String, dynamic>;

      // 跳过 CRC 和间隔
      await raf.setPosition(await raf.position() + 4 + 5);

      // 跳过图片
      final imageLengthBytes = await raf.read(4);
      final imageLength = _readLittleEndianUint32(
        Uint8List.fromList(imageLengthBytes),
      );
      await raf.setPosition(await raf.position() + imageLength);

      // 获取输出格式
      final format = metadata['format'] as String? ?? 'mp3';

      // 构建输出路径
      final inputFileName = inputPath.split(RegExp(r'[/\\]')).last;
      final baseName = inputFileName.replaceAll(
        RegExp(r'\.ncm$', caseSensitive: false),
        '',
      );
      var outputPath = outputDir;
      if (!outputPath.endsWith('/') && !outputPath.endsWith('\\')) {
        outputPath += Platform.pathSeparator;
      }
      outputPath += '$baseName.$format';

      // 记录音频数据起始位置和总长度
      final audioStartPos = await raf.position();
      final fileLength = await file.length();
      final audioLength = fileLength - audioStartPos;

      // 创建输出文件
      final outputFile = File(outputPath);
      outputSink = outputFile.openWrite();

      // 流式解密音频数据
      final buffer = Uint8List(bufferSize);
      var globalOffset = 0;
      var remaining = audioLength;
      var chunkCount = 0; // 块计数器

      while (remaining > 0) {
        final toRead = remaining > bufferSize ? bufferSize : remaining;
        final bytesRead = await raf.readInto(buffer, 0, toRead);

        if (bytesRead == 0) break;

        // 解密当前块
        for (var i = 0; i < bytesRead; i++) {
          final j = (globalOffset + i + 1) & 0xff;
          buffer[i] ^=
              keyBox[(keyBox[j] + keyBox[(keyBox[j] + j) & 0xff]) & 0xff];
        }

        // 写入输出
        outputSink.add(Uint8List.sublistView(buffer, 0, bytesRead));

        globalOffset += bytesRead;
        remaining -= bytesRead;
        chunkCount++;

        // 定期刷新以防止内存累积
        if (chunkCount % flushInterval == 0) {
          await outputSink.flush();
        }
      }

      // 刷新并关闭
      await outputSink.flush();
      await outputSink.close();
      outputSink = null;

      await raf.close();
      raf = null;

      return (true, outputPath, null);
    } catch (e) {
      // 清理资源
      await outputSink?.close();
      await raf?.close();
      return (false, '', '流式解密失败: $e');
    }
  }

  /// 从字节数组读取小端序 uint32
  int _readLittleEndianUint32(Uint8List bytes) {
    return bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
  }

  /// 构建 RC4 变种的 KeyBox
  Uint8List _buildKeyBox(Uint8List key) {
    final box = Uint8List(256);
    for (var i = 0; i < 256; i++) {
      box[i] = i;
    }

    var c = 0;
    var lastByte = 0;
    var keyOffset = 0;

    for (var i = 0; i < 256; i++) {
      final swap = box[i];
      c = (swap + lastByte + key[keyOffset]) & 0xff;
      keyOffset++;
      if (keyOffset >= key.length) {
        keyOffset = 0;
      }
      box[i] = box[c];
      box[c] = swap;
      lastByte = c;
    }

    return box;
  }

  /// AES-ECB 解密
  Uint8List _aesEcbDecrypt(Uint8List data, Uint8List key) {
    final cipher = BlockCipher('AES/ECB');
    cipher.init(false, KeyParameter(key));

    final result = Uint8List(data.length);
    for (var i = 0; i < data.length; i += 16) {
      cipher.processBlock(data, i, result, i);
    }
    return result;
  }

  /// PKCS7 去填充
  Uint8List _pkcs7Unpad(Uint8List data) {
    if (data.isEmpty) return data;
    final padLen = data.last;
    if (padLen > 16 || padLen > data.length) return data;
    return data.sublist(0, data.length - padLen);
  }

  /// 十六进制字符串转字节数组
  Uint8List _hexToBytes(String hex) {
    final result = Uint8List(hex.length ~/ 2);
    for (var i = 0; i < result.length; i++) {
      result[i] = int.parse(hex.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return result;
  }

  /// 比较两个列表是否相等
  bool _listEquals(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// 字节流读取器
class _ByteReader {
  final Uint8List _data;
  int _offset = 0;

  _ByteReader(this._data);

  Uint8List read(int length) {
    final result = Uint8List.sublistView(_data, _offset, _offset + length);
    _offset += length;
    return result;
  }

  void skip(int length) {
    _offset += length;
  }

  int readLittleEndianUint32() {
    final bytes = read(4);
    return bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
  }

  Uint8List readRemaining() {
    final result = Uint8List.sublistView(_data, _offset);
    _offset = _data.length;
    return result;
  }
}
