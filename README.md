# NCM Converter

## 简介

一个用于转换网易云音乐 .ncm 格式文件的 Flutter 应用，支持 Windows/Android 平台。

## 特性

- ✅ 对指定文件夹的 .ncm 文件进行批量处理
- ✅ 现代的 Material Design 3 界面
- ✅ 支持 Android 7.0+ / Windows 10+ (64bit)

## 截图
<table>
  <tr>
    <td><img src="https://github.com/user-attachments/assets/abc3d578-ce03-450a-83bc-73be64f4ef02" width=200></td>
    <td><img src="https://github.com/user-attachments/assets/6ac1dd39-6375-4369-b8d9-1950edb6f29a" width=200></td>
    <td><img src="https://github.com/user-attachments/assets/43a4099b-a684-42ca-9f08-b7d1e2beb1ad" width=200></td>
  </tr>
</table>
<table>
  <tr> 
    <td><img src="https://github.com/user-attachments/assets/b7e7e119-a844-45c3-a586-990f114a5155" width=300></td>
    <td><img src="https://github.com/user-attachments/assets/3af443a3-4615-43ec-a6ba-1ee7a2e5d0e6" width=300></td>
  </tr>
</table>


## 性能测试

WIP

## 和 [ncmppGui](https://github.com/Majjcom/ncmppGui) 的对比

本项目使用 Flutter 框架，相比 ncmppGui，本项目具有以下优势：

- 现代的 Material Design 3 界面
- 支持暗色模式
- 使用**原生 File Picker**，选取文件夹的效率大幅提高

*btw，ncmppGui使用的Qt的路径选择器太难用是我开发这个应用的直接诱因*

同时，目前版本的 ncmconverter 的性能在体感上和 ncmppGui 仍有差距，具体的差距有待测试

## 技术栈

- **Flutter** - 跨平台 UI 框架
- **pointycastle** - 纯 Dart AES 加密库

## 参与贡献

我们非常欢迎并感谢任何形式的贡献！欢迎提交 Issue 或 Pull Request，但由于个人能力和经验有限，不一定能及时处理。


## 许可证

本项目采用 **MIT** 许可证开源。详情请参阅 LICENSE 文件。

## 致谢

* 本项目的灵感来源于 [ncmppGui](https://github.com/Majjcom/ncmppGui)
* 本项目的 .ncm 文件处理逻辑改写自 [ncmpp](https://github.com/Majjcom/ncmpp)
