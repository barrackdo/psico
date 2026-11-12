# {"version": "0.1.6"}

<#
.SYNOPSIS
    PSICO Completion Module - Tab completion logic (Register-ArgumentCompleter)

.DESCRIPTION
    タブ補完専用モジュール。psico_shared.ps1 からキャッシュ・メタ解析ヘルパーのみインポート。
    補完用の定数・ヘルパーはこのファイル内で完結させ、依存問題を回避。
    Function: グローバルドライブ経由で確実にグローバル関数を登録。
#>

# 共通モジュール読み込み（キャッシュ・メタ解析・ルート取得のみ使用）
$script:CoreDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $script:CoreDir "psico_shared.ps1")

# 補完状態追跡用グローバル変数
if (-not (Test-Path Variable:global:_PsicoCompletionEnabled)) {
    $global:_PsicoCompletionEnabled = $false
}

# ============================================================
# 補完用定数（このファイル内で完結）
# ============================================================

$global:_PsicoComp_Options = @{
    '-i'  = '--install'
    '-a'  = '--add'
    '-r'  = '--remove'
    '-e'  = '--edit'
    '-l'  = '--list'
    '-s'  = '--search'
    '-h'  = '--help'
    '-v'  = '--version'
    '--init'       = $null
    '--install'    = $null
    '--add'        = $null
    '--remove'     = $null
    '--edit'       = $null
    '--list'       = $null
    '--search'     = $null
    '--info'       = $null
    '--test'       = $null
    '--log'        = $null
    '--help'       = $null
    '--version'    = $null
    '--completion' = $null
}

$global:_PsicoComp_OptionDescriptions = @{
    '--init'       = 'Initialize PSICO structure'
    '--install'    = 'Install script from URL or local file'
    '--add'        = 'Create new script'
    '--remove'     = 'Remove script'
    '--edit'       = 'Edit script'
    '--list'       = 'List all scripts (optionally filter by tag)'
    '--search'     = 'Search scripts (wildcard or regex)'
    '--info'       = 'Show script metadata'
    '--test'       = 'Run script without arguments to verify execution'
    '--log'        = 'Set log level (0-2, or -1 to delete logs)'
    '--completion' = 'Enable tab completion'
    '--help'       = 'Show this help'
    '--version'    = 'Show version'
}

$global:_PsicoComp_ShortOptionDescriptions = @{
    '-i' = 'Install script from URL or local file'
    '-a' = 'Create new script'
    '-r' = 'Remove script'
    '-e' = 'Edit script'
    '-l' = 'List all scripts (optionally filter by tag)'
    '-s' = 'Search scripts (wildcard or regex)'
    '-h' = 'Show this help'
    '-v' = 'Show version'
}

$global:_PsicoComp_OptionsWithArgs = @(
    '--install', '-i',
    '--add', '-a',
    '--remove', '-r',
    '--edit', '-e',
    '--list', '-l',
    '--search', '-s',
    '--info',
    '--test',
    '--log',
    '--completion'
)

$global:_PsicoComp_OptionsNeedingScript = @(
    '--remove', '-r',
    '--edit', '-e',
    '--info',
    '--test'
)

# 引数が省略可能で、引数があっても継続補完するオプション（--list 等）
$global:_PsicoComp_OptionsWithOptionalArgs = @(
    '--list', '-l'
)

$global:_PsicoComp_LogLevels = @(
    @{ Value = '0';  Description = 'Quiet (no output)' },
    @{ Value = '1';  Description = 'Normal (default)' },
    @{ Value = '2';  Description = 'Verbose (debug output)' },
    @{ Value = '-1'; Description = 'Delete log files' }
)

# ============================================================
# 補完専用ヘルパー関数（グローバル登録）
# ============================================================

# 完了済み引数をトークンから計算
Set-Item -Path "Function:global:_Psico_GetCompletedArgs" -Value {
    param($commandAst, $wordToComplete)

    $tokens = $null
    $errors = $null
    # commandAst が再構築済みならそのまま使う、そうでなければ ToString() で
    $inputText = $commandAst.ToString()
    if (-not $inputText -or $inputText.Trim() -eq '') {
        $inputText = "psico $wordToComplete"
    }
    $ast = [System.Management.Automation.Language.Parser]::ParseInput($inputText, [ref]$tokens, [ref]$errors)

    $completedArgs = @()
    $skipFirst = $true

    foreach ($token in $tokens) {
        if ($skipFirst) { $skipFirst = $false; continue }
        # 不完全なオプショントークン（単独の - や --）は除外
        if ($token.Text -eq '-' -or $token.Text -eq '--') {
            continue
        }
        if ($token.Kind -in @('String', 'CommandArgument', 'Variable', 'Member', 'CommandParameter', 'Parameter', 'Number', 'Generic', 'Identifier', 'MinusMinus')) {
            $completedArgs += $token.Text
        }
    }

    # 確実に配列として返す（@() でラップして単要素でも配列を維持）
    return @($completedArgs)
} -Force

# 引数を期待しているオプションを探す
# - 必須引数オプション（--remove, --install, --add 等）：必要引数数に達していない場合
# - 省略可能引数オプション（--list 等）：常に期待中として扱う（引数があっても継続補完）
Set-Item -Path "Function:global:_Psico_FindOptionExpectingArg" -Value {
    param($completedArgs)

    # オプションごとの必要引数数を定義
    $requiredArgCount = @{
        '--install' = 1; '-i' = 1
        '--add'     = 2; '-a' = 2
        '--remove'  = 1; '-r' = 1
        '--edit'    = 1; '-e' = 1
        '--list'    = 1; '-l' = 1
        '--search'  = 1; '-s' = 1
        '--info'    = 1
        '--test'    = 1
        '--log'     = 1
        '--completion' = 0
    }

    for ($i = 0; $i -lt $completedArgs.Count; $i++) {
        $arg = $completedArgs[$i]
        if ($global:_PsicoComp_OptionsWithArgs -contains $arg) {
            # 省略可能引数オプション（--list 等）は常に期待中
            if ($global:_PsicoComp_OptionsWithOptionalArgs -contains $arg) {
                return $arg
            }

            # 必須引数オプション：既に渡された引数数を数える
            $reqCount = $requiredArgCount[$arg]
            if ($reqCount -and $reqCount -gt 0) {
                # このオプションの後の非オプション引数を数える
                $argsAfter = 0
                for ($j = $i + 1; $j -lt $completedArgs.Count; $j++) {
                    if ($completedArgs[$j] -like '-*') { break }
                    $argsAfter++
                }
                if ($argsAfter -lt $reqCount) {
                    return $arg
                }
            }
            # 必須引数オプション（引数数未定義）：次の要素がオプションでない、または次の要素がない場合
            elseif (-not $reqCount) {
                if ($i -eq $completedArgs.Count - 1 -or $completedArgs[$i + 1] -like '-*') {
                    return $arg
                }
            }
        }
    }
    return $null
} -Force

# 最初の引数がスクリプト名か判定
Set-Item -Path "Function:global:_Psico_IsFirstArgScript" -Value {
    param($firstArg)
    if ($firstArg -and $firstArg -notlike '-*') {
        $scripts = & ${function:global:_Psico_GetScripts}
        if ($scripts -contains $firstArg) {
            return $true
        }
    }
    return $false
} -Force

# 位置引数インデックス取得
Set-Item -Path "Function:global:_Psico_GetPositionalArgIndex" -Value {
    param($completedArgs)
    $positionalArgs = $completedArgs | Where-Object { $_ -notlike '-*' }
    return $positionalArgs.Count - 1
} -Force

# 長縮オプション補完
Set-Item -Path "Function:global:_Psico_CompleteLongOptions" -Value {
    param([string]$Filter = '*')
    $global:_PsicoComp_Options.Keys |
    Where-Object { $_ -like '--*' -and $_ -like $Filter } |
    Sort-Object |
    ForEach-Object {
        $opt = $_
        $desc = $global:_PsicoComp_OptionDescriptions[$opt]
        & ${function:global:_Psico_MakeCompletionResult} $opt $opt $desc
    }
} -Force

# 短縮オプション補完
Set-Item -Path "Function:global:_Psico_CompleteShortOptions" -Value {
    param([string]$Filter = '*')
    $global:_PsicoComp_Options.Keys |
    Where-Object { $_ -like '-*' -and $_ -notlike '--*' -and $_ -like $Filter } |
    Sort-Object |
    ForEach-Object {
        $opt = $_
        $long = $global:_PsicoComp_Options[$opt]
        $desc = $global:_PsicoComp_ShortOptionDescriptions[$long]
        & ${function:global:_Psico_MakeCompletionResult} $opt $opt $desc
    }
} -Force

# スクリプト名補完
Set-Item -Path "Function:global:_Psico_CompleteScripts" -Value {
    param([string]$Filter = '*')
    (global:_Psico_GetScripts) |
    Where-Object { $_ -like $Filter } |
    Sort-Object |
    ForEach-Object {
        $name = $_
        $meta = global:_Psico_GetScriptMetas | Where-Object { $_.scriptName -ieq $name } | Select-Object -First 1
        $desc = if ($meta -and $meta.description) { $meta.description } else { '' }
        & ${function:global:_Psico_MakeCompletionResult} $name $name $desc
    }
} -Force

# タグ補完
Set-Item -Path "Function:global:_Psico_CompleteTags" -Value {
    param([string]$Filter = '*')
    (global:_Psico_GetTags) |
    Where-Object { $_ -like $Filter } |
    Sort-Object |
    ForEach-Object {
        & ${function:global:_Psico_MakeCompletionResult} $_ $_ "Filter by tag: $_"
    }
} -Force

# ログレベル補完
Set-Item -Path "Function:global:_Psico_CompleteLogLevels" -Value {
    param([string]$Filter = '*')
    $global:_PsicoComp_LogLevels |
    Where-Object { $_.Value -like $Filter } |
    ForEach-Object {
        & ${function:global:_Psico_MakeCompletionResult} $_.Value $_.Value $_.Description
    }
} -Force

# ============================================================
# メイン補完関数（グローバル）
# ============================================================

$completerScriptBlock = {
    param($wordToComplete, $commandName, $cursorPosition, $commandAst)

    # commandAst が null の場合、commandName（フルコマンドライン）から再構築してパース
    if (-not $commandAst) {
        $reconstructedLine = $commandName
        try {
            $tokens2 = $null
            $errors2 = $null
            $commandAst = [System.Management.Automation.Language.Parser]::ParseInput($reconstructedLine, [ref]$tokens2, [ref]$errors2)
        } catch {
            return
        }
    }

    # コマンド名確認（commandName パラメータは信用せず、ASTから取得）
    try {
        $cmdLine = $commandAst.ToString()
        $cmdName = $cmdLine.Trim().Split()[0]
    } catch {
        return
    }

    if ($cmdName -notin @('psico', 'psico.ps1')) {
        return
    }

    # 完成済み引数を計算（単要素配列の自動アンロール対策）
    $completedArgs = @(& ${function:global:_Psico_GetCompletedArgs} $commandAst $wordToComplete)

    # ===== 第1引数：オプション ＋ スクリプト名 =====
    if ($completedArgs.Count -eq 0) {
        if ($wordToComplete -like '--*') {
            & ${function:global:_Psico_CompleteLongOptions} -Filter "$wordToComplete*"
            return
        }
        elseif ($wordToComplete -like '-*' -and $wordToComplete -notlike '--*') {
            # 短オプションのみ（-- で始まるものは除外）
            & ${function:global:_Psico_CompleteShortOptions} -Filter "$wordToComplete*"
            return
        }
        else {
            if (-not $wordToComplete) {
                & ${function:global:_Psico_CompleteLongOptions}
                & ${function:global:_Psico_CompleteShortOptions}
            }
            # wordToComplete があればスクリプト名でフィルタ（スペースなし入力対応）
            & ${function:global:_Psico_CompleteScripts} -Filter "$wordToComplete*"
            return
        }
    }

    # ===== 最初の引数が確定済み =====
    $firstArg = $completedArgs[0]
    $optionForArg = & ${function:global:_Psico_FindOptionExpectingArg} $completedArgs

    # オプションの引数補完
    if ($optionForArg) {
        $filter = if ($wordToComplete) { "$wordToComplete*" } else { '*' }

        switch ($optionForArg) {
            { $_ -in @('--remove', '-r', '--edit', '-e', '--info', '--test') } {
                & ${function:global:_Psico_CompleteScripts} -Filter $filter
                return
            }
            { $_ -in @('--list', '-l') } {
                & ${function:global:_Psico_CompleteTags} -Filter "$wordToComplete*"
                return
            }
            { $_ -in @('--search', '-s') } {
                & ${function:global:_Psico_MakeCompletionResult} $wordToComplete $wordToComplete "Search pattern (wildcard or /regex/)"
                return
            }
            { $_ -in @('--install', '-i', '--completion') } {
                return
            }
            { $_ -in @('--add', '-a') } {
                # --add はファイル補完
                return
            }
            { $_ -in @('--log') } {
                & ${function:global:_Psico_CompleteLogLevels} -Filter "$wordToComplete*"
                return
            }
        }
        return
    }

    # ===== スクリプト実行モード：引数補完 =====
    $isScript = & ${function:global:_Psico_IsFirstArgScript} $firstArg

    # wordToComplete が空でないかつ firstArg と同じなら、まだスクリプト名入力中
    if ($isScript -and $wordToComplete -and $wordToComplete -eq $firstArg) {
        & ${function:global:_Psico_CompleteScripts} -Filter "$wordToComplete*"
        return
    }

    if ($isScript) {
        $argMetas = & ${function:global:_Psico_GetScriptArgMetas} $firstArg

        if ($argMetas) {
            $argIndex = & ${function:global:_Psico_GetPositionalArgIndex} $completedArgs

            if ($argIndex -ge 0 -and $argIndex -lt $argMetas.Count) {
                $argMeta = $argMetas[$argIndex]
                $type = if ($argMeta.type -is [array]) { $argMeta.type -join '|' } else { $argMeta.type }
                $default = if ($argMeta.default) { " (default: $($argMeta.default))" } else { "" }
                $output = if ($argMeta.output) { " - $($argMeta.output)" } else { "" }

                if ($argMeta.type -ilike 'enum') {
                    if ($argMeta.options) {
                        $argMeta.options |
                        Where-Object { $_ -like "$wordToComplete*" } |
                        ForEach-Object {
                            $marker = if ($argMeta.default -and $_ -eq $argMeta.default) { ' (default)' } else { '' }
                            & ${function:global:_Psico_MakeCompletionResult} $_ $_ "$type$default$output$marker"
                        }
                        return
                    }
                }
                elseif ($argMeta.type -ilike 'bool') {
                    @('true', 'false') |
                    Where-Object { $_ -like "$wordToComplete*" } |
                    ForEach-Object {
                        & ${function:global:_Psico_MakeCompletionResult} $_ $_ "bool$default$output"
                    }
                    return
                }
                else {
                    & ${function:global:_Psico_MakeCompletionResult} $wordToComplete $wordToComplete "$type$default$output"
                    return
                }
            }
        }
        # メタ定義外 → ファイル補完
        & ${function:global:_Psico_CompleteScripts} -Filter "$wordToComplete*"
        return
    }

    # ===== フォールバック =====
    $all = @()
    $all += $global:_PsicoComp_Options.Keys | Where-Object { $_ -like "$wordToComplete*" }
    $all += (& ${function:global:_Psico_GetScripts}) | Where-Object { $_ -like "$wordToComplete*" }
    $all | Sort-Object -Unique | ForEach-Object { & ${function:global:_Psico_MakeCompletionResult} $_ $_ '' }
}

Set-Item -Path "Function:global:_Psico_Completer" -Value $completerScriptBlock -Force

# ============================================================
# 公開関数
# ============================================================

Set-Item -Path "Function:global:Enable-PsicoCompletion" -Value {
    param([switch]$Silent)

    if ($global:_PsicoCompletionEnabled) {
        if (-not $Silent) {
            Write-Host "PSICO tab completion already enabled" -ForegroundColor Yellow
        }
        return
    }

    try {
        Register-ArgumentCompleter -CommandName 'psico' -ScriptBlock ${function:global:_Psico_Completer} -ErrorAction Stop
        Register-ArgumentCompleter -CommandName 'psico.ps1' -ScriptBlock ${function:global:_Psico_Completer} -ErrorAction Stop
    } catch {
        throw
    }

    # PSReadLine ハンドラ
    if (Get-Module -Name PSReadLine -ErrorAction SilentlyContinue) {
        try {
            Set-PSReadLineOption -CompletionQueryItems 100 -ErrorAction SilentlyContinue
            if (Get-Command Register-CompletionHandler -ErrorAction SilentlyContinue) {
                Register-CompletionHandler -CommandName 'psico' -ScriptBlock {
                    param($wordToComplete, $commandAst, $cursorPosition, $completionResults)
                    foreach ($result in $completionResults) {
                        if (-not $result.ToolTip -and $result.CompletionText -like '*.ps1') {
                            $result.ToolTip = "Script file: $($result.CompletionText)"
                        }
                    }
                    return $completionResults
                } -ErrorAction SilentlyContinue
            }
        } catch { }
    }

    $global:_PsicoCompletionEnabled = $true

    if (-not $Silent) {
        Write-Host "PSICO tab completion enabled (Register-ArgumentCompleter + PSReadLine)" -ForegroundColor Green
    }
} -Force

Set-Item -Path "Function:global:Get-PsicoCompletionDebugStatus" -Value {
    try {
        $dict = [System.Management.Automation.CommandCompletion]::Completers
        if ($dict -and $dict.ContainsKey('psico')) {
            Write-Host "psico completer: REGISTERED" -ForegroundColor Green
            return $true
        }
    } catch { }
    Write-Host "psico completer: NOT REGISTERED (or PowerShell < 7.4)" -ForegroundColor Yellow
    return $false
} -Force

Set-Item -Path "Function:global:Disable-PsicoCompletion" -Value {
    Write-Host "Warning: Once enabled, completion cannot be disabled in the same session." -ForegroundColor Yellow
    Write-Host "To disable, restart PowerShell or remove the registration from your profile." -ForegroundColor Gray
} -Force

Set-Item -Path "Function:global:Get-PsicoCompletionStatus" -Value {
    if ($global:_PsicoCompletionEnabled) {
        Write-Host "PSICO Completion Status: ENABLED" -ForegroundColor Green
        Write-Host "  - psico: REGISTERED" -ForegroundColor Green
        Write-Host "  - psico.ps1: REGISTERED" -ForegroundColor Green
        return $true
    } else {
        Write-Host "PSICO Completion Status: DISABLED" -ForegroundColor Yellow
        Write-Host "  - psico: NOT REGISTERED" -ForegroundColor Gray
        Write-Host "  - psico.ps1: NOT REGISTERED" -ForegroundColor Gray
        return $false
    }
} -Force