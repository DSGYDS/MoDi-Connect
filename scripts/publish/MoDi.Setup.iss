; MoDi Setup — 社区版安装脚本（Inno Setup 6）
; 编译: ISCC.exe scripts\publish\MoDi.Setup.iss /DInputDir=artifacts\community-release /DOutputDir=artifacts\setup
;
; Gitee 更新版差异（后续实现 GiteeUpdateService 时再启用）:
;   /DGiteeEdition=1  捆绑 tools\git + update.json；凭据绝不写入本脚本。

#ifndef GiteeEdition
  #define GiteeEdition "0"
#endif
#if GiteeEdition == "1"
  #define AppFullName "墨堤互联（官方更新版）"
  #define AppIdStr "{{8F3D7A2E-1B45-4C6E-9A01-5E8F2D4C7B01}"
#else
  #define AppFullName "墨堤互联"
  #define AppIdStr "{{8F3D7A2E-1B45-4C6E-9A01-5E8F2D4C7B02}"
#endif

[Setup]
AppId={#AppIdStr}
AppName={#AppFullName}
AppVersion=1.0.0
AppPublisher=Silvite
AppPublisherURL=https://modiconnect.cn
AppSupportURL=https://modiconnect.cn
DefaultDirName={autopf}\MoDi Connect
DefaultGroupName={#AppFullName}
OutputDir={#OutputDir}
OutputBaseFilename=MoDi.Setup.community.1.0.0
Compression=lzma2/max
SolidCompression=yes
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin
; 中文界面（语言文件随 ISCC 安装目录分发）
LicenseFile={#InputDir}\LICENSE.txt
SetupIconFile={#AppIcon}
UninstallDisplayIcon={app}\MoDi.Desktop.exe
WizardStyle=modern
; 版本升级：AppId 固定，AppVersion 每次递增

; 收费版（Gitee 更新版）构建时启用中文安装界面：
; 语言文件已就位于 Inno 安装目录 Languages\ChineseSimplified.isl（kira-96 版，ISCC 编译验证通过）。
; 启用方式：取消下面三行注释（收费版要求；社区版保持英文）。
; [Languages]
; Name: "chinesesimplified"; MessagesFile: "compiler:Languages\ChineseSimplified.isl"

[Files]
; 应用发布目录（self-contained .NET，无需用户预装运行时）
Source: "{#InputDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "release-manifest.json,update.json,Install-VbCable.ps1"

; 协议二进制许可文本（随包分发要求）
Source: "{#InputDir}\Licenses\MoDi.Protocol\*"; DestDir: "{app}\Licenses\MoDi.Protocol"; Flags: ignoreversion recursesubdirs createallsubdirs

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式"; GroupDescription: "附加任务:"

[Icons]
Name: "{group}\{#AppFullName}"; Filename: "{app}\MoDi.Desktop.exe"
Name: "{group}\卸载 {#AppFullName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#AppFullName}"; Filename: "{app}\MoDi.Desktop.exe"; Tasks: desktopicon

[Run]
; VB-CABLE 引导：安装完成后由用户选择是否运行（告知+官方渠道静默安装）
Filename: "{app}\Install-VbCable.ps1"; \
  Description: "安装 VB-Audio Virtual CABLE（墨堤虚拟麦克风路线需要；从官方渠道下载并静默安装）"; \
  Flags: postinstall shellexec runascurrentuser unchecked; \
  Parameters: "-ExecutionPolicy Bypass -File ""{app}\Install-VbCable.ps1"""

[UninstallDelete]
Type: filesandordirs; Name: "{app}\tools"

[Code]
// 预留：Gitee 更新版安装完成后执行私有工具链校验。
// 社区版不执行任何更新相关操作。
