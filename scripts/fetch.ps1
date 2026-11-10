# @meta {
#   "version": "0.1.0",
#   "description": "URL からコンテンツを取得して保存（url, folder, file, bool, int のデモ）",
#   "tag": ["sample", "web", "types"],
#   "args": [
#     {
#       "name": "url",
#       "type": "url",
#       "output": "取得する URL を指定"
#     },
#     {
#       "name": "outDir",
#       "type": "folder",
#       "output": "保存先フォルダを指定"
#     },
#     {
#       "name": "outFile",
#       "type": "string",
#       "output": "保存ファイル名（省略時は URL から自動決定）"
#     },
#     {
#       "name": "timeout",
#       "type": "int",
#       "output": "タイムアウト秒数"
#     },
#     {
#       "name": "verbose",
#       "type": "bool",
#       "output": "詳細ログを表示するか"
#     }
#   ]
# }

param(
    [string]$url = "https://httpbin.org/get",
    [string]$outDir = ".",
    [string]$outFile = "",
    [int]$timeout = 30,
    [bool]$verbose = $false
)

try {
    if ($verbose) { Write-Host "Fetching: $url" -ForegroundColor Cyan }

    $response = Invoke-WebRequest -Uri $url -TimeoutSec $timeout -ErrorAction Stop

    if (-not $outFile) {
        $uri = [System.Uri]$url
        $outFile = [System.IO.Path]::GetFileName($uri.LocalPath)
        if (-not $outFile -or $outFile -eq '') { $outFile = "response.txt" }
    }

    $fullPath = Join-Path $outDir $outFile

    if ($verbose) { Write-Host "Saving to: $fullPath" -ForegroundColor Cyan }

    Set-Content -Path $fullPath -Value $response.Content -Encoding UTF8

    Write-Host "Saved: $fullPath ($($response.Content.Length) bytes)" -ForegroundColor Green

    if ($verbose) {
        Write-Host "Status: $($response.StatusCode) $($response.StatusDescription)"
        Write-Host "Headers:" -ForegroundColor Gray
        $response.Headers.GetEnumerator() | ForEach-Object {
            Write-Host "  $($_.Key): $($_.Value)" -ForegroundColor DarkGray
        }
    }

} catch {
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}