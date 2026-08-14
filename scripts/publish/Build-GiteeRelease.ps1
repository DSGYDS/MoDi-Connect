#Requires -Version 7.0
<#
.SYNOPSIS
    墨堤 Windows 官方更新版（Gitee）发行包构建脚本。

.DESCRIPTION
    在社区版基础上增加更新能力所需的私有工具链：
    1. 调用社区版构建（self-contained .NET 随包分发）。
    2. 从官方源下载固定版本 MinGit 并解压到发行目录 tools\git（应用私有目录，
       不写入系统 PATH、不改全局安装）。
    3. 复制 update.json（真实凭据只在受控构建阶段注入，模板里只有 TBD 占位）。
    4. 生成包清单并拒绝凭据泄漏。

.NOTES
    更新服务（GiteeUpdateService）尚未实现前，本脚本产出为"候选包"，
    不得对外发布。凭据绝不写入仓库、清单或此脚本。
#>
[CmdletBinding()]
param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
    [string]$MinGitUrl = 'https://github.com/git-for-windows/git/releases/download/v2.46.0.windows.1/MinGit-2.46.0-64-bit.zip',
    [string]$MinGitSha256 = '',   # 受控构建阶段注入官方发布页公布的 SHA-256；为空则跳过强校验
    [string]$WorkDir = (Join-Path $RepositoryRoot 'artifacts\tools'),
    [string]$OutputRoot = (Join-Path $RepositoryRoot 'artifacts\gitee-release')
)

$ErrorActionPreference = 'Stop'

function Main {
    Write-Host "== 1. 构建社区版基底 ==" -ForegroundColor Cyan
    & (Join-Path $PSScriptRoot 'Build-CommunityRelease.ps1') `
        -RepositoryRoot $RepositoryRoot `
        -SelfContained $true `
        -OutputRoot $OutputRoot
    if (-not $?) { throw '社区版基底构建失败' }

    Write-Host "== 2. 下载并捆绑 MinGit（应用私有目录） ==" -ForegroundColor Cyan
    New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
    $zip = Join-Path $WorkDir 'MinGit-official.zip'
    if (-not (Test-Path -LiteralPath $zip)) {
        Write-Host "下载官方 MinGit：$MinGitUrl"
        Invoke-WebRequest -Uri $MinGitUrl -OutFile $zip -UseBasicParsing
    }
    if ($MinGitSha256) {
        $actual = (Get-FileHash -Algorithm SHA256 $zip).Hash.ToLowerInvariant()
        if ($actual -ne $MinGitSha256.ToLowerInvariant()) {
            throw "MinGit SHA-256 校验失败：期望 $MinGitSha256，实际 $actual"
        }
    }
    $gitDir = Join-Path $OutputRoot 'tools\git'
    if (Test-Path $gitDir) { Remove-Item -Recurse -Force $gitDir }
    Expand-Archive -Path $zip -DestinationPath $gitDir
    if (-not (Test-Path (Join-Path $gitDir 'mingw64\bin\git.exe')) -and
        -not (Test-Path (Join-Path $gitDir 'cmd\git.exe'))) {
        throw 'MinGit 解压后未找到 git.exe'
    }
    Write-Host "MinGit 已捆绑至 tools\git（不修改系统 PATH）"

    Write-Host "== 3. 复制 update.json 模板 ==" -ForegroundColor Cyan
    Copy-Item (Join-Path $PSScriptRoot 'update.gitee.json.template') (Join-Path $OutputRoot 'update.json')

    Write-Host "== 4. 凭据泄漏扫描 ==" -ForegroundColor Cyan
    $suspects = Get-ChildItem -Path $OutputRoot -Recurse -File |
        Where-Object { $_.Name -match '\.(pem|key|p12|pfx|env)$' -or $_.Name -match 'credential|token|secret' }
    if ($suspects) { throw "发行目录含疑似凭据文件：$($suspects.FullName -join ', ')" }

    Write-Host "== 5. 重新生成包清单（含工具链） ==" -ForegroundColor Cyan
    $files = Get-ChildItem -Path $OutputRoot -Recurse -File | ForEach-Object {
        [ordered]@{
            path = $_.FullName.Substring($OutputRoot.Length).TrimStart('\','/')
            sizeBytes = $_.Length
            sha256 = (Get-FileHash -Algorithm SHA256 $_.FullName).Hash.ToLowerInvariant()
        }
    }
    $manifest = @{
        schemaVersion = 1
        edition = 'official-gitee'
        version = '1.0.0'
        protocolVersion = '0.1.1'
        updateServiceImplemented = $false
        commitSha = (& git -C $RepositoryRoot rev-parse HEAD).Trim()
        builtAtUtc = (Get-Date).ToUniversalTime().ToString('o')
        bundledGit = ($MinGitUrl -replace '.*/', '')
        files = $files
    }
    Set-Content -Path (Join-Path $OutputRoot 'release-manifest.json') `
        -Value ($manifest | ConvertTo-Json -Depth 6) -Encoding utf8NoBOM

    Write-Host "== 完成（候选包，未实现更新服务前不得发布） ==" -ForegroundColor Yellow
    Write-Host "官方更新版发行目录：$OutputRoot"
}

try {
    Main
    exit 0
}
catch {
    Write-Host "官方更新版构建失败：$_" -ForegroundColor Red
    exit 1
}
