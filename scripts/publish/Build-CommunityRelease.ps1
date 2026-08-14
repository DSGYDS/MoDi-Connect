#Requires -Version 7.0
<#
.SYNOPSIS
    墨堤 Windows 社区版（GitHub）发行包构建脚本。

.DESCRIPTION
    1. dotnet publish MoDi.Desktop（Release，win-x64，自包含或框架依赖由参数决定）。
    2. 校验协议制品（Verify-ProtocolArtifacts.ps1）。
    3. 组装发行目录：应用 + 协议 0.1.1 DLL 许可 + 法律文本 + 发布清单。
    4. 生成 SHA-256 包清单（release-manifest.json）。
    5. 扫描并拒绝：Gitee 凭据片段、更新器工具链、.cs/.pdb/协议源码。

.NOTES
    社区版不包含 Gitee 更新机制。Gitee 更新包由独立构建配置产出（未实现前禁止宣称可发布）。
    默认 self-contained 发布（.NET 运行时随包分发），确保用户机器无需预装 .NET。
#>
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$Configuration = 'Release',
    [string]$Runtime = 'win-x64',
    [bool]$SelfContained = $true,
    [string]$OutputRoot = (Join-Path $RepositoryRoot 'artifacts\community-release')
)

$ErrorActionPreference = 'Stop'

function Assert-NoForbiddenContent([string]$dir) {
    $forbiddenPatterns = @(
        'gitee', 'token', 'credential', 'password=',
        '.cs$', '.pdb$', 'appsettings.*.json'
    )
    $hits = @()
    foreach ($pattern in $forbiddenPatterns) {
        $matches = Get-ChildItem -Path $dir -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -match $pattern -or ($pattern -eq 'gitee' -and $_.Name -match 'gitee') }
        foreach ($m in $matches) { $hits += $m.FullName }
    }
    if ($hits) {
        throw "发行目录含禁止内容：$($hits -join ', ')"
    }
}

function Main {
    Write-Host "== 1. 校验协议制品 ==" -ForegroundColor Cyan
    & (Join-Path $RepositoryRoot 'scripts\protocol\Verify-ProtocolArtifacts.ps1')
    if (-not $?) { throw '协议制品校验失败' }

    Write-Host "== 2. 发布 MoDi.Desktop ==" -ForegroundColor Cyan
    $proj = Join-Path $RepositoryRoot 'windows\MoDi.Desktop\MoDi.Desktop.csproj'
    $publishDir = Join-Path $RepositoryRoot "artifacts\publish\$Runtime"
    $args = @('publish', $proj, '-c', $Configuration, '-r', $Runtime, '-o', $publishDir, '--nologo',
        '-p:DebugType=None', '-p:DebugSymbols=false')
    if ($SelfContained) { $args += '--self-contained', 'true' }
    & dotnet @args
    if ($LASTEXITCODE -ne 0) { throw 'dotnet publish 失败' }

    Write-Host "== 3. 组装发行目录 ==" -ForegroundColor Cyan
    if (Test-Path $OutputRoot) { Remove-Item -Recurse -Force $OutputRoot }
    New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null

    # 应用产物
    Copy-Item -Recurse -Force (Join-Path $publishDir '*') $OutputRoot

    # 清理调试符号：自家 pdb 已由 DebugType=None 抑制；
    # 第三方 NuGet 包（HarfBuzzSharp/SkiaSharp 等）自带的 pdb 一并移除。
    Get-ChildItem -Recurse -Filter '*.pdb' -Path $OutputRoot | Remove-Item -Force

    # 协议法律文本（第三方清单要求的随包副本）
    $legalDir = Join-Path $OutputRoot 'Licenses\MoDi.Protocol'
    New-Item -ItemType Directory -Force -Path $legalDir | Out-Null
    foreach ($f in @(
        'BINARY-REDISTRIBUTION-GRANT.txt',
        'LICENSE-PROTOCOL-BINARY.txt',
        'MODI-PROTOCOL-BINARY-LINKING-EXCEPTION-1.0.txt',
        'THIRD-PARTY-NOTICES.md'
    )) {
        Copy-Item (Join-Path $RepositoryRoot "third_party\modi-protocol\$f") $legalDir
    }
    Copy-Item (Join-Path $RepositoryRoot 'LICENSE') (Join-Path $OutputRoot 'LICENSE.txt')
    Copy-Item (Join-Path $RepositoryRoot 'third_party\modi-protocol\protocol-artifacts.v1.json') (Join-Path $legalDir 'protocol-artifacts.v1.json')

    # VB-CABLE 引导脚本（安装器组件；不打包二进制）
    Copy-Item (Join-Path $PSScriptRoot 'Install-VbCable.ps1') (Join-Path $OutputRoot 'Install-VbCable.ps1')

    Write-Host "== 4. 内容扫描 ==" -ForegroundColor Cyan
    Assert-NoForbiddenContent $OutputRoot

    Write-Host "== 5. 生成包清单 ==" -ForegroundColor Cyan
    $manifest = @{
        schemaVersion = 1
        edition = 'community'
        version = '1.0.0'
        protocolVersion = '0.1.1'
        commitSha = (& git -C $RepositoryRoot rev-parse HEAD).Trim()
        builtAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        runtime = $Runtime
        selfContained = $SelfContained
        files = @()
    }
    $files = @()
    Get-ChildItem -Path $OutputRoot -Recurse -File | ForEach-Object {
        $files += [ordered]@{
            path = $_.FullName.Substring($OutputRoot.Length).TrimStart('\','/')
            sizeBytes = $_.Length
            sha256 = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
        }
    }
    $manifest.files = $files
    $manifestJson = $manifest | ConvertTo-Json -Depth 6
    Set-Content -Path (Join-Path $OutputRoot 'release-manifest.json') -Value $manifestJson -Encoding utf8NoBOM

    Write-Host "== 完成 ==" -ForegroundColor Green
    Write-Host "社区版发行目录：$OutputRoot"
    Write-Host "文件数：$($files.Count)"
}

try {
    Main
    exit 0
}
catch {
    Write-Host "社区版构建失败：$_" -ForegroundColor Red
    exit 1
}
