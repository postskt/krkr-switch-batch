# P0 决策文档：主基底确认与支持能力矩阵

- 日期：2026-11-14
- 代码快照：`upstream/krkr-ns` @ `b51a0ad`（2026-11-08）；`upstream/Kirikiroid2-NX` @ `e96b603`（2026-10-19），均为浅克隆
- 性质：选型验证（P0）。矩阵结论**以代码为准**（编译清单、条件编译、实现文件），非 README 转述；每条带 `文件[:行号]` 出处
- 路径约定：下文 `A/` 指 `upstream/krkr-ns/krkrsdl2/`，`B/` 指 `upstream/Kirikiroid2-NX/src/`

---

## 0. 结论先行

**主基底 krkr-ns 成立，维持「krkr-ns 主线 + Kirikiroid2-NX fallback」双线**。决定性依据：

1. **插件覆盖面直接决定游戏覆盖率**：E-mote / LayerExRaster / AlphaMovie / shrinkCopy / scriptsEx / layerExImage / layerExDraw 在 krkr-ns 已全部内建（`A/src/plugins/` + `CMakeLists.txt:658-713`），而 K2NX 明确缺失 E-mote、KAGParserEx、scriptsEx、layerExRaster、shrinkCopy、json、sqlite（`platforms/switch/CMakeLists.txt:139` 注释 + 全库 grep 无实现）。E-mote 是 Yuzusoft 系及大量现代 galgame 的硬依赖，没有它 fallback 线对这批游戏直接不可用。
2. **启动器形态贴合批量移植目标**：krkr-ns 自带游戏库（`A/data/startup.tjs`，扫描 `sdmc:/switch/KRKR-ns/Game/`，`A/src/core/sdl2/SDLApplication.cpp:6260-6284`）、每游戏存档分离（`:6477-6496`）、游戏退出回启动器进程内重建引擎（`:7060-7180`）——正对「一个通用 NRO + SD 卡游戏目录 + 每游戏适配配置」的目标形态；K2NX 只有安卓版文件选择器（`B/core/environ/ui/MainFileSelectorForm.cpp`），换游戏要手动浏览。
3. **加密扩展有原生扩展点**：krkr-ns 已内置 YuzuSoft 原生 XOR 快路径 + 可仿写模式（`A/src/core/base/sdl2/XP3ExtractionFilter.cpp:399-499`），xp3filter.tjs 之外的私有加密有明确 C++ 落点；K2NX 只有脚本解密一条路（与安卓版同边界）。
4. **两者共同边界**：都没有原生 cxdec；都以 xp3filter.tjs 为通用解密入口。fallback 线保留的理由：KAG/KAGEX 纯脚本游戏的安卓 1.3.9 行为对齐、BPG/JXR 图像格式支持、swkbd 文本输入（krkr-ns 无软键盘）。

构建环境路线（WSL2 统一 vs Windows 原生）已单独决策：**WSL2 统一**。理由与现状见 §5。

---

## 1. 矩阵 A：krkr-ns

### 1.1 图形渲染

| 能力 | 状态 | 出处 |
|---|---|---|
| 三态渲染：纯 CPU / 混合（默认）/ 完整 GPU 合成 | 混合为默认：CPU 合成 + E-mote GPU 光栅；`renderer-gl.txt`+XML `renderer=opengl` 才走整帧 GPU | `A/src/core/sdl2/KrkrNSResourcePolicy.cpp:133-193`；默认值 `ReferenceRendererConfig.h:8-10` |
| 每游戏/全局渲染配置 | 全局 `GlobalPreference.xml` → 游戏目录 `Kirikiroid2Preference.xml` 逐键覆盖（renderer/memusage/fps_limit 三键） | `A/src/core/sdl2/ReferenceRendererConfig.cpp:54-66,28-49` |
| GPU 合成 | ES2 FBO 纹理合成，`gpu-composite.txt` marker 激活 + 驱动探测，失败永久禁用（模拟器软件 GLES 兼容注释） | `A/src/core/sdl2/GLComposite.cpp:26-30,540-657` |
| NEON 优化 | Alpha/Crossfade/双线性缩放/目标 alpha 四组原生 NEON 循环（`KRKRNS_*_NEON` CMake 开关，仅 Switch 生效） | `A/external/krkrz/visual/gl/blend_function_sse2.cpp:891-945,1562-1598`；`CMakeLists.txt:211-249` |
| E-mote GPU 后端 | GL/SW 双后端自检，失败锁死 CPU；`emote-cpu.txt`/`emote-gl.txt` 可强制 | `A/src/plugins/emoteplayer/TVPCompositor.cpp:33-128` |
| CPU boost | 软件渲染会话申请 `ApmCpuBoostMode_FastLoad`，GPU 会话回落 Normal，失败不重试 | `A/src/core/sdl2/KrkrNSResourcePolicy.cpp:40-64` |
| 比例处理 | `System.screenWidth` 用显示可用区，防 KAGEX 舞台错误信箱化；`GetFullScreen()` 恒 false 防 setZoom 短路 | `A/src/core/visual/sdl2/TVPScreen.cpp:13-53`；`WindowImpl.cpp:1786-1813` |

### 1.2 图像格式

| 格式 | 状态 | 出处 |
|---|---|---|
| BMP / PNG / TLG5/6 / JPEG | 全支持；PNG 用 portlibs libpng16（原生 ARM row filter，排除捆绑 lpng） | `A/external/krkrz/visual/GraphicsLoaderIntf.cpp:230-260`；`CMakeLists.txt:164-169,632` |
| WebP | **仅 Switch 目标**启用（`TVP_IMAGE_ENABLE_WEBP`） | `CMakeLists.txt:748,763`；`A/src/plugins/psbfile/LoadWEBP.cpp:27` |
| JPEG XR | jxrlib 编译进库，但 Switch **不注册**（注册代码在 `#ifdef _WIN32` 内）→ 不可用 | `GraphicsLoaderIntf.cpp:67-70,258-259`；`sources.txt:154-175` |
| BPG | **无**（全仓库无 bpg 符号） | grep 证实 |
| PSB/PIMG 签名路由 | 按字节签名（非扩展名）路由解码器——翻译包混用 PNG/WebP 的关键机制 | `GraphicsLoaderIntf.cpp:44-88` |
| Susie .spi | 归档读取有（`SusieArchive.cpp:82-88`），但 Switch 禁外部插件，图片解码 .spi 不可加载 | `CMakeLists.txt:79-83` |

### 1.3 音频

| 能力 | 状态 | 出处 |
|---|---|---|
| 输出后端 | FAudio + 自研 Switch 音频适配器（直链覆盖 `SWITCHAUDIO_bootstrap`，48kHz/2ch 双缓冲，修复 OP 卡死） | `CMakeLists.txt:793-806,882-887`；`A/src/core/sound/sdl2/switch/SDL_switchaudio_krkrns.cpp:55-58` |
| WAV / OGG(Vorbis) / Opus / TCWF | 全支持；TCWF 按 `TCWF0\x1a` magic 无视扩展名 | `A/external/krkrz/sound/WaveIntf.cpp:808-837`；`A/src/plugins/wutcwf/WutcWf.cpp:22-24` |
| AAC/M4A/MP3/FLAC 等 | FFmpeg 后备解码（仅 Switch），**纯内容探测**（空文件名 open），扩展名与内容不一致可容错 | `A/src/core/sound/sdl2/FFWaveDecoder.cpp:84-92`；`CMakeLists.txt:747` |
| 扩展名兜底 | 三层：Opus 试 `.opus`+`.ogg` → FFmpeg 内容探测 → 注册逆序专用优先 | `OpusCodecDecoder.cpp:232-237`；`WaveIntf.cpp:814-821` |

### 1.4 视频

| 能力 | 状态 | 出处 |
|---|---|---|
| 容器/编码白名单 | demuxer: asf/mov/mpegps/mpegvideo/mp3；decoder: wmv3/vc1/wmav1/2/wmapro/wmavoice/h264/hevc/aac/mpeg1/2video/mp2/mp3（FFmpeg 7.1 静态子集） | `tools/build_ffmpeg_switch.sh:66-79`（`A` 仓库根 `tools/`） |
| XP3 内直读 | AVIO 回调接 `tTJSBinaryStream`，视频可从资源包内播放 | `A/src/core/visual/sdl2/SwitchMovieOverlay.cpp:49-160` |
| 跳转 | `SeekToMilliseconds`/`SetFrame`/`Rewind` 有实现 + 失败回滚重试 | `SwitchMovieOverlay.h:101-105,168`；`.cpp:667-688` |
| 片段循环 / 变速 / 多音轨 | **不支持**：`SetStopFrame` no-op（"plays to EOF"）、`SetPlayRate` 恒 1.0、`SelectAudioStream` no-op | `SwitchMovieOverlay.h:111-117,125` |
| 循环 | EOF→Stop 事件，由游戏脚本重播；无原生循环 | `SwitchMovieOverlay.cpp:995-997` |
| AlphaMovie (.amv) | 自研解码（不依赖 FFmpeg），alphaMode 1/2，帧索引 seek | `A/src/plugins/alphamovie/AmvMovie.cpp:34,150` |
| 图层视频 / 独立视频 | 两者皆有（vomLayer 走 CPU 合成；overlay 直绘主 surface；GPU 模式走 take_frame） | `A/src/core/visual/sdl2/VideoOvlImpl.cpp:1835-1949` |

### 1.5 输入

| 能力 | 状态 | 出处 |
|---|---|---|
| 手柄映射 | A=左键/确认、B=右键/返回、Y=Space、X=Enter、Minus=F5 快存、Plus=Escape、L3=Ctrl 快进、R3=F7 快读、L/R=滚轮、十字键=方向键 | `A/src/core/sdl2/SDLApplication.cpp:5250-5300` |
| 左摇杆=鼠标 | 死区 8000、14px/帧移动光标并合成鼠标键 | `SDLApplication.cpp:742-744` |
| 触摸 | SDL FINGER 事件 → `TVPOnTouch*InputEvent` | `SDLApplication.cpp:4988-5002` |
| 软键盘（swkbd） | **不存在**：全仓库无 swkbd 符号，仅 `SDL_StartTextInput`（Switch 无屏显键盘可调）→ 含名字输入的游戏是功能缺口 | `SDLApplication.cpp:4140-4143`；grep 证实 |
| MenuItem 弹出菜单 | 原生类 + `compat/system/menu_popup.tjs` TJS 实现；`menu.dll` 保持 opt-in | `A/external/krkrz/visual/MenuItemImpl.cpp:15-56`；`A/compat-patches/system/menu_popup.tjs:1-10` |

### 1.6 字体

| 能力 | 状态 | 出处 |
|---|---|---|
| 光栅化 | FreeType 全模块静态编译 | `A/src/config/src_list/kirikirisdl2/sources.txt:116-153` |
| 内置字体 | `notosanssc.ttf` 进 RomFS；默认字体名强制 `Noto Sans SC`（仅请求 family 缺失时兜底） | `A/src/core/sdl2/SDLApplication.cpp:7399-7405`；`A/data/notosanssc.ttf` |
| addfont | `System.addFont()` → `TVPAddFontToFreeType` | `A/src/plugins/addfont/AddFont.cpp:1-15` |
| CJK 编码 | gbk2unicode/cp932 表编译在内；onig 含 gb18030/big5 | `sources.txt:79-82,248,254` |
| 会话隔离 | 引擎重建时清空私有字体，防两游戏同名字体冲突 | `SDLApplication.cpp:7151-7160` |

### 1.7 内置插件（全部静态，Switch 禁动态加载）

| 插件 | 作用 | 出处 |
|---|---|---|
| emoteplayer | E-mote 立绘（Yuzusoft 系），自研 GL/SW 双后端 | `CMakeLists.txt:704-711`；`UPSTREAM-LICENSE.txt` |
| alphamovie | .amv 透明动画 | `A/src/plugins/alphamovie/` |
| psbfile | PSB/PIMG 资源 + `psb://` 存储 + WebP 解码 | `CMakeLists.txt:634-636` |
| kagparser / csvparser / textrender | 内置 TJS 类（KAG3/CSV/KAGEX TextRender 依赖） | `A/external/krkrz/base/ScriptMgnIntf.cpp:306-326` |
| layerexraster / layereximage / layerexdraw / layerexsave / layerexbtoa | 图层扩展族（波纹/光照模糊/GdiPlus 兼容/存图） | `A/src/plugins/layerex*/` |
| shrinkcopy | `Layer.shrinkCopy`，**随引擎默认启用** | `A/src/core/base/sdl2/PluginImpl.cpp:787-798` |
| extrans | wave/mosaic/turn/rotate/ripple 转场 | `A/src/plugins/extrans/` |
| scriptsex / fstat / dirlist / getabout / addsample / addfont / varfile / savestruct / fftgraph(stub) / win32dialog(stub) | Kirikiroid2 兼容内建 | 各文件头注释 |
| wutcwf | TCWF 音频 | `A/src/plugins/wutcwf/` |
| 注册机制 | ncbind 静态注册表 + `krkrsdl2_link_*_plugin()` 锚防裁剪；`Plugins.link("xxx.dll")` 按短名分发；别名 motionplayer/emotedriver→emoteplayer | `A/src/plugins/ncbind/ncbind.cpp:15-27`；`PluginImpl.cpp:590-750,662-668` |

### 1.8 加密/解密

| 能力 | 状态 | 出处 |
|---|---|---|
| xp3filter.tjs | 完整支持：游戏目录放 `xp3filter.tjs` 自动装备；每线程私有 tTJS 实例（存档读取在 worker 线程） | `A/external/krkrz/base/StorageIntf.cpp:3331-3354`；`A/src/core/base/sdl2/XP3ExtractionFilter.cpp:251-347,522-548` |
| 原生快路径 | YuzuSoft 形态无状态 XOR 已内置（4 块脚本/原生比对门控），可仿写扩展 | `XP3ExtractionFilter.cpp:399-499` |
| cxdec / Crilayla | **未 vendored**（grep 无符号）——只有 xp3filter.tjs 形态开箱即用 | grep 证实；`XP3Archive.cpp:70-76` 仅回调接口 |
| .xp3 后缀的 7z 包 | 内容判定兼容（Kirikiroid2 兼容行为） | `A/src/core/sdl2/SDLApplication.cpp:6394-6404` |

### 1.9 启动器

| 能力 | 状态 | 出处 |
|---|---|---|
| 游戏库扫描 | 枚举 `sdmc:/switch/KRKR-ns/Game/` 子目录；文件惰性列举，只列 `.xp3`+`.tjs` | `A/src/core/sdl2/SDLApplication.cpp:6260-6344`；`A/src/core/sdl2/KrkrNSPaths.h:18` |
| 入口限制 | **必须 `.xp3` 入口**：非 .xp3 直接 `throw "Invalid XP3 entry name"`（散装 startup.tjs 不能从库启动） | `SDLApplication.cpp:6366-6370`；`A/data/startup.tjs:1150-1153` |
| 入口偏好/记忆 | `ENTRY_PREFERENCE` 中文名优先；上次选择存 `saves/<dir>/entry.txt` | `startup.tjs:76`；`SDLApplication.cpp:6458-6466` |
| 存档分离 | 重定向 `saves/<GameFolder>/`，同目录多包共用 | `SDLApplication.cpp:6477-6496` |
| 别名/预览图 | `Names.tjs` 别名；`Artwork/` + native 缩略图管线 | `startup.tjs:75`；`StorageIntf.cpp:3224-3267` |
| 退出回库 | 拦截终止→进程内 10 步重建引擎（清缓存/卸插件/清字体/重置路径），或链式重启 NRO | `SDLApplication.cpp:7060-7180,6140-6150` |

### 1.10 已知缺陷（代码级）

| 缺陷 | 出处 |
|---|---|
| E-mote 多个 API 空实现（initPhysics/setColor/风场/setTimelineBlendRatio/getVariableFrameList 等，仅打日志） | `A/src/plugins/emoteplayer/emoteplayerclass.cpp:1481-2063` |
| LayerExDraw 部分 API 返回空 RectF（TODO） | `A/src/plugins/layerexdraw/LayerExDraw.cpp:1882-1904` |
| 视频片段循环/变速/多音轨不支持（README 声称循环支持，实际 no-op） | `SwitchMovieOverlay.h:111-117` |
| 软键盘缺失（见 1.5） | grep 证实 |
| BPG 缺失 / JXR Switch 未注册（见 1.2） | `GraphicsLoaderIntf.cpp:258-259` |
| 内存碎片化防护依赖 TLSF 全局接管（`--wrap=malloc`）；applet 模式要求 ≥1GiB 或拒绝启动 | `CMakeLists.txt:837-842`；`A/src/core/sdl2/SwitchHeap.cpp:3-12`；`SDLApplication.cpp:6209-6222` |
| 兼容垫片 k2compat.tjs（1001 行）需按会话重装（修复第二游戏 loadPlugin 丢失） | `A/compat-patches/system/k2compat.tjs`、`k2compat_reinstall.tjs` |
| NRO 需 GCS unwind cbnz 补丁（Nextendo 模拟器 chkfeat bug；真机不受影响） | 仓库根 `build_nro.sh:44-74` |

---

## 2. 矩阵 B：Kirikiroid2-NX

### 2.1 图形渲染

| 能力 | 状态 | 出处 |
|---|---|---|
| 渲染路线 | **纯软件渲染是默认且唯一受验证路径**（OpenGL 渲染管理器已编译、偏好可选，但无 CPU boost 且未验证） | `B/core/visual/RenderManager.cpp:4443-4460`；`B/core/visual/ogl/RenderManager_ogl.cpp:4032`；`B/core/environ/switch/SwitchUtils.cpp:41-44` |
| NEON | Tegra X1 强制 `TVP_CPU_HAS_NEON`；AlphaBlend 族/Stretch 族/LinTrans 族/ColorMap 等 30+ 例程 | `B/core/environ/DetectCPU.cpp:191-196`；`B/core/visual/ARM/tvpgl_arm.cpp:49-190` |
| CPU boost | 软件渲染器运行时开 FastLoad（1785MHz），退出恢复 | `B/core/environ/switch/SwitchUtils.cpp:48-60` |
| 比例 | GL view 固定 1280×720（修复 16:9 黑边），design resolution 按帧比例自适应 | `B/core/environ/cocos2d/AppDelegate.cpp:42-48`；cocos 补丁 `0001:469-491` |
| extrans 转场 | wave/mosaic/turn/rotatezoom/rotatevanish/rotateswap/ripple 全 7 种 | `B/plugins/extrans/Main.cpp:6-40`；`rotatetrans.cpp:152-318` |
| layerExImage | light/colorize/modulate/noise/gaussianBlur 全实现（GL 渲染器下不可用） | `B/plugins/layerExImage/LayerExImage.h:40-73` |

### 2.2 图像格式

| 格式 | 状态 | 出处 |
|---|---|---|
| BMP/PNG/TLG/JPEG | 全支持（libpng16 / libjpeg-turbo / NEON chroma TLG） | `B/core/visual/GraphicsLoaderIntf.cpp:47-83`；`platforms/switch/CMakeLists.txt:174` |
| WebP | libwebp 含 demux 动图 | `B/core/visual/LoadWEBP.cpp:28-29` |
| BPG | **支持**（libbpg 0.9.8 + Kirikiroid2 私有 gray_line 补丁） | `B/core/visual/LoadBPG.cpp:8`；`portlibs/build_libbpg.sh:4-12` |
| JPEG XR | **支持**（jxrlib） | `B/core/visual/LoadJXR.cpp:396` |
| 重打包 | p7zip 16.02 + UnRAR 5.6.5 静态内置 | `platforms/switch/CMakeLists.txt:47-84` |

### 2.3 音频

| 能力 | 状态 | 出处 |
|---|---|---|
| 输出后端 | OpenAL（引擎混音器直连） | `B/core/sound/win32/WaveMixer.cpp:4-5,546,675` |
| 解码器 | Ogg Vorbis（vorbisfile）/ Opus（opusfile）/ WAV RIFF / TCWF（wutcwf 静态内置）+ FFmpeg 兜底 | `B/core/sound/VorbisWaveDecoder.cpp:1,455`；`B/core/sound/WaveIntf.cpp:749-760`；`B/plugins/wutcwf.cpp:10,220` |

### 2.4 视频

| 能力 | 状态 | 出处 |
|---|---|---|
| FFmpeg | **3.2.19**（对齐安卓 1.3.9 内置版本），全量 demuxer/decoder 仅解码（禁 encoder/muxer/network/hwaccel） | `platforms/switch/tools/portlibs/build_ffmpeg.sh:2,21-28` |
| 播放路径 | VideoOverlay → KRMoviePlayer，YUV 由 cocos 精灵呈现 | `B/core/visual/win32/VideoOvlImpl.cpp:30-44`；`B/core/movie/ffmpeg/krffmpeg.cpp:60` |
| 静态视频插件 | layerExMovie / AlphaMovie（自研 .amv） | `B/plugins/layerExMovie.cpp:17`；`B/plugins/AlphaMovie/AlphaMovie.cpp:1-12` |
| aarch64 兼容 | fft/imdct NEON 跳转表 `relocate=1` 过 PIE TEXTREL 检查 | `build_ffmpeg.sh:11-17,30-32` |

### 2.5 输入

| 能力 | 状态 | 出处 |
|---|---|---|
| 手柄 | A/B/X/Y→VK_PAD1/2/4/5、ZL→PAD5（与 Y 重复）、ZR→PAD6、Plus→PAD9、−=安卓菜单键 | `B/core/environ/cocos2d/CCKeyCodeConv.cpp:194-214`；cocos 补丁 `0001:75-91,151-155` |
| 左摇杆=鼠标 | 虚拟光标 + 死区 0.15 + 精调步进；A=左键 B=右键 | `B/core/environ/cocos2d/MainScene.cpp:2303-2387` |
| 触摸 | ≤16 指多点触摸，libnx HID 直采 | cocos 补丁 `0001:469-527` |
| **swkbd 软键盘** | **支持**（输入框与 EditBox 均接系统键盘）；完整 IME 是 TODO | `B/core/environ/switch/SwitchUtils.cpp:278-293`；cocos 补丁 `0001:822-840` |
| 改键 | 安卓同款 `_keymap` 管线 + Kirikiroid2 KeySelect UI | `MainScene.cpp:2389-2396`；`B/core/environ/ui/PreferenceConfig.h:277` |

### 2.6 字体

| 能力 | 状态 | 出处 |
|---|---|---|
| 光栅化 | FreeType（portlibs） | `platforms/switch/CMakeLists.txt:106,174` |
| 内置字体 | DroidSansFallback.ttf 构建时从官方 1.3.9 APK 提取（不入库） | `platforms/switch/tools/extract_apk_assets.sh:2-14` |
| 枚举顺序 | SD `default.ttf` → RomFS DroidSansFallback（[K2S] 对齐安卓顺序） | `B/core/visual/FontImpl.cpp:220-232` |
| 游戏字体 | `<游戏目录>/fonts/*` 通用枚举（同安卓） | `FontImpl.cpp:245-250` |
| UI CJK | 无 fontconfig：未知 family 回落系统共享字体（简中优先） | cocos 补丁 `0001:666-700` |

### 2.7 插件（全部静态，`--whole-archive`）

| 已移植 | 出处 |
|---|---|
| xp3filter / wutcwf / layerExImage / extrans / layerExDraw(Blend2D) / fstat / windowEx / AlphaMovie / layerExMovie / perspective / addFont / csvParser / varfile / saveStruct / fftgraph / dirlist / getabout / getSample / win32dialog / ncbind | `platforms/switch/CMakeLists.txt:138-143`；各插件 `NCB_MODULE_NAME` 实测 |
| **未移植（无 stub，直接缺失）** | KAGParserEx、**E-mote/motion player**、scriptsEx、layerExRaster、shrinkCopy、json、sqlite——游戏报 "Member ... does not exist" | `platforms/switch/CMakeLists.txt:139`；全库 grep；`B/plugins/windowEx/main.cpp:6-7` |
| 注册机制 | `TVPLoadInternalPlugin` 只查静态表，动态加载被切断（"seal all plugins"） | `B/core/base/win32/PluginImpl.cpp:451-452` |

### 2.8 加密/解密

| 能力 | 状态 | 出处 |
|---|---|---|
| xp3filter.tjs | 支持：读 `<游戏目录>/xp3filter.tjs`，提取+内容双过滤器；每线程 TJS 实例 + 解码器缓存 | `B/plugins/xp3filter.cpp:295-354,438-456` |
| one-pass 解码（[K2S]） | ≤8MB 存储整块解码进内存（修复脚本过滤 3-4s/场景） | `B/core/base/XP3Archive.cpp:606-616` |
| 脚本字节操作 | CBinaryAccessor 全算子 + 64 位字宽批量 xor | `xp3filter.cpp:16-207` |
| cxdec | **无**（仅 Windows 调试比对代码 `#if WIN32 && CHECK_CXDEC` 内提及）；与安卓 1.3.9 同边界 | `xp3filter.cpp:402-408`；`XP3Archive.cpp:598` 注释 |

### 2.9 UI/启动器

| 能力 | 状态 | 出处 |
|---|---|---|
| 启动器 | 安卓版文件选择器 + 历史列表；**无游戏库** | `B/core/environ/ui/MainFileSelectorForm.cpp:192-286,512-548` |
| 浏览范围 | SD 根 `/` 单根；点 data.xp3 或含 startup.tjs 的目录启动；也支持直接播视频/装 .skin | `B/core/environ/switch/SwitchUtils.cpp:106-108` |
| 每游戏配置 | 游戏目录 `Kirikiroid2Preference.xml`（同安卓）；历史条目有配置按钮 | `B/core/environ/ConfigManager/IndividualConfigManager.cpp:6`；`MainFileSelectorForm.cpp:535` |
| 全局配置 | `/switch/kirikiroid2/.preference/GlobalPreference.xml` | `B/core/environ/cocos2d/MainScene.cpp:2483-2493` |
| UI 资源 | .csb 从 APK 1.3.9 提取（.csd 源无法复现，构建强依赖 APK） | `extract_apk_assets.sh`；cocos 补丁 `0001:328-338` |

### 2.10 已知缺陷（代码级）

| 缺陷 | 出处 |
|---|---|
| Yes/No 系统弹窗**恒选第一个按钮**（自绘模态未完成） | `B/core/environ/switch/SwitchUtils.cpp:295-307` |
| 退出游戏可能报"软件因错误关闭"（`exit()` 直退 + 线程未销毁被 `#if 0`） | `SwitchUtils.cpp:261-267`；`B/core/environ/Application.cpp:611-618` |
| applet 模式 ~400MB vs title-takeover ~3.2GB | `SwitchUtils.cpp:62-65` |
| IME 不完整（仅 swkbd 简单输入框） | `SwitchUtils.cpp:270-274` |
| 无启动参数机制 | `SwitchUtils.cpp:134-136` |
| libnx `hardware_concurrency()`=0 → 0 绘制线程（用 sysconf=3 绕过） | `B/core/utils/win32/ThreadImpl.cpp:176`；`SwitchUtils.cpp:324-331` |
| KAG 高频日志曾致 6fps（256KB 块缓冲修复） | `B/core/environ/switch/main.cpp:17-22` |

---

## 3. README 与代码不一致（要点）

**krkr-ns**：
1. README 声称视频「指定片段循环」——代码 `SetStopFrame` 是 no-op（`SwitchMovieOverlay.h:111-115`）
2. compat-patches/README 写旧路径 `sdmc:/switch/krkrsdl2/patch/system/`，代码实际 `sdmc:/switch/KRKR-ns/patch/system/`（`KrkrNSPaths.h:19`）
3. 渲染配置「游戏目录优先」实为「全局先读、游戏逐键覆盖」（语义等价，`ReferenceRendererConfig.cpp:57-64`）

**Kirikiroid2-NX**：
1. "Only the software renderer is supported"——OpenGL 渲染器已编译且可选，准确说法是「仅软件渲染受验证」（`RenderManager_ogl.cpp:4032`）
2. "fast bilinear scaling" 实为 OpenCV `INTER_LINEAR` 路径，措辞夸大（`RenderManager.cpp:2423-2433`）
3. 注释引用的 `docs/PLUGINS.md` 不在仓库中（未移植插件清单只能靠代码 grep）

---

## 4. 风险清单

### krkr-ns（主线）

| # | 风险 | 等级 | 缓解 |
|---|---|---|---|
| K1 | 构建脚本 Windows 偏置：`build_nro.sh` 写死 `D:/devkitPro`、作者机器工具目录 `D:/KRKR-ns-tools`（含不在仓库的 `Switch.toolchain.cmake`）；FFmpeg 脚本默认 make 取自作者另一项目 WA2-ns | 中 | WSL 下用官方 `/opt/devkitpro/cmake/Switch.cmake` + apt 工具重写适配脚本（本阶段执行中）；FFmpeg 脚本支持 `FFMPEG_MAKE`/`FFMPEG_ARCHIVE` 覆盖 |
| K2 | 无 cxdec 原生解密：xp3filter.tjs 之外的私有加密（feng 系等）不可用 | 高（批量视角） | 批量移植时按游戏仿照 `NativeXorDecrypt`（`XP3ExtractionFilter.cpp:399-499`）加原生分支，或静态编入对应 Kirikiroid2 插件——这是后续阶段的核心工作量 |
| K3 | 软键盘缺失：含名字输入/文本输入的游戏在真机不可输入 | 中 | 涉及此类游戏时 fallback 到 K2NX，或移植 swkbd（K2NX 有现成实现可抄：`SwitchUtils.cpp:278-293`） |
| K4 | E-mote 部分 API 空实现（物理/风场/时间线混合等） | 中 | 遇到的游戏逐个验证；空实现只打日志不崩，通常是动作退化非崩溃 |
| K5 | 视频：无片段循环/变速/多音轨；容器白名单固定（无 mkv/webm） | 低-中 | 加编码需改 `tools/build_ffmpeg_switch.sh` 的 enable 清单重编 FFmpeg |
| K6 | BPG 缺失、JXR Switch 未注册 | 低 | 有该格式的游戏需补解码器注册（JXR 已编译，注册代码要从 `#ifdef _WIN32` 摘出来） |
| K7 | 实验性项目声明 + 启动器内存不足防护依赖 title-takeover | 低 | 真机测试指引强制 R 键启动；`krkrsdl2_can_launch_game` 有防护（`SDLApplication.cpp:6209-6222`） |

### Kirikiroid2-NX（fallback）

| # | 风险 | 等级 | 缓解 |
|---|---|---|---|
| B1 | E-mote 等七插件缺失：Yuzusoft 系游戏直接不可用 | 高 | fallback 定位限定「无 E-mote 的 KAG/KAGEX/纯 KAG3 游戏」；或后续把 krkr-ns 的 E-mote 移植过来（工作量大） |
| B2 | Yes/No 弹窗恒选第一个按钮：依赖确认框分支的游戏行为错误（存档覆盖确认等） | 中 | 真机验证清单加专项；必要时补自绘模态（作者已在 TODO） |
| B3 | 退出报错（exit 直退 + 线程未清） | 低 | UX 缺陷不阻游戏；真机测试预期管理 |
| B4 | 构建链最重：cocos2d-x fetch + 7 个 portlibs（opencv/blend2d 等）+ APK 资产提取，磁盘/时间成本最大 | 中 | 磁盘评估见 §5；构建自动化时固化脚本顺序 |
| B5 | FFmpeg 3.2 老旧 + 纯软解：高码率/新编码视频风险 | 低 | 与安卓 1.3.9 同代，行为对齐本身就是 fallback 的价值 |
| B6 | 工作区假设（`$K2NX_WS/src`、缓存散在 `$HOME`） | 低 | 自动化脚本显式 export `K2NX_WS` |

### 共同边界

- 均无原生 cxdec/Crilayla；xp3filter.tjs 是共同且唯一的通用解密入口
- 均要求 title-takeover 启动（applet 内存不可用）
- SD 卡路径 ASCII（krkr-ns 硬限制；K2NX 侧建议同样遵守，避免脚本引用混乱）

---

## 5. 构建环境与磁盘/内存评估

**路线决策：WSL2 统一构建**（用户 2026-11-13 确认）。理由：
1. Kirikiroid2-NX 官方仅支持 Linux/WSL2 构建（`platforms/switch/tools/` 全套 bash 脚本）；
2. krkr-ns 虽上游作者用 Windows 原生 devkitPro，但其工具集（cmake/ninja/pkg-config 二进制 + 私有 toolchain 文件）不在仓库，复现成本不低于 WSL 适配；
3. 一条环境服务两线，apt/dkp-pacman 标准化打包可复现。

**本机现状**（侦察确认）：
- Win10 22H2 (19045)，固件虚拟化已启用 ✓，C 盘 477GB 总量 / **剩 36GB**
- WSL 功能未启用 → 用户执行一次性提权脚本（`tools/setup_wsl_admin.ps1`：启用功能 + WSL2 内核 + 设默认 2）后重启；发行版安装及后续**无需再提权**
- 本机代理 127.0.0.1:7890：WSL2 NAT 下需用 Windows 主机 IP 访问，Clash 需允许局域网（待验证）

**磁盘预算**（C 盘 36GB 剩余）：

| 项 | 估计 |
|---|---|
| WSL Ubuntu 24.04（ext4 动态 vhdx，base + apt 工具链） | 2–3 GB |
| devkitPro（devkitA64 + libnx + switch-dev/portlibs） | 2–3 GB |
| krkr-ns：FFmpeg 源码+交叉编译产物 + build-switch 目录 | 3–5 GB |
| krkr-ns NRO 产物 | ~0.1 GB |
| （后续 K2NX）cocos fetch + 7 portlibs + 构建树 | 8–12 GB |
| 合计 | **15–23 GB → 剩余余量 13–21 GB，可容纳** |

**策略**：装大依赖（K2NX portlibs）前报告 `df -h` 实测；每步构建成功后清理中间产物（FFmpeg 解压源码树、`build-switch` 目标文件保留但可再清理、K2NX 的 opencv/blend2d 构建目录），保留最终 NRO 与压缩归档。WSL vhdx 只增不减，超过 26GB 用量时主动 `wsl --shrink` 或迁出产物。

**内存**：构建用 ninja 默认并行度受 WSL2 默认内存上限（约宿主 50%）约束；若构建期吃紧用 `.wslconfig` 限核。真机侧内存约束（applet 448MB vs takeover ~3.2GB）不适用于开发机。

---

## 6. 批量移植落点摘要（矩阵的工程结论）

1. **新游戏私有插件静态化**：krkr-ns 五步模板（ncbind 模块名 + link 锚 + CMake 清单 + PluginImpl 分发 + 存在性探测登记，`PluginImpl.cpp:61-83,530-750`）；K2NX 单点（`src/plugins/` + NCB_MODULE_NAME + CMake glob + whole-archive 兜底）。两线均天然支持多游戏插件共存一个 NRO。
2. **xp3 加密静态化**：首选零编译方案——游戏目录放 `xp3filter.tjs`（两线一致支持）；性能敏感场景走 krkr-ns 原生分支模板；cxdec 类需新开发。
3. **每游戏适配配置**：krkr-ns=XML(3键) + 12 种 SD marker 文件 + patch.tjs + patch/system/ 目录；K2NX=安卓同款 Kirikiroid2Preference.xml。krkr-ns 的 marker 文件体系更适合自动化逐游戏调优。
4. **游戏目录规范**（给用户/适配文档用）：`sdmc:/switch/KRKR-ns/Game/<GameFolder>/`（ASCII），入口 `data.xp3` 等命中 ENTRY_PREFERENCE 列表；K2NX 放 `sdmc:/kirikiri/<game>/`。
