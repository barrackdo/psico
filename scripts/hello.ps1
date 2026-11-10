# @meta {
#   "version": "0.1.1",
#   "description": "挨拶を表示するスクリプト（enum, int, bool のデモ）",
#   "tag": ["sample", "greeting", "types"],
#   "args": [
#     {
#       "name": "name",
#       "type": "enum",
#       "output": "名前を選択",
#       "options": ["Alice", "Bob", "Charlie"]
#     },
#     {
#       "name": "greeting",
#       "type": "enum",
#       "output": "挨拶の種類を選択",
#       "options": ["Hello", "Hi", "Hey", "Greetings"]
#     },
#     {
#       "name": "times",
#       "type": "int",
#       "output": "繰り返し回数"
#     },
#     {
#       "name": "excited",
#       "type": "bool",
#       "output": "興奮気味にするか（! を増やす）"
#     }
#   ]
# }

param(
    [string]$name = "Alice",
    [string]$greeting = "Hello",
    [int]$times = 1,
    [bool]$excited = $false
)

$suffix = if ($excited) { "!!!" } else { "!" }

for ($i = 1; $i -le $times; $i++) {
    Write-Host "$greeting, $name$suffix (#$i)"
}