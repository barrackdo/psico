# {"version": "0.1.1"}

<#
.SYNOPSIS
    PSICO - PowerShell Script CLI Tool (Wrapper)

.DESCRIPTION
    Thin wrapper that handles zone identifier unblocking, sets up script paths,
    and loads the core module. All actual command processing is delegated to
    core\psico_core.ps1.

.PARAMETER Command
    Command to execute (short option or script name).
.PARAMETER Arg1
    First positional argument.
.PARAMETER Arg2
    Second positional argument.
.PARAMETER RemainingArgs
    Remaining arguments passed to the target script.
#>

param(
    [string]$Command,
    [string]$Arg1,
    [string]$Arg2,
    [string[]]$RemainingArgs
)

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
        editor   = "notepad.exe"
        logLevel = 2
    }
    $defaultConfig | ConvertTo-Json | Set-Content $script:ConfigFile -Encoding UTF8
}

# --- 長オプション・短オプションの手動パース ($args から直接) ---
# PowerShell の [CmdletBinding()] + [switch] では --install が $long_install に
# バインドされず、$Install ($install) と衝突するため、生の $args を
# 自分で走査してコマンドと引数を確定する。
$rawArgs = @($args)
$parsedCommand = $null
$parsedArg1    = $null
$parsedArg2    = $null

for ($i = 0; $i -lt $rawArgs.Count; $i++) {
    $arg = $rawArgs[$i]

    switch -Regex ($arg) {
        '^(--install|-i)$' {
            $parsedCommand = '-i'
            if (($i + 1) -lt $rawArgs.Count -and $rawArgs[$i + 1] -notmatch '^-') {
                $parsedArg1 = $rawArgs[++$i]
            }
        }
        '^(--list|-l)$' {
            $parsedCommand = '-l'
            if (($i + 1) -lt $rawArgs.Count -and $rawArgs[$i + 1] -notmatch '^-') {
                $parsedArg1 = $rawArgs[++$i]
            }
        }
        '^(--version|-v)$' { $parsedCommand = '-v' }
        '^(--help|-h)$'    { $parsedCommand = '-h' }
        '^--init$'         { $parsedCommand = '--init' }
        '^(--add|-a)$' {
            $parsedCommand = '-a'
            if (($i + 1) -lt $rawArgs.Count) { $parsedArg1 = $rawArgs[++$i] }
            if (($i + 1) -lt $rawArgs.Count) { $parsedArg2 = $rawArgs[++$i] }
        }
        '^(--remove|-r)$' {
            $parsedCommand = '-r'
            if (($i + 1) -lt $rawArgs.Count -and $rawArgs[$i + 1] -notmatch '^-') {
                $parsedArg1 = $rawArgs[++$i]
            }
        }
        '^(--edit|-e)$' {
            $parsedCommand = '-e'
            if (($i + 1) -lt $rawArgs.Count -and $rawArgs[$i + 1] -notmatch '^-') {
                $parsedArg1 = $rawArgs[++$i]
            }
        }
        '^(--search|-s)$' {
            $parsedCommand = '-s'
            if (($i + 1) -lt $rawArgs.Count -and $rawArgs[$i + 1] -notmatch '^-') {
                $parsedArg1 = $rawArgs[++$i]
            }
        }
        '^--info$' {
            $parsedCommand = '--info'
            if (($i + 1) -lt $rawArgs.Count -and $rawArgs[$i + 1] -notmatch '^-') {
                $parsedArg1 = $rawArgs[++$i]
            }
        }
        '^--test$' {
            $parsedCommand = '--test'
            if (($i + 1) -lt $rawArgs.Count -and $rawArgs[$i + 1] -notmatch '^-') {
                $parsedArg1 = $rawArgs[++$i]
            }
        }
        '^--log$' {
            $parsedCommand = '--log'
            if (($i + 1) -lt $rawArgs.Count -and $rawArgs[$i + 1] -notmatch '^-') {
                $parsedArg1 = $rawArgs[++$i]
            }
        }
    }
}

# パース結果を適用（コマンドライン位置パラメータより $args パースを優先）
if ($parsedCommand) { $Command = $parsedCommand }
if ($parsedArg1 -and [string]::IsNullOrEmpty($Arg1)) { $Arg1 = $parsedArg1 }
if ($parsedArg2 -and [string]::IsNullOrEmpty($Arg2)) { $Arg2 = $parsedArg2 }

# デフォルト値のフォールバック
$Arg1          = $Arg1          ?? $null
$Arg2          = $Arg2          ?? $null
$RemainingArgs = $RemainingArgs ?? @()

# コアモジュールの読み込み（dot-source により関数とメインロジックを読み込む）
$corePath = Join-Path $script:CoreDir "psico_core.ps1"
if (-not (Test-Path $corePath)) {
    Write-Host "Error: Core module not found at $corePath" -ForegroundColor Red
    exit 1
}

. $corePath
