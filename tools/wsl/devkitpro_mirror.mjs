// devkitPro 仓库镜像代理（Windows 用户级，免管理员）
// 背景：apt.devkitpro.org / deb.devkitpro.org 走 Cloudflare WAF，按 TLS 指纹放行
// Windows 版 curl（OpenSSL mingw 构建）、拦截 Ubuntu curl(GnuTLS)/python(ssl) 的握手
// （403 或 SSL_ERROR_SYSCALL）。本服务在 0.0.0.0:17892 接收 WSL 的 apt/pacman 请求，
// 用 Windows curl 抓取上游后回传 —— 等价于把"正确的 TLS 指纹"借给 WSL。
//
// 路由（仅允许 devkitPro 两个域名，非开放代理）：
//   /aptroot/* -> https://apt.devkitpro.org/*    （apt 源：devkitpro-pacman/keyring）
//   /deb/*     -> https://deb.devkitpro.org/*    （pacman 仓库：devkitA64/libnx/switch-*）
// 用法: node tools/wsl/devkitpro_mirror.mjs
import http from 'node:http';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { spawn, execSync } from 'node:child_process';

const PORT = Number(process.env.MIRROR_PORT || 17892);
const ROUTES = [
  ['/aptroot/', 'https://apt.devkitpro.org/'],
  ['/deb/', 'https://deb.devkitpro.org/'],
];

// 明确选用 Git for Windows 的 mingw64 curl（已验证能过 Cloudflare 的指纹），
// 回退 PATH 中的第一个 curl 并打印实际使用的二进制，便于排查。
function resolveCurl() {
  try {
    const out = execSync('where curl', { encoding: 'utf8' }).split(/\r?\n/).filter(Boolean);
    const git = out.find((p) => /Git[\\/]mingw64[\\/]bin[\\/]curl\.exe/i.test(p));
    return git || out[0];
  } catch {
    return 'curl';
  }
}
const CURL = resolveCurl();
console.log(`mirror: using curl = ${CURL}`);

const server = http.createServer((req, res) => {
  const urlPath = decodeURIComponent(req.url.split('?')[0]);
  const route = ROUTES.find(([p]) => urlPath.startsWith(p));
  if (!route) {
    res.writeHead(404, { 'content-type': 'text/plain' });
    res.end(`mirror: no route for ${urlPath}`);
    return;
  }
  const upstream = route[1] + urlPath.slice(route[0].length);
  const tmp = path.join(os.tmpdir(), `dkpmirror-${Date.now()}-${Math.random().toString(16).slice(2)}`);
  // -f: 4xx/5xx 时 curl 以非零退出（状态码仍写到 stdout），镜像如实回传状态
  const child = spawn(CURL, ['-fsSL', '--max-time', '900', '-o', tmp, '-w', '%{http_code}', upstream]);
  let code = '';
  child.stdout.on('data', (d) => { code += d; });
  let err = '';
  child.stderr.on('data', (d) => { err += d; });
  child.on('close', (c) => {
    if (c !== 0 || !/^\d{3}$/.test(code)) {
      console.log(`MISS ${code || c} ${urlPath} ${err.trim().slice(0, 160)}`);
      res.writeHead(502, { 'content-type': 'text/plain' });
      res.end(`mirror upstream failed: ${code || `exit ${c}`} ${err.trim().slice(0, 400)}`);
      fs.rm(tmp, { force: true }, () => {});
      return;
    }
    let size = 0;
    try { size = fs.statSync(tmp).size; } catch { /* empty body ok */ }
    console.log(`OK ${code} ${urlPath} (${size}B)`);
    res.writeHead(Number(code), { 'content-length': size });
    const stream = fs.createReadStream(tmp);
    stream.on('close', () => fs.rm(tmp, { force: true }, () => {}));
    stream.pipe(res);
  });
  req.on('aborted', () => child.kill());
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`devkitpro mirror listening 0.0.0.0:${PORT}`);
  console.log('  /aptroot/ -> https://apt.devkitpro.org/');
  console.log('  /deb/     -> https://deb.devkitpro.org/');
});
