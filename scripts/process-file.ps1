# @meta {
#   "version": "0.1.0",
#   "description": "ファイル処理ユーティリティ（file, folder, string, enum, int, bool のデモ）",
#   "tag": ["sample", "file", "utility", "types"],
#   "args": [
#     {
#       "name": "inputFile",
#       "type": "file",
#       "output": "入力ファイルを指定"
#     },
#     {
#       "name": "outputDir",
#       "type": "folder",
#       "output": "出力先フォルダを指定"
#     },
#     {
#       "name": "action",
#       "type": "enum",
#       "output": "処理アクションを選択",
#       "options": ["copy", "move", "backup", "info", "lines", "encoding"]
#     },
#     {
#       "name": "suffix",
#       "type": "string",
#       "output": "バックアップ/コピー時のサフィックス"
#     },
#     {
#       "name": "encoding",
#       "type": "enum",
#       "output": "文字エンコーディング",
#       "options": ["UTF8", "UTF7", "UTF32", "ASCII", "Default"]
#     },
#     {
#       "name": "verbose",
#       "type": "bool",
#       "output": "詳細を表示するか"
#     }
#   ]
# }

param(
    [string]$inputFile = "",
    [string]$outputDir = ".",
    [string]$action = "info",
    [string]$suffix = "_bak",
    [string]$encoding = "UTF8",
    [bool]$verbose = $false
)

if (-not $inputFile -or -not (Test-Path $inputFile -PathType Leaf)) {
    Write-Host "Error: Input file not found: $inputFile" -ForegroundColor Red
    exit 1
}

$srcPath = (Resolve-Path $inputFile).Path
$fileName = [System.IO.Path]::GetFileName($srcPath)
$fileExt = [System.IO.Path]::GetExtension($fileName)
$baseName = [System.IO.Path]::GetFileNameWithoutExtension($fileName)

if ($verbose) {
    Write-Host "Source: $srcPath" -ForegroundColor Cyan
    Write-Host "Action: $action" -ForegroundColor Cyan
}

switch ($action) {
    "info" {
        $item = Get-Item $srcPath
        Write-Host "=== File Information ===" -ForegroundColor Cyan
        Write-Host "Name:       $fileName"
        Write-Host "Full Path:  $srcPath"
        Write-Host "Size:       $($item.Length) bytes ($([Math]::Round($item.Length/1KB, 2)) KB)"
        Write-Host "Created:    $($item.CreationTime)"
        Write-Host "Modified:   $($item.LastWriteTime)"
        Write-Host "Extension:  $fileExt"
        Write-Host "ReadOnly:   $($item.IsReadOnly)"
    }
    "lines" {
        $lines = Get-Content $srcPath -Raw -ErrorAction Stop
        $count = ($lines -split "`r?`n").Count
        Write-Host "Line count: $count" -ForegroundColor Green
        if ($verbose) {
            $content = Get-Content $srcPath
            for ($i = 0; $i -lt [Math]::Min(10, $content.Count); $i++) {
                Write-Host "$($i+1): $($content[$i])"
            }
            if ($content.Count -gt 10) { Write-Host "... ($($content.Count) total lines)" }
        }
    }
    "encoding" {
        $enc = switch ($encoding) {
            "UTF8"    { [Text.Encoding]::UTF8 }
            "UTF7"    { [Text.Encoding]::UTF7 }
            "UTF32"   { [Text.Encoding]::UTF32 }
            "ASCII"   { [Text.Encoding]::ASCII }
            "Default" { [Text.Encoding]::Default }
            default   { [Text.Encoding]::UTF8 }
        }
        $content = Get-Content $srcPath -Raw -Encoding $enc
        $outFile = Join-Path $outputDir "$baseName.reencoded$fileExt"
        Set-Content -Path $outFile -Value $content -Encoding $enc
        Write-Host "Re-encoded to $encoding: $outFile" -ForegroundColor Green
    }
    "copy" {
        $outFile = Join-Path $outputDir "$baseName$suffix$fileExt"
        Copy-Item $srcPath $outFile -Force
        Write-Host "Copied to: $outFile" -ForegroundColor Green
    }
    "move" {
        $outFile = Join-Path $outputDir "$baseName$suffix$fileExt"
        Move-Item $srcPath $outFile -Force
        Write-Host "Moved to: $outFile" -ForegroundColor Green
    }
    "backup" {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $outFile = Join-Path $outputDir "$baseName$suffix.$timestamp$fileExt"
        Copy-Item $srcPath $outFile -Force
        Write-Host "Backup created: $outFile" -ForegroundColor Green
    }
    default { Write-Host "Unknown action: $action" -ForegroundColor Red; exit 1 }
}