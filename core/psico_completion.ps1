# {"version": "0.1.3"}

<#
.SYNOPSIS
    PSICO Completion Module - Fixed Shared Path

.DESCRIPTION
    v3.3.0: psico_shared パスを直接指定（MyInvocation 問題解決）。
#>

# ============================================================
# 定数定義のみ（空ハッシュテーブル・配列） - インポート高速化
# ============================================================
$global:_PsicoComp_Options = @{}
$global:_PsicoComp_OptionDescriptions = @{}
$global:_PsicoComp_ShortOptionDescriptions = @{}
$global:_PsicoComp_OptionsWithArgs = @()
$global:_PsicoComp_OptionsNeedingScript = @()
$global:_PsicoComp_OptionsWithOptionalArgs = @()
$global:_PsicoComp_LogLevels = @()
$global:_PsicoComp_RequiredArgCount = @{}

$global:_Psico_ConstInitScript = @'
$global:_PsicoComp_Options = @{
    "-i"="--install"; "-a"="--add"; "-r"="--remove"; "-e"="--edit"
    "-l"="--list"; "-s"="--search"; "-h"="--help"; "-v"="--version"
    "--init"=$null; "--install"=$null; "--add"=$null; "--remove"=$null
    "--edit"=$null; "--list"=$null; "--search"=$null; "--info"=$null
    "--test"=$null; "--log"=$null; "--help"=$null; "--version"=$null
    "--completion"=$null
}
$global:_PsicoComp_OptionDescriptions = @{
    "--init"="Initialize PSICO structure"; "--install"="Install script from URL or local file"
    "--add"="Create new script"; "--remove"="Remove script"; "--edit"="Edit script"
    "--list"="List all scripts (optionally filter by tag)"; "--search"="Search scripts (wildcard or regex)"
    "--info"="Show script metadata"; "--test"="Run script without arguments to verify execution"
    "--log"="Set log level (0-2, or -1 to delete logs)"; "--completion"="Enable tab completion"
    "--help"="Show this help"; "--version"="Show version"
}
$global:_PsicoComp_ShortOptionDescriptions = @{
    "-i"="Install script from URL or local file"; "-a"="Create new script"
    "-r"="Remove script"; "-e"="Edit script"; "-l"="List all scripts (optionally filter by tag)"
    "-s"="Search scripts (wildcard or regex)"; "-h"="Show this help"; "-v"="Show version"
}
$global:_PsicoComp_OptionsWithArgs = "--install","-i","--add","-a","--remove","-r","--edit","-e","--list","-l","--search","-s","--info","--test","--log","--completion"
$global:_PsicoComp_OptionsNeedingScript = "--remove","-r","--edit","-e","--info","--test"
$global:_PsicoComp_OptionsWithOptionalArgs = "--list","-l"
$global:_PsicoComp_LogLevels = @(
    @{Value="0";Description="Quiet (no output)"}, @{Value="1";Description="Normal (default)"}
    @{Value="2";Description="Verbose (debug output)"}, @{Value="-1";Description="Delete log files"}
)
$global:_PsicoComp_RequiredArgCount = @{
    "--install"=1;"-i"=1; "--add"=2;"-a"=2; "--remove"=1;"-r"=1; "--edit"=1;"-e"=1
    "--list"=1;"-l"=1; "--search"=1;"-s"=1; "--info"=1; "--test"=1; "--log"=1; "--completion"=0
}
'@

if (-not (Test-Path Variable:global:_PsicoCompletionState)) {
    $global:_PsicoCompletionState = @{
        Initialized = $false
        StubRegistered = $false
    }
}

# CoreDir を直接指定（MyInvocation 問題回避）
$coreDir = "C:\Dev\PowerShell\psico\core"

# 初期化コード全体をヒアドキュメントとして保持（パス直接指定版）
$global:_Psico_FullInitScript = @"
# --- 1. psico_shared 読み込み（パス直接指定） ---
. `"$coreDir\psico_shared.ps1`"

# --- 2. ヘルパー関数定義 ---
function global:_Psico_GetCompletedArgs {
    param(`$commandAst, `$wordToComplete)
    `$tokens = `$null; `$errors = `$null
    `$inputText = `$commandAst.ToString()
    if (-not `$inputText -or `$inputText.Trim() -eq "") { `$inputText = "psico `$wordToComplete" }
    `$ast = [System.Management.Automation.Language.Parser]::ParseInput(`$inputText, [ref]`$tokens, [ref]`$errors)
    `$completedArgs = @(); `$skipFirst = `$true
    foreach (`$token in `$tokens) {
        if (`$skipFirst) { `$skipFirst = `$false; continue }
        if (`$token.Text -in "-","--") { continue }
        if (`$token.Kind -in "String","CommandArgument","Variable","Member","CommandParameter","Parameter","Number","Generic","Identifier","MinusMinus") {
            `$completedArgs += `$token.Text
        }
    }
    return @(`$completedArgs)
}

function global:_Psico_FindOptionExpectingArg {
    param(`$completedArgs)
    for (`$i = 0; `$i -lt `$completedArgs.Count; `$i++) {
        `$arg = `$completedArgs[`$i]
        if (`$global:_PsicoComp_OptionsWithArgs -contains `$arg) {
            if (`$global:_PsicoComp_OptionsWithOptionalArgs -contains `$arg) { return `$arg }
            `$reqCount = `$global:_PsicoComp_RequiredArgCount[`$arg]
            if (`$reqCount -and `$reqCount -gt 0) {
                `$argsAfter = 0
                for (`$j = `$i + 1; `$j -lt `$completedArgs.Count; `$j++) {
                    if (`$completedArgs[`$j] -like "-*") { break }
                    `$argsAfter++
                }
                if (`$argsAfter -lt `$reqCount) { return `$arg }
            } elseif (-not `$reqCount) {
                if (`$i -eq `$completedArgs.Count - 1 -or `$completedArgs[`$i + 1] -like "-*") { return `$arg }
            }
        }
    }
    return `$null
}

function global:_Psico_IsFirstArgScript {
    param(`$firstArg)
    if (`$firstArg -and `$firstArg -notlike "-*") {
        if ((global:_Psico_GetScripts) -contains `$firstArg) { return `$true }
    }
    return `$false
}

function global:_Psico_GetPositionalArgIndex {
    param(`$completedArgs)
    (`$completedArgs | Where-Object { `$_ -notlike "-*" }).Count - 1
}

function global:_Psico_MakeCompletionResult {
    param([string]`$CompletionText, [string]`$ListItemText, [string]`$ToolTip = "")
    if (`$CompletionText -eq `$null) { return `$null }
    if (-not `$ListItemText) { `$ListItemText = `$CompletionText }
    if (`$ToolTip) { return [System.Management.Automation.CompletionResult]::new(`$CompletionText, `$ListItemText, "ParameterValue", `$ToolTip) }
    return [System.Management.Automation.CompletionResult]::new(`$CompletionText, `$ListItemText, "ParameterValue", `$CompletionText)
}

function global:_Psico_CompleteLongOptions {
    param([string]`$Filter = "*")
    `$global:_PsicoComp_Options.Keys | Where-Object { `$_ -like "--*" -and `$_ -like `$Filter } | Sort-Object |
    ForEach-Object { global:_Psico_MakeCompletionResult `$_ `$_ `$global:_PsicoComp_OptionDescriptions[`$_] }
}

function global:_Psico_CompleteShortOptions {
    param([string]`$Filter = "*")
    `$global:_PsicoComp_Options.Keys | Where-Object { `$_ -like "-*" -and `$_ -notlike "--*" -and `$_ -like `$Filter } | Sort-Object |
    ForEach-Object { `$long = `$global:_PsicoComp_Options[`$_]; global:_Psico_MakeCompletionResult `$_ `$_ `$global:_PsicoComp_ShortOptionDescriptions[`$long] }
}

function global:_Psico_CompleteScripts {
    param([string]`$Filter = "*")
    (global:_Psico_GetScripts) | Where-Object { `$_ -like `$Filter } | Sort-Object |
    ForEach-Object { `$name = `$_; `$meta = global:_Psico_GetScriptMetas | Where-Object { `$_.scriptName -ieq `$name } | Select-Object -First 1; `$desc = if (`$meta -and `$meta.description) { `$meta.description } else { "" }; global:_Psico_MakeCompletionResult `$name `$name `$desc }
}

function global:_Psico_CompleteTags {
    param([string]`$Filter = "*")
    (global:_Psico_GetTags) | Where-Object { `$_ -like `$Filter } | Sort-Object |
    ForEach-Object { global:_Psico_MakeCompletionResult `$_ `$_ "Filter by tag: `$_" }
}

function global:_Psico_CompleteLogLevels {
    param([string]`$Filter = "*")
    `$global:_PsicoComp_LogLevels | Where-Object { `$_.Value -like `$Filter } |
    ForEach-Object { global:_Psico_MakeCompletionResult `$_.Value `$_.Value `$_.Description }
}

# --- 3. 本体補完関数 ---
function global:_Psico_FullCompleter {
    param(`$wordToComplete, `$commandName, `$cursorPosition, `$commandAst)

    if (-not `$commandAst) {
        try { `$commandAst = [System.Management.Automation.Language.Parser]::ParseInput(`$commandName, [ref]`$null, [ref]`$null) } catch { return }
    }

    try { `$cmdName = `$commandAst.ToString().Trim().Split()[0] } catch { return }
    if (`$cmdName -notin "psico","psico.ps1") { return }

    `$completedArgs = @(global:_Psico_GetCompletedArgs `$commandAst `$wordToComplete)

    if (`$completedArgs.Count -eq 0) {
        if (`$wordToComplete -like "--*") { global:_Psico_CompleteLongOptions -Filter "`$wordToComplete*"; return }
        elseif (`$wordToComplete -like "-*" -and `$wordToComplete -notlike "--*") { global:_Psico_CompleteShortOptions -Filter "`$wordToComplete*"; return }
        else { if (-not `$wordToComplete) { global:_Psico_CompleteLongOptions; global:_Psico_CompleteShortOptions }; global:_Psico_CompleteScripts -Filter "`$wordToComplete*"; return }
    }

    `$firstArg = `$completedArgs[0]
    `$optionForArg = global:_Psico_FindOptionExpectingArg `$completedArgs

    if (`$optionForArg) {
        `$filter = if (`$wordToComplete) { "`$wordToComplete*" } else { "*" }
        switch (`$optionForArg) {
            { `$_ -in "--remove","-r","--edit","-e","--info","--test" } { global:_Psico_CompleteScripts -Filter `$filter; return }
            { `$_ -in "--list","-l" } { global:_Psico_CompleteTags -Filter "`$wordToComplete*"; return }
            { `$_ -in "--search","-s" } { global:_Psico_MakeCompletionResult `$wordToComplete `$wordToComplete "Search pattern (wildcard or /regex/)"; return }
            { `$_ -in "--install","-i","--completion" } { return }
            { `$_ -in "--add","-a" } { return }
            { `$_ -in "--log" } { global:_Psico_CompleteLogLevels -Filter "`$wordToComplete*"; return }
        }
        return
    }

    `$isScript = global:_Psico_IsFirstArgScript `$firstArg

    if (`$isScript -and `$wordToComplete -and `$wordToComplete -eq `$firstArg) { global:_Psico_CompleteScripts -Filter "`$wordToComplete*"; return }

    if (`$isScript) {
        `$argMetas = global:_Psico_GetScriptArgMetas `$firstArg
        if (`$argMetas) {
            `$argIndex = global:_Psico_GetPositionalArgIndex `$completedArgs
            if (`$argIndex -ge 0 -and `$argIndex -lt `$argMetas.Count) {
                `$argMeta = `$argMetas[`$argIndex]
                `$type = if (`$argMeta.type -is [array]) { `$argMeta.type -join "|" } else { `$argMeta.type }
                `$default = if (`$argMeta.default) { " (default: `$(`$argMeta.default))" } else { "" }
                `$output = if (`$argMeta.output) { " - `$(`$argMeta.output)" } else { "" }
                if (`$argMeta.type -ilike "enum" -and `$argMeta.options) {
                    `$argMeta.options | Where-Object { `$_ -like "`$wordToComplete*" } | ForEach-Object { `$marker = if (`$argMeta.default -and `$_ -eq `$argMeta.default) { " (default)" } else { "" }; global:_Psico_MakeCompletionResult `$_ `$_ "`$type`$default`$output`$marker" }
                    return
                } elseif (`$argMeta.type -ilike "bool") {
                    "true","false" | Where-Object { `$_ -like "`$wordToComplete*" } | ForEach-Object { global:_Psico_MakeCompletionResult `$_ `$_ "bool`$default`$output" }
                    return
                } else { global:_Psico_MakeCompletionResult `$wordToComplete `$wordToComplete "`$type`$default`$output"; return }
            }
        }
        global:_Psico_CompleteScripts -Filter "`$wordToComplete*"; return
    }

    `$all = @(`$global:_PsicoComp_Options.Keys | Where-Object { `$_ -like "`$wordToComplete*" }) + @((global:_Psico_GetScripts) | Where-Object { `$_ -like "`$wordToComplete*" })
    `$all | Sort-Object -Unique | ForEach-Object { global:_Psico_MakeCompletionResult `$_ `$_ "" }
}

# --- 4. 本体補完関数登録 ---
Register-ArgumentCompleter -CommandName "psico" -ScriptBlock `${function:global:_Psico_FullCompleter} -ErrorAction SilentlyContinue
Register-ArgumentCompleter -CommandName "psico.ps1" -ScriptBlock `${function:global:_Psico_FullCompleter} -ErrorAction SilentlyContinue
"@

# ============================================================
# 公開関数（トップレベルで即座に利用可能）
# ============================================================

function global:Enable-PsicoCompletion {
    param([switch]$Silent)

    $state = $global:_PsicoCompletionState
    if ($state.Initialized) {
        if (-not $Silent) { Write-Host "Already enabled" -ForegroundColor Yellow }
        return
    }

    # 初期化実行
    $state.Initialized = $true

    $totalSw = [System.Diagnostics.Stopwatch]::StartNew()

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    try { Invoke-Expression $global:_Psico_ConstInitScript } catch { Write-Host "[PSICO] Const init error: $_" -ForegroundColor Red }
    $sw.Stop()
    $tConst = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)

    $sw.Restart()
    try {
        Invoke-Expression $global:_Psico_FullInitScript
    } catch {
        Write-Host "[PSICO] Init failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    $sw.Stop()
    $tInit = [math]::Round($sw.Elapsed.TotalMilliseconds, 1)

    $totalSw.Stop()
    $totalMs = [math]::Round($totalSw.Elapsed.TotalMilliseconds, 1)

    # completionSilent 設定を config.json から読み込み
    $silent = $false
    try {
        $rootDir = global:_Psico_GetRootDir
        if ($rootDir) {
            $configPath = Join-Path $rootDir "config.json"
            if (Test-Path $configPath) {
                $config = Get-Content $configPath -Raw | ConvertFrom-Json
                if ($config.completionSilent -eq $true) {
                    $silent = $true
                }
            }
        }
    } catch { }

    # -Silent パラメータが優先
    if ($Silent) { $silent = $true }

    if (-not $silent) {
        Write-Host "`n[PSICO] Initializing completion..." -ForegroundColor Cyan
        Write-Host "[PSICO] Initialized in $totalMs ms (Const: $tConst ms, Init: $tInit ms)" -ForegroundColor Green
    }

    if (-not $Silent) { Write-Host "PSICO completion enabled" -ForegroundColor Green }
}

function global:Get-PsicoCompletionStatus {
    if ($global:_PsicoCompletionState.Initialized) { Write-Host "FULLY INITIALIZED" -ForegroundColor Green; return $true }
    else { Write-Host "NOT INITIALIZED (will init on first Tab)" -ForegroundColor Gray; return $false }
}

function global:Get-PsicoCompletionDebugStatus {
    Write-Host "Initialized: $($global:_PsicoCompletionState.Initialized)"
    Write-Host "Helpers defined: $((Test-Path Function:global:_Psico_GetCompletedArgs))"
}

function global:Disable-PsicoCompletion { Write-Host "Restart PowerShell to disable." -ForegroundColor Yellow }

# ============================================================
# スタブ補完関数（即登録、初回Tabで初期化トリガー）
# ============================================================
$script:stubCompleter = [ScriptBlock]::Create(@"
param(`$wordToComplete, `$commandName, `$cursorPosition, `$commandAst)

`$state = `$global:_PsicoCompletionState

if (-not `$state.Initialized) {
    `$state.Initialized = `$true

    `$totalSw = [System.Diagnostics.Stopwatch]::StartNew()

    `$sw = [System.Diagnostics.Stopwatch]::StartNew()
    try { Invoke-Expression `$global:_Psico_ConstInitScript } catch { Write-Host "[PSICO] Const init error: `$_" -ForegroundColor Red }
    `$sw.Stop()
    `$tConst = [math]::Round(`$sw.Elapsed.TotalMilliseconds, 1)

    `$sw.Restart()
    try {
        Invoke-Expression `$global:_Psico_FullInitScript
    } catch {
        Write-Host "[PSICO] Init failed: `$(`$_.Exception.Message)" -ForegroundColor Red
    }
    `$sw.Stop()
    `$tInit = [math]::Round(`$sw.Elapsed.TotalMilliseconds, 1)

    `$totalSw.Stop()
    `$totalMs = [math]::Round(`$totalSw.Elapsed.TotalMilliseconds, 1)

    # completionSilent 設定を config.json から読み込み
    `$silent = `$false
    try {
        `$rootDir = global:_Psico_GetRootDir
        if (`$rootDir) {
            `$configPath = Join-Path `$rootDir "config.json"
            if (Test-Path `$configPath) {
                `$config = Get-Content `$configPath -Raw | ConvertFrom-Json
                if (`$config.completionSilent -eq `$true) {
                    `$silent = `$true
                }
            }
        }
    } catch { }

    if (-not `$silent) {
        Write-Host "`n[PSICO] Initializing completion..." -ForegroundColor Cyan
        Write-Host "[PSICO] Initialized in `$totalMs ms (Const: `$tConst ms, Init: `$tInit ms)" -ForegroundColor Green
    }

    if (Test-Path Function:global:_Psico_FullCompleter) {
        return global:_Psico_FullCompleter `$wordToComplete `$commandName `$cursorPosition `$commandAst
    }
}

if (Test-Path Function:global:_Psico_FullCompleter) {
    return global:_Psico_FullCompleter `$wordToComplete `$commandName `$cursorPosition `$commandAst
}

`$filter = if (`$wordToComplete) { "`$wordToComplete*" } else { "*" }
`$results = @()
`$global:_PsicoComp_Options.Keys | Where-Object { `_ -like "--*" -and `_ -like `$filter } | Sort-Object |
ForEach-Object { `$results += [System.Management.Automation.CompletionResult]::new(`$_, `$_, "ParameterValue", `$global:_PsicoComp_OptionDescriptions[`$_]) }
`$global:_PsicoComp_Options.Keys | Where-Object { `_ -like "-*" -and `_ -notlike "--*" -and `_ -like `$filter } | Sort-Object |
ForEach-Object { `$long = `$global:_PsicoComp_Options[`$_]; `$results += [System.Management.Automation.CompletionResult]::new(`$_, `$_, "ParameterValue", `$global:_PsicoComp_ShortOptionDescriptions[`$long]) }
return `$results
"@)

Register-ArgumentCompleter -CommandName "psico" -ScriptBlock $script:stubCompleter -ErrorAction SilentlyContinue
Register-ArgumentCompleter -CommandName "psico.ps1" -ScriptBlock $script:stubCompleter -ErrorAction SilentlyContinue
$global:_PsicoCompletionState.StubRegistered = $true