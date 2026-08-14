# Windows 现代水墨舞台原型验收记录

初始日期：2026-08-07

最新复核：2026-08-11

范围：`01`–`09` 验证 `InkStageControl`、本地演示状态机和舞台资产；`10`–`16` 验证独立测试 UI 的外壳、深浅主题、设备/QR 浮层、设置、关于和紧凑左栏。该项目仍不绑定正式应用层。

## 构建与自动化测试

在 `D:\LAN-Audio-Bridge-worktrees\modern-ink-uitest` 执行：

```powershell
dotnet test test-ui\UITest.Tests\UITest.Tests.csproj -c Debug --no-restore
dotnet build test-ui\UITest\UITest.csproj -c Debug
dotnet build test-ui\UITest\UITest.csproj -c Release
```

2026-08-11 最新结果：114 项测试全部通过；Debug 构建 0 warning、0 error；UI Automation 完成 10–16 全套原生窗口捕获，最终退出码为 0。2026-08-07 的舞台基线为 23 项测试，且当时 Debug/Release 均为 0 warning、0 error。

测试覆盖动画关键时间点、不可中断的顺序队列、相邻重复目标去重、正反向人物状态、独立羽化上色源、三层水波、RMS 边界值及非有限值。

## 状态截图

| 文件 | 验证内容 | 结果 |
|---|---|---|
| `01-disconnected.png` | 左岸灰态待机、灰桥、无水 | 通过 |
| `02-handshaking.png` | 握手黄态、舞台仍为灰态且无水 | 通过 |
| `03-connected-rms-low.png` | 青绿桥、暖橘男孩、5% RMS 平缓三层水波 | 通过 |
| `04-connected-rms-high.png` | 100% RMS 明显提高波幅，平均水位不变 | 通过 |
| `05-reconnecting.png` | 立即断开 RMS、退水、桥与男孩独立羽化褪色 | 通过 |
| `06-light-theme-connected.png` | 浅色主题连接稳定帧，无裁切或错位 | 通过 |
| `07-dark-theme-connected.png` | 深色“墨·夜堤”连接稳定帧，岸线、桥、男孩和水均清晰 | 通过 |
| `08-bridge-walk-midpoint.png` | 正向中段脚底贴合压低后的桥面外沿 | 通过 |
| `09-bridge-return-midpoint.png` | 镜像回程复用同一桥面轨迹 | 通过 |
| `10-shell-main-dark.png` | 深色主界面、连接稳定态、完整外壳 | 通过 |
| `11-shell-main-light.png` | 浅色主界面和主题切换 | 通过 |
| `12-shell-qr.png` | 右上 QR 悬浮层、真实二维码与刷新版本 | 通过 |
| `13-shell-device-list.png` | 左上 P2P 配对设备层和唯一设备记录 | 通过 |
| `14-shell-settings.png` | 设置页首屏及固定板块顺序 | 通过 |
| `15-shell-about.png` | 关于页、许可信息、内容位和页底钓鱼场景 | 通过 |
| `16-shell-sidebar-compact.png` | 左栏拖拽吸附到 56px 纯图标态 | 通过 |
| `17-shell-button-reference-comparison.png` | 旧参考图与当前 48px 青绿手机/暖橘四宫格圆钮的同屏比较 | 通过 |
| `18-shell-sidebar-before-after.png` | 音频按钮从内容宽度收缩态到铺满功能栏的前后比较 | 通过 |
| `reference-shell-stage-buttons.png` | 用户选定的舞台圆钮视觉来源 | 参考基准 |
| `feedback-shell-sidebar-before.png` | 用户指出音频按钮宽度与页面作用域问题时的界面 | 反馈基准 |
| `feedback-before-geometry-correction.png` | 用户反馈前状态：高桥、直线行走和局部上色 | 对照基准 |

`design-qa-connected-stage.png` 是从最终连接截图中截取的舞台逻辑画布，用于和选定视觉稿并排检查。详细结论见 `../design-qa.md`。

截图由 `capture-stage-states.ps1` 通过 Windows UI Automation 驱动本地状态按钮并用 `PrintWindow` 保存。脚本为不可中断队列预留完整结算时间，避免把排队中的过渡帧误标为稳定帧。

## 用户反馈修正（2026-08-07）

- 桥灰/彩图层围绕共同桥脚基线 `Y=296` 同步执行 `ScaleY=0.70`，桥峰约降低 30%，两层仍完全重合。
- 男孩脚底使用端点归零的高斯钟形路径：左右端 `Y=296`、中央 `Y=142`；正向和镜像回程共用该路径，不再叠加直线 Y 或额外弹跳。
- 第一轮中点截图发现按 alpha 边界设置的脚底偏移仍有约 8px 视觉悬空；以运行画面重新标定为 `87px` 后，`08` 与 `09` 截图均显示脚底接触桥面外沿。
- 羽化只在上色/褪色过程中启用；`ColorReveal >= 0.999` 时移除彩色层遮罩。最终浅色、深色连接截图中桥全部青绿、男孩全部暖橘，没有残留局部灰色。

## DPI 与对齐

- 本机实际系统 DPI 为 144（150%）。七张完整窗口截图均在该缩放下生成，固定窗口、舞台边缘、岸、桥、人物和水没有裁切或相对漂移。
- 舞台内部使用固定 `1000×400` 逻辑坐标，全部场景资产保持相同注册尺寸，并由 `Viewbox Stretch="Uniform"` 等比缩放。因此 100%、150%、200% 的坐标换算不会改变场景元素间的相对位置。
- 100% 和 200% 未通过修改用户系统缩放进行实体显示器复测；这里只完成逻辑缩放结构检查。外围控件在这些 DPI 下的点击区域属于真实应用 UI 的后续整体验收范围，不在本轮舞台改动内。

## 与应用层隔离

舞台原型最初对 C#、AXAML 和项目文件扫描以下外部能力关键词：

```text
Socket TcpClient UdpClient Bluetooth USB mDNS NAudio Wasapi AudioClient
```

结果为 0 条匹配。原型只使用本地演示状态和 RMS；不选择链路、不做自动降级，也不启动网络、蓝牙、USB、mDNS 或音频引擎。测试外壳现使用 QRCoder 在本地内存中生成二维码图片，但不发送网络请求。运行时稳定性脚本同时记录该进程的 TCP 连接与 UDP 端点。

## 30 分钟稳定性测试

执行：

```powershell
& test-ui\UITest\Validation\run-stage-soak.ps1 -DurationMinutes 30
```

脚本每 4 秒按固定序列提交状态请求并启用自动 RMS，在 0、15、30 分钟记录工作集与进程网络端点；结束时关闭窗口并确认进程退出。

| 时间 | 工作集 | TCP 连接 | UDP 端点 |
|---:|---:|---:|---:|
| 0 分钟 | 201.23 MB | 0 | 0 |
| 15 分钟 | 241.96 MB | 0 | 0 |
| 30 分钟 | 242.40 MB | 0 | 0 |

结果：`SOAK_OK`。共提交 449 次状态请求；15–30 分钟工作集仅增加 0.44 MB，预热后没有持续增长趋势。`CloseMainWindow` 后 10 秒内正常退出，UITest 进程和控制脚本进程均无残留。机器可读结果见 `soak-result.csv` 与 `soak-summary.txt`。

## 已知非阻塞差异

- 男孩相对桥的比例比选定概念图小，当前保持资产注册稳定，列为 P3 视觉取舍。
- 岸的线条密度和水波强度比概念图克制；状态辨识和三色焦点不受影响。
- 设备/QR 已回归用户选定的 48px 青绿小手机与暖橘四宫格方向。现有 Material 图标的内部字形比例比旧图略紧凑，列为 P3；颜色、圆形轮廓、位置、弹层和刷新职责一致。

## 壳层反馈修正（2026-08-11）

- 展开态音频按钮从约 86px 改为铺满功能栏可用宽度，在 150% DPI 下实测为 182.67–183px；紧凑态仍保留居中音乐图标。
- 功能栏只绑定 `AppPage.Main`。设置与关于页隐藏后，Auto 列宽归零，页面内容占用腾出的宽度。
- 左上设备圆钮改为 48×48、`BridgeGreen #47937F`、`Cellphone`；右上 QR 圆钮改为 48×48、`InkOrange #E8863C`、`ViewGridOutline`。
- 首轮重拍发现设备弹层展开会把圆钮从 X=0 推到 X=116；补充真实布局测试后固定左对齐，`13-shell-device-list.png` 已显示按钮保持在弹层左上顶点。
- 设备与二维码图标由 20×20 增至 22×22；按钮内容区改为双向 Stretch，图标在 48×48 圆钮内按真实布局中心对齐。150% DPI 下允许不可避免的 0.5 物理像素舍入，自动检查已覆盖两侧中心。
- 侧栏拖动热区从内缩的 6px 改为 16px 独立覆盖层，中心严格压住展开态 200px 与紧凑态 56px 的真实分界线；捕获脚本也改为从 X=200 边界抓取，`16-shell-sidebar-compact.png` 重新验证吸附成功。
- 五字体角色已落地：品牌/诗文使用霞鹜文楷 Lite，注释使用 FandolFang 仿宋，页标题与板块标题使用 Noto Serif SC（思源宋体同源），功能文字使用 Noto Sans SC（思源黑体同源）；字号为 24/15/12/20/16/14。设计书候选大楷仍未定稿，顶栏品牌暂用霞鹜文楷作为已打包回退。
- 第二轮逐节点审计修正了 11 处语义遗漏：主界面副说明、QR 版本、设置页四条次级说明、关于页版本/版权/三个空内容位、设备空状态和壳层备用空状态。新增测试不再只抽查代表节点，而是验证这些次级说明与空状态的真实渲染字体。
