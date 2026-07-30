#requires -version 5.1
[CmdletBinding()]
param(
    [string]$SourcePath
)

$ErrorActionPreference = 'Stop'
$scriptDirectory = $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($scriptDirectory)) {
    $scriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
}
if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    $projectRoot = Split-Path -Parent $scriptDirectory
    $SourcePath = Join-Path $projectRoot 'src\LouisMahdi.SystemInspector.ps1'
}
if (-not (Test-Path -LiteralPath $SourcePath -PathType Leaf)) {
    Write-Host ("Source file was not found: {0}" -f $SourcePath) -ForegroundColor Red
    exit 1
}
$resolvedSourcePath = (Resolve-Path -LiteralPath $SourcePath).Path
$tokens = $null
$parseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile($resolvedSourcePath,[ref]$tokens,[ref]$parseErrors) | Out-Null

if (@($parseErrors).Count -gt 0) {
    Write-Host 'PowerShell parser errors:' -ForegroundColor Red
    foreach ($error in @($parseErrors)) {
        Write-Host ("Line {0}, column {1}: {2}" -f $error.Extent.StartLineNumber,$error.Extent.StartColumnNumber,$error.Message) -ForegroundColor Red
    }
    exit 1
}

$sourceText = [IO.File]::ReadAllText($resolvedSourcePath,[Text.Encoding]::UTF8)
$contractErrors = New-Object 'System.Collections.Generic.List[string]'
if ($sourceText -match '\$form\.Opacity\s*=\s*0(?:\.0+)?') { $contractErrors.Add('The main form must not start fully transparent.') | Out-Null }
if ($sourceText -notmatch '\$form\.Opacity\s*=\s*1(?:\.0+)?') { $contractErrors.Add('The main form full-opacity startup contract is missing.') | Out-Null }
if ($sourceText -notmatch '\$form\.ShowInTaskbar\s*=\s*\$true') { $contractErrors.Add('The taskbar visibility contract is missing.') | Out-Null }
if ($sourceText -notmatch '\$form\.WindowState\s*=\s*''Normal''') { $contractErrors.Add('The normal window-state contract is missing.') | Out-Null }
if ($sourceText -match '\$fadeTimer') { $contractErrors.Add('The startup fade timer must not control application visibility.') | Out-Null }
$sectionMaterializationCount = [regex]::Matches($sourceText,'\$sectionSnapshot\s*=\s*\$sections\.ToArray\(\)').Count
if ($sectionMaterializationCount -lt 3) { $contractErrors.Add('The generic section list must be materialized before warning, metadata, and final-model use.') | Out-Null }
if ($sourceText -notmatch 'Sections\s*=\s*\$sectionSnapshot') { $contractErrors.Add('The final report model must expose the materialized section snapshot.') | Out-Null }
if ($sourceText -match 'Sections\s*=\s*@\(\s*\$sections\s*\)') { $contractErrors.Add('The final report model must not expose the generic section list through array-subexpression syntax.') | Out-Null }
if ($sourceText -match 'Collect-WarningsSection\s+@\(\s*\$sections\s*\)') { $contractErrors.Add('Warnings collection must use a materialized section snapshot.') | Out-Null }
if ($sourceText -match 'Collect-MetadataSection[^\r\n]*@\(\s*\$sections\s*\)') { $contractErrors.Add('Metadata collection must use a materialized section snapshot.') | Out-Null }
if ($sourceText -match 'Get-AllSection(?:Warnings|Errors)\s+@\(\s*\$sections\s*\)') { $contractErrors.Add('Section aggregation must use a materialized section snapshot.') | Out-Null }
if ($sourceText -match 'return\s+@\(\$list\)') { $contractErrors.Add('Generic List[object] return values must not use array-subexpression syntax.') | Out-Null }
if ($sourceText -notmatch '\$warnings\s*=\s*@\(Get-AllSectionWarnings\s+\$ExistingSections\)') { $contractErrors.Add('Warnings aggregation must materialize singleton output before Count access.') | Out-Null }
if ($sourceText -notmatch '\$errors\s*=\s*@\(Get-AllSectionErrors\s+\$ExistingSections\)') { $contractErrors.Add('Error aggregation must materialize singleton output before Count access.') | Out-Null }
if ($sourceText -notmatch '\$allWarnings\s*=\s*@\(Get-AllSectionWarnings\s+\$sectionSnapshot\)') { $contractErrors.Add('Final warning aggregation must materialize singleton output.') | Out-Null }
if ($sourceText -notmatch '\$allErrors\s*=\s*@\(Get-AllSectionErrors\s+\$sectionSnapshot\)') { $contractErrors.Add('Final error aggregation must materialize singleton output.') | Out-Null }
if ($contractErrors.Count -gt 0) {
    Write-Host 'Source startup-contract errors:' -ForegroundColor Red
    foreach ($contractError in $contractErrors) { Write-Host $contractError -ForegroundColor Red }
    exit 1
}

Write-Host 'Source parser and startup-contract validation passed.' -ForegroundColor Green
exit 0
