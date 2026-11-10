# @meta {
#   "version": "0.1.1",
#   "description": "基本的な計算を実行（int, double, decimal, enum のデモ）",
#   "tag": ["sample", "math", "types"],
#   "args": [
#     {
#       "name": "x",
#       "type": "double",
#       "output": "数値 X を入力"
#     },
#     {
#       "name": "y",
#       "type": "double",
#       "output": "数値 Y を入力"
#     },
#     {
#       "name": "op",
#       "type": "enum",
#       "output": "演算子を選択",
#       "options": ["+", "-", "*", "/", "%", "**"]
#     },
#     {
#       "name": "precision",
#       "type": "int",
#       "output": "小数点以下の桁数"
#     }
#   ]
# }

param(
    [double]$x = 10.5,
    [double]$y = 2.5,
    [string]$op = "+",
    [int]$precision = 2
)

$format = "N$precision"

switch ($op) {
    "+" { $result = $x + $y }
    "-" { $result = $x - $y }
    "*" { $result = $x * $y }
    "/" {
        if ($y -eq 0) { Write-Host "Error: Division by zero" -ForegroundColor Red; exit 1 }
        $result = $x / $y
    }
    "%" {
        if ($y -eq 0) { Write-Host "Error: Modulo by zero" -ForegroundColor Red; exit 1 }
        $result = $x % $y
    }
    "**" { $result = [Math]::Pow($x, $y) }
    default { Write-Host "Unknown operator: $op" -ForegroundColor Red; exit 1 }
}

Write-Host "$x $op $y = $($result.ToString($format))"
Write-Host "Types: x=[double], y=[double], result=[double]"