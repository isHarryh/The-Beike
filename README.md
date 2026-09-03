<!-- 欢迎阅读 The-Beike 说明文档 -->
<!-- 仓库：https://github.com/isHarryh/The-Beike -->

<!--suppress HtmlDeprecatedAttribute -->
<div align="center" style="text-align:center">
   <h1> The-Beike </h1>
   <img alt="The-Beike icon" width="64" src="https://raw.githubusercontent.com/isHarryh/The-Beike/main/android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png">
   <p>The Integrated Campus Assistant for USTB | 大贝壳：北京科技大学校园助手 (The-Beike)</p>
   <p>
      <img alt="GitHub Latest Release" src="https://img.shields.io/github/v/release/isHarryh/The-Beike?display_name=tag&label=Release&sort=semver&include_prereleases">
      <img alt="GitHub Stars" src="https://img.shields.io/github/stars/isHarryh/The-Beike?label=Stars">
   </p>
   <hr>
   <p>
      <img alt="GitHub Top Language" src="https://img.shields.io/github/languages/top/isHarryh/The-Beike?label=Dart">
      <img alt="GitHub License" src="https://img.shields.io/github/license/isHarryh/The-Beike?label=License">
      <img alt="GitHub Workflow Status" src="https://img.shields.io/github/actions/workflow/status/isHarryh/The-Beike/build.yml?label=Build">
   </p>
   <p>
      <a href="https://thebeike.cn?from=readme">🔗官方网站 | Official Website</a>
   </p>
   <sub>
      <i> This project only supports Chinese docs. If you are an English user, feel free to contact us. </i>
   </sub>
</div>

## 介 绍 <sub>Intro</sub>

### 实现的功能

1. 📚**支持北科教务系统相关功能。**  
    可以登录北科本研一体教务账号；可以查课表、选课、查考场和查成绩。
2. 📶**支持北科校园网自助服务系统相关功能。**  
    可以登录北科校园网自助服务账号；可以查询流量使用情况和每月账单详情；可以管理入网设备、修改密码和修改限额。
3. 🔁**支持跨设备同步配置数据。**  
    可以通过配对码来为不同设备上的软件实现配置数据的同步。

### 支持的平台

| Android | Windows | Linux |  MacOS  |   iOS   |
| :-----: | :-----: | :---: | :-----: | :-----: |
|  ✅支持  |  ✅支持  | ✅支持 | ❌不支持 | ⏰计划中 |

### 常用文档

- **门户网站** > [点击访问](https://thebeike.cn)
- **更新日志** > [点击查看](CHANGELOG.md)

## 使用方法 <sub>Usage</sub>

1. 请[**前往此页面**](https://github.com/isHarryh/The-Beike/releases)下载适合你的操作系统的程序文件。
2. 安装或解压下载的文件，并运行程序即可。

## 开发指南 <sub>Development</sub>

本项目基于 **Flutter** 框架编写，使用 **Dart** 语言。

### 开发环境准备

1. 安装 [Git](https://git-scm.com/install/) 和 [VS Code](https://code.visualstudio.com/download)；
2. 参考[《Flutter 快速开始》](https://docs.flutter.dev/install/quick)文档来安装 Flutter SDK；
3. 安装 VS Code 的 [Flutter 插件](https://marketplace.visualstudio.com/items?itemName=Dart-Code.flutter)；
4. 使用 Git 克隆本仓库到本地；
5. 在项目文件夹中运行 `flutter pub get` 来下载依赖。

### 运行与调试

1. 在 VS Code 的右下角状态栏（或者打开“命令面板”进入 `Flutter: Select Device`）来选择要调试的设备或模拟器；
2. 在 VS Code 的“运行”菜单栏中（或者在左侧的“🐞运行与调试”视图中）点击启动调试按钮，即可开始调试程序。

> [!TIP]
>
> 如需在 Android 模拟器上调试，需配置 Android 相关开发环境并使用 ADB 事先连接模拟器端口。如遇设备连接问题，可以运行命令 `flutter doctor` 来执行故障排除。

> [!TIP]
>
> 在调试过程中，修改代码后手动保存或在调试工具栏单击“⚡热重载”按钮，即可在不重启程序的情况下预览代码更改。但发生未捕获的错误时，无法热重载，需重启程序。

### 构建与打包

本仓库配置有持续集成（CI）工作流，可以自动构建发行文件。如需本地构建，请参考以下指引：

<details>
<summary>💡本地构建指引（展开详情）</summary>
<br>

- Android 通用安装包构建：  
    执行命令行
    ```bash
    flutter build apk --release --obfuscate --split-debug-info=build/symbols
    ```
    输出文件位于 `build/app/outputs/flutter-apk`。

- Windows 发行文件构建：  
    执行命令行
    ```bash
    flutter build windows --release --obfuscate --split-debug-info=build/symbols
    ```
    输出文件位于 `build/windows/x64/runner/Release` 文件夹中。

- Windows 安装程序打包：  
    安装 [Inno Setup](https://jrsoftware.org/isdl.php) 并构建发行文件后，执行命令行
    ```bash
    iscc windows/packaging/packaging.iss
    ```
    输出文件位于 `dist` 文件夹中。

- Linux 发行文件构建：  
    执行命令行
    ```bash
    flutter build linux --release --obfuscate --split-debug-info=build/symbols
    ```
    输出文件位于 `build/linux/x64/release/bundle` 文件夹中。

</details>

## 关 于 <sub>About</sub>

### 许可证

本项目基于 **GPL3协议**。任何人都可以自由地使用和修改项目内的源代码，前提是要在源代码或版权声明中保留作者说明和原有协议，且使用相同的许可证进行开源。

### 参与贡献

欢迎任何形式的贡献！如果你有任何想法或建议，或者发现了任何问题，请随时在 GitHub 上提交 Issue 或 Pull Request。

-----

<div align="center">
   <p><i>GitHub Star History</i></p>
   <picture>
      <!--suppress HtmlUnknownTarget -->
      <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/chart?repos=isHarryh/The-Beike&type=date&theme=dark&legend=top-left&sealed_token=nDQMtXKD3RsT0uVgzwcqDrSUnSl0FKBjccIeKhlZ6y3rafo5wsjtSiTTEVI89YOyPZ_CxZ1TD2Ll5akaXRyY_R9vttBYMWoXASpyhqK675g0QQOHsxTgAw" />
      <!--suppress HtmlUnknownTarget -->
      <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/chart?repos=isHarryh/The-Beike&type=date&legend=top-left&sealed_token=nDQMtXKD3RsT0uVgzwcqDrSUnSl0FKBjccIeKhlZ6y3rafo5wsjtSiTTEVI89YOyPZ_CxZ1TD2Ll5akaXRyY_R9vttBYMWoXASpyhqK675g0QQOHsxTgAw" />
      <img alt="Star History Chart" src="https://api.star-history.com/chart?repos=isHarryh/The-Beike&type=date&legend=top-left&sealed_token=nDQMtXKD3RsT0uVgzwcqDrSUnSl0FKBjccIeKhlZ6y3rafo5wsjtSiTTEVI89YOyPZ_CxZ1TD2Ll5akaXRyY_R9vttBYMWoXASpyhqK675g0QQOHsxTgAw" />
   </picture>
</div>
