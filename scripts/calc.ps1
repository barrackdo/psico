# @meta {
#   "version": "0.1.0",
#   "description": "簡単な計算を実行",
#   "tag": ["sample", "math"],
#   "args": [
#     {
#       "name": "x",
#       "type": "int",
#       "output": "整数 X を入力",
#       "default": 10
#     },
#     {
#       "name": "y",
#       "type": "int",
#       "output": "整数 Y を入力",
#       "default": 5
#     },
#     {
#       "name": "op",
#       "type": "enum",
#       "output": "演算子を選択",
#       "options": ["+", "-", "*", "/"],
#       "default": "+"
#     }
#   ]
# }

param(
    [int]$x = 10,
    [int]$y = 5,
    [string]$op = "+"
)

switch ($op) {
    "+" { $result = $x + $y }
    "-" { $result = $x - $y }
    "*" { $result = $x * $y }
    "/" { 
        if ($y -eq 0) { Write-Host "Error: Division by zero"; exit 1 }
        $result = $x / $y 
    }
}

Write-Host "$x $op $y = $result"