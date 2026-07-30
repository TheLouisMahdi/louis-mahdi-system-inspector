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
$files = Get-ChildItem -LiteralPath $Root -File -Recurse | Where-Object {
    $_.FullName -ne $outputFullPath -and
    $_.FullName -notmatch '[\\/]\.git[\\/]' -and
    $_.FullName -notmatch '[\\/]LouisMahdi_System_Report_[^\\/]*[\\/]'
} | Sort-Object FullName

$lines = foreach ($file in $files) {
    $relative = $file.FullName.Substring($Root.Length).TrimStart('\','/') -replace '\\','/'
    $hash = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    '{0}  {1}' -f $hash,$relative
}

[IO.File]::WriteAllLines($outputFullPath,$lines,(New-Object Text.UTF8Encoding($false)))
Write-Host ("Source manifest created: {0}" -f $outputFullPath) -ForegroundColor Green
