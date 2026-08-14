using Windows.Devices.WiFiDirect;
using Windows.Security.Credentials;
using System.Collections.ObjectModel;
using System.Net.NetworkInformation;
using System.Net.Sockets;
using System.Windows;
using System.Windows.Media;

namespace PocWifiDirectUi;

public partial class MainWindow : Window
{
    private WiFiDirectAdvertisementPublisher? _pub;
    private UdpClient? _udp;
    private CancellationTokenSource? _cts;
    private readonly ObservableCollection<PacketItem> _packets = new();

    public MainWindow()
    {
        InitializeComponent();
        PacketList.ItemsSource = _packets;
        Closing += Window_Closing;
    }

    private async void OnStartClick(object sender, RoutedEventArgs e)
    {
        BtnStart.IsEnabled = false;
        BtnStop.IsEnabled = true;
        _packets.Clear();
        TxtFooter.Text = "正在启动…";

        try
        {
            // ── 创建 Publisher ──
            _pub = new WiFiDirectAdvertisementPublisher();
            _pub.StatusChanged += OnPubStatusChanged;

            var legacy = _pub.Advertisement.LegacySettings;
            legacy.IsEnabled = true;
            legacy.Ssid = "LABridge-PoC";
            legacy.Passphrase = new PasswordCredential { Password = "PoCPass12" };

            _pub.Advertisement.IsAutonomousGroupOwnerEnabled = true;
            _pub.Advertisement.ListenStateDiscoverability =
                WiFiDirectAdvertisementListenStateDiscoverability.Intensive;

            SetInfo("SSID", "LABridge-PoC");
            SetInfo("密码", "PoCPass12");
            SetStatus("正在启动 WiFi Direct…", Colors.Orange);
            StatusDot.Fill = new SolidColorBrush(Colors.Orange);

            _pub.Start();
            await Task.Delay(1000);
            SetPubStatus($"Started (Error=Success)");

            // ── 等 IP ──
            string? p2pIp = null;
            for (int i = 0; i < 10; i++)
            {
                p2pIp = GetP2pAdapterIp();
                if (p2pIp != null) break;
                await Task.Delay(1000);
                SetFooter($"等待 P2P 适配器 IP… ({i + 1}/10)");
            }

            if (p2pIp == null)
            {
                SetStatus("❌ P2P 适配器 IP 未就绪", Colors.Red);
                StatusDot.Fill = new SolidColorBrush(Colors.Red);
                return;
            }

            SetInfo("IP", p2pIp);
            SetStatus($"✅ 已就绪 — {p2pIp}", Colors.Green);
            StatusDot.Fill = new SolidColorBrush(Colors.Green);
            SetFooter($"监听 UDP 12345，发数据到 {p2pIp}:12345");

            // ── 开始监听 UDP ──
            _cts = new CancellationTokenSource();
            _udp = new UdpClient(12345);
            _ = ListenLoop(_udp, _cts.Token);
        }
        catch (Exception ex)
        {
            SetStatus($"❌ 启动失败: {ex.Message}", Colors.Red);
            StatusDot.Fill = new SolidColorBrush(Colors.Red);
            StopAll();
        }
    }

    private async Task ListenLoop(UdpClient udp, CancellationToken ct)
    {
        try
        {
            while (!ct.IsCancellationRequested)
            {
                var result = await udp.ReceiveAsync(ct);
                var item = new PacketItem(DateTime.Now,
                    result.RemoteEndPoint.ToString(),
                    result.Buffer);

                // UI 线程更新
                await Dispatcher.InvokeAsync(() =>
                {
                    _packets.Add(item);
                    if (_packets.Count > 500) _packets.RemoveAt(0);
                    SetFooter($"已收到 {_packets.Count} 个数据包，最新来自 {result.RemoteEndPoint}");

                    // 自动滚动到底部
                    PacketList?.ScrollIntoView(item);
                });

                // 回包确认
                try
                {
                    var reply = System.Text.Encoding.UTF8.GetBytes(
                        $"ACK #{_packets.Count} ({result.Buffer.Length} bytes)");
                    await udp.SendAsync(reply, reply.Length, result.RemoteEndPoint);
                }
                catch { /* 回包失败不影响接收 */ }
            }
        }
        catch (OperationCanceledException) { }
        catch (ObjectDisposedException) { }
        catch (Exception ex)
        {
            await Dispatcher.InvokeAsync(() =>
                SetFooter($"监听异常: {ex.Message}"));
        }
    }

    private void OnStopClick(object sender, RoutedEventArgs e)
    {
        StopAll();
        SetStatus("已停止", Colors.Gray);
        StatusDot.Fill = new SolidColorBrush(Colors.Gray);
        SetFooter("已停止");
    }

    private void OnClearClick(object sender, RoutedEventArgs e)
    {
        _packets.Clear();
    }

    private void StopAll()
    {
        _cts?.Cancel();
        _cts?.Dispose();
        _cts = null;

        _udp?.Close();
        _udp?.Dispose();
        _udp = null;

        _pub?.Stop();
        _pub = null;

        BtnStart.IsEnabled = true;
        BtnStop.IsEnabled = false;
    }

    private void OnPubStatusChanged(WiFiDirectAdvertisementPublisher sender,
        WiFiDirectAdvertisementPublisherStatusChangedEventArgs args)
    {
        Dispatcher.InvokeAsync(() =>
            SetPubStatus($"{args.Status} (Error={args.Error})"));
    }

    // ── UI 辅助 ──

    private void SetStatus(string text, Color color)
    {
        StatusText.Text = text;
        StatusText.Foreground = new SolidColorBrush(color);
    }

    private void SetFooter(string text)
    {
        TxtFooter.Text = text;
    }

    private void SetInfo(string label, string value)
    {
        switch (label)
        {
            case "SSID": TxtSsid.Text = value; break;
            case "密码": TxtPassword.Text = value; break;
            case "IP": TxtIp.Text = value; break;
        }
    }

    private void SetPubStatus(string text)
    {
        TxtPublisherStatus.Text = text;
    }

    // ── 辅助方法 ──

    private static string? GetP2pAdapterIp()
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

    private void Window_Closing(object? sender, System.ComponentModel.CancelEventArgs e)
    {
        StopAll();
    }
}
