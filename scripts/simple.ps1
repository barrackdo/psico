# @meta {
#   "version": "0.1.1",
#   "description": "文字列処理のデモ",
#   "tag": ["sample", "string"],
#   "args": [
#     {
#       "name": "text",
#       "type": "string",
#       "output": "処理するテキスト",
#       "default": "Hello World"
#     },
#     {
#       "name": "action",
#       "type": "enum",
#       "output": "実行するアクション",
#       "options": ["length", "words", "chars", "trim", "replace"],
#       "default": "length"
#     },
#     {
#       "name": "arg",
#       "type": "string",
#       "output": "アクション用の追加引数",
#       "default": ""
#     }
#   ]
# }

param(
    [string]$text = "Hello World",
    [string]$action = "length",
    [string]$arg = ""
)

switch ($action) {
    "length"   { Write-Host "Length: $($text.Length)" }
    "words"    { Write-Host "Words: $($text.Split(' ').Count)" }
    "chars"    { Write-Host "Chars: $($text.ToCharArray().Count)" }
    "trim"     { Write-Host "Trimmed: '$($text.Trim())'" }
    "replace"  {
        if ($arg) { Write-Host "Replaced: '$($text.Replace('World', $arg))'" }
        else { Write-Host "Error: replace needs arg" }
    }
    default    { Write-Host "Unknown action: $action" }
}