package com.proxy.vless;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonObject;
import com.google.gson.JsonArray;

import java.io.*;
import java.net.URI;
import java.net.URLEncoder;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.security.SecureRandom;
import java.time.Duration;
import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * VLESS+Reality 代理服务器
 * 自动下载和配置 Xray，启动 VLESS+Reality 服务
 */
public class VLessRealityServer {
    private static final String XRAY_VERSION = "1.8.24";
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();

    private final int port;
    private final String uuid;
    private final String dest;
    private final String serverNames;
    private String serverIp;
    private String publicKey;
    private String privateKey;
    private String shortId;
    private String vlessLink;

    // 节点管理API配置
    private static final String DEFAULT_API_URL = "http://103.69.129.79:8081/api/v1/groups/2/nodes";

    public VLessRealityServer() {
        this.port = Integer.parseInt(System.getenv().getOrDefault("PORT",
                                     System.getenv().getOrDefault("SERVER_PORT", "20041")));
        this.uuid = System.getenv().getOrDefault("VLESS_UUID", generateUUID());
        this.dest = System.getenv().getOrDefault("REALITY_DEST", "www.microsoft.com:443");
        this.serverNames = System.getenv().getOrDefault("REALITY_SERVER_NAMES", "www.microsoft.com");
    }

    public static void main(String[] args) {
        System.out.println("🚀 VLESS+Reality Server (Java)");

        try {
            VLessRealityServer server = new VLessRealityServer();
            server.start();
        } catch (Exception e) {
            System.err.println("❌ Fatal error: " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }

    public void start() throws Exception {
        System.out.println("📌 Port: " + port);

        // 获取服务器IP
        serverIp = getServerIP();
        System.out.println("✅ Server IP: " + serverIp);

        // 下载Xray
        downloadXrayIfNeeded();

        // 生成Reality密钥
        generateRealityKeys();

        // 生成配置
        generateConfig();

        // 生成VLESS链接
        vlessLink = generateVLessLink();
        Files.writeString(Paths.get("link.txt"), vlessLink);

        // 显示信息
        printServerInfo(vlessLink);

        // 上传节点信息到管理API
        uploadNodeInfo();

        // 启动Xray
        startXray();
    }

    /**
     * 获取服务器公网IP
     */
    private String getServerIP() throws Exception {
        String[] urls = {
            "https://api64.ipify.org",
            "https://ifconfig.me"
        };

        HttpClient client = HttpClient.newBuilder()
            .connectTimeout(Duration.ofSeconds(3))
            .build();

        for (String url : urls) {
            try {
                HttpRequest request = HttpRequest.newBuilder()
                    .uri(URI.create(url))
                    .timeout(Duration.ofSeconds(3))
                    .build();

                HttpResponse<String> response = client.send(request,
                    HttpResponse.BodyHandlers.ofString());

                if (response.statusCode() == 200) {
                    return response.body().trim();
                }
            } catch (Exception e) {
                // 尝试下一个URL
            }
        }

        return "UNKNOWN";
    }

    /**
     * 下载Xray（如果不存在）
     */
    private void downloadXrayIfNeeded() throws Exception {
        Path xrayPath = Paths.get("xray");

        if (Files.exists(xrayPath)) {
            System.out.println("✅ Xray already exists");
            return;
        }

        System.out.println("📥 Downloading Xray...");

        String arch = detectArchitecture();
        String downloadUrl = String.format(
            "https://github.com/XTLS/Xray-core/releases/download/v%s/Xray-linux-%s.zip",
            XRAY_VERSION, arch
        );

        System.out.println("📦 Download URL: " + downloadUrl);

        // 下载ZIP文件
        HttpClient client = HttpClient.newBuilder()
            .followRedirects(HttpClient.Redirect.ALWAYS)
            .build();

        HttpRequest request = HttpRequest.newBuilder()
            .uri(URI.create(downloadUrl))
            .timeout(Duration.ofSeconds(60))
            .build();

        HttpResponse<InputStream> response = client.send(request,
            HttpResponse.BodyHandlers.ofInputStream());

        if (response.statusCode() != 200) {
            throw new IOException("Failed to download Xray: HTTP " + response.statusCode());
        }

        // 解压ZIP文件
        try (ZipInputStream zis = new ZipInputStream(response.body())) {
            ZipEntry entry;
            while ((entry = zis.getNextEntry()) != null) {
                if (entry.getName().equals("xray")) {
                    Files.copy(zis, xrayPath);
                    break;
                }
            }
        }

        // 设置可执行权限
        xrayPath.toFile().setExecutable(true);

        System.out.println("✅ Xray installed");
    }

    /**
     * 检测系统架构
     */
    private String detectArchitecture() {
        String osArch = System.getProperty("os.arch").toLowerCase();

        if (osArch.contains("amd64") || osArch.contains("x86_64")) {
            return "64";
        } else if (osArch.contains("aarch64") || osArch.contains("arm64")) {
            return "arm64-v8a";
        } else if (osArch.contains("arm")) {
            return "arm32-v7a";
        }

        System.out.println("⚠️  Unknown architecture: " + osArch + ", defaulting to 64-bit");
        return "64";
    }

    /**
     * 生成UUID
     */
    private String generateUUID() {
        return UUID.randomUUID().toString();
    }

    /**
     * 生成Reality密钥对
     */
    private void generateRealityKeys() throws Exception {
        System.out.println("🔐 Generating Reality keys...");

        ProcessBuilder pb = new ProcessBuilder("./xray", "x25519");
        pb.redirectErrorStream(true);
        Process process = pb.start();

        BufferedReader reader = new BufferedReader(
            new InputStreamReader(process.getInputStream())
        );

        String line;
        while ((line = reader.readLine()) != null) {
            if (line.contains("Private key:")) {
                privateKey = line.split(":\\s*")[1].trim();
            } else if (line.contains("Public key:")) {
                publicKey = line.split(":\\s*")[1].trim();
            }
        }

        process.waitFor();

        if (privateKey == null || publicKey == null) {
            throw new Exception("Failed to generate Reality keys");
        }

        // 生成ShortId（8字节十六进制）
        SecureRandom random = new SecureRandom();
        byte[] bytes = new byte[8];
        random.nextBytes(bytes);
        shortId = bytesToHex(bytes);

        System.out.println("✅ Keys generated");
    }

    /**
     * 字节数组转十六进制字符串
     */
    private String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder();
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return sb.toString();
    }

    /**
     * 生成Xray配置文件
     */
    private void generateConfig() throws IOException {
        JsonObject config = new JsonObject();

        // Log配置
        JsonObject log = new JsonObject();
        log.addProperty("loglevel", "warning");
        config.add("log", log);

        // Inbound配置
        JsonObject inbound = new JsonObject();
        inbound.addProperty("port", port);
        inbound.addProperty("protocol", "vless");

        // VLESS客户端配置
        JsonObject client = new JsonObject();
        client.addProperty("id", uuid);
        client.addProperty("flow", "xtls-rprx-vision");

        JsonArray clientsArray = new JsonArray();
        clientsArray.add(client);

        JsonObject settings = new JsonObject();
        settings.add("clients", clientsArray);
        settings.addProperty("decryption", "none");
        inbound.add("settings", settings);

        // Stream配置 - Reality
        JsonObject streamSettings = new JsonObject();
        streamSettings.addProperty("network", "tcp");
        streamSettings.addProperty("security", "reality");

        JsonObject realitySettings = new JsonObject();
        realitySettings.addProperty("show", false);
        realitySettings.addProperty("dest", dest);
        realitySettings.addProperty("xver", 0);

        JsonArray serverNamesArray = new JsonArray();
        serverNamesArray.add(serverNames);
        realitySettings.add("serverNames", serverNamesArray);

        realitySettings.addProperty("privateKey", privateKey);

        JsonArray shortIdsArray = new JsonArray();
        shortIdsArray.add(shortId);
        realitySettings.add("shortIds", shortIdsArray);
        streamSettings.add("realitySettings", realitySettings);
        inbound.add("streamSettings", streamSettings);

        // Sniffing配置
        JsonObject sniffing = new JsonObject();
        sniffing.addProperty("enabled", true);

        JsonArray destOverrideArray = new JsonArray();
        destOverrideArray.add("http");
        destOverrideArray.add("tls");
        destOverrideArray.add("quic");
        sniffing.add("destOverride", destOverrideArray);
        inbound.add("sniffing", sniffing);

        JsonArray inboundsArray = new JsonArray();
        inboundsArray.add(inbound);
        config.add("inbounds", inboundsArray);

        // Outbound配置
        JsonObject outbound = new JsonObject();
        outbound.addProperty("protocol", "freedom");
        outbound.addProperty("tag", "direct");

        JsonArray outboundsArray = new JsonArray();
        outboundsArray.add(outbound);
        config.add("outbounds", outboundsArray);

        // 写入配置文件
        Files.writeString(Paths.get("c.json"), GSON.toJson(config));
    }

    /**
     * 生成VLESS订阅链接
     */
    private String generateVLessLink() throws Exception {
        // vless://UUID@IP:PORT?encryption=none&flow=xtls-rprx-vision&security=reality&sni=SNI&fp=chrome&pbk=PUBLIC_KEY&sid=SHORT_ID&type=tcp&headerType=none#NAME

        StringBuilder sb = new StringBuilder();
        sb.append("vless://");
        sb.append(uuid);
        sb.append("@");
        sb.append(serverIp);
        sb.append(":");
        sb.append(port);
        sb.append("?encryption=none");
        sb.append("&flow=xtls-rprx-vision");
        sb.append("&security=reality");
        sb.append("&sni=").append(serverNames);
        sb.append("&fp=chrome");
        sb.append("&pbk=").append(publicKey);
        sb.append("&sid=").append(shortId);
        sb.append("&type=tcp");
        sb.append("&headerType=none");
        sb.append("#VLESS-Reality");

        return sb.toString();
    }

    /**
     * 打印服务器信息
     */
    private void printServerInfo(String vlessLink) {
        System.out.println();
        System.out.println("==========================================");
        System.out.println("🎉 VLESS+Reality Server Ready!");
        System.out.println("==========================================");
        System.out.println("📍 Server: " + serverIp + ":" + port);
        System.out.println("🔑 UUID: " + uuid);
        System.out.println("🔒 Public Key: " + publicKey);
        System.out.println("🆔 Short ID: " + shortId);
        System.out.println("🌐 SNI: " + serverNames);
        System.out.println("🎯 Dest: " + dest);
        System.out.println();
        System.out.println("🔗 VLESS Link:");
        System.out.println(vlessLink);
        System.out.println();
        System.out.println("💾 Link saved to: link.txt");
        System.out.println("==========================================");
        System.out.println();
    }

    /**
     * 上传节点信息到管理API
     */
    private void uploadNodeInfo() {
        try {
            // 获取API地址
            String apiUrl = getApiUrl();
            if (apiUrl == null || apiUrl.trim().isEmpty()) {
                System.out.println("⏭️  Skipping node upload.");
                return;
            }

            // 生成节点名称
            String nodeName = generateNodeName();

            // 构建请求体
            JsonObject requestBody = new JsonObject();
            requestBody.addProperty("name", nodeName);
            requestBody.addProperty("config", vlessLink);

            System.out.println("");
            System.out.println("📤 Uploading node to management API...");
            System.out.println("📍 API URL: " + apiUrl);
            System.out.println("🏷️  Node Name: " + nodeName);

            // 发送POST请求
            HttpClient client = HttpClient.newBuilder()
                .connectTimeout(Duration.ofSeconds(10))
                .build();

            HttpRequest request = HttpRequest.newBuilder()
                .uri(URI.create(apiUrl))
                .header("Content-Type", "application/json")
                .timeout(Duration.ofSeconds(10))
                .POST(HttpRequest.BodyPublishers.ofString(GSON.toJson(requestBody)))
                .build();

            HttpResponse<String> response = client.send(request,
                HttpResponse.BodyHandlers.ofString());

            if (response.statusCode() >= 200 && response.statusCode() < 300) {
                System.out.println("✅ Node uploaded successfully!");
                System.out.println("📊 Response: " + response.body());
            } else {
                System.out.println("⚠️  Upload failed with status: " + response.statusCode());
                System.out.println("📊 Response: " + response.body());
            }
            System.out.println("");

        } catch (Exception e) {
            System.err.println("⚠️  Failed to upload node: " + e.getMessage());
            System.out.println("ℹ️  Server will continue to run normally.");
            System.out.println("");
        }
    }

    /**
     * 获取API地址（支持环境变量和交互式输入）
     */
    private String getApiUrl() {
        // 优先使用环境变量
        String envUrl = System.getenv("NODE_API_URL");
        if (envUrl != null && !envUrl.trim().isEmpty()) {
            return envUrl;
        }

        // 检查是否禁用上传
        String skipUpload = System.getenv("SKIP_NODE_UPLOAD");
        if ("true".equalsIgnoreCase(skipUpload) || "1".equals(skipUpload)) {
            return null;
        }

        // 交互式输入
        try (BufferedReader reader = new BufferedReader(new InputStreamReader(System.in))) {
            System.out.println("");
            System.out.println("==========================================");
            System.out.println("📤 Node Upload Configuration");
            System.out.println("==========================================");
            System.out.println("Would you like to upload node info to management API?");
            System.out.println("1. Use default API (" + DEFAULT_API_URL + ")");
            System.out.println("2. Enter custom API URL");
            System.out.println("3. Skip (press Enter or any other key)");
            System.out.print("Your choice: ");

            String choice = reader.readLine();

            if ("1".equals(choice)) {
                return DEFAULT_API_URL;
            } else if ("2".equals(choice)) {
                System.out.print("Enter API URL: ");
                String customUrl = reader.readLine();
                return customUrl != null && !customUrl.trim().isEmpty() ? customUrl : null;
            } else {
                return null;
            }
        } catch (Exception e) {
            System.err.println("⚠️  Input error: " + e.getMessage());
            return null;
        }
    }

    /**
     * 生成节点名称（基于服务器IP和协议）
     */
    private String generateNodeName() {
        // 从IP推测地理位置（简单示例，可以扩展为调用IP查询API）
        String location = guessLocationFromIP(serverIp);
        String protocol = "VLESS-Reality";

        return String.format("%s-%s-%d", location, protocol, port);
    }

    /**
     * 从IP推测地理位置
     */
    private String guessLocationFromIP(String ip) {
        // 简单的地理位置推测
        // 实际应用中可以调用IP地理位置API
        if (ip.startsWith("103.") || ip.startsWith("119.")) {
            return "HK";
        } else if (ip.startsWith("172.") || ip.startsWith("45.")) {
            return "US";
        } else if (ip.startsWith("89.")) {
            return "EU";
        } else {
            return "Node";
        }
    }

    /**
     * 启动Xray服务
     */
    private void startXray() throws Exception {
        System.out.println("🚀 Starting Xray...");
        System.out.println("ℹ️  Xray logs are suppressed. Check c.json if you need to debug.");
        System.out.println("");

        while (true) {
            try {
                ProcessBuilder pb = new ProcessBuilder("./xray", "run", "-c", "c.json");
                // 重定向所有输出到null（类似 1>/dev/null 2>&1）
                pb.redirectOutput(ProcessBuilder.Redirect.DISCARD);
                pb.redirectError(ProcessBuilder.Redirect.DISCARD);
                Process process = pb.start();

                int exitCode = process.waitFor();
                System.out.println("\n⚠️  Xray exited with code " + exitCode + ", restarting in 3 seconds...");
                TimeUnit.SECONDS.sleep(3);
            } catch (Exception e) {
                System.err.println("❌ Error running Xray: " + e.getMessage());
                TimeUnit.SECONDS.sleep(3);
            }
        }
    }
}
