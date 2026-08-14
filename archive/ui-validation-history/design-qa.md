# Modern Ink Stage — Design QA

Date: 2026-08-11

Scope: `InkStageControl` 舞台基线，以及 2026-08-11 用户点名的功能栏、页面作用域、配对设备/二维码入口、侧栏拖动热区和五字体修正。设置/关于页面检查侧栏作用域、内容扩展和字体层级；不重新设计正式应用层。

Reference: `C:\Users\wxb27\.codex\generated_images\019fcc02-eb06-7143-89d7-a77f048210e5\exec-727efb1f-60a7-4605-a4a0-4e59401e37a8.png`

Runtime crop: `Validation/design-qa-connected-stage.png`

Shell visual sources: `Validation/reference-shell-stage-buttons.png`（1920×1128）与 `Validation/feedback-shell-sidebar-before.png`（1920×1080）。

Shell implementation evidence: `Validation/10-shell-main-dark.png`、`Validation/13-shell-device-list.png`、`Validation/14-shell-settings.png`、`Validation/15-shell-about.png`，均保存为 1280×720。捕获时 Windows UIA 原生窗口为 1920×1080，系统 DPI 144（150%），脚本归一到 1280×720 逻辑视口。

## Result

**Passed for current test-UI visual acceptance.** No P0/P1/P2 stage or named shell-correction defect remains in the captured states.

## Comparison

- The composition preserves the selected direction: one dominant dry-brush arch, separated banks, a single warm-colour boy, restrained blue water, and generous negative space.
- The fixed scene colours are present: boy `#E8863C`, bridge `#47937F`, water `#86BFD8`.
- The connected state has three independently moving water lines; the 5% and 100% RMS captures show visibly different amplitude without moving the mean waterline.
- The stage paper/ink resources switch independently for light and dark themes; the dark capture now matches the selected “ink at night” direction while retaining scene contrast.
- Disconnected and handshaking captures contain no water. The reconnecting capture shows water removed and the bridge/boy colour withdrawing through feathered masks.
- Scene assets remain registered and unclipped inside the `1000×400` logical coordinate system.
- No temporary ellipse, rectangle, emoji, ASCII, or code-drawn fallback is used for the bridge, banks, or boy.

## User feedback correction QA

Source: `Validation/feedback-before-geometry-correction.png`

Corrected evidence: `Validation/08-bridge-walk-midpoint.png`, `Validation/09-bridge-return-midpoint.png`, `Validation/06-light-theme-connected.png`, and `Validation/07-dark-theme-connected.png`.

- P1 fixed: the boy no longer travels horizontally through open space; the visible foot anchor follows the flattened Gaussian bridge surface in both directions.
- P1 fixed: the bridge gray and colour layers share a 70% vertical scale about the same foot baseline, reducing the excessive arch without moving the banks.
- P1 fixed: settled colour layers remove their masks, so the whole bridge and whole standing boy are coloured.
- The first corrected midpoint capture exposed an 8px visual foot gap. The sprite anchor was recalibrated and the final midpoint captures show contact with the bridge edge.

## 2026-08-11 shell correction QA

### Normalization and comparison evidence

- Full-view comparison: `Validation/18-shell-sidebar-before-after.png` places the 1920×1080 user feedback capture, normalized to 1280×720, beside the new 1280×720 main screen. The audio button changes from roughly 86 logical pixels to the full 182.67–183px rail content width while preserving the 8px rail padding.
- Focused button comparison: `Validation/17-shell-button-reference-comparison.png` places the older 1920×1128 reference, normalized to 1280px width, above the current 1280×720 implementation. The compared region contains both circular anchors, their colors, icon silhouettes, border radii and top-corner positions.
- Page-scope evidence: `Validation/14-shell-settings.png` and `Validation/15-shell-about.png` show the content starting at the page margin without the 200px function rail; the center content column occupies the released space.
- Interaction evidence: `Validation/12-shell-qr.png` keeps the QR hover popover and real QR bitmap; `Validation/13-shell-device-list.png` keeps the device anchor at the top-left vertex while the device popover opens directly below it.

### Findings and iteration history

- P1 fixed — audio button width: the old rendered button was 86px inside a 200px rail. `HorizontalAlignment=Stretch` now renders it at 182.67–183px after 8px left/right padding and the right border.
- P1 fixed — rail page scope: the old rail stayed visible on every page. It is now bound to `AppPage.Main`; Settings and About collapse the Auto rail column and expand the page host.
- P1 fixed — stage-button style: two 54px neutral `Laptop`/`Qrcode` controls were replaced by 48px circles. The device control uses `BridgeGreen #47937F` with `Cellphone`; the QR control uses `InkOrange #E8863C` with `ViewGridOutline`.
- P2 found and fixed during the first post-change capture — opening the 280px device popover changed the device anchor X from 0 to 116 inside its stack. Explicit left alignment now keeps X at 0; the corrected evidence is `Validation/13-shell-device-list.png`.
- P1 fixed — circular icon geometry: both Material icons are 22×22 and their button content areas stretch across each 48×48 circle. Real-layout assertions confirm both centers coincide with their anchors, including the 150% DPI rounding tolerance.
- P1 fixed — sidebar resize target: the former 6px target was inset from the 200px rail boundary. The target is now a 16px overlay centered on the boundary and remains centered after snapping to 56px compact mode; the updated native drag capture succeeds from X=200.
- P1 fixed — design typography: packaged resources now implement Brand/Poetic/Annotation/Heading/Ui roles. Runtime screenshots show 24px brand, 20/16px serif headings, 15px poetic copy, 12px annotation and 14px functional UI without clipping. The unfinalized big-Kai candidate remains a documented P3 asset gap, with LXGW WenKai Lite used for the current brand.
- Post-fix automation: 114/114 tests pass; Debug build reports 0 warnings and 0 errors; the final 10–16 capture pass exits successfully.
- Follow-up typography audit fixed 11 semantic-role omissions that still inherited UI sans: main subtitle, QR revision, four settings descriptions, About version/copyright/three placeholders, P2P empty state and the shell fallback empty state. Annotation and poetic integration tests now cover the actual rendered nodes.

### Required fidelity surfaces

- Fonts and typography: the five design roles are now explicit and packaged; representative runtime nodes and resource names/sizes are covered by automated tests. No wrapping, truncation or glyph fallback appears in 10–16.
- Spacing and layout rhythm: audio button fills the rail content width; settings/about remove the rail cleanly; both stage anchors remain 48×48 with radius 24 and stable corner positions.
- Colors and tokens: the controls use the existing `BridgeGreen` and `InkOrange` theme resources rather than duplicated literals in product XAML.
- Image and icon fidelity: stage assets remain source images; controls use the installed Material icon library, with no handcrafted SVG, glyph placeholder or CSS/code drawing.
- Copy and content: navigation, device, QR, settings and about text remain unchanged; only layout and visual affordances changed.

### Remaining polish

- P3: the installed Material icons have slightly tighter internal glyph proportions than the older reference image, but the phone/four-grid silhouettes, semantic colors, circle size and interaction roles match the selected direction.

## Non-blocking differences from the concept

- P3: the boy is intentionally smaller relative to the bridge than in the concept image; this keeps the bridge as the dominant visual and preserves existing asset registration.
- P3: the generated banks use lighter line density and the water is more restrained than the painterly concept.
- The current artifacts remain an isolated test UI. Passing this QA does not mean the formal Windows application has been integrated or visually accepted.

final result: passed
