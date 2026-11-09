# @meta {
#   "version": "0.1.0",
#   "description": "テキストを様々な形式で出力",
#   "tag": ["sample", "format"],
#   "args": [
#     {
#       "name": "text",
#       "type": "string",
#       "output": "出力するテキスト",
#       "default": "Hello World"
#     },
#     {
#       "name": "format",
#       "type": "enum",
#       "output": "出力形式を選択",
#       "options": ["upper", "lower", "title", "reverse", "json"],
#       "default": "upper"
#     },
#     {
#       "name": "repeat",
#       "type": "int",
#       "output": "繰り返し回数",
#       "default": 1
#     }
#   ]
# }

param(
    [string]$text = "Hello World",
    [string]$format = "upper",
    [int]$repeat = 1
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
        default    { return $text }
    }
}

for ($i = 1; $i -le $repeat; $i++) {
    $result = Format-Text $text $format
    Write-Host "[$i] $result"
}