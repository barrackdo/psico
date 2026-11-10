# @meta {
#   "version": "0.1.1",
#   "description": "挨拶を表示するスクリプト",
#   "tag": ["sample", "greeting"],
#   "args": [
#     {
#       "name": "name",
#       "type": "enum",
#       "output": "名前を選択",
#       "options": ["Alice", "Bob", "Charlie"],
#       "default": "Alice"
#     },
#     {
#       "name": "greeting",
#       "type": "enum",
#       "output": "挨拶の種類を選択",
#       "options": ["Hello", "Hi", "Hey", "Greetings"],
#       "default": "Hello"
#     },
#     {
#       "name": "times",
#       "type": "int",
#       "output": "繰り返し回数",
#       "default": 1
#     }
#   ]
# }

param(
    [string]$name = "Alice",
    [string]$greeting = "Hello",
    [int]$times = 1
)

for ($i = 1; $i -le $times; $i++) {
    Write-Host "$greeting, $name! (#$i)"
}