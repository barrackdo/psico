# {"version": "0.1.0"}

<#
.SYNOPSIS
    PSICO - PowerShell Script CLI Tool (Wrapper)

.DESCRIPTION
    Thin wrapper that handles zone identifier unblocking, sets up script paths,
    and loads the core module. All actual command processing is delegated to
    core\psico_core.ps1.
#>

param(
    [Parameter(Position = 0)]
    [string]$Command,

    [Parameter(Position = 1)]
    [string]$Arg1,

    [Parameter(Position = 2)]
    [string]$Arg2,

    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)

# 【重要】ゾーン識別子（Zone.Identifier）の即時解除
# インターネットからダウンロードされたファイルとしてマークされている場合はブロックを解除
$myPath = $MyInvocation.MyCommand.Path
if (Test-Path "$myPath:Zone.Identifier") {
    Unblock-File -Path $myPath
}

# スクリプトのルートディレクトリを取得（ラッパー自身の場所）
$script:PsicoRoot = Split-Path -Parent $myPath
$script:CoreDir   = Join-Path $script:PsicoRoot "core"
$script:ScriptsDir = Join-Path $script:PsicoRoot "scripts"
$script:ModulesDir = Join-Path $script:PsicoRoot "modules"
$script:LogsDir   = Join-Path $script:PsicoRoot "logs"
$script:ConfigFile = Join-Path $script:PsicoRoot "config.json"

# config.jsonの初期化（まだの場合のみ）
if (-not (Test-Path $script:ConfigFile)) {
    $defaultConfig = @{
        editor = "notepad.exe"
        logLevel = 2
    }
    $defaultConfig | ConvertTo-Json | Set-Content $script:ConfigFile -Encoding UTF8
}

# コアモジュールの読み込み（dot-source により関数とメインロジックを読み込む）
$corePath = Join-Path $script:CoreDir "psico_core.ps1"
if (-not (Test-Path $corePath)) {
    Write-Host "Error: Core module not found at $corePath" -ForegroundColor Red
    exit 1
}

. $corePath