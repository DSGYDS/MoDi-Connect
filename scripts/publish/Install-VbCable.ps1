#Requires -Version 7.0
<#
.SYNOPSIS
    VB-CABLE 检测与引导安装（官方渠道，静默安装前必须获得用户明确同意）。

.DESCRIPTION
    1. 检测系统是否已安装 VB-CABLE（注册表 + CABLE 设备类存在性）。
    2. 未安装时：显示说明 → 询问用户 → 从官方 URL 下载官方安装包 → 静默执行。
    3. 不打包、不复制、不修改 VB-CABLE 二进制；只调用官方渠道。
    4. 任何一步失败都只报告，不自动重试、不绕过用户同意。

.NOTES
    仅供安装器/发行流程调用；应用内不应执行安装动作。
#>
[CmdletBinding()]
param(
    [string]$DownloadUrl = 'https://download.vb-audio.com/Download_CABLE/VBCABLE_Driver_Pack45.zip',
    [string]$WorkDir = (Join-Path $env:TEMP 'modi-vbcable-setup'),
    [switch]$SkipDownloadIfCached
)

$ErrorActionPreference = 'Stop'

function Test-VbCableInstalled {
    # 官方驱动路径检查：C:\Windows\System32\drivers\vbabbler.sys 系列 + MMDevices 设备
    $driver = Join-Path $env:WINDIR 'System32\drivers\vbabbler.sys'
    if (Test-Path -LiteralPath $driver) { return $true }
    try {
        $devs = Get-PnpDevice -Class 'AudioEndpoint' -ErrorAction SilentlyContinue |
            Where-Object { $_.FriendlyName -match 'CABLE' }
        return ($null -ne $devs -and $devs.Count -gt 0)
    }
    catch { return $false }
}

function Write-ModiNotice {
    Write-Host ''
    Write-Host '================================================' -ForegroundColor Cyan
    Write-Host ' 墨堤（MoDi）需要 VB-Audio Virtual CABLE' -ForegroundColor Cyan
    Write-Host '================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host '墨堤的"虚拟麦克风"路线依赖 VB-CABLE 虚拟音频设备。'
    Write-Host '墨堤不打包、不修改 VB-CABLE；以下操作将从官方渠道'
    Write-Host '(vb-audio.com) 下载并静默安装官方驱动包。'
    Write-Host '安装后需要在系统重启前由 Windows 完成驱动注册。'
    Write-Host ''
}

function Main {
    if (Test-VbCableInstalled) {
        Write-Host 'VB-CABLE 已安装，跳过。' -ForegroundColor Green
        return 0
    }

    Write-ModiNotice
    $choice = Read-Host '是否现在从官方渠道下载并静默安装 VB-CABLE？[y/N]'
    if ($choice -notmatch '^[yY]') {
        Write-Host '已取消。用户可在 https://vb-audio.com/Cable/ 手动安装。' -ForegroundColor Yellow
        return 2
    }

    New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
    $zip = Join-Path $WorkDir 'vb-cable-official.zip'
    if (-not (Test-Path -LiteralPath $zip) -or -not $SkipDownloadIfCached) {
        Write-Host "下载官方包：$DownloadUrl"
        Invoke-WebRequest -Uri $DownloadUrl -OutFile $zip -UseBasicParsing
    }

    $extract = Join-Path $WorkDir 'official'
    if (Test-Path -LiteralPath $extract) { Remove-Item -Recurse -Force $extract }
    Expand-Archive -Path $zip -DestinationPath $extract

    $setup = Get-ChildItem -Path $extract -Recurse -Filter 'VBCABLE_Setup*.exe' |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $setup) {
        Write-Host '未找到官方安装程序，请手动安装：https://vb-audio.com/Cable/' -ForegroundColor Red
        return 3
    }

    Write-Host "静默执行官方安装程序：$($setup.Name)（-i -h 静默参数）"
    $proc = Start-Process -FilePath $setup.FullName -ArgumentList '-i','-h' -Wait -PassThru
    if ($proc.ExitCode -ne 0) {
        Write-Host "官方安装程序退出码 $($proc.ExitCode)。可能需要重启后生效。" -ForegroundColor Yellow
        return $proc.ExitCode
    }

    Write-Host 'VB-CABLE 安装流程完成。重启系统后驱动完全生效。' -ForegroundColor Green
    return 0
}

try {
    exit Main
}
catch {
    Write-Host "VB-CABLE 引导失败：$_" -ForegroundColor Red
    Write-Host '请手动安装：https://vb-audio.com/Cable/' -ForegroundColor Yellow
    exit 1
}
