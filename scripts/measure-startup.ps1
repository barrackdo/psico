# @meta {
#   "version": "0.1.0",
#   "description": "Measure PSICO startup overhead (in-process)",
#   "tag": ["diagnostics"],
#   "args": []
# }

param()

function Measure-Ms {
    param([ScriptBlock]$Block)
    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    & $Block
    $sw.Stop()
    return [double]$sw.Elapsed.TotalMilliseconds
}

function Round2($val) {
    return [math]::Round($val, 2)
}

Write-Host "=== PSICO Startup Overhead Measurement (In-Process) ===" -ForegroundColor Cyan
Write-Host ""

# ベースライン：何もしない
$null = Measure-Ms { Start-Sleep -Milliseconds 1 }
$baseline = 0

# 1. psico_shared.ps1 の dot-source
Write-Host "1. Dot-source psico_shared.ps1" -ForegroundColor Yellow
$t1 = Measure-Ms {
    . "C:\Users\Owner\AppData\Local\psico\core\psico_shared.ps1"
}
Write-Host "   Time: $(Round2 $t1) ms"
Write-Host ""

# 2. psico_completion.ps1 の dot-source（shared含む）
Write-Host "2. Dot-source psico_completion.ps1 (includes shared)" -ForegroundColor Yellow
$t2 = Measure-Ms {
    . "C:\Users\Owner\AppData\Local\psico\core\psico_completion.ps1"
}
Write-Host "   Time: $(Round2 $t2) ms"
Write-Host ""

# 3. Enable-PsicoCompletion -Silent
Write-Host "3. Enable-PsicoCompletion -Silent" -ForegroundColor Yellow
$t3 = Measure-Ms {
    Enable-PsicoCompletion -Silent
}
Write-Host "   Time: $(Round2 $t3) ms"
Write-Host ""

# 4. psico_core.ps1 の dot-source（shared + completion含む）
# 新しいセッションで測るため変数クリア
Remove-Variable -Name '_PsicoScriptMetaCache', '_PsicoScriptMetaCacheTime', '_PsicoScriptMetaCacheValid', '_PsicoComp_Options', '_PsicoComp_OptionDescriptions', '_PsicoComp_ShortOptionDescriptions', '_PsicoComp_OptionsWithArgs', '_PsicoComp_OptionsNeedingScript', '_PsicoComp_OptionsWithOptionalArgs', '_PsicoComp_LogLevels' -ErrorAction SilentlyContinue
Remove-Item Function:global:_Psico_GetCompletedArgs -ErrorAction SilentlyContinue
Remove-Item Function:global:_Psico_FindOptionExpectingArg -ErrorAction SilentlyContinue
Remove-Item Function:global:_Psico_IsFirstArgScript -ErrorAction SilentlyContinue
Remove-Item Function:global:_Psico_GetPositionalArgIndex -ErrorAction SilentlyContinue
Remove-Item Function:global:_Psico_CompleteLongOptions -ErrorAction SilentlyContinue
Remove-Item Function:global:_Psico_CompleteShortOptions -ErrorAction SilentlyContinue
Remove-Item Function:global:_Psico_CompleteScripts -ErrorAction SilentlyContinue
Remove-Item Function:global:_Psico_CompleteTags -ErrorAction SilentlyContinue
Remove-Item Function:global:_Psico_CompleteLogLevels -ErrorAction SilentlyContinue
Remove-Item Function:global:_Psico_Completer -ErrorAction SilentlyContinue
Remove-Item Function:global:Enable-PsicoCompletion -ErrorAction SilentlyContinue
Remove-Item Function:global:Get-PsicoCompletionDebugStatus -ErrorAction SilentlyContinue
Remove-Item Function:global:Disable-PsicoCompletion -ErrorAction SilentlyContinue
Remove-Item Function:global:Get-PsicoCompletionStatus -ErrorAction SilentlyContinue

Write-Host "4. Dot-source psico_core.ps1 (includes shared + completion)" -ForegroundColor Yellow
$t4 = Measure-Ms {
    . "C:\Users\Owner\AppData\Local\psico\core\psico_core.ps1"
}
Write-Host "   Time: $(Round2 $t4) ms"
Write-Host ""

# 5. psico ラッパー実行（引数なし = ヘルプ表示）
Write-Host "5. psico (no args -> help)" -ForegroundColor Yellow
$t5 = Measure-Ms {
    & "C:\Users\Owner\AppData\Local\psico\psico.ps1"
}
Write-Host "   Time: $(Round2 $t5) ms"
Write-Host ""

# 6. psico --version
Write-Host "6. psico --version" -ForegroundColor Yellow
$t6 = Measure-Ms {
    & "C:\Users\Owner\AppData\Local\psico\psico.ps1" --version
}
Write-Host "   Time: $(Round2 $t6) ms"
Write-Host ""

# 7. psico --list
Write-Host "7. psico --list" -ForegroundColor Yellow
$t7 = Measure-Ms {
    & "C:\Users\Owner\AppData\Local\psico\psico.ps1" --list
}
Write-Host "   Time: $(Round2 $t7) ms"
Write-Host ""

# まとめ
Write-Host "=== Summary ===" -ForegroundColor Cyan
Write-Host "Dot-source psico_shared.ps1:          $(Round2 $t1) ms"
Write-Host "Dot-source psico_completion.ps1:      $(Round2 $t2) ms"
Write-Host "Enable-PsicoCompletion -Silent:       $(Round2 $t3) ms"
Write-Host "Dot-source psico_core.ps1 (all):      $(Round2 $t4) ms"
Write-Host "psico (help):                         $(Round2 $t5) ms"
Write-Host "psico --version:                      $(Round2 $t6) ms"
Write-Host "psico --list:                         $(Round2 $t7) ms"
Write-Host ""

$totalCompletion = $t2 + $t3
$totalCore = $t4
Write-Host "Completion load (dot-source + enable): $(Round2 $totalCompletion) ms" -ForegroundColor $(if ($totalCompletion -gt 200) { "Red" } elseif ($totalCompletion -gt 100) { "Yellow" } else { "Green" })
Write-Host "Core load (shared + completion):       $(Round2 $totalCore) ms" -ForegroundColor $(if ($totalCore -gt 300) { "Red" } elseif ($totalCore -gt 150) { "Yellow" } else { "Green" })