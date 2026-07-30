#requires -version 5.1
[CmdletBinding()]
param(
    [string]$Root,
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 2.0

if ([string]::IsNullOrWhiteSpace($Root)) {
    $Root = Split-Path -Parent $PSScriptRoot
}
$Root = (Resolve-Path -LiteralPath $Root).Path
if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = Join-Path $Root 'SOURCE_MANIFEST_SHA256.txt'
}
$outputFullPath = [IO.Path]::GetFullPath($OutputPath)

$files = @()
$git = Get-Command git -ErrorAction SilentlyContinue
if ($git) {
    Push-Location $Root
    try {
        $trackedPaths = @(& $git.Source ls-files)
        if ($LASTEXITCODE -ne 0) { throw 'git ls-files failed.' }
        $files = @($trackedPaths | ForEach-Object {
            $candidate = Join-Path $Root $_
            if (Test-Path -LiteralPath $candidate -PathType Leaf) { Get-Item -LiteralPath $candidate }
        })
    } finally {
        Pop-Location
    }
} else {
    $files = @(Get-ChildItem -LiteralPath $Root -File -Recurse | Where-Object {
        $_.FullName -ne $outputFullPath -and
        $_.FullName -notmatch '[\\/]\.git[\\/]' -and
        $_.FullName -notmatch '[\\/]LouisMahdi_System_Report_[^\\/]*[\\/]' -and
        $_.Name -notmatch '\.(exe|zip|log|jsonl)$' -and
        $_.Name -ne 'LouisMahdi_System_Inspector.exe.sha256.txt'
    })
}

$lines = foreach ($file in @($files | Sort-Object FullName)) {
    $relative = $file.FullName.Substring($Root.Length).TrimStart([char[]]@('\','/')) -replace '\\','/'
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    '{0}  {1}' -f $hash,$relative
}

[IO.File]::WriteAllLines($outputFullPath,$lines,(New-Object Text.UTF8Encoding($false)))
Write-Host ("Source manifest created: {0}" -f $outputFullPath) -ForegroundColor Green
