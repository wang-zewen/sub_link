package com.proxy.vmess;

import com.google.gson.Gson;
import com.google.gson.GsonBuilder;
import com.google.gson.JsonObject;
import com.google.gson.JsonArray;

import java.io.*;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.time.Duration;
import java.util.*;
import java.util.concurrent.TimeUnit;
import java.util.zip.ZipEntry;
import java.util.zip.ZipInputStream;

/**
 * VMess 代理服务器
 * 自动下载和配置 Xray，启动 VMess 服务
 */
public class VMessServer {
    private static final String XRAY_VERSION = "1.8.24";
    private static final Gson GSON = new GsonBuilder().setPrettyPrinting().create();

    private final int port;
    private final String uuid;
    private String serverIp;

    public VMessServer() {
        this.port = Integer.parseInt(System.getenv().getOrDefault("PORT",
                                     System.getenv().getOrDefault("SERVER_PORT", "20041")));
        this.uuid = System.getenv().getOrDefault("VMESS_UUID", generateUUID());
    }

    public static void main(String[] args) {
        System.out.println("🚀 VMess Server (Java)");

        try {
            VMessServer server = new VMessServer();
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

        // 生成配置
        generateConfig();

        // 生成VMess链接
        String vmessLink = generateVMessLink();
        Files.writeString(Paths.get("link.txt"), vmessLink);

        // 显示信息
        printServerInfo(vmessLink);

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
     * 生成Xray配置文件
     */
    private void generateConfig() throws IOException {
        JsonObject config = new JsonObject();

        // Log配置
        JsonObject log = new JsonObject();
        log.addProperty("loglevel", "none");
        config.add("log", log);

        // Inbound配置
        JsonObject inbound = new JsonObject();
        inbound.addProperty("port", port);
        inbound.addProperty("protocol", "vmess");

        // VMess客户端配置
        JsonObject client = new JsonObject();
        client.addProperty("id", uuid);
        client.addProperty("alterId", 0);

        JsonArray clientsArray = new JsonArray();
        clientsArray.add(client);

        JsonObject settings = new JsonObject();
        settings.add("clients", clientsArray);
        inbound.add("settings", settings);

        // Stream配置
        JsonObject streamSettings = new JsonObject();
        streamSettings.addProperty("network", "tcp");

        JsonObject tcpSettings = new JsonObject();
        tcpSettings.addProperty("acceptProxyProtocol", false);

        JsonObject header = new JsonObject();
        header.addProperty("type", "http");

        JsonObject response = new JsonObject();
        response.addProperty("version", "1.1");
        response.addProperty("status", "200");
        response.addProperty("reason", "OK");

        JsonArray contentTypeArray = new JsonArray();
        contentTypeArray.add("text/html; charset=utf-8");

        JsonArray transferEncodingArray = new JsonArray();
        transferEncodingArray.add("chunked");

        JsonArray connectionArray = new JsonArray();
        connectionArray.add("keep-alive");

        JsonObject headers = new JsonObject();
        headers.add("Content-Type", contentTypeArray);
        headers.add("Transfer-Encoding", transferEncodingArray);
        headers.add("Connection", connectionArray);
        headers.addProperty("Pragma", "no-cache");
        response.add("headers", headers);

        header.add("response", response);
        tcpSettings.add("header", header);
        streamSettings.add("tcpSettings", tcpSettings);
        inbound.add("streamSettings", streamSettings);

        inbound.addProperty("tag", "vmess");

        JsonArray inboundsArray = new JsonArray();
        inboundsArray.add(inbound);
        config.add("inbounds", inboundsArray);

        // Outbound配置
        JsonObject outbound = new JsonObject();
        outbound.addProperty("protocol", "freedom");

        JsonArray outboundsArray = new JsonArray();
        outboundsArray.add(outbound);
        config.add("outbounds", outboundsArray);

        // 写入配置文件
        Files.writeString(Paths.get("c.json"), GSON.toJson(config));
    }

    /**
     * 生成VMess订阅链接
     */
    private String generateVMessLink() {
        JsonObject vmessConfig = new JsonObject();
        vmessConfig.addProperty("v", "2");
        vmessConfig.addProperty("ps", "VMess-Server");
        vmessConfig.addProperty("add", serverIp);
        vmessConfig.addProperty("port", String.valueOf(port));
        vmessConfig.addProperty("id", uuid);
        vmessConfig.addProperty("aid", "0");
        vmessConfig.addProperty("net", "tcp");
        vmessConfig.addProperty("type", "http");
        vmessConfig.addProperty("tls", "");

        String json = GSON.toJson(vmessConfig);
        String base64 = Base64.getEncoder().encodeToString(json.getBytes(StandardCharsets.UTF_8));

        return "vmess://" + base64;
    }

    /**
     * 打印服务器信息
     */
    private void printServerInfo(String vmessLink) {
        System.out.println();
        System.out.println("==========================================");
        System.out.println("🎉 VMess Server Ready!");
        System.out.println("==========================================");
        System.out.println("📍 Server: " + serverIp + ":" + port);
        System.out.println("🔑 UUID: " + uuid);
        System.out.println();
        System.out.println("🔗 VMess Link:");
        System.out.println(vmessLink);
        System.out.println();
        System.out.println("💾 Link saved to: link.txt");
        System.out.println("==========================================");
        System.out.println();
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
