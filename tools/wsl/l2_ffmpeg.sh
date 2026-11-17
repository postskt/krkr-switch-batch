#!/usr/bin/env bash
# L2: krkr-ns 同步进 WSL ext4 + FFmpeg 7.1 Switch 子集交叉编译
# 说明：/mnt/c（drvfs）上编译海量小文件极慢，构建树放 ~/krkr-ns；
#       FFmpeg 源码包由 Windows 侧预下载（sha256 已核对上游脚本预期值）。
set -euo pipefail
export DEVKITPRO=/opt/devkitpro
export DEVKITA64="$DEVKITPRO/devkitA64"
export PATH="$DEVKITA64/bin:$DEVKITPRO/tools/bin:$PATH"
export no_proxy="localhost,127.0.0.1,::1"

# 输入由环境变量提供（发布版不绑定任何机器路径）：
#   KRKRNS_SRC  指向 krkr-ns 检出目录（Windows 侧 CRLF 工作区即可，脚本会清洗）
#   FFMPEG_PKG  指向 ffmpeg-7.1.tar.xz 源码包（sha256 校验值见下方）
SRC="${KRKRNS_SRC:?Please set KRKRNS_SRC to your krkr-ns checkout directory}"
PKG="${FFMPEG_PKG:?Please set FFMPEG_PKG to your ffmpeg-7.1.tar.xz package}"
K2="${K2WS:-$HOME/krkr-ns}"

echo "== rsync krkr-ns -> $K2 =="
rsync -a --delete --info=progress2 "$SRC/" "$K2/"
# Windows 侧 git clone 是 CRLF 工作区；WSL 里 bash/CRLF 会炸（pipefail\r），
# 只清洗构建树里的 sh/patch（CMake/C++ 源对 CRLF 不敏感，不动）
find "$K2" \( -name "*.sh" -o -name "*.patch" \) -type f -exec sed -i 's/\r$//' {} +
mkdir -p "$K2/out"
echo "== 校验源码包 =="
echo "40973d44970dbc83ef302b0609f2e74982be2d85916dd2ee7472d30678a7abe6  $PKG" | sha256sum -c -
cp "$PKG" "$K2/out/ffmpeg-7.1.tar.xz"

echo "== FFmpeg 交叉编译 =="
FFMPEG_MAKE=/usr/bin/make bash "$K2/tools/build_ffmpeg_switch.sh"

echo "== 产物 =="
ls -la "$K2/out/ffmpeg_switch/lib"
echo "L2 完成"
