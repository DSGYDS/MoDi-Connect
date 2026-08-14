using System.ComponentModel;
using System.Windows;
using System.Windows.Media;

namespace PocWifiDirectUi;

/// <summary>收到的数据包，绑定到 ListBox</summary>
public class PacketItem : INotifyPropertyChanged
{
    public string TimeSource { get; }
    public string LengthText { get; }
    public string HexText { get; }
    public string TextContent { get; }
    public Visibility HasText { get; }
    public Brush BorderBrush { get; }
    public Brush BgBrush { get; }

    public PacketItem(DateTime time, string source, byte[] data)
    {
        TimeSource = $"[{time:HH:mm:ss.fff}] 来自 {source}";
        LengthText = $"{data.Length} 字节";
        HexText = BitConverter.ToString(data);

        // 检测是否为可读文本：UTF-8 解码后，可打印字符占比高
        var text = System.Text.Encoding.UTF8.GetString(data);
        if (data.Length > 0)
        {
            var printable = text.Count(c => !char.IsControl(c) && !char.IsSurrogate(c));
            TextContent = text;
            HasText = text.Length > 0 && (double)printable / text.Length > 0.3
                ? Visibility.Visible
                : Visibility.Collapsed;
        }
        else
        {
            TextContent = "";
            HasText = Visibility.Collapsed;
        }

        // 颜色：短包亮色，长包深色
        if (data.Length <= 8)
        {
            BorderBrush = new SolidColorBrush(Color.FromRgb(0x99, 0xCC, 0x66));
            BgBrush = new SolidColorBrush(Color.FromRgb(0xF0, 0xFF, 0xF0));
        }
        else
        {
            BorderBrush = new SolidColorBrush(Color.FromRgb(0x66, 0x99, 0xCC));
            BgBrush = new SolidColorBrush(Color.FromRgb(0xF0, 0xF5, 0xFF));
        }
    }

    public event PropertyChangedEventHandler? PropertyChanged;
    protected void OnPropertyChanged(string name) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));
}
