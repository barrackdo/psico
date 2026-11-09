# PSICO インストールスクリプト
# インストール先: $env:LocalAppData\PSICO
# ソース: GitHubリポジトリ (https://github.com/barrackdo/psico) 以外のローカルディレクトリ
#
# 以下のいずれかの方法で最新版を取得します:
# 1. GitHubからダウンロード (https://raw.githubusercontent.com/barrackdo/psico/main)
# 2. ローカル開発ディレクトリからコピー (C:\Dev\PowerShell\psico)

$installDir = "$env:LocalAppData\PSICO"
$baseUrl  = "https://raw.githubusercontent.com/barrackdo/psico/main"
$fallbackSrc = "C:\Dev\PowerShell\psico"

function Download-File {
    param([string]$Url, [string]$Destination)
    Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing
    Unblock-File -Path $Destination
}

# インストール先ディレクトリを作成
if (-not (Test-Path $installDir)) {
    New-Item -ItemType Directory -Path $installDir -Force | Out-Null
    Write-Host "インストール先ディレクトリを作成しました: $installDir"
}

# 最適なソースの選択: GitHub か、ローカルのいずれか
$srcPs1    = Join-Path $installDir "psico.ps1"
$srcCorePs1 = Join-Path $installDir "core\psico_core.ps1"
$srcCoreDir  = Join-Path $installDir "core"

if (Test-Path $fallbackSrc) {
    Write-Host "[情報] ローカル開発ディレクトリが存在します: $fallbackSrc" -ForegroundColor DarkGray
    Write-Host "[情報] GitHub にアクセスできない場合は、そちらからコピーします。" -ForegroundColor DarkGray
}

# psico.ps1 の取得・保存
$psicoPs1Exists = Test-Path $srcPs1
if ($psicoPs1Exists -and (Get-Item $srcPs1).LastWriteTime -gt (Get-Date).AddDays(-7)) {
    Write-Host "psico.ps1 は最新です ($($srcPs1.Replace($installDir,'').TrimStart('\')))" -ForegroundColor Green
} else {
    try {
        Download-File -Url "$baseUrl/psico.ps1" -Destination $srcPs1
        Write-Host "psico.ps1 を GitHub からダウンロードしました" -ForegroundColor Cyan
    } catch {
        Write-Host "GitHub へのアクセスに失敗しました。" -ForegroundColor Yellow
        Write-Host "ローカルの最新版を使用します: $fallbackSrc\psico.ps1" -ForegroundColor Yellow
        if (Test-Path "$fallbackSrc\psico.ps1") {
            Copy-Item -Path "$fallbackSrc\psico.ps1" -Destination $srcPs1 -Force
        } else {
            throw "psico.ps1 が見つかりません: $fallbackSrc\psico.ps1"
        }
    }
}

# core/psico_core.ps1 の取得・保存
if (-not (Test-Path $srcCoreDir)) {
    New-Item -ItemType Directory -Path $srcCoreDir -Force | Out-Null
}
$corePs1Exists = Test-Path $srcCorePs1
if ($corePs1Exists -and (Get-Item $srcCorePs1).LastWriteTime -gt (Get-Date).AddDays(-7)) {
    Write-Host "core\psico_core.ps1 は最新です ($($srcCorePs1.Replace($installDir,'').TrimStart('\')))" -ForegroundColor Green
} else {
    try {
        Download-File -Url "$baseUrl/core/psico_core.ps1" -Destination $srcCorePs1
        Write-Host "core\psico_core.ps1 を GitHub からダウンロードしました" -ForegroundColor Cyan
    } catch {
        Write-Host "GitHub へのアクセスに失敗しました。" -ForegroundColor Yellow
        Write-Host "ローカルの最新版を使用します: $fallbackSrc\core\psico_core.ps1" -ForegroundColor Yellow
        if (Test-Path "$fallbackSrc\core\psico_core.ps1") {
            Copy-Item -Path "$fallbackSrc\core\psico_core.ps1" -Destination $srcCorePs1 -Force
        } else {
            throw "core\psico_core.ps1 が見つかりません: $fallbackSrc\core\psico_core.ps1"
        }
    }
}

# PowerShell プロファイルの追加
$profilePath = $profile
$profileContent = @"
function psico {
    & "$installDir\psico.ps1" @args
}
Set-Alias psico psico
"@
Add-Content -Path $profilePath -Value $profileContent -Encoding UTF8
Write-Host "PowerShell プロファイル ($profilePath) に psico 関数を追加しました" -ForegroundColor Cyan

# 初期化 (初回のみ)
& "$installDir\psico.ps1" --init
Write-Host "PSICO の初期化が完了しました。" -ForegroundColor Green
Write-Host ""
Write-Host "==========================" -ForegroundColor Green
Write-Host "インストール完了" -ForegroundColor Green
Write-Host "==========================" -ForegroundColor Green
Write-Host "インストール先: $installDir"
Write-Host "スクリプト:    $installDir\psico.ps1"
Write-Host "コア:          $installDir\core\psico_core.ps1"
Write-Host "プロファイル:   $profilePath"
Write-Host "=================================================="
