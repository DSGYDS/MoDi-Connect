using Windows.Devices.WiFiDirect;
using Windows.Security.Credentials;
using System.Net.NetworkInformation;
using System.Net.Sockets;

Console.WriteLine("═══════════════════════════════════════════");
Console.WriteLine("  LAN Audio Bridge — WiFi Direct PoC");
Console.WriteLine("═══════════════════════════════════════════");
Console.WriteLine();

// ── 1. 列出当前网络适配器 ──
Console.WriteLine("[诊断] 当前网络适配器列表：");
foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
{
    var desc = ni.Description;
    if (desc.Contains("Wi-Fi", StringComparison.OrdinalIgnoreCase)
        || desc.Contains("P2P", StringComparison.OrdinalIgnoreCase)
        || desc.Contains("Direct", StringComparison.OrdinalIgnoreCase)
        || desc.Contains("Virtual", StringComparison.OrdinalIgnoreCase)
        || desc.Contains("Loopback", StringComparison.OrdinalIgnoreCase))
    {
        var ips = string.Join(", ",
            ni.GetIPProperties().UnicastAddresses
                .Where(u => u.Address.AddressFamily == AddressFamily.InterNetwork)
                .Select(u => u.Address.ToString()));
        Console.WriteLine($"  [{ni.OperationalStatus}] {ni.Name}: {desc}");
        Console.WriteLine($"       IP: {ips}");
    }
}
Console.WriteLine();

// ── 2. 创建 Publisher ──
var pub = new WiFiDirectAdvertisementPublisher();

pub.StatusChanged += (s, e) =>
{
    Console.WriteLine($"[事件] Status={e.Status}  Error={e.Error}");
};

var legacy = pub.Advertisement.LegacySettings;
legacy.IsEnabled = true;
legacy.Ssid = "LABridge-PoC";
legacy.Passphrase = new PasswordCredential { Password = "PoCPass12" };

// 关键设置：自动成为 Group Owner + 高强度发现
pub.Advertisement.IsAutonomousGroupOwnerEnabled = true;
pub.Advertisement.ListenStateDiscoverability = Windows.Devices.WiFiDirect.WiFiDirectAdvertisementListenStateDiscoverability.Intensive;

// ── 3. 启动 ──
Console.WriteLine("[*] 启动 WiFiDirectAdvertisementPublisher (Legacy GO)...");
pub.Start();
await Task.Delay(1000);

Console.WriteLine();
Console.WriteLine("══════════ WiFi Direct 网络信息 ══════════");
Console.WriteLine($"  SSID : LABridge-PoC");
Console.WriteLine($"  密码 : PoCPass12");
Console.WriteLine($"  端口 : 12345 (UDP)");
Console.WriteLine("═══════════════════════════════════════════");
Console.WriteLine();
Console.WriteLine("[*] 请在手机上打开 WiFi → 连接 LABridge-PoC");
Console.WriteLine("[*] 输入手机连上后的密码：PoCPass12");
Console.WriteLine();

try
{
    // 等 IP 就绪（最多 10 秒）
    string? p2pIp = null;
    for (int i = 0; i < 5; i++)
    {
        p2pIp = GetP2pAdapterIp();
        if (p2pIp != null) break;
        await Task.Delay(2000);
    }

    if (p2pIp == null)
    {
        Console.WriteLine("❌ P2P 适配器 IP 未就绪，退出");
        return;
    }

    Console.WriteLine("✅✅✅  P2P 适配器 IP 已就绪！ " + p2pIp);
    Console.WriteLine();
    Console.WriteLine("══════════ UDP 监听 ══════════");
    Console.WriteLine($"  端口 : 12345");
    Console.WriteLine($"  你手机连上后，发 UDP 到 {p2pIp}:12345");
    Console.WriteLine("══════════════════════════════");
    Console.WriteLine();

    using var udp = new UdpClient(12345);
    Console.WriteLine("[*] 持续监听中...（按 Ctrl+C 退出）");
    Console.WriteLine();

    while (true)
    {
        var result = await udp.ReceiveAsync();
        var content = result.Buffer;
        var text = System.Text.Encoding.UTF8.GetString(content);

        Console.WriteLine($"📩 [{DateTime.Now:HH:mm:ss.fff}] 来自 {result.RemoteEndPoint}");
        Console.WriteLine($"   长度 : {content.Length} 字节");
        Console.WriteLine($"   HEX  : {BitConverter.ToString(content)}");
        Console.WriteLine($"   文本 : {text}");
        Console.WriteLine();

        // 回包
        var reply = System.Text.Encoding.UTF8.GetBytes($"收到 {content.Length} 字节");
        await udp.SendAsync(reply, reply.Length, result.RemoteEndPoint);
    }
}
finally
{
    pub.Stop();
}

// ── 辅助方法 ──
static string? GetP2pAdapterIp()
{
    foreach (var ni in NetworkInterface.GetAllNetworkInterfaces())
    {
        if (!ni.Description.Contains("Wi-Fi Direct", StringComparison.OrdinalIgnoreCase)
            && !ni.Description.Contains("P2P", StringComparison.OrdinalIgnoreCase)
            && !ni.Description.Contains("Microsoft Wi-Fi Direct", StringComparison.OrdinalIgnoreCase))
            continue;

        if (ni.OperationalStatus != OperationalStatus.Up) continue;

        foreach (var ip in ni.GetIPProperties().UnicastAddresses)
        {
            if (ip.Address.AddressFamily == AddressFamily.InterNetwork)
                return ip.Address.ToString();
        }
    }
    return null;
}
