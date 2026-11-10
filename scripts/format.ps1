# @meta {
#   "version": "0.1.1",
#   "description": "テキストを様々な形式で出力（string, enum, int, bool のデモ）",
#   "tag": ["sample", "format", "types"],
#   "args": [
#     {
#       "name": "text",
#       "type": "string",
#       "output": "出力するテキスト"
#     },
#     {
#       "name": "format",
#       "type": "enum",
#       "output": "出力形式を選択",
#       "options": ["upper", "lower", "title", "reverse", "json", "base64"]
#     },
#     {
#       "name": "repeat",
#       "type": "int",
#       "output": "繰り返し回数"
#     },
#     {
#       "name": "colorize",
#       "type": "bool",
#       "output": "色付き出力するか"
#     }
#   ]
# }

param(
    [string]$text = "Hello World",
    [string]$format = "upper",
    [int]$repeat = 1,
    [bool]$colorize = $false
)

function Format-Text {
    param($text, $format)
    switch ($format) {
        "upper"    { return $text.ToUpper() }
        "lower"    { return $text.ToLower() }
        "title"    { return (Get-Culture).TextInfo.ToTitleCase($text.ToLower()) }
        "reverse"  {
            $si = [System.Globalization.StringInfo]::new($text)
            $count = $si.LengthInTextElements
            $result = [System.Text.StringBuilder]::new()
            for ($i = $count - 1; $i -ge 0; $i--) {
                $result.Append($si.SubstringByTextElements($i, 1)) | Out-Null
            }
            return $result.ToString()
        }
        "json"     { return ('{ "text": "' + $text + '" }') }
        "base64"   { return [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($text)) }
        default    { return $text }
    }
}

$colors = @{
    upper   = "Cyan"
    lower   = "Green"
    title   = "Yellow"
    reverse = "Magenta"
    json    = "Gray"
    base64  = "DarkGray"
}

for ($i = 1; $i -le $repeat; $i++) {
    $result = Format-Text $text $format
    if ($colorize -and $colors.ContainsKey($format)) {
        Write-Host "[$i] $result" -ForegroundColor $colors[$format]
    } else {
        Write-Host "[$i] $result"
    }
}