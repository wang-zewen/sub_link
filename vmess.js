#!/usr/bin/env node

const fs = require('fs');
const https = require('https');
const http = require('http');
const { execSync, spawn } = require('child_process');
const crypto = require('crypto');

// ==================== 配置 ====================
const PORT = process.env.PORT || process.env.SERVER_PORT || 20041;
const UUID = process.env.VMESS_UUID || crypto.randomUUID();
const VERSION = '1.8.24';

console.log('🚀 VMess Server');
console.log(`📌 Port: ${PORT}`);

// ==================== 工具函数 ====================
function httpGet(url, timeout = 3000) {
  return new Promise((resolve, reject) => {
    const client = url.startsWith('https') ? https : http;
    const timer = setTimeout(() => {
      req.destroy();
      reject(new Error('Timeout'));
    }, timeout);

    const req = client.get(url, (res) => {
      clearTimeout(timer);
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => resolve(data.trim()));
    }).on('error', (err) => {
      clearTimeout(timer);
      reject(err);
    });
  });
}

async function getPublicIP() {
  const urls = [
    'https://api64.ipify.org',
    'https://ifconfig.me'
  ];

  for (const url of urls) {
    try {
      return await httpGet(url, 3000);
    } catch (err) {
      continue;
    }
  }
  return 'UNKNOWN';
}

function downloadFile(url, output) {
  return new Promise((resolve, reject) => {
    const file = fs.createWriteStream(output);
    https.get(url, (response) => {
      response.pipe(file);
      file.on('finish', () => {
        file.close();
        resolve();
      });
    }).on('error', (err) => {
      fs.unlink(output, () => {});
      reject(err);
    });
  });
}

async function downloadXray() {
  if (fs.existsSync('xray')) {
    return;
  }

  console.log('📥 Downloading Xray...');
  const zipFile = 'x.zip';
  const downloadUrl = `https://github.com/XTLS/Xray-core/releases/download/v${VERSION}/Xray-linux-64.zip`;

  await downloadFile(downloadUrl, zipFile);
  execSync(`unzip -qo ${zipFile} xray`);
  execSync('chmod +x xray');
  fs.unlinkSync(zipFile);
  console.log('✅ Xray installed');
}

function generateXrayConfig(port, uuid) {
  const config = {
    log: { loglevel: 'none' },
    inbounds: [
      {
        port: parseInt(port),
        protocol: 'vmess',
        settings: {
          clients: [{ id: uuid, alterId: 0 }]
        },
        streamSettings: {
          network: 'tcp',
          tcpSettings: {
            acceptProxyProtocol: false,
            header: {
              type: 'http',
              response: {
                version: '1.1',
                status: '200',
                reason: 'OK',
                headers: {
                  'Content-Type': ['text/html; charset=utf-8'],
                  'Transfer-Encoding': ['chunked'],
                  'Connection': ['keep-alive'],
                  'Pragma': 'no-cache'
                }
              }
            }
          }
        },
        tag: 'vmess'
      }
    ],
    outbounds: [{ protocol: 'freedom' }]
  };

  fs.writeFileSync('c.json', JSON.stringify(config, null, 2));
}

function generateVMessLink(ip, port, uuid) {
  const vmessConfig = {
    v: '2',
    ps: 'VMess-Server',
    add: ip,
    port: port.toString(),
    id: uuid,
    aid: '0',
    net: 'tcp',
    type: 'http',
    tls: ''
  };

  const base64Config = Buffer.from(JSON.stringify(vmessConfig)).toString('base64');
  return `vmess://${base64Config}`;
}

function getLocationFromIP(ip) {
  if (ip.startsWith('103.') || ip.startsWith('119.')) {
    return 'HK';
  } else if (ip.startsWith('172.') || ip.startsWith('45.')) {
    return 'US';
  } else if (ip.startsWith('89.')) {
    return 'EU';
  }
  return 'Node';
}

async function uploadNodeInfo(ip, port, vmessLink) {
  const DEFAULT_API = 'http://103.69.129.79:8081/api/v1/groups/2/nodes';

  // 检查是否跳过上传
  if (process.env.SKIP_NODE_UPLOAD === 'true') {
    console.log('⏭️  Skipping node upload (SKIP_NODE_UPLOAD=true)');
    return;
  }

  let apiUrl = process.env.NODE_API_URL;

  // 如果没有设置环境变量且不是在自动化环境中
  if (!apiUrl && process.stdin.isTTY) {
    const readline = require('readline');
    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout
    });

    console.log('==========================================');
    console.log('📤 Node Upload Configuration');
    console.log('==========================================');
    console.log('Would you like to upload node info to management API?');
    console.log('1. Use default API');
    console.log('2. Enter custom API URL');
    console.log('3. Skip (press Enter or any other key)');

    const choice = await new Promise(resolve => {
      rl.question('Your choice: ', answer => {
        rl.close();
        resolve(answer.trim());
      });
    });

    switch (choice) {
      case '1':
        apiUrl = DEFAULT_API;
        break;
      case '2':
        const customUrl = await new Promise(resolve => {
          const rl2 = readline.createInterface({
            input: process.stdin,
            output: process.stdout
          });
          rl2.question('Enter API URL: ', answer => {
            rl2.close();
            resolve(answer.trim());
          });
        });
        if (!customUrl) {
          console.log('⏭️  Skipping node upload.');
          return;
        }
        apiUrl = customUrl;
        break;
      default:
        console.log('⏭️  Skipping node upload.');
        return;
    }
  } else if (!apiUrl) {
    // 非交互模式且没有设置环境变量，跳过上传
    console.log('⏭️  Skipping node upload (non-interactive mode).');
    return;
  }

  const location = getLocationFromIP(ip);
  const nodeName = `${location}-VMess-${port}`;

  console.log('');
  console.log('📤 Uploading node to management API...');
  console.log(`📍 API URL: ${apiUrl}`);
  console.log(`🏷️  Node Name: ${nodeName}`);

  const postData = JSON.stringify({
    name: nodeName,
    config: vmessLink
  });

  return new Promise((resolve) => {
    const urlObj = new URL(apiUrl);
    const client = urlObj.protocol === 'https:' ? https : http;

    const options = {
      hostname: urlObj.hostname,
      port: urlObj.port,
      path: urlObj.pathname + urlObj.search,
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Content-Length': Buffer.byteLength(postData)
      },
      timeout: 15000
    };

    const req = client.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => data += chunk);
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          console.log('✅ Node uploaded successfully!');
          if (data) console.log(`📊 Response: ${data}`);
        } else {
          console.log(`⚠️  Upload failed with status: ${res.statusCode}`);
          if (data) console.log(`📊 Response: ${data}`);
        }
        console.log('');
        resolve();
      });
    });

    req.on('error', (err) => {
      console.log(`⚠️  Upload failed: ${err.message}`);
      console.log('');
      resolve();
    });

    req.on('timeout', () => {
      req.destroy();
      console.log('⚠️  Upload timeout');
      console.log('');
      resolve();
    });

    req.write(postData);
    req.end();
  });
}

function startXray() {
  console.log('🚀 Starting Xray...');

  const start = () => {
    const xray = spawn('./xray', ['run', '-c', 'c.json'], {
      stdio: 'ignore'
    });

    xray.on('error', (err) => {
      console.error('❌ Failed to start Xray:', err.message);
      setTimeout(start, 3000);
    });

    xray.on('exit', (code) => {
      console.log(`⚠️  Xray exited with code ${code}, restarting in 3s...`);
      setTimeout(start, 3000);
    });
  };

  start();
}

// ==================== 主函数 ====================
async function main() {
  try {
    // 获取 IP
    const ip = await getPublicIP();
    console.log(`✅ Server IP: ${ip}`);

    // 下载 Xray
    await downloadXray();

    // 生成配置
    generateXrayConfig(PORT, UUID);

    // 生成 VMess 链接
    const vmessLink = generateVMessLink(ip, PORT, UUID);
    fs.writeFileSync('link.txt', vmessLink);

    console.log('');
    console.log('==========================================');
    console.log('🎉 VMess Server Ready!');
    console.log('==========================================');
    console.log(`📍 Server: ${ip}:${PORT}`);
    console.log(`🔑 UUID: ${UUID}`);
    console.log('');
    console.log('🔗 VMess Link:');
    console.log(vmessLink);
    console.log('');
    console.log('💾 Link saved to: link.txt');
    console.log('==========================================');
    console.log('');

    // 上传节点信息
    await uploadNodeInfo(ip, PORT, vmessLink);

    // 启动 Xray
    startXray();

  } catch (err) {
    console.error('❌ Error:', err.message);
    process.exit(1);
  }
}

// 处理进程信号
process.on('SIGINT', () => {
  console.log('\n👋 Shutting down...');
  process.exit(0);
});

process.on('SIGTERM', () => {
  console.log('\n👋 Shutting down...');
  process.exit(0);
});

// 运行主函数
main();
