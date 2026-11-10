# @meta {
#   "version": "0.1.1",
#   "description": "文字列・ファイル・URL・数値処理のデモ（全タイプのデモ）",
#   "tag": ["sample", "string", "types"],
#   "args": [
#     {
#       "name": "text",
#       "type": "string",
#       "output": "処理するテキスト"
#     },
#     {
#       "name": "action",
#       "type": "enum",
#       "output": "実行するアクション",
#       "options": ["length", "words", "chars", "trim", "replace", "reverse", "hash"]
#     },
#     {
#       "name": "arg",
#       "type": "string",
#       "output": "アクション用の追加引数"
#     },
#     {
#       "name": "inputFile",
#       "type": "file",
#       "output": "入力ファイルを指定（内容を text として使用）"
#     },
#     {
#       "name": "count",
#       "type": "int",
#       "output": "繰り返し回数"
#     },
#     {
#       "name": "precision",
#       "type": "double",
#       "output": "数値アクション時の精度"
#     }
#   ]
# }

param(
    [string]$text = "Hello World",
    [string]$action = "length",
    [string]$arg = "",
    [string]$inputFile = "",
    [int]$count = 1,
    [double]$precision = 2.0
)

# 入力ファイルが指定されている場合、その内容を読み込み
if ($inputFile -and (Test-Path $inputFile -PathType Leaf)) {
    $text = Get-Content $inputFile -Raw
    Write-Host "Loaded from file: $inputFile ($($text.Length) chars)" -ForegroundColor Gray
}

for ($i = 1; $i -le $count; $i++) {
    switch ($action) {
        "length"   { Write-Host "Length: $($text.Length)" }
        "words"    { Write-Host "Words: $($text.Split(' ').Count)" }
        "chars"    { Write-Host "Chars: $($text.ToCharArray().Count)" }
        "trim"     { Write-Host "Trimmed: '$($text.Trim())'" }
        "replace"  {
            if ($arg) { Write-Host "Replaced: '$($text.Replace('World', $arg))'" }
            else { Write-Host "Error: replace needs arg" }
        }
        "reverse"  {
            $si = [System.Globalization.StringInfo]::new($text)
            $cnt = $si.LengthInTextElements
            $result = [System.Text.StringBuilder]::new()
            for ($j = $cnt - 1; $j -ge 0; $j--) {
                $result.Append($si.SubstringByTextElements($j, 1)) | Out-Null
            }
            Write-Host "Reversed: '$($result.ToString())'"
        }
        "hash"     {
            $bytes = [Text.Encoding]::UTF8.GetBytes($text)
            $sha = [System.Security.Cryptography.SHA256]::Create()
            $hash = $sha.ComputeHash($bytes)
            Write-Host "SHA256: $([BitConverter]::ToString($hash).Replace('-', '').ToLower())"
        }
        default    { Write-Host "Unknown action: $action" }
    }
}