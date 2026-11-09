# PSICO インストールスクリプト
# インストール先: $env:LocalAppData\PSICO
# ソース: GitHubリポジトリ (https://github.com/barrackdo/psico) から取得

$installDir = "$env:LocalAppData\PSICO"
$baseUrl  = "https://raw.githubusercontent.com/barrackdo/psico/main"

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

# psico.ps1 の取得・保存
$srcPs1 = Join-Path $installDir "psico.ps1"
try {
    Download-File -Url "$baseUrl/psico.ps1" -Destination $srcPs1
    Write-Host "psico.ps1 を GitHub からダウンロードしました" -ForegroundColor Cyan
} catch {
    Write-Host "GitHub へのアクセスに失敗しました。" -ForegroundColor Yellow
    throw "psico.ps1 のダウンロードに失敗しました: $($_.Exception.Message)"
}

# core/psico_core.ps1 の取得・保存
if (-not (Test-Path (Join-Path $installDir "core"))) {
    New-Item -ItemType Directory -Path (Join-Path $installDir "core") -Force | Out-Null
}
$srcCorePs1 = Join-Path $installDir "core\psico_core.ps1"
try {
    Download-File -Url "$baseUrl/core/psico_core.ps1" -Destination $srcCorePs1
    Write-Host "core\psico_core.ps1 を GitHub からダウンロードしました" -ForegroundColor Cyan
} catch {
    Write-Host "GitHub へのアクセスに失敗しました。" -ForegroundColor Yellow
    throw "core\psico_core.ps1 のダウンロードに失敗しました: $($_.Exception.Message)"
}

# インストール完了の報告
Write-Host "PSICO のインストールが完了しました。" -ForegroundColor Green
Write-Host ""
Write-Host "==========================" -ForegroundColor Green
Write-Host "インストール完了" -ForegroundColor Green
Write-Host "==========================" -ForegroundColor Green
Write-Host "インストール先: $installDir"
Write-Host "スクリプト:    $installDir\psico.ps1"
Write-Host "コア:          $installDir\core\psico_core.ps1"
Write-Host "=================================================="

# プロファイルへの書き込みは行わず、追記すべきテキストのみを出力する
$profileContent = @"
function psico {
    & "$installDir\psico.ps1" @args
}
Set-Alias psico psico
"@

Write-Host "--- プロファイルに追加するテキスト ---" -ForegroundColor Cyan
Write-Host $profileContent
Write-Host "--- このテキストをプロファイルファイルに追加してください ---" -ForegroundColor Cyan
Write-Host "--- 追加後、PowerShell を再起動してください ---" -ForegroundColor Cyan
