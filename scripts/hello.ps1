# @meta {
#   "version": "0.1.1",
#   "description": "多言語挨拶ジェネレータ",
#   "tag": ["sample", "greeting"],
#   "args": [
#     {
#       "name": "name",
#       "type": "string",
#       "output": "名前を入力",
#       "default": "World"
#     },
#     {
#       "name": "lang",
#       "type": "enum",
#       "output": "言語を選択",
#       "options": ["en", "ja", "es", "fr", "de", "zh", "ko"],
#       "default": "en"
#     },
#     {
#       "name": "style",
#       "type": "enum",
#       "output": "スタイルを選択",
#       "options": ["formal", "casual", "friendly"],
#       "default": "friendly"
#     }
#   ]
# }

param(
    [string]$name = "World",
    [string]$lang = "en",
    [string]$style = "friendly"
)

$greetings = @{
    en = @{ formal = "Good day"; casual = "Hello"; friendly = "Hi" }
    ja = @{ formal = "こんにちは"; casual = "やあ"; friendly = "こんにちは！" }
    es = @{ formal = "Buenos días"; casual = "Hola"; friendly = "¡Hola!" }
    fr = @{ formal = "Bonjour"; casual = "Salut"; friendly = "Salut !" }
    de = @{ formal = "Guten Tag"; casual = "Hallo"; friendly = "Hallo!" }
    zh = @{ formal = "您好"; casual = "你好"; friendly = "你好呀！" }
    ko = @{ formal = "안녕하십니까"; casual = "안녕"; friendly = "안녕하세요!" }
}

$greeting = $greetings[$lang][$style] ?? $greetings.en.friendly
Write-Host "$greeting, $name!"