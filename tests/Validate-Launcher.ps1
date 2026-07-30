#requires -version 5.1
[CmdletBinding()]
param(
    [string]$LauncherPath,
    [string]$BuilderPath
)

$ErrorActionPreference='Stop'
$scriptDirectory=$PSScriptRoot
if([string]::IsNullOrWhiteSpace($scriptDirectory)){$scriptDirectory=Split-Path -Parent $MyInvocation.MyCommand.Path}
$projectRoot=Split-Path -Parent $scriptDirectory
if([string]::IsNullOrWhiteSpace($LauncherPath)){$LauncherPath=Join-Path $projectRoot 'docs\LouisMahdiHost.cs'}
if([string]::IsNullOrWhiteSpace($BuilderPath)){$BuilderPath=Join-Path $projectRoot 'Build_LouisMahdi_System_Inspector_ONE_FILE.bat'}
if(-not (Test-Path -LiteralPath $LauncherPath -PathType Leaf)){Write-Host ("Launcher source was not found: {0}" -f $LauncherPath) -ForegroundColor Red;exit 1}
$text=[IO.File]::ReadAllText((Resolve-Path -LiteralPath $LauncherPath).Path,[Text.Encoding]::UTF8)
$errors=New-Object 'System.Collections.Generic.List[string]'
if($text -notmatch 'GetManifestResourceStream\(resourceName\)'){$errors.Add('The launcher must load the application source from a managed resource.')|Out-Null}
if($text -notmatch 'LouisMahdi\.SystemInspector\.Source'){$errors.Add('The launcher source resource name is missing.')|Out-Null}
if($text -notmatch 'SHA256\.Create\(\)'){$errors.Add('The launcher source-integrity check is missing.')|Out-Null}
if($text -notmatch 'ExpectedSourceSha256\s*=\s*"__SOURCE_SHA256__"'){$errors.Add('The launcher source-hash placeholder is missing.')|Out-Null}
if($text -match 'FromBase64String|ToBase64String'){$errors.Add('The distributed EXE launcher must not decode the application from Base64 at runtime.')|Out-Null}
if($text -match 'System\.Management\.Automation'){$errors.Add('The launcher must not bind to an in-process PowerShell automation assembly.')|Out-Null}
if($text -notmatch 'WindowsPowerShell.*v1\.0.*powershell\.exe'){$errors.Add('The Windows PowerShell discovery contract is missing.')|Out-Null}
if($text -notmatch 'values\.Add\("-STA"\)'){$errors.Add('The launcher must start Windows PowerShell in STA mode.')|Out-Null}
if($text -notmatch 'values\.Add\("-File"\)'){$errors.Add('The launcher must invoke the embedded application through a temporary script file.')|Out-Null}
if($text -notmatch 'CreateNoWindow\s*=\s*true'){$errors.Add('The launcher must suppress the PowerShell console window.')|Out-Null}
if($text -notmatch '--launcher-self-test'){$errors.Add('The launcher self-test contract is missing.')|Out-Null}
if(Test-Path -LiteralPath $BuilderPath -PathType Leaf){
    $builderText=[IO.File]::ReadAllText((Resolve-Path -LiteralPath $BuilderPath).Path,[Text.Encoding]::UTF8)
    if($builderText -notmatch '/platform:anycpu'){$errors.Add('The builder must compile the launcher as AnyCPU.')|Out-Null}
    if($builderText -notmatch 'LouisMahdi\.SystemInspector\.Source'){$errors.Add('The builder must embed the PowerShell source as a named resource.')|Out-Null}
    if($builderText -notmatch 'LouisMahdi\.SystemInspector\.Icon'){$errors.Add('The builder must embed the icon as a named resource.')|Out-Null}
    if($builderText -notmatch '--launcher-self-test'){$errors.Add('The builder must run the compiled launcher self-test.')|Out-Null}
}
if($errors.Count -gt 0){Write-Host 'Launcher contract errors:' -ForegroundColor Red;foreach($item in $errors){Write-Host $item -ForegroundColor Red};exit 1}
Write-Host 'Launcher resource, integrity, architecture, and startup-contract validation passed.' -ForegroundColor Green
exit 0
