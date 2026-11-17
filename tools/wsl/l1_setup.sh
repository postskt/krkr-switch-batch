#!/usr/bin/env bash
# L1: WSL Ubuntu 24.04 初始化 —— 代理 + apt 基础包 + devkitPro（devkitA64/switch-tools/portlibs）
# 由 Windows 侧以 root 调用：
#   wsl.exe -d Ubuntu-24.04 -u root -- bash /mnt/c/<workspace>/tools/wsl/l1_setup.sh
# 代理经 Windows 主机 IP 访问本机 Clash（NAT 模式；Clash 需允许局域网连接）
set -euo pipefail

# 默认走 node 中继 0.0.0.0:17890 -> 127.0.0.1:7890（Clash 未开 Allow LAN，
# 用户级中继 tools/wsl/clash_relay.mjs 免管理员；需保持该进程运行）。
# 若 Clash 已开 Allow LAN 可 export CLASH_PORT=7890 直连。
CLASH_PORT="${CLASH_PORT:-17890}"
HOSTIP="$(ip route show default | awk '{print $3}')"
PROXY="http://${HOSTIP}:${CLASH_PORT}"
export http_proxy="$PROXY" https_proxy="$PROXY"
export no_proxy="localhost,127.0.0.1,::1"
echo "== 主机代理: $PROXY =="

# 连通性测试（失败通常是 Clash 未开 Allow LAN，或防火墙拦 WSL 子网）
if ! curl -sI --max-time 10 https://github.com 2>&1 | head -1; then
  echo "代理连通失败：检查 Clash Allow LAN / Windows 防火墙对 WSL 子网的放行" >&2
  exit 2
fi

# apt 走同一代理；每次运行重写，防主机 IP 漂移
cat > /etc/apt/apt.conf.d/95krkr-proxy <<EOF
Acquire::http::Proxy "$PROXY";
Acquire::https::Proxy "$PROXY";
EOF

echo "== apt update + 基础包 =="
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends \
  build-essential cmake ninja-build pkg-config python3 curl wget ca-certificates \
  patch xz-utils file git rsync

echo "== devkitPro pacman（经本仓 Windows 侧镜像代理，见 devkitpro_mirror.mjs） =="
# Cloudflare WAF 按 TLS 指纹拦 WSL 侧客户端（GnuTLS/通用 OpenSSL），放行 Windows mingw curl。
# 故 apt/pacman 的 devkitPro 仓库一律走 http://$HOSTIP:17892（node 镜像，上游 https 时由
# Windows curl 拉取，完整性由其证书校验保证；apt 源标记 trusted=yes 跳过本地 gpg 复核）。
MIRROR="http://${HOSTIP}:17892"
# apt 对镜像直连（不经 Clash 中继，避免绕环）
cat > /etc/apt/apt.conf.d/96krkr-mirror-direct <<EOF
Acquire::http::Proxy::"${HOSTIP}" "DIRECT";
EOF
# 布局对齐官方 install-devkitpro-pacman.sh：dists=stable, components=main
mkdir -p /usr/share/keyring
curl -fsS --max-time 60 -o /usr/share/keyring/devkitpro-pub.gpg "${MIRROR}/aptroot/devkitpro-pub.gpg"
cat > /etc/apt/sources.list.d/devkitpro.list <<EOF
deb [signed-by=/usr/share/keyring/devkitpro-pub.gpg] ${MIRROR}/aptroot stable main
EOF
apt-get update
apt-get install -y --no-install-recommends devkitpro-pacman

# pacman 仓库镜像重写（幂等：每次按当前主机 IP 重写）
sed -i "s|https://deb.devkitpro.org/|${MIRROR}/deb/|g" \
  /opt/devkitpro/etc/pacman.conf /opt/devkitpro/etc/pacman.d/* 2>/dev/null || true
export no_proxy="${HOSTIP},localhost,127.0.0.1"

echo "== dkp-pacman: switch-dev + krkr-ns 所需 portlibs =="
dkp-pacman -Syy --noconfirm --needed
dkp-pacman -S --noconfirm --needed switch-dev \
  switch-sdl2 switch-libpng switch-libwebp switch-libvorbis switch-libogg

echo "== 校验 =="
export DEVKITPRO=/opt/devkitpro
export DEVKITA64="$DEVKITPRO/devkitA64"
export PKG_CONFIG_PATH="$DEVKITPRO/portlibs/switch/lib/pkgconfig"
export PATH="$DEVKITPRO/devkitA64/bin:$DEVKITPRO/tools/bin:$PATH"
test -f "$DEVKITPRO/cmake/Switch.cmake" || { echo "缺 $DEVKITPRO/cmake/Switch.cmake" >&2; exit 1; }
for pc in sdl2 libpng16 vorbis vorbisfile ogg; do
  pkg-config --exists "$pc" || { echo "缺 pkg-config 模块: $pc" >&2; exit 1; }
  echo "  pc OK: $pc"
done
command -v elf2nro nacptool >/dev/null || { echo "缺 switch-tools（elf2nro/nacptool）" >&2; exit 1; }
echo "L1 完成"
