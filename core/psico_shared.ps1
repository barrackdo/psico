# {"version": "0.1.3"}

<#
.SYNOPSIS
    PSICO Shared Module - Common helpers and constants for core and completion

.DESCRIPTION
    共通ヘルパー関数と定数を定義。psico_core.ps1 と psico_completion.ps1 から dot-source される前提。
    ここが定数の単一ソース（Single Source of Truth）です。
#>

# ============================================================
# 共通定数（グローバルスコープで共有）
# ============================================================

# 設定の既定値（ハードコード - config.json がない/壊れていても動作するため）
$global:_PsicoDefaultConfig = @{
    editor           = "notepad"
    logLevel         = 1
    completionSilent = $false
}

# 有効な logLevel の値
$global:_PsicoValidLogLevels = @(0, 1, 2, -1)

# 有効な completionSilent の値（bool型のみ）
$global:_PsicoValidCompletionSilent = @($true, $false)

# オプション定義（短縮形→長縮形のマッピング含む）
$global:_PsicoOptions = @{
    # 短縮形
    '-i'  = '--install'
    '-a'  = '--add'
    '-r'  = '--remove'
    '-e'  = '--edit'
    '-l'  = '--list'
    '-s'  = '--search'
    '-h'  = '--help'
    '-v'  = '--version'
    # 長縮形
    '--init'      = $null
    '--install'   = $null
    '--add'       = $null
    '--remove'    = $null
    '--edit'      = $null
    '--list'      = $null
    '--search'    = $null
    '--info'      = $null
    '--test'      = $null
    '--log'       = $null
    '--help'      = $null
    '--version'   = $null
    '--completion'= $null
}

# オプションの説明マップ（補完ツールチップ用）
$global:_PsicoOptionDescriptions = @{
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

# 短縮形の説明マップ
$global:_PsicoShortOptionDescriptions = @{
    '-i' = 'Install script from URL or local file'
    '-a' = 'Create new script'
    '-r' = 'Remove script'
    '-e' = 'Edit script'
    '-l' = 'List all scripts (optionally filter by tag)'
    '-s' = 'Search scripts (wildcard or regex)'
    '-h' = 'Show this help'
    '-v' = 'Show version'
}

# 引数を取るオプション（引数補完が必要なもの）
$global:_PsicoOptionsWithArgs = @(
    '--install', '-i',      # URL/path
    '--add', '-a',          # name, description
    '--remove', '-r',       # script name
    '--edit', '-e',         # script name
    '--list', '-l',         # [tag]
    '--search', '-s',       # pattern
    '--info',               # script name
    '--test',               # script name
    '--log',                # level
    '--completion'
)

# スクリプト名が必要なオプション
$global:_PsicoOptionsNeedingScript = @(
    '--remove', '-r',
    '--edit', '-e',
    '--info',
    '--test'
)

# タグフィルタ用オプション
$global:_PsicoOptionsTagFilter = @(
    '--list', '-l'
)

# 補完不要オプション（ガイドのみ、ヘルプ参照）
$global:_PsicoOptionsGuideOnly = @(
    '--install', '-i',
    '--init',
    '--help', '-h',
    '--version', '-v'
)


# ログレベル候補
$global:_PsicoLogLevels = @(
    @{ Value = '0';  Description = 'Quiet (no output)' },
    @{ Value = '1';  Description = 'Normal (default)' },
    @{ Value = '2';  Description = 'Verbose (debug output)' },
    @{ Value = '-1'; Description = 'Delete log files' }
)

# ADD オプションの引数ガイド
$global:_PsicoAddArgGuides = @(
    @{ Index = 1; Placeholder = 'Script name' },
    @{ Index = 2; Placeholder = 'Description' }
)

# ============================================================
# キャッシュ管理
# ============================================================

$global:_PsicoScriptMetaCache = $null
$global:_PsicoScriptMetaCacheTime = $null
$global:_PsicoScriptMetaCacheValid = $false

function global:_Psico_InvalidateScriptCache {
    $global:_PsicoScriptMetaCache = $null
    $global:_PsicoScriptMetaCacheTime = $null
    $global:_PsicoScriptMetaCacheValid = $false
}

function global:_Psico_EnsureScriptCache {
    if ($global:_PsicoScriptMetaCacheValid) { return }
    $global:_PsicoScriptMetaCache = @()
    $global:_PsicoScriptMetaCacheTime = Get-Date
    $global:_PsicoScriptMetaCacheValid = $true
}

# ============================================================
# 共通ヘルパー関数
# ============================================================

# ヘルパー：PSICO ルートディレクトリ取得
function global:_Psico_GetRootDir {
    # 1. 環境変数から
    if ($env:PSICO_ROOT -and (Test-Path (Join-Path $env:PSICO_ROOT "core\psico_core.ps1"))) {
        return $env:PSICO_ROOT
    }
    # 2. 既知の候補から探索
    $candidates = @(
        "$env:LOCALAPPDATA\psico",
        "$env:USERPROFILE\AppData\Local\psico",
        "C:\Dev\PowerShell\psico"
    )
    foreach ($c in $candidates) {
        if (Test-Path (Join-Path $c "core\psico_core.ps1")) {
            return $c
        }
    }
    return $null
}

# ヘルパー：スクリプト一覧取得（メタ情報付き・キャッシュ付き）
function global:_Psico_GetScriptMetas {
    # キャッシュ有効期限 30秒
    if ($global:_PsicoScriptMetaCacheValid -and $global:_PsicoScriptMetaCacheTime -and ((Get-Date) - $global:_PsicoScriptMetaCacheTime).TotalSeconds -lt 30) {
        return $global:_PsicoScriptMetaCache
    }

    $root = global:_Psico_GetRootDir
    if (-not $root) { return @() }
    $scriptsDir = Join-Path $root "scripts"
    if (-not (Test-Path $scriptsDir)) { return @() }
    $metas = @()
    Get-ChildItem $scriptsDir -Filter "*.ps1" -ErrorAction SilentlyContinue | ForEach-Object {
        $meta = Get-ScriptMeta $_.FullName
        if ($meta) {
            # ConvertFrom-Json で生成されるオブジェクトはイミュータブルなので、新しいハッシュテーブルを作成してマージ
            $metaHash = @{}
            $meta.PSObject.Properties | ForEach-Object { $metaHash[$_.Name] = $_.Value }
            $metaHash['scriptName'] = $_.BaseName
            $metas += $metaHash
        }
    }
    $global:_PsicoScriptMetaCache = $metas
    $global:_PsicoScriptMetaCacheTime = Get-Date
    $global:_PsicoScriptMetaCacheValid = $true
    return $metas
}

# ヘルパー：スクリプト名のみ取得
function global:_Psico_GetScripts {
    (global:_Psico_GetScriptMetas).scriptName
}

# ヘルパー：タグ一覧取得
function global:_Psico_GetTags {
    $tags = @()
    global:_Psico_GetScriptMetas | ForEach-Object {
        if ($_.tag) { $tags += $_.tag }
    }
    $tags | Sort-Object -Unique
}

# ヘルパー：スクリプトの引数メタ取得
function global:_Psico_GetScriptArgMetas {
    param([string]$ScriptName)
    $metas = global:_Psico_GetScriptMetas
    $found = $metas | Where-Object { $_.scriptName -ieq $ScriptName }
    if ($found -and $found.args) { return $found.args }
    return @()
}

# ヘルパー：CompletionResult 作成（ツールチップに詳細情報を埋め込み）
function global:_Psico_MakeCompletionResult {
    param(
        [string]$CompletionText,
        [string]$ListItemText,
        [string]$ToolTip = ""
    )
    # nullチェック（空文字は許可してツールチップのみの補完を可能にする）
    if ($CompletionText -eq $null) { return $null }
    if (-not $ListItemText) { $ListItemText = $CompletionText }
    if ($ToolTip) {
        return [System.Management.Automation.CompletionResult]::new($CompletionText, $ListItemText, 'ParameterValue', $ToolTip)
    }
    return [System.Management.Automation.CompletionResult]::new($CompletionText, $ListItemText, 'ParameterValue', $CompletionText)
}

# ヘルパー：オプション一覧を補完結果として出力（長縮形）
function global:_Psico_CompleteLongOptions {
    param([string]$Filter = '*', [string]$Prefix = '--*')
    $global:_PsicoOptions.Keys |
    Where-Object { $_ -like $Prefix -and $_ -like $Filter } |
    Sort-Object |
    ForEach-Object {
        $opt = $_
        $desc = $global:_PsicoOptionDescriptions[$opt]
        global:_Psico_MakeCompletionResult $opt $opt $desc
    }
}

# ヘルパー：オプション一覧を補完結果として出力（短縮形）
function global:_Psico_CompleteShortOptions {
    param([string]$Filter = '*')
    $global:_PsicoOptions.Keys |
    Where-Object { $_ -like '-*' -and $_ -notlike '--*' -and $_ -like $Filter } |
    Sort-Object |
    ForEach-Object {
        $opt = $_
        $long = $global:_PsicoOptions[$opt]
        $desc = $global:_PsicoShortOptionDescriptions[$long]
        global:_Psico_MakeCompletionResult $opt $opt $desc
    }
}

# ヘルパー：スクリプト名を補完結果として出力
function global:_Psico_CompleteScripts {
    param([string]$Filter = '*')
    (global:_Psico_GetScripts) |
    Where-Object { $_ -like $Filter } |
    Sort-Object |
    ForEach-Object {
        $name = $_
        $meta = global:_Psico_GetScriptMetas | Where-Object { $_.scriptName -ieq $name } | Select-Object -First 1
        $desc = if ($meta -and $meta.description) { $meta.description } else { '' }
        global:_Psico_MakeCompletionResult $name $name $desc
    }
}

# ヘルパー：タグ一覧を補完結果として出力
function global:_Psico_CompleteTags {
    param([string]$Filter = '*')
    (global:_Psico_GetTags) |
    Where-Object { $_ -like $Filter } |
    Sort-Object |
    ForEach-Object {
        global:_Psico_MakeCompletionResult $_ $_ "Filter by tag: $_"
    }
}

# ヘルパー：ログレベルを補完結果として出力
function global:_Psico_CompleteLogLevels {
    param([string]$Filter = '*')
    $global:_PsicoLogLevels |
    Where-Object { $_.Value -like $Filter } |
    ForEach-Object {
        global:_Psico_MakeCompletionResult $_.Value $_.Value $_.Description
    }
}

# ヘルパー：引数がガイドのみオプションか判定
function global:_Psico_IsGuideOnlyOption {
    param([string]$Option)
    $Option -in $global:_PsicoOptionsGuideOnly
}

# ヘルパー：引数を取るオプションか判定
function global:_Psico_HasOptionArg {
    param([string]$Option)
    $Option -in $global:_PsicoOptionsWithArgs
}

# ヘルパー：スクリプト名が必要なオプションか判定
function global:_Psico_NeedsScriptName {
    param([string]$Option)
    $Option -in $global:_PsicoOptionsNeedingScript
}

# ============================================================
# メタ情報抽出（core と completion 双方で使用するため shared に配置）
# ============================================================

# メタ情報抽出（# @meta { ... # } ブロックから JSON を抽出 + param() デフォルト値マージ）
function global:Get-ScriptMeta {
    param([string]$ScriptPath)

    if (-not (Test-Path $ScriptPath)) {
        return $null
    }

    $content = Get-Content $ScriptPath -Raw

    # # @meta { ... # } ブロックを抽出（コメントアウト済み形式に対応）
    $meta = $null
    if ($content -match '# @meta\s*({[\s\S]*?\n# \})') {
        try {
            # 各行から '# ' または '#' プレフィックスを除去して JSON を復元
            $cleanJson = ($Matches[1] -split "`n" | ForEach-Object {
                if ($_ -match '^#\s?(.*)$') {
                    $Matches[1]
                } else {
                    $_
                }
            }) -join "`n"
            $meta = $cleanJson | ConvertFrom-Json
        } catch {
            $meta = $null
        }
    }

    # param() ブロックからデフォルト値を抽出
    $paramDefaults = Get-ParamDefaults $content

    # メタデータの args にデフォルト値をマージ（メタ側が優先、無い場合は param() から補完）
    # ConvertFrom-Json で生成されるオブジェクトはイミュータブルなので、新しい配列を作成
    if ($meta -and $meta.args -and $paramDefaults) {
        $newArgs = @()
        foreach ($arg in $meta.args) {
            # ハッシュテーブルに変換して操作可能にする
            $argHash = @{}
            $arg.PSObject.Properties | ForEach-Object { $argHash[$_.Name] = $_.Value }

            if (-not $argHash.ContainsKey('default') -or $null -eq $argHash['default']) {
                if ($paramDefaults.ContainsKey($argHash['name'])) {
                    $argHash['default'] = $paramDefaults[$argHash['name']]
                }
            }
            $newArgs += $argHash
        }
        $meta.args = $newArgs
    }

    return $meta
}

# param() ブロックからデフォルト値を抽出
function global:Get-ParamDefaults {
    param([string]$Content)

    # param(...) ブロックを探す
    if ($Content -match 'param\s*\(([\s\S]*?)\)') {
        $paramBlock = $Matches[1]
        $defaults = @{}

        # 各行を解析: [type]$name = value
        $paramBlock -split "`n" | ForEach-Object {
            $line = $_.Trim()
            if ($line -match '^\[?\w+\]?\$(\w+)\s*=\s*(.+)$') {
                $name = $Matches[1]
                $value = $Matches[2].Trim().TrimEnd(',')
                # 値を適切な型に変換して保存
                $defaults[$name] = Parse-DefaultValue $value
            }
        }

        return $defaults
    }

    return @{}
}

# デフォルト値文字列を適切な型にパース
function global:Parse-DefaultValue {
    param([string]$Value)

    $Value = $Value.Trim()

    # ブーリアン
    if ($Value -match '^\$?(true|false)$') {
        return [bool]::Parse($Value.TrimStart('$'))
    }

    # 数値（int, double, decimal）
    if ($Value -match '^\d+$') {
        return [int]$Value
    }
    if ($Value -match '^\d+\.\d+$') {
        return [double]$Value
    }
    if ($Value -match '^\d+\.\d+[dD]$') {
        return [decimal]$Value.TrimEnd('d','D')
    }

    # 文字列（クォート除去）
    $dq = '"'
    $sq = "'"
    if ($Value -match "^[$dq$sq](.*)[$dq$sq]$") {
        return $Matches[1]
    }
    if ($Value -match '^@\("(.*)"\)$') {
        return $Matches[1]
    }

    # 配列・ハッシュテーブル等は文字列のまま返す
    return $Value
}