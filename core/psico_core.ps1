# {"version": "0.1.2"}

<#
.SYNOPSIS
    PSICO Core - PowerShell Script CLI Tool (Core)

.DESCRIPTION
    PowerShellスクリプトの統合・制御・整理を目的としたCLI補助ツール（コアモジュール）
#>

# パス初期化（ラッパー未経由で dot-source された場合のフォールバック）
if (-not (Test-Path Variable:script:PsicoRoot)) {
    $coreScriptPath = $MyInvocation.MyCommand.Path
    $script:CoreDir     = Split-Path -Parent $coreScriptPath
    $script:PsicoRoot   = Split-Path -Parent $script:CoreDir
    $script:ScriptsDir  = Join-Path $script:PsicoRoot "scripts"
    $script:ModulesDir  = Join-Path $script:PsicoRoot "modules"
    $script:LogsDir     = Join-Path $script:PsicoRoot "logs"
    $script:ConfigFile  = Join-Path $script:PsicoRoot "config.json"
}

# 共通モジュール読み込み
. (Join-Path $script:CoreDir "psico_shared.ps1")

# 補完状態追跡用グローバル変数（初回のみ初期化）
if (-not (Test-Path Variable:global:_PsicoCompletionEnabled)) {
    $global:_PsicoCompletionEnabled = $false
}

# 補完モジュール読み込み（トップレベルで dot-source して global: 関数を確実に定義）
. (Join-Path $script:CoreDir "psico_completion.ps1")

# --completion: 補完機能を有効化（引数なし）
function Manage-PsicoCompletion {
    # 引数があれば無視して警告
    if ($Arg1) {
        Write-Host "Warning: 'psico --completion' takes no arguments. Enabling completion..." -ForegroundColor Yellow
    }
    # config.json の silent 設定を尊重
    $silent = $false
    try {
        $config = Get-PsicoConfig
        if ($config.completionSilent -eq $true) {
            $silent = $true
        }
    } catch { }
    Enable-PsicoCompletion -Silent:$silent
}

# バージョン取得（ファイル先頭の # {"version": "x.y.z"} から読み取り）
function Get-PsicoVersion {
    $corePath = Join-Path $script:CoreDir "psico_core.ps1"
    if (Test-Path $corePath) {
        $firstLine = Get-Content $corePath -TotalCount 1
        if ($firstLine -match '"version"\s*:\s*"([^"]+)"') {
            return $Matches[1]
        }
    }
    return "0.1.0"
}

# 設定読み込み
function Get-PsicoConfig {
    if (Test-Path $script:ConfigFile) {
        try {
            return Get-Content $script:ConfigFile -Raw | ConvertFrom-Json
        } catch {
            return @{
                editor = "notepad.exe"
                logLevel = 2
            }
        }
    }
    return @{
        editor = "notepad.exe"
        logLevel = 2
    }
}

# 設定保存
function Set-PsicoConfig {
    param($Config)
    $Config | ConvertTo-Json | Set-Content $script:ConfigFile -Encoding UTF8
}

# ログ出力
function Write-PsicoLog {
    param(
        [string]$Message,
        [int]$Level = 1
    )

    $config = Get-PsicoConfig
    if ($config.logLevel -ge $Level) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logMessage = "[$timestamp] $Message"
        Write-Host $logMessage

        if (-not (Test-Path $script:LogsDir)) {
            New-Item -ItemType Directory -Path $script:LogsDir -Force | Out-Null
        }

        $logFile = Join-Path $script:LogsDir "psico_$(Get-Date -Format 'yyyyMMdd').log"
        Add-Content -Path $logFile -Value $logMessage -Encoding UTF8
    }
}


# --init: 初期構成生成
function Initialize-Psico {
    Write-Host "Initializing PSICO structure..."

    @($script:ScriptsDir, $script:ModulesDir, $script:LogsDir, $script:CoreDir) | ForEach-Object {
        if (-not (Test-Path $_)) {
            New-Item -ItemType Directory -Path $_ -Force | Out-Null
            Write-Host "Created: $_"
        }
    }

    if (-not (Test-Path $script:ConfigFile)) {
        $defaultConfig = @{
            editor = "notepad.exe"
            logLevel = 2
        }
        Set-PsicoConfig $defaultConfig
        Write-Host "Created: $script:ConfigFile"
    }

    Write-Host "PSICO initialized successfully!" -ForegroundColor Green
}

# --install: スクリプトインストール
function Install-PsicoScript {
    param([string]$Source)

    Write-PsicoLog "Installing from: $Source" 1

    # URL またはローカルファイルパスかを判定
    $isUrl = $Source -match '^https?://'

    $tempFile = Join-Path $env:TEMP "psico_install_$(Get-Date -Format 'yyyyMMddHHmmss').tmp"
    $fileName = ""
    $sourcePath = ""

    try {
        if ($isUrl) {
            # URL の妥当性チェック
            try {
                $uri = [System.Uri]$Source
                if (-not $uri.IsAbsoluteUri) { throw "Not absolute" }
            } catch {
                Write-Host "Error: Invalid URL: $Source" -ForegroundColor Red
                return
            }

            # ダウンロード
            try {
                Invoke-WebRequest -Uri $Source -OutFile $tempFile
            } catch {
                Write-Host "Error: Failed to download from URL - $($_.Exception.Message)" -ForegroundColor Red
                return
            }

            $fileName = [System.IO.Path]::GetFileName($uri.LocalPath)
            if (-not $fileName -or $fileName -eq '') {
                $fileName = "downloaded_script.ps1"
            }
        } else {
            # ローカルファイルパスの存在チェック
            $sourcePath = (Resolve-Path $Source -ErrorAction SilentlyContinue).Path
            if (-not $sourcePath -or -not (Test-Path $sourcePath -PathType Leaf)) {
                Write-Host "Error: File not found: $Source" -ForegroundColor Red
                return
            }

            # テキストファイルか確認
            try {
                $null = Get-Content $sourcePath -ErrorAction Stop
            } catch {
                Write-Host "Error: File is not a valid text file: $Source" -ForegroundColor Red
                return
            }

            # 一時ファイルにコピー
            Copy-Item $sourcePath $tempFile -Force
            $fileName = [System.IO.Path]::GetFileName($sourcePath)
        }

        # 拡張子チェック
        $extension = [System.IO.Path]::GetExtension($fileName)
        if ($extension -ne '.ps1' -and $extension -ne '.psm1') {
            Write-Host "Error: File must be .ps1 or .psm1 (got: $extension)" -ForegroundColor Red
            Remove-Item $tempFile -Force
            return
        }

        $destination = switch ($extension) {
            ".ps1" { Join-Path $script:ScriptsDir $fileName }
            ".psm1" { Join-Path $script:ModulesDir $fileName }
        }

        Move-Item $tempFile $destination -Force
        Write-Host "Installed: $fileName" -ForegroundColor Green
        Write-PsicoLog "Installed: $fileName" 1

        # キャッシュ無効化（.ps1 の場合のみ）
        if ($extension -eq '.ps1') {
            global:_Psico_InvalidateScriptCache
        }

    } catch {
        Write-Host "Error: Failed to install - $($_.Exception.Message)" -ForegroundColor Red
        if (Test-Path $tempFile) {
            Remove-Item $tempFile -Force
        }
    }
}

# --add: 新規スクリプト作成
function Add-PsicoScript {
    param(
        [string]$Name,
        [string]$Description
    )

    $scriptPath = Join-Path $script:ScriptsDir "$Name.ps1"

    if (Test-Path $scriptPath) {
        Write-Host "Error: Script '$Name' already exists" -ForegroundColor Red
        return
    }

    $template = @"
# @meta {
#   "version": "0.1.0",
#   "description": "$Description",
#   "tag": [],
#   "args": []
# }

param()

# Your script here
Write-Host "Hello from $Name!"
"@

    Set-Content -Path $scriptPath -Value $template -Encoding UTF8
    Write-Host "Created: $Name.ps1" -ForegroundColor Green
    Write-PsicoLog "Created script: $Name" 1

    # キャッシュ無効化
    global:_Psico_InvalidateScriptCache

    # エディタで開く
    $config = Get-PsicoConfig
    Start-Process $config.editor -ArgumentList "`"$scriptPath`""
}

# --remove: スクリプト削除
function Remove-PsicoScript {
    param([string]$Name)

    $scriptPath = Join-Path $script:ScriptsDir "$Name.ps1"

    if (-not (Test-Path $scriptPath)) {
        Write-Host "Error: Script '$Name' not found" -ForegroundColor Red
        return
    }

    Remove-Item $scriptPath -Force
    Write-Host "Removed: $Name.ps1" -ForegroundColor Green
    Write-PsicoLog "Removed script: $Name" 1

    # キャッシュ無効化
    global:_Psico_InvalidateScriptCache
}

# --edit: スクリプト編集
function Edit-PsicoScript {
    param([string]$Name)

    $scriptPath = Join-Path $script:ScriptsDir "$Name.ps1"

    if (-not (Test-Path $scriptPath)) {
        Write-Host "Error: Script '$Name' not found" -ForegroundColor Red
        return
    }

    $config = Get-PsicoConfig
    Start-Process $config.editor -ArgumentList "`"$scriptPath`""
}

# --list: スクリプト一覧表示
function Get-PsicoScriptList {
    param([string]$Tag = "")

    $scripts = Get-ChildItem $script:ScriptsDir -Filter "*.ps1" -ErrorAction SilentlyContinue

    if (-not $scripts) {
        Write-Host "No scripts found" -ForegroundColor Yellow
        return
    }

    Write-Host "`nAvailable Scripts:" -ForegroundColor Cyan
    Write-Host ("=" * 60)

    foreach ($script in $scripts) {
        $meta = Get-ScriptMeta $script.FullName
        $name = $script.BaseName
        $description = if ($meta -and $meta.description) { $meta.description } else { "No description" }

        # タグフィルタリング
        if ($Tag) {
            $tagName = $Tag
            $scriptTags = @($meta.tag)
            if (-not ($scriptTags -contains $tagName)) {
                continue
            }
        }

        Write-Host "  $name" -ForegroundColor Green -NoNewline
        Write-Host " - $description"

        if ($meta -and $meta.tag -and $meta.tag.Count -gt 0) {
            Write-Host "    Tags: " -NoNewline -ForegroundColor Gray
            Write-Host ($meta.tag | ForEach-Object { "$_" }) -Separator ", " -ForegroundColor DarkGray
        }
    }

    Write-Host ("=" * 60)
}

# --search: スクリプト検索
function Search-PsicoScript {
    param([string]$Pattern)

    $scripts = Get-ChildItem $script:ScriptsDir -Filter "*.ps1" -ErrorAction SilentlyContinue

    if (-not $scripts) {
        Write-Host "No scripts found" -ForegroundColor Yellow
        return
    }

    $isRegex = $Pattern -match '^/(.+)/$'
    if ($isRegex) {
        $Pattern = $Matches[1]
    }

    Write-Host "`nSearch Results:" -ForegroundColor Cyan
    Write-Host ("=" * 60)

    $found = $false
    foreach ($script in $scripts) {
        $meta = Get-ScriptMeta $script.FullName
        $name = $script.BaseName
        $description = if ($meta -and $meta.description) { $meta.description } else { "" }
        $searchText = "$name $description"

        $match = if ($isRegex) {
            $searchText -match $Pattern
        } else {
            $searchText -like "*$Pattern*"
        }

        if ($match) {
            $found = $true
            Write-Host "  $name" -ForegroundColor Green -NoNewline
            Write-Host " - $description"
        }
    }

    if (-not $found) {
        Write-Host "  No matches found" -ForegroundColor Yellow
    }

    Write-Host ("=" * 60)
}

# --info: メタ情報表示
function Show-PsicoScriptInfo {
    param([string]$Name)

    $scriptPath = Join-Path $script:ScriptsDir "$Name.ps1"

    if (-not (Test-Path $scriptPath)) {
        Write-Host "Error: Script '$Name' not found" -ForegroundColor Red
        return
    }

    $meta = Get-ScriptMeta $scriptPath

    Write-Host "`nScript Information: $Name" -ForegroundColor Cyan
    Write-Host ("=" * 60)

    if ($meta) {
        Write-Host "Version:     " -NoNewline -ForegroundColor Gray
        Write-Host $meta.version
        Write-Host "Description: " -NoNewline -ForegroundColor Gray
        Write-Host $meta.description
        Write-Host "Tags:        " -NoNewline -ForegroundColor Gray
        Write-Host ($meta.tag -join ", ")

        if ($meta.args -and $meta.args.Count -gt 0) {
            Write-Host "`nArguments:" -ForegroundColor Gray
            for ($i = 0; $i -lt $meta.args.Count; $i++) {
                $arg = $meta.args[$i]
                $typeStr = Get-ArgumentTypeString $arg
                Write-Host "  [$i] Type: $typeStr" -NoNewline
                if ($arg.default) {
                    Write-Host " (default: $($arg.default))" -NoNewline
                }
                if ($arg.output) {
                    Write-Host " - $($arg.output)" -NoNewline
                }
                if ($arg.options) {
                    Write-Host " [options: $($arg.options -join ', ')]" -NoNewline
                }
                Write-Host ""
            }
        }
    } else {
        Write-Host "No metadata found" -ForegroundColor Yellow
    }

    Write-Host ("=" * 60)
}

# --test: テスト実行
function Test-PsicoScript {
    param([string]$Name)

    $scriptPath = Join-Path $script:ScriptsDir "$Name.ps1"

    if (-not (Test-Path $scriptPath)) {
        Write-Host "Error: Script '$Name' not found" -ForegroundColor Red
        return
    }

    Write-Host "Testing script: $Name" -ForegroundColor Cyan
    Write-Host "Note: Runs script without arguments to verify it executes without errors" -ForegroundColor Yellow
    Write-Host ("=" * 60)

    try {
        & $scriptPath
        Write-Host ("=" * 60)
        Write-Host "Test completed" -ForegroundColor Green
    } catch {
        Write-Host "Test failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# --log: ログレベル変更
function Set-PsicoLogLevel {
    param([int]$Level)

    if ($Level -eq -1) {
        if (Test-Path $script:LogsDir) {
            Remove-Item (Join-Path $script:LogsDir "*") -Force
            Write-Host "Log files deleted" -ForegroundColor Green
        }
        return
    }

    if ($Level -lt 0 -or $Level -gt 2) {
        Write-Host "Error: Log level must be 0, 1, or 2" -ForegroundColor Red
        return
    }

    $config = Get-PsicoConfig
    $config.logLevel = $Level
    Set-PsicoConfig $config
    Write-Host "Log level set to: $Level" -ForegroundColor Green
}

# --help: ヘルプ表示
function Show-PsicoHelp {
    $ver = Get-PsicoVersion
    Write-Host @"

PowerShell Script CLI Tool v$ver

USAGE:
    psico [options] [args...]
    psico <script-name> [args...]

OPTIONS:
    --init                          Initialize PSICO structure
    --install, -i <url|path>        Install script from URL or local file (.ps1 or .psm1)
    --add, -a <name> <description>  Create new script
    --remove, -r <name>             Remove script
    --edit, -e <name>               Edit script
    --list, -l [tag]                List all scripts (optionally filter by tag)
    --search, -s <pattern>          Search scripts (wildcard or regex)
    --info <name>                   Show script metadata
    --test <name>                   Run script without arguments to verify it executes without errors
    --log <level>                   Set log level (0-2, or -1 to delete logs)
    --completion                    Enable tab completion
    --help, -h                      Show this help
    --version, -v                   Show version

EXAMPLES:
    psico --init
    psico --add myScript "My useful script"
    psico --install https://example.com/script.ps1
    psico --list
    psico --list utility
    psico --search "sample"
    psico --search "/sample/"
    psico myScript arg1 arg2

"@ -ForegroundColor Cyan
}

# 引数タイプの取得（配列または文字列）
function Get-ArgumentTypes {
    param($ArgMeta)

    $typeValue = $ArgMeta.type
    if ($typeValue -is [array]) {
        return @($typeValue | ForEach-Object { [string]$_ })
    } else {
        return @([string]$typeValue)
    }
}

# 引数タイプの表示用文字列
function Get-ArgumentTypeString {
    param($ArgMeta)

    $types = Get-ArgumentTypes $ArgMeta
    if ($types.Count -gt 1) {
        return ($types -join '|')
    } else {
        # $types は単要素時 String にアンロールされるため、元の型情報を使う
        return [string]$ArgMeta.type
    }
}

# スクリプト実行
function Invoke-PsicoScript {
    param(
        [string]$Name,
        [string[]]$Arguments
    )

    $scriptPath = Join-Path $script:ScriptsDir "$Name.ps1"

    if (-not (Test-Path $scriptPath)) {
        Write-Host "Error: Script '$Name' not found" -ForegroundColor Red
        Write-Host "Use 'psico --list' to see available scripts" -ForegroundColor Yellow
        return
    }

    $meta = Get-ScriptMeta $scriptPath
    $scriptArgs = @()

    if ($meta -and $meta.args) {
        for ($i = 0; $i -lt $meta.args.Count; $i++) {
            $argMeta = $meta.args[$i]

            if ($i -lt $Arguments.Count) {
                $rawValue = $Arguments[$i]
                $scriptArgs += Convert-ArgumentValue $rawValue $argMeta
            } else {
                $types = Get-ArgumentTypes $argMeta
                $typeString = Get-ArgumentTypeString $argMeta
                $prompt = if ($argMeta.output) { $argMeta.output } else { "Enter argument [$typeString]" }

                if ($types.Count -gt 1) {
                    Write-Host $prompt
                    Write-Host "Select input type:" -ForegroundColor Yellow
                    for ($j = 0; $j -lt $types.Count; $j++) {
                        $typeName = $types[$j]
                        $defaultMarker = if ($argMeta.default) { " (default: $($argMeta.default))" } else { "" }
                        Write-Host "  [$j] $typeName$defaultMarker"
                    }
                    $typeSelection = Read-Host "Select type"
                    if ($typeSelection -match '^\d+$' -and [int]$typeSelection -lt $types.Count) {
                        $selectedType = $types[[int]$typeSelection]
                        $value = Read-Host "Enter $selectedType value"
                        # 一時的な ArgMeta を作って変換
                        $tempMeta = @{ type = $selectedType }
                        $scriptArgs += Convert-ArgumentValue $value $tempMeta
                    } else {
                        Write-Host "Invalid selection, using first type: $($types[0])" -ForegroundColor Yellow
                        $value = Read-Host "Enter $($types[0]) value"
                        $tempMeta = @{ type = $types[0] }
                        $scriptArgs += Convert-ArgumentValue $value $tempMeta
                    }
                }
                elseif ([string]$argMeta.type -eq "enum" -or [string]$argMeta.type -eq "Enum" -or ([string]$argMeta.type).ToLower() -eq "enum") {
                    if ($argMeta.options) {
                        # 選択肢を表示
                        Write-Host $prompt
                        Write-Host "Options:" -ForegroundColor Yellow
                        for ($j = 0; $j -lt $argMeta.options.Count; $j++) {
                            $opt = $argMeta.options[$j]
                            $defaultMarker = if ($argMeta.default -and $opt -eq $argMeta.default) { " (default)" } else { "" }
                            Write-Host "  [$j] $opt$defaultMarker"
                        }
                        $selection = Read-Host "Select option"
                        if ($selection -match '^\d+$' -and [int]$selection -lt $argMeta.options.Count) {
                            $scriptArgs += $argMeta.options[[int]$selection]
                        } elseif ($selection -eq '' -and $argMeta.default) {
                            $scriptArgs += $argMeta.default
                        } else {
                            if ($argMeta.default) {
                                Write-Host "無効な選択です。デフォルト値 '$($argMeta.default)' を使用します。" -ForegroundColor Yellow
                                $scriptArgs += $argMeta.default
                            } else {
                                $scriptArgs += $selection
                            }
                        }
                    } else {
                        # enumだがoptionsがない場合は通常入力
                        $scriptArgs += Read-Host $prompt
                    }
                }
                elseif ($argMeta.default) {
                    $input = Read-Host "$prompt (default: $($argMeta.default))"
                    $value = if ($input) { $input } else { $argMeta.default }
                    $scriptArgs += Convert-ArgumentValue $value $argMeta
                }
                else {
                    $value = Read-Host $prompt
                    $scriptArgs += Convert-ArgumentValue $value $argMeta
                }
            }
        }
    } else {
        $scriptArgs = $Arguments
    }

    Write-PsicoLog "Executing script: $Name with args: $($scriptArgs -join ', ')" 2

    try {
        & $scriptPath @scriptArgs
    } catch {
        Write-Host "Error executing script: $($_.Exception.Message)" -ForegroundColor Red
        Write-PsicoLog "Error executing $Name : $($_.Exception.Message)" 1
    }
}

# 型変換ヘルパー関数
function Convert-ArgumentValue {
    param(
        [string]$Value,
        $ArgMeta
    )
    $type = if ($ArgMeta.type -is [array]) { $ArgMeta.type[0] } else { $ArgMeta.type }
    switch ($type) {
        "int"       { [int]$Value }
        "double"    { [double]$Value }
        "decimal"   { [decimal]$Value }
        "bool"      {
            # bool型は文字列 'true'/'false' を正しく変換
            if ($Value -match '^(true|false|yes|no|1|0)$') {
                return [bool]::Parse($Value)
            }
            # 空文字列やnullの場合はfalse（デフォルト値がある場合はそちらが使われる）
            if ([string]::IsNullOrEmpty($Value)) { return $false }
            throw "Invalid bool value: $Value (use true/false, yes/no, 1/0)"
        }
        "url"       {
            try {
                $uri = [System.Uri]$Value
                if (-not $uri.IsAbsoluteUri) { throw "Not absolute" }
                $uri.AbsoluteUri
            } catch {
                throw "Invalid URL: $Value"
            }
        }
        "file"      {
            $full = (Resolve-Path $Value -ErrorAction Stop).Path
            if (-not (Test-Path $full -PathType Leaf)) { throw "File not found: $full" }
            $full
        }
        "folder"    {
            $full = (Resolve-Path $Value -ErrorAction Stop).Path
            if (-not (Test-Path $full -PathType Container)) { throw "Directory not found: $full" }
            $full
        }
        "directory" { # folder のエイリアス
            $full = (Resolve-Path $Value -ErrorAction Stop).Path
            if (-not (Test-Path $full -PathType Container)) { throw "Directory not found: $full" }
            $full
        }
        "datetime"  { [datetime]$Value }
        default     { $Value }
    }
}

# メインロジック（ラッパーから dot-source される前提。ラッパーがバインドしたパラメータを使用）
# ラッパー経由でない場合（$Command 未定義）は何もしない
if (-not (Test-Path Variable:Command)) {
    return
}
if (-not $Command) {
    Show-PsicoHelp
    exit
}

switch -Regex ($Command) {
    '^(-h|--help)$' { Show-PsicoHelp }
    '^(-v|--version)$' { Write-Host "PSICO version $(Get-PsicoVersion)" }
    '^--completion$' { Manage-PsicoCompletion }
    '^--init$' { Initialize-Psico }
    '^(-i|--install)$' {
        if ($Arg1) {
            Install-PsicoScript $Arg1
        } else {
            Write-Host "Error: URL required" -ForegroundColor Red
        }
    }
    '^(-a|--add)$' {
        if ($Arg1 -and $Arg2) {
            Add-PsicoScript $Arg1 $Arg2
        } else {
            Write-Host "Error: Name and description required" -ForegroundColor Red
        }
    }
    '^(-r|--remove)$' {
        if ($Arg1) {
            Remove-PsicoScript $Arg1
        } else {
            Write-Host "Error: Script name required" -ForegroundColor Red
        }
    }
    '^(-e|--edit)$' {
        if ($Arg1) {
            Edit-PsicoScript $Arg1
        } else {
            Write-Host "Error: Script name required" -ForegroundColor Red
        }
    }
    '^(-l|--list)$' {
        Get-PsicoScriptList $Arg1
    }
    '^(-s|--search)$' {
        if ($Arg1) {
            Search-PsicoScript $Arg1
        } else {
            Write-Host "Error: Search pattern required" -ForegroundColor Red
        }
    }
    '^--info$' {
        if ($Arg1) {
            Show-PsicoScriptInfo $Arg1
        } else {
            Write-Host "Error: Script name required" -ForegroundColor Red
        }
    }
    '^--test$' {
        if ($Arg1) {
            Test-PsicoScript $Arg1
        } else {
            Write-Host "Error: Script name required" -ForegroundColor Red
        }
    }
    '^--log$' {
        if ($Arg1 -match '^-?\d+$') {
            Set-PsicoLogLevel ([int]$Arg1)
        } else {
            Write-Host "Error: Log level must be a number" -ForegroundColor Red
        }
    }
    default {
        # スクリプト実行
        $allArgs = @($Arg1) + $Arg2 + $RemainingArgs | Where-Object { $_ }
        Invoke-PsicoScript $Command $allArgs
    }
}