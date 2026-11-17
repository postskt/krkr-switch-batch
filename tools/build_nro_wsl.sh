#!/usr/bin/env bash
# krkr-ns WSL2 构建脚本（本项目 tools/，不改上游文件）
# 上游 build_nro.sh 是 Windows 原生的（写死 D:/devkitPro 与作者机器的
# KRKR-ns-tools 工具目录），本脚本按 decision.md 风险项 K1 的方案做
# WSL/devkitPro-Linux 等价实现：
#   - DEVKITPRO=/opt/devkitpro（dkp-pacman 标准位置）
#   - 官方 /opt/devkitpro/cmake/Switch.cmake 替代作者私有 Switch.toolchain.cmake
#   - cmake/ninja/pkg-config/python3 用 apt（不走作者的内嵌二进制目录）
#   - FFmpeg 静态子集由 tools/build_ffmpeg_switch.sh 产出（FFMPEG_MAKE 用系统 make）
#   - 保留 GCS unwind cbnz 补丁步（Nextendo 模拟器兼容，真机无影响）
#   - 去掉模拟器拷贝步（本机无 Nextendo 环境）
# 用法：bash tools/build_nro_wsl.sh [--no-patch]
# 产物：build-switch/krkrsdl2.nro，并复制到本仓 dist/
# 状态：草案（L3 预推进版），待 WSL 环境就绪后实测迭代
set -euo pipefail

# ---- 路径约定 ----
# 本仓根（含 upstream/ tools/ dist/）：默认由脚本位置推导
REPO_ROOT="$(cd -P "$(dirname "$0")/.." && pwd)"
KRKRNS="${KRKRNS_DIR:-$REPO_ROOT/upstream/krkr-ns}"
ENGINE="$KRKRNS/krkrsdl2"

# ---- devkitPro 环境（WSL/Linux 标准布局）----
export DEVKITPRO="${DEVKITPRO:-/opt/devkitpro}"
export DEVKITA64="$DEVKITPRO/devkitA64"
export PKG_CONFIG_PATH="$DEVKITPRO/portlibs/switch/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export PATH="$DEVKITPRO/devkitA64/bin:$DEVKITPRO/tools/bin:$PATH"

for c in cmake ninja python3 pkg-config elf2nro nacptool; do
  command -v "$c" >/dev/null 2>&1 || { echo "缺工具: $c（cmake/ninja/pkg-config/python3 属 apt；elf2nro/nacptool 属 devkitPro 的 switch-tools 包）" >&2; exit 1; }
done
[[ -d "$DEVKITPRO/devkitA64" ]] || { echo "缺 devkitPro: $DEVKITPRO/devkitA64 不存在" >&2; exit 1; }
[[ -d "$KRKRNS/out/ffmpeg_switch/lib" ]] || {
  echo "缺 FFmpeg 交叉产物: $KRKRNS/out/ffmpeg_switch" >&2
  echo "先跑: bash upstream/krkr-ns/tools/build_ffmpeg_switch.sh（FFMPEG_MAKE=make）" >&2
  exit 1
}

DO_PATCH=1
for a in "$@"; do
  case "$a" in
    --no-patch) DO_PATCH=0 ;;
  esac
done

cd "$KRKRNS"

echo "== configure =="
cmake -S krkrsdl2 -B build-switch -G Ninja \
  -DCMAKE_TOOLCHAIN_FILE="$DEVKITPRO/cmake/Switch.cmake" \
  -DNINTENDO_SWITCH=ON \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DOPTION_BUILD_MACOS_BUNDLE=OFF

echo "== build =="
cmake --build build-switch

# 官方 Switch.cmake 的可执行输出带 .elf 后缀（与作者私有 toolchain 的无后缀命名不同）；
# CMake 在 build 阶段已生成 krkrsdl2.nacp 与初版 nro（romfs/data 未拍平），
# 下文补丁 + 拍平后用 elf2nro 重打包覆盖。
ELF=build-switch/krkrsdl2.elf
NRO=build-switch/krkrsdl2.nro

if [ "$DO_PATCH" = 1 ]; then
  echo "== patch GCS unwind (Nextendo emulator chkfeat bug workaround) =="
  # 与上游 build_nro.sh:46-73 等价；差异：python->python3、输入 ELF 路径改为环境变量
  # 传入（官方 Switch.cmake 输出带 .elf 后缀，且上游把文件名硬编码在 python 里）
  KRKRNS_ELF="$ELF" python3 - <<'PYEOF'
import os, struct
elf_in = os.environ['KRKRNS_ELF']
data = bytearray(open(elf_in,'rb').read())
pos = 0
sites = []
while True:
    i = data.find(bytes.fromhex('1F2503D5'), pos)
    if i < 0: break
    sites.append(i); pos = i+1
n = 0
for fo in sites:
    va = fo - 0x10000
    for k in range(4, 24, 4):
        w = struct.unpack('<I', data[fo+k:fo+k+4])[0]
        if (w >> 24) != 0xB5: continue
        imm19 = (w >> 5) & 0x7FFFF
        if imm19 & 0x40000: imm19 -= 0x80000
        cbnz_va = va + k
        target = cbnz_va + (imm19 << 2)
        imm26 = ((target - cbnz_va) >> 2) & 0x3FFFFFF
        data[fo+k:fo+k+4] = struct.pack('<I', 0x14000000 | imm26)
        print('  patched cbnz@%x -> b %x' % (cbnz_va, target))
        n += 1
        break
open('build-switch/krkrsdl2-patched.elf','wb').write(data)
print('patched %d chkfeat/cbnz sites (in %s)' % (n, elf_in))
PYEOF
  ELF=build-switch/krkrsdl2-patched.elf
fi

echo "== package NRO =="
# RomFS：引擎要求 startup.tjs 位于归档根，故把 cmake 产出的 data/ 拍平。
# 与上游 build_nro.sh:79-91 一致；retired motion.tjs 必须删（会遮蔽原生 E-mote）。
ROMFS_DATA_ABS="$(realpath -m build-switch/romfs/data)"
if [[ "$ROMFS_DATA_ABS" != "$PWD/build-switch/romfs/data" ]]; then
  echo "Refusing to clean RomFS data outside the build directory" >&2
  exit 1
fi
rm -rf -- "$ROMFS_DATA_ABS"
cp -r krkrsdl2/data/. build-switch/romfs/
mkdir -p build-switch/romfs/compat/system
rm -f build-switch/romfs/compat/system/motion.tjs
cp -r compat-patches/system/. build-switch/romfs/compat/system/

# nacp：Linux 下 elf2nro 不一定自动生成，显式产出。
# 标题/作者/版本运行时从 CMakeCache.txt 读 SWITCH_APP_NAME/SWITCH_AUTHOR/SWITCH_VERSION，
# 保证与 CMake 侧一致；缓存行缺失时才退回 CMakeLists.txt:133-135 的缺省值。
read_nacp_field() {
  local key="$1" def="$2" v
  v="$(sed -n -E "s/^${key}:[^=]*=//p" build-switch/CMakeCache.txt 2>/dev/null | head -n1)"
  printf '%s' "${v:-$def}"
}
NACP=build-switch/krkrsdl2.nacp
if [[ ! -f "$NACP" ]]; then
  NACP_TITLE="$(read_nacp_field SWITCH_APP_NAME "Kirikiri SDL2")"
  NACP_AUTHOR="$(read_nacp_field SWITCH_AUTHOR "uyjulian")"
  NACP_VERSION="$(read_nacp_field SWITCH_VERSION "v0.1.0")"
  "$DEVKITPRO/tools/bin/nacptool" --create "$NACP_TITLE" "$NACP_AUTHOR" "$NACP_VERSION" "$NACP"
fi

"$DEVKITPRO/tools/bin/elf2nro" "$ELF" "$NRO" \
  --icon=krkrsdl2/src/resources/nswitch/icon.jpg \
  --nacp="$NACP" \
  --romfsdir=build-switch/romfs

echo "== dist =="
mkdir -p "$REPO_ROOT/dist"
cp "$NRO" "$REPO_ROOT/dist/krkrsdl2.nro"

echo "== done: $NRO =="
ls -la "$NRO" "$REPO_ROOT/dist/krkrsdl2.nro"
