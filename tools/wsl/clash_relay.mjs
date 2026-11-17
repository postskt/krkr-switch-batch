// WSL2 → Windows 主机 Clash 中继（用户级，免管理员）
// 背景：Clash 仅监听 127.0.0.1:7890（Allow LAN 未开），WSL2 NAT 下 127.0.0.1 不可达。
// 本中继在 0.0.0.0:17890 收 WSL 侧连接，转发到本机回环的 Clash。
// 用法: node tools/wsl/clash_relay.mjs   （保持运行；LSK2 环境下由 ZCode 后台任务托管）
import net from 'node:net';

const LISTEN_PORT = Number(process.env.RELAY_PORT || 17890);
const TARGET_PORT = Number(process.env.CLASH_PORT || 7890);
const TARGET_HOST = '127.0.0.1';

const server = net.createServer((client) => {
  const upstream = net.connect(TARGET_PORT, TARGET_HOST);
  client.pipe(upstream);
  upstream.pipe(client);
  const bye = () => { client.destroy(); upstream.destroy(); };
  client.on('error', bye);
  upstream.on('error', bye);
  client.on('close', bye);
  upstream.on('close', bye);
});

server.on('error', (e) => { console.error('relay error:', e.message); process.exit(1); });
server.listen(LISTEN_PORT, '0.0.0.0', () => {
  console.log(`relay listening 0.0.0.0:${LISTEN_PORT} -> ${TARGET_HOST}:${TARGET_PORT}`);
});
