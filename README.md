<div align="center">

# krkr-switch-batch — 吉里吉里 Switch 批量版
# krkr-switch-batch — KiriKiri Games Batch Edition for Nintendo Switch

**在 Nintendo Switch 上批量畅玩 KiriKiri2 / Z 引擎视觉小说的开源家用 brew 平台**
**An open-source homebrew platform for batch-playing KiriKiri2 / Z engine visual novels on Nintendo Switch**

![License](https://img.shields.io/badge/License-MIT%20%2B%20bundled-blue)
![Platform](https://img.shields.io/badge/Platform-Nintendo_Switch_(CFW)-e60012)
![Status](https://img.shields.io/badge/Status-Work_in_Progress-orange)
![Based on](https://img.shields.io/badge/Based_on-krkr--ns_2F_krkrsdl2-6aa84f)

</div>

> [!NOTE]
> **中文**：本项目正在活跃开发中；首个公开版本将在真机验证完成后发布。
> **English**: This project is under active development; the first public release will follow on-hardware validation.

---

## 📖 项目简介 | About

**中文**

本项目以 [DrFlyingPig/krkr-ns](https://github.com/DrFlyingPig/krkr-ns)（基于 [krkrsdl2](https://github.com/krkrsdl2/krkrsdl2)）为基底，面向「一次构建、批量适配」的目标做了工程化改造：一个通用 NRO 读取 SD 卡上的游戏目录即可运行，无需为每个游戏单独编译。配套提供游戏适配诊断工具、加密解密三轨方案（`xp3filter.tjs` / 原生 XOR 快路径 / 外置密钥表）、私有插件静态化模板、双引擎兜底（[Kirikiroid2-NX](https://github.com/Erige005/Kirikiroid2-NX)）以及 WSL2 下可复现的一键构建流程。

**English**

Built on top of [DrFlyingPig/krkr-ns](https://github.com/DrFlyingPig/krkr-ns) (which is based on [krkrsdl2](https://github.com/krkrsdl2/krkrsdl2)), this project is engineered for a *build-once, adapt-many* workflow: a single universal `.nro` runs games straight from directories on your SD card — no per-game compilation. It ships with a game-compatibility diagnostic toolkit, a three-track decryption approach (`xp3filter.tjs` / native XOR fast path / user-supplied key tables), static-plugin porting templates, a dual-engine fallback ([Kirikiroid2-NX](https://github.com/Erige005/Kirikiroid2-NX)), and a reproducible one-click build pipeline under WSL2.

## ✨ 特性 | Features

| 特性（继承自 krkr-ns 内核） | Core features (inherited from the krkr-ns core) |
| --- | --- |
| 内置游戏库启动器，每游戏存档独立，退出回库 | Built-in game library launcher, per-game save separation, return-to-library on exit |
| E-mote 立绘 / AlphaMovie 透明视频 / LayerExRaster 等插件静态内建 | Statically built-in plugins: E-mote sprites, AlphaMovie transparent video, LayerExRaster, and more |
| CPU / 混合 / 全 GPU 三种渲染模式 + ARM NEON 优化 | CPU / hybrid / full-GPU compositing modes with ARM NEON optimizations |
| WAV / OGG / Opus 音频，WMV / MP4 / MPEG 视频（FFmpeg 静态子集） | WAV / OGG / Opus audio and WMV / MP4 / MPEG video via a static FFmpeg subset |
| 触摸 + 手柄全操作，支持系统级 CPU 加速 | Full touch + gamepad support with system CPU boost |

| 批量平台能力（本项目开发中） | Batch-platform capabilities (under development in this project) |
| --- | --- |
| 游戏扫描诊断工具：插件/加密/媒体格式清单自动生成 | Game scanner: automatic plugin / encryption / media-format profiling |
| 加密三轨：零编译 `xp3filter.tjs`、原生 XOR 分支、外置密钥表加载 | Three decryption tracks: zero-compile `xp3filter.tjs`, native XOR branches, user-supplied key tables |
| 每游戏配置自动化（XML 覆盖 + SD 卡标记文件） | Per-game configuration automation (XML overrides + SD-card marker files) |
| 双引擎兜底：无 E-mote 的 KAG/KAGEX 老游戏转 Kirikiroid2-NX | Dual-engine fallback: pure KAG/KAGEX titles route to Kirikiroid2-NX |
| 兼容性台账与 ASCII 路径规范化工具 | Compatibility ledger and ASCII path normalization tooling |
| WSL2 一键可复现构建（devkitA64 + FFmpeg 交叉编译脚本固化） | Reproducible WSL2 one-click build (devkitA64 + scripted FFmpeg cross-compilation) |

## ⚠️ 免责声明 | Disclaimer

- **中文**：本项目**不分发、不包含任何游戏资源**（含图像、音视频、脚本、存档、解密密钥/密钥表，以及从任何商业游戏或 APK 中提取的资产）。玩家须自行准备**合法拥有**的游戏数据。运行需要破解（CFW，Atmosphère）环境，并以 title-takeover（完整内存）方式启动。本项目为独立社区项目，与 Nintendo、KiriKiri 原作者及贡献者、M2 Co., Ltd.、以及任何上游项目均无隶属或背书关系。
- **English**: This project **does not distribute or contain any game assets** — including images, audio/video, scripts, saves, decryption keys/tables, or anything extracted from commercial games or APKs. Players must supply data for games they **legally own**. A hacked console (CFW, Atmosphère) launched in title-takeover (full-memory) mode is required. This is an independent community project, not affiliated with or endorsed by Nintendo, the original KiriKiri authors and contributors, M2 Co., Ltd., or any upstream project.

## 📦 安装 | Installation

**中文**：将 `krkrsdl2.nro` 放入 SD 卡 `sdmc:/switch/KRKR-ns/`，游戏目录（含 `data.xp3`，**纯 ASCII 路径**）放入 `sdmc:/switch/KRKR-ns/Game/<游戏名>/`，按住 R 键启动任一已安装游戏进入 HBMenu 后选择 NRO 即可。详细步骤与真机测试清单见 [`docs/真机测试指引.md`](docs/真机测试指引.md)。

**English**: Copy `krkrsdl2.nro` to `sdmc:/switch/KRKR-ns/`, place game folders (containing `data.xp3`, **ASCII-only paths**) under `sdmc:/switch/KRKR-ns/Game/<GameFolder>/`, then hold **R** while launching any installed game to enter HBMenu and select the NRO. See the detailed on-device test guide in [`docs/真机测试指引.md`](docs/真机测试指引.md) (Chinese).

## 🛠 构建 | Building

**中文**：在 WSL2 (Ubuntu 24.04) 下构建。核心脚本：

| 脚本 | 作用 |
| --- | --- |
| `tools/windows/setup_wsl_admin.ps1` | 一次性启用 Windows 的 WSL2 功能（需管理员） |
| `tools/wsl/l1_setup.sh` | 安装 devkitA64 / libnx / portlibs（幂等，内置镜像代理配置） |
| `tools/wsl/l2_ffmpeg.sh` | FFmpeg 7.1 交叉编译（通过 `KRKRNS_SRC` / `FFMPEG_PKG` 环境变量传入路径） |
| `tools/build_nro_wsl.sh` | 引擎编译 + cbnz 补丁 + NRO 打包，产物输出至 `dist/` |
| `tools/wsl/clash_relay.mjs`、`tools/wsl/devkitpro_mirror.mjs` | 网络中继与镜像代理（devkitPro 仓库下载时保持运行） |

**English**: Build under WSL2 (Ubuntu 24.04). Key scripts: `tools/windows/setup_wsl_admin.ps1` (one-time WSL2 enablement, admin), `tools/wsl/l1_setup.sh` (idempotent devkitA64/libnx/portlibs setup), `tools/wsl/l2_ffmpeg.sh` (FFmpeg 7.1 cross-compilation; pass paths via `KRKRNS_SRC` / `FFMPEG_PKG`), `tools/build_nro_wsl.sh` (engine build + cbnz patch + NRO packaging → `dist/`), and the relay/mirror helpers (`clash_relay.mjs`, `devkitpro_mirror.mjs`) which must stay running while downloading devkitPro packages. Full build documentation will ship with the first release.

## 📜 许可与合规 | Licensing & Compliance

**中文**

本项目源码以 **MIT** 许可发布（继承自 krkrsdl2 / krkr-ns）。NRO 中静态捆绑的组件各自保留其原始许可，发布物随附完整许可文本包（见 [`licenses/`](licenses/) 目录）。要点如下：

| 组件 | 许可 | 关键义务 |
| --- | --- | --- |
| krkr-ns / krkrsdl2 项目代码 | MIT | 保留版权与许可声明 |
| KiriKiri 内核与 KAG 相关插件 | KiriKiri 许可（W.Dee 及贡献者，BSD 式） | 随附版权声明、条件与免责；不得以贡献者/组织名义宣传派生产品 |
| E-mote 运行时复刻插件 | KiriKiri 许可 + krkrsdl3 补充条例 | 分发含游戏数据的"游戏专用"二进制且修改过引擎时，修改部分必须开源——**本项目永不分发含游戏数据的二进制，且所有引擎修改保持公开** |
| zlib / libpng / FreeType / Xiph / Apache-2.0 等 | 各自宽松许可 | 发布物随附各自声明 |
| FFmpeg / libiconv / OpenAL Soft / p7zip 等 LGPL 组件 | LGPL-2.1（无 GPL 部件） | 静态链接场景下提供可再链接手段——本项目公开全部构建脚本以满足此义务 |

**三条红线**（对本项目发布物的硬性约束）：① 不含任何游戏数据；② 不含任何解密密钥/密钥表；③ 不含从商业 APK 提取的资产（Kirikiroid2-NX 线的 UI 资源由使用者构建时自行从官方 APK 提取）。

**English**

The source code of this project is released under the **MIT** license (inherited from krkrsdl2 / krkr-ns). Statically bundled components retain their original licenses, and every release ships with the complete license texts (see the [`licenses/`](licenses/) directory). Highlights:

| Component | License | Key obligation |
| --- | --- | --- |
| krkr-ns / krkrsdl2 project code | MIT | Retain copyright and license notices |
| KiriKiri engine & KAG-related plugins | KiriKiri license (W.Dee & contributors, BSD-style) | Include copyright, conditions & disclaimer; do not use contributors'/organizations' names to promote derivative products |
| E-mote runtime reimplementation plugin | KiriKiri license + krkrsdl3 supplementary clause | When distributing game-specific binaries containing game data with engine modifications, those modifications must be open-sourced — **this project never distributes game-data-carrying binaries and keeps all engine modifications public** |
| zlib / libpng / FreeType / Xiph / Apache-2.0, etc. | Permissive licenses (see bundled texts) | Ship each component's notice |
| LGPL components (FFmpeg / libiconv / OpenAL Soft / p7zip, etc.) | LGPL-2.1 (no GPL parts) | Provide a means to relink for static linking — satisfied by publishing all build scripts |

**Three red lines** (hard constraints on our release artifacts): ① no game data; ② no decryption keys/tables; ③ no assets extracted from commercial APKs (Kirikiroid2-NX UI resources are extracted from the official APK by the user at build time).

## 🧩 借鉴与致谢 | Based On & Credits

| 项目 Project | 本项目借鉴了什么 What we built on | 许可 License |
| --- | --- | --- |
| [DrFlyingPig/krkr-ns](https://github.com/DrFlyingPig/krkr-ns) | **主基底**：Switch 移植本体、启动器、内置插件、构建脚本（`build_ffmpeg_switch.sh` 随附于 `tools/upstream-krkr-ns/`） | MIT |
| [krkrsdl2/krkrsdl2](https://github.com/krkrsdl2/krkrsdl2)（作者/原作者 [uyjulian](https://github.com/uyjulian)） | krkr-ns 的上游：KirikiriZ 的 SDL2 多平台内核 | MIT |
| [krkrz](https://github.com/krkrz)（W.Dee 及 Kirikiri Z 项目贡献者） | KiriKiri2/Z 引擎本体与 TJS2 | KiriKiri license |
| [zeas2/Kirikiroid2](https://github.com/zeas2/Kirikiroid2) | 安卓移植与脚本级解密（xp3filter）生态 | KiriKiri license |
| [Erige005/Kirikiroid2-NX](https://github.com/Erige005/Kirikiroid2-NX) | 兜底引擎线（无 E-mote 的 KAG/KAGEX 游戏、BPG/JXR、软键盘） | KiriKiri license |
| [devkitPro](https://devkitpro.org) / libnx / SDL2 / FFmpeg / FAudio / FreeType / libpng / zlib 等全部上游库 | 工具链与多媒体基座 | 见 [`licenses/`](licenses/) |

## 📄 许可证 | License

**中文**：本项目自有代码以 [MIT](https://opensource.org/licenses/MIT) 许可发布（见 [`LICENSE`](LICENSE)）；捆绑组件随附各自许可文本，完整清单见 [`licenses/`](licenses/) 目录。

**English**: This project's own code is released under the [MIT](https://opensource.org/licenses/MIT) license (see [`LICENSE`](LICENSE)); bundled components ship with their own license texts, inventoried in the [`licenses/`](licenses/) directory.

---

## 📄 许可 | License

**中文**：本项目代码以 [MIT](LICENSE) 许可发布。本项目是 [krkr-ns](https://github.com/DrFlyingPig/krkr-ns)（MIT）与 [krkrsdl2](https://github.com/krkrsdl2/krkrsdl2)（MIT）之上、包含 [KiriKiri2/Z](https://github.com/krkrz/krkr2) 引擎组件的衍生作品；所捆绑的第三方组件保留其各自许可，完整清单见上游仓库的许可文件。

**English**: This project's code is released under the [MIT](LICENSE) license. It is a derivative work built on [krkr-ns](https://github.com/DrFlyingPig/krkr-ns) (MIT), [krkrsdl2](https://github.com/krkrsdl2/krkrsdl2) (MIT) and KiriKiri2/Z engine components; bundled third-party components retain their own licenses — see the upstream repositories for the complete inventory.

> 补充 | Note: This project is a derivative work built on top of krkr-ns and krkrsdl2
(MIT, Copyright (C) Kirikiri SDL2 Developers), the KiriKiri2/KiriKiri Z
engine (KiriKiri license, Copyright (c), W.Dee and contributors), and other
bundled third-party components that retain their own licenses.
See the licenses/ directory for the complete inventory.
