# @meta {
#   "version": "0.1.0",
#   "description": "複利計算（decimal, double, int, bool のデモ）",
#   "tag": ["sample", "math", "finance", "types"],
#   "args": [
#     {
#       "name": "principal",
#       "type": "decimal",
#       "output": "元本を入力"
#     },
#     {
#       "name": "rate",
#       "type": "double",
#       "output": "年利率（%）を入力"
#     },
#     {
#       "name": "years",
#       "type": "int",
#       "output": "運用年数を入力"
#     },
#     {
#       "name": "compound",
#       "type": "enum",
#       "output": "複利の種類を選択",
#       "options": ["annual", "monthly", "daily"]
#     },
#     {
#       "name": "showTable",
#       "type": "bool",
#       "output": "年ごとの推移を表示するか"
#     }
#   ]
# }

param(
    [decimal]$principal = 1000000,
    [double]$rate = 3.5,
    [int]$years = 10,
    [string]$compound = "annual",
    [bool]$showTable = $false
)

$rateDecimal = [decimal]($rate / 100)

switch ($compound) {
    "annual"  { $n = 1 }
    "monthly" { $n = 12 }
    "daily"   { $n = 365 }
    default   { $n = 1 }
}

$totalPeriods = $years * $n
$periodRate = $rateDecimal / $n

$amount = $principal * ([decimal]::Pow(1 + $periodRate, $totalPeriods))
$interest = $amount - $principal

Write-Host "=== Compound Interest Calculation ===" -ForegroundColor Cyan
Write-Host "Principal:  $($principal.ToString("N0"))" -ForegroundColor Gray
Write-Host "Rate:       $rate% per year" -ForegroundColor Gray
Write-Host "Years:      $years" -ForegroundColor Gray
Write-Host "Compound:   $compound ($n times/year)" -ForegroundColor Gray
Write-Host "-----------------------------------"
Write-Host "Amount:     $($amount.ToString("N2"))" -ForegroundColor Green
Write-Host "Interest:   $($interest.ToString("N2"))" -ForegroundColor Yellow

if ($showTable) {
    Write-Host "`nYear-by-Year Breakdown:" -ForegroundColor Cyan
    Write-Host ("-" * 50)
    $balance = $principal
    for ($y = 1; $y -le $years; $y++) {
        $balance = $balance * ([decimal]::Pow(1 + $periodRate, $n))
        Write-Host "Year $($y.ToString().PadLeft(2)): $($balance.ToString("N2"))"
    }
}