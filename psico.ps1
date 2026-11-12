# {"version": "0.1.2"}

<#
.SYNOPSIS
    PSICO - PowerShell Script CLI Tool (Wrapper)

.DESCRIPTION
    Thin wrapper that handles zone identifier unblocking, sets up script paths,
    and loads the core module. All actual command processing is delegated to
    core\psico_core.ps1.
#>

# 【重要】ゾーン識別子（Zone.Identifier）の即時解除
$myPath = $MyInvocation.MyCommand.Path
if (Test-Path "$myPath:Zone.Identifier") {
    Unblock-File -Path $myPath
}

# スクリプトのルートディレクトリを取得（ラッパー自身の場所）
$script:PsicoRoot   = Split-Path -Parent $myPath
$script:CoreDir     = Join-Path $script:PsicoRoot "core"
$script:ScriptsDir  = Join-Path $script:PsicoRoot "scripts"
$script:ModulesDir  = Join-Path $script:PsicoRoot "modules"
$script:LogsDir     = Join-Path $script:PsicoRoot "logs"
$script:ConfigFile  = Join-Path $script:PsicoRoot "config.json"

# config.json の初期化（まだの場合のみ）
if (-not (Test-Path $script:ConfigFile)) {
    $defaultConfig = @{
        editor            = "notepad.exe"
        logLevel          = 2
        completionSilent  = $true
    }
    $defaultConfig | ConvertTo-Json | Set-Content $script:ConfigFile -Encoding UTF8
}

# --- 生の引数 ($args) を直接パース ---
# param ブロックを使わないことで $args に全引数が残るようにする
$rawArgs = @($args)

# パース結果
$Command       = $null
$Arg1          = $null
$Arg2          = $null
$RemainingArgs = @()

# 既知オプションの定義（引数を取るもの）
$optionsWithArgs = @(
    '--install', '-i',
    '--list', '-l',
    '--add', '-a',
    '--remove', '-r',
    '--edit', '-e',
    '--search', '-s',
    '--info',
    '--test',
    '--log'
)

# 既知オプション（引数を取らないもの）
$optionsNoArgs = @(
    '--init',
    '--version', '-v',
    '--help', '-h',
    '--completion'
)

for ($i = 0; $i -lt $rawArgs.Count; $i++) {
    $arg = $rawArgs[$i]

    # 既知オプション（引数あり）の処理
    if ($optionsWithArgs -contains $arg) {
        if (-not $Command) { $Command = $arg }
        # 次の引数がオプションでなければ値として取得
        if (($i + 1) -lt $rawArgs.Count -and $rawArgs[$i + 1] -notmatch '^-') {
            if (-not $Arg1) { $Arg1 = $rawArgs[++$i] }
            elseif (-not $Arg2) { $Arg2 = $rawArgs[++$i] }
            else { $RemainingArgs += $rawArgs[++$i] }
        }
        continue
    }

    # 既知オプション（引数なし）の処理
    if ($optionsNoArgs -contains $arg) {
        if (-not $Command) { $Command = $arg }
        continue
    }

    # --add は引数を2つ取る特殊ケース
    if ($arg -eq '--add' -or $arg -eq '-a') {
        if (-not $Command) { $Command = $arg }
        if (($i + 1) -lt $rawArgs.Count) {
            if (-not $Arg1) { $Arg1 = $rawArgs[++$i] }
        }
        if (($i + 1) -lt $rawArgs.Count) {
            if (-not $Arg2) { $Arg2 = $rawArgs[++$i] }
        }
        continue
    }

    # 未知の引数 = 位置引数（スクリプト名またはスクリプトへの引数）
    if (-not $Command -and $arg -notmatch '^-') {
        $Command = $arg
    } elseif ($Command -and $Command -notmatch '^-') {
        # スクリプト実行モードの場合、残りはすべてスクリプト引数
        if (-not $Arg1) { $Arg1 = $arg }
        elseif (-not $Arg2) { $Arg2 = $arg }
        else { $RemainingArgs += $arg }
    } else {
        # オプション風だが未知のものは位置引数として扱う
        if (-not $Arg1) { $Arg1 = $arg }
        elseif (-not $Arg2) { $Arg2 = $arg }
        else { $RemainingArgs += $arg }
    }
}

# デフォルト値のフォールバック
$Arg1          = if ([string]::IsNullOrEmpty($Arg1)) { $null } else { $Arg1 }
$Arg2          = if ([string]::IsNullOrEmpty($Arg2)) { $null } else { $Arg2 }
$RemainingArgs = $RemainingArgs ?? @()

# スクリプト名がパス形式の場合、ベース名のみ抽出
if ($Command -and $Command -notmatch '^-' -and ($Command -like '*.ps1' -or $Command -like '*\*' -or $Command -like '*/')) {
    $Command = [System.IO.Path]::GetFileNameWithoutExtension($Command)
}

# コアモジュールの読み込み（dot-source により関数とメインロジックを読み込む）
$corePath = Join-Path $script:CoreDir "psico_core.ps1"
if (-not (Test-Path $corePath)) {
    Write-Host "Error: Core module not found at $corePath" -ForegroundColor Red
    exit 1
}

. $corePath