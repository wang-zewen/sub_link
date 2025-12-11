#!/usr/bin/env node

import { spawn, execSync } from 'child_process';
import { existsSync, writeFileSync, chmodSync, unlinkSync } from 'fs';
import { resolve } from 'path';
import crypto from 'crypto';

// ==================== 配置 ====================
const PORT = process.env.PORT || process.env.SERVER_PORT || '20041';
const XRAY_VERSION = '1.8.24';

// Reality 配置
const DEST = process.env.REALITY_DEST || 'www.microsoft.com:443';
const SERVER_NAMES = process.env.REALITY_SERVER_NAMES || 'www.microsoft.com';

// 默认 UUID - 用户可以在此处修改为自己的 UUID
// 留空则自动生成，或通过环境变量 VLESS_UUID 指定
const DEFAULT_UUID = '9afd1229-b893-40c1-84dd-51e7ce204913';

// ==================== 工具函数 ====================

// 自动生成 UUID
function autoGenerateUUID() {
  // 1. 优先尝试系统命令生成
  try {
    const uuid = execSync('cat /proc/sys/kernel/random/uuid 2>/dev/null || uuidgen 2>/dev/null', {
      encoding: 'utf-8',
      timeout: 2000
    }).trim();

    if (uuid && uuid.length === 36 && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(uuid)) {
      return uuid;
    }
  } catch (err) {
    // 系统命令失败，继续使用其他方法
  }

  // 2. 使用 crypto.randomUUID (Node.js 14.17.0+)
  try {
    if (crypto.randomUUID) {
      return crypto.randomUUID();
    }
  } catch (err) {
    // crypto.randomUUID 不可用
  }

  // 3. 使用 Math.random 生成（最后的 fallback）
  console.log('⚠️  Using Math.random to generate UUID');
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, function(c) {
    const r = Math.random() * 16 | 0;
    const v = c === 'x' ? r : (r & 0x3 | 0x8);
    return v.toString(16);
  });
}

// 获取 UUID：按优先级 1.环境变量 2.脚本指定 3.自动生成
function getUUID() {
  // 优先级 1: 环境变量 VLESS_UUID
  if (process.env.VLESS_UUID) {
    return process.env.VLESS_UUID;
  }

  // 优先级 2: 脚本中指定的默认 UUID
  if (DEFAULT_UUID && /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(DEFAULT_UUID)) {
    console.log('ℹ️  Using DEFAULT_UUID from script');
    return DEFAULT_UUID;
  }

  // 优先级 3: 自动生成
  return autoGenerateUUID();
}

const UUID = getUUID();

// 获取服务器 IP
async function getServerIP() {
  const urls = ['https://api64.ipify.org', 'https://ifconfig.me'];

  for (const url of urls) {
    try {
      const response = await fetch(url, {
        signal: AbortSignal.timeout(3000)
      });
      if (response.ok) {
        return await response.text();
      }
    } catch (err) {
      continue;
    }
  }
  return 'UNKNOWN';
}

// 检测系统架构
function detectArchitecture() {
  try {
    const arch = execSync('uname -m', { encoding: 'utf-8' }).trim();

    console.log(`🔍 Detected architecture: ${arch}`);

    // 架构映射
    if (arch === 'x86_64' || arch === 'amd64') {
      return '64';
    } else if (arch === 'aarch64' || arch === 'arm64') {
      return 'arm64-v8a';
    } else if (arch === 'armv7' || arch === 'armv7l') {
      return 'arm32-v7a';
    } else if (arch === 'armv6' || arch === 'armv6l') {
      return 'arm32-v6';
    } else if (arch.startsWith('mips64')) {
      return 'mips64';
    } else if (arch.startsWith('mips')) {
      return 'mips32';
    } else if (arch === 's390x') {
      return 's390x';
    } else if (arch.startsWith('riscv64')) {
      return 'riscv64';
    } else {
      console.log(`⚠️  Unknown architecture: ${arch}, defaulting to 64-bit`);
      return '64';
    }
  } catch (err) {
    console.log('⚠️  Could not detect architecture, defaulting to 64-bit');
    return '64';
  }
}

// 下载文件
async function downloadFile(url, outputPath) {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`Failed to download: ${response.statusText}`);
  }

  const buffer = await response.arrayBuffer();
  writeFileSync(outputPath, Buffer.from(buffer));
}

// 生成 Reality 密钥对
function generateRealityKeys() {
  try {
    const output = execSync('./xray x25519', { encoding: 'utf-8' });
    const privateKey = output.match(/Private key: (\S+)/)?.[1];
    const publicKey = output.match(/Public key: (\S+)/)?.[1];

    if (!privateKey || !publicKey) {
      throw new Error('Failed to parse keys');
    }

    return { privateKey, publicKey };
  } catch (error) {
    console.error('❌ Failed to generate Reality keys:', error.message);
    process.exit(1);
  }
}

// 生成短 ID
function generateShortId() {
  return crypto.randomBytes(8).toString('hex');
}

// ==================== 节点上传功能 ====================

const DEFAULT_API_URL = 'http://103.69.129.79:8081/api/v1/groups/2/nodes';

async function uploadNodeInfo(vlessLink, ip, port) {
  try {
    // 检查是否跳过上传
    if (process.env.SKIP_NODE_UPLOAD === 'true' || process.env.SKIP_NODE_UPLOAD === '1') {
      console.log('⏭️  Skipping node upload (SKIP_NODE_UPLOAD=true)');
      return;
    }

    // 获取API地址
    const apiUrl = process.env.NODE_API_URL || DEFAULT_API_URL;

    // 生成节点名称
    const location = guessLocationFromIP(ip);
    const nodeName = `${location}-VLESS-Reality-${port}`;

    console.log('');
    console.log('📤 Uploading node to management API...');
    console.log(`📍 API URL: ${apiUrl}`);
    console.log(`🏷️  Node Name: ${nodeName}`);

    // 发送POST请求
    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json'
      },
      body: JSON.stringify({
        name: nodeName,
        config: vlessLink
      }),
      signal: AbortSignal.timeout(10000)
    });

    if (response.ok) {
      const data = await response.text();
      console.log('✅ Node uploaded successfully!');
      console.log(`📊 Response: ${data}`);
    } else {
      console.log(`⚠️  Upload failed with status: ${response.status}`);
      const data = await response.text();
      console.log(`📊 Response: ${data}`);
    }
    console.log('');

  } catch (error) {
    console.error(`⚠️  Failed to upload node: ${error.message}`);
    console.log('ℹ️  Server will continue to run normally.');
    console.log('');
  }
}

function guessLocationFromIP(ip) {
  if (ip.startsWith('103.') || ip.startsWith('119.')) {
    return 'HK';
  } else if (ip.startsWith('172.') || ip.startsWith('45.')) {
    return 'US';
  } else if (ip.startsWith('89.')) {
    return 'EU';
  } else {
    return 'Node';
  }
}

// ==================== 主程序 ====================

async function main() {
  console.log('🚀 VLESS+Reality Server');
  console.log(`📌 Port: ${PORT}`);

  // 获取 IP
  console.log('🌐 Getting server IP...');
  const IP = await getServerIP();
  console.log(`✅ Server IP: ${IP}`);

  // 检测架构
  const arch = detectArchitecture();

  // 下载 Xray（如果不存在）
  const xrayPath = resolve('./xray');
  if (!existsSync(xrayPath)) {
    console.log(`📥 Downloading Xray for ${arch}...`);
    const zipPath = './x.zip';
    const downloadUrl = `https://github.com/XTLS/Xray-core/releases/download/v${XRAY_VERSION}/Xray-linux-${arch}.zip`;

    console.log(`📦 Download URL: ${downloadUrl}`);

    try {
      await downloadFile(downloadUrl, zipPath);

      // 解压
      execSync(`unzip -qo ${zipPath} xray`);
      chmodSync('./xray', 0o755);

      // 删除 zip 文件
      try {
        unlinkSync(zipPath);
      } catch {}

      console.log('✅ Xray installed');
    } catch (error) {
      console.error('❌ Failed to download Xray:', error.message);
      console.error('💡 Please check if your architecture is supported');
      process.exit(1);
    }
  } else {
    console.log('✅ Xray already exists');
  }

  // 生成 Reality 密钥对
  console.log('🔐 Generating Reality keys...');
  const { privateKey, publicKey } = generateRealityKeys();
  const shortId = generateShortId();
  console.log('✅ Keys generated');

  // 生成 Xray 配置
  const config = {
    log: { loglevel: 'warning' },
    inbounds: [
      {
        port: parseInt(PORT),
        protocol: 'vless',
        settings: {
          clients: [
            {
              id: UUID,
              flow: 'xtls-rprx-vision'
            }
          ],
          decryption: 'none'
        },
        streamSettings: {
          network: 'tcp',
          security: 'reality',
          realitySettings: {
            show: false,
            dest: DEST,
            xver: 0,
            serverNames: [SERVER_NAMES],
            privateKey: privateKey,
            shortIds: [shortId]
          }
        },
        sniffing: {
          enabled: true,
          destOverride: ['http', 'tls', 'quic']
        }
      }
    ],
    outbounds: [
      {
        protocol: 'freedom',
        tag: 'direct'
      }
    ]
  };

  writeFileSync('./c.json', JSON.stringify(config, null, 2));

  // 生成 VLESS 链接
  const vlessLink = `vless://${UUID}@${IP}:${PORT}?encryption=none&flow=xtls-rprx-vision&security=reality&sni=${SERVER_NAMES}&fp=chrome&pbk=${publicKey}&sid=${shortId}&type=tcp&headerType=none#VLESS-Reality`;

  writeFileSync('./link.txt', vlessLink);

  // 显示信息
  console.log('');
  console.log('==========================================');
  console.log('🎉 VLESS+Reality Server Ready!');
  console.log('==========================================');
  console.log(`📍 Server: ${IP}:${PORT}`);
  console.log(`🔑 UUID: ${UUID}`);
  console.log(`🔒 Public Key: ${publicKey}`);
  console.log(`🆔 Short ID: ${shortId}`);
  console.log(`🌐 SNI: ${SERVER_NAMES}`);
  console.log(`🎯 Dest: ${DEST}`);
  console.log('');
  console.log('🔗 VLESS Link:');
  console.log(vlessLink);
  console.log('');
  console.log('💾 Link saved to: link.txt');
  console.log('==========================================');
  console.log('');

  // 上传节点信息
  await uploadNodeInfo(vlessLink, IP, PORT);

  // 启动 Xray
  console.log('🚀 Starting Xray...');

  // 获取绝对路径
  const absoluteXrayPath = resolve(xrayPath);
  const absoluteConfigPath = resolve('./c.json');

  console.log(`📂 Xray path: ${absoluteXrayPath}`);
  console.log(`📂 Config path: ${absoluteConfigPath}`);

  // 验证文件存在和权限
  if (!existsSync(absoluteXrayPath)) {
    console.error('❌ Xray executable not found!');
    process.exit(1);
  }

  // 无限循环启动 Xray
  while (true) {
    try {
      const xray = spawn(absoluteXrayPath, ['run', '-c', absoluteConfigPath], {
        stdio: 'inherit',
        cwd: process.cwd()
      });

      await new Promise((resolve) => {
        xray.on('exit', (code) => {
          console.log(`\n⚠️  Xray exited with code ${code}, restarting in 3 seconds...`);
          setTimeout(resolve, 3000);
        });

        xray.on('error', (err) => {
          console.error('❌ Xray error:', err);
          setTimeout(resolve, 3000);
        });
      });
    } catch (error) {
      console.error('❌ Error running Xray:', error);
      await new Promise(resolve => setTimeout(resolve, 3000));
    }
  }
}

// 启动程序
main().catch((error) => {
  console.error('❌ Fatal error:', error);
  process.exit(1);
});
