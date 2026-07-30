#requires -version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference='Stop'
$root=Split-Path -Parent $PSScriptRoot
. (Join-Path $root 'src\LouisMahdi.SystemInspector.ps1') -LibraryOnly

$script:Passed=0;$script:Failed=0
function Assert-True([bool]$Condition,[string]$Name){if($Condition){Write-Host "PASS  $Name" -ForegroundColor Green;$script:Passed++}else{Write-Host "FAIL  $Name" -ForegroundColor Red;$script:Failed++}}
function Assert-Equal($Expected,$Actual,[string]$Name){Assert-True ([object]::Equals($Expected,$Actual)) "$Name (expected: $Expected, actual: $Actual)"}
function Get-Field($Item,[string]$Name){return @($Item.Fields|Where-Object{$_.DisplayName -eq $Name}|Select-Object -First 1)[0]}

Write-Host 'LouisMahdi System Inspector mock-provider tests' -ForegroundColor Cyan
Write-Host ('='*65)

$productionSourcePath=Join-Path $root 'src\LouisMahdi.SystemInspector.ps1'
$productionSource=[IO.File]::ReadAllText($productionSourcePath,[Text.Encoding]::UTF8)
Assert-True ($productionSource -notmatch '\$form\.Opacity\s*=\s*0(?:\.0+)?') 'GUI never starts fully transparent'
Assert-True ($productionSource -match '\$form\.Opacity\s*=\s*1(?:\.0+)?') 'GUI starts at full opacity'
Assert-True ($productionSource -match '\$form\.ShowInTaskbar\s*=\s*\$true') 'GUI explicitly appears in the taskbar'
Assert-True ($productionSource -match '\$form\.WindowState\s*=\s*''Normal''') 'GUI explicitly starts in the normal window state'
Assert-True ($productionSource -notmatch '\$fadeTimer') 'GUI visibility does not depend on a fade timer'
Assert-True ($productionSource -match '\$env:LOUISMAHDI_ICON_PATH') 'GUI accepts the launcher-provided icon resource path'
Assert-Equal '2.2.0' $script:AppVersion 'Application version matches the release package'
$sectionMaterializationCount=[regex]::Matches($productionSource,'\$sectionSnapshot\s*=\s*\$sections\.ToArray\(\)').Count
Assert-True ($sectionMaterializationCount -ge 3) 'Generic section list is materialized before aggregation and final-model use'
Assert-True ($productionSource -match 'Sections\s*=\s*\$sectionSnapshot') 'Final report model uses the materialized section snapshot'
Assert-True ($productionSource -notmatch 'Sections\s*=\s*@\(\s*\$sections\s*\)') 'Final report model avoids unsafe generic-list array-subexpression conversion'
Assert-True ($productionSource -match 'foreach\(\$section in @\(\$Sections\)\)') 'Typed object-array parameters may use array-subexpression safely'
Assert-True ($productionSource -notmatch 'return\s+@\(\$list\)') 'Generic object-list return values use ToArray'

$field=New-InventoryField -DisplayName 'Missing' -RawValue $null -NormalizedValue $null -Source 'Mock' -SourceProperty 'Value'
Assert-True (-not [string]::IsNullOrWhiteSpace($field.DisplayValue)) 'Missing field never displays a blank value'
Assert-Equal 'NotAvailable' $field.CollectionStatus 'Missing field receives explicit collection status'

$field=New-TextField 'OEM Value' 'To Be Filled By O.E.M.' 'Mock SMBIOS' 'Value'
Assert-Equal 'InvalidValue' $field.CollectionStatus 'OEM placeholder is rejected as invalid data'
Assert-True ($field.RawValue -eq 'To Be Filled By O.E.M.') 'OEM placeholder raw value is preserved'

Assert-Equal 'Lenovo' (Normalize-Manufacturer 'LENOVO') 'Lenovo manufacturer normalization'
Assert-Equal 'ASUS' (Normalize-Manufacturer 'ASUSTeK COMPUTER INC.') 'ASUS manufacturer normalization'
Assert-Equal 'Western Digital' (Normalize-Manufacturer 'WDC') 'Western Digital manufacturer normalization'

$inference=Infer-ManufacturerFromModel 'CT16G4SFRA32A' 'Memory'
Assert-Equal 'Crucial' $inference.Manufacturer 'CT16G4SFRA32A optional Crucial inference'
Assert-Equal 'High' $inference.Confidence 'Crucial part-number inference confidence'

$mockModules=@(
    [pscustomobject]@{DeviceLocator='DIMM 0';BankLabel='P0 CHANNEL A';Tag='Physical Memory 0';Manufacturer='';PartNumber='CT8G4SFRA32A';SerialNumber='A1';Capacity=[uint64]8GB;ConfiguredClockSpeed=3200;Speed=3200;SMBIOSMemoryType=26;FormFactor=12;DataWidth=64;TotalWidth=64;ConfiguredVoltage=1200;MinVoltage=1200;MaxVoltage=1200;Replaceable=$true},
    [pscustomobject]@{DeviceLocator='DIMM 0';BankLabel='P0 CHANNEL B';Tag='Physical Memory 1';Manufacturer='';PartNumber='CT16G4SFRA32A';SerialNumber='B2';Capacity=[uint64]16GB;ConfiguredClockSpeed=3200;Speed=3200;SMBIOSMemoryType=26;FormFactor=12;DataWidth=64;TotalWidth=64;ConfiguredVoltage=1200;MinVoltage=1200;MaxVoltage=1200;Replaceable=$true}
)
$moduleItems=Convert-RawMemoryModules $mockModules
Assert-Equal 2 $moduleItems.Count 'Both RAM modules are preserved'
Assert-Equal 'DIMM 0' (Get-Field $moduleItems[0] 'Device Locator').DisplayValue 'First duplicate DeviceLocator preserved'
Assert-Equal 'DIMM 0' (Get-Field $moduleItems[1] 'Device Locator').DisplayValue 'Second duplicate DeviceLocator preserved'
Assert-Equal '1' (Get-Field $moduleItems[0] 'Report Index').DisplayValue 'First RAM module gets unique report index'
Assert-Equal '2' (Get-Field $moduleItems[1] 'Report Index').DisplayValue 'Second RAM module gets unique report index'
Assert-Equal 'P0 CHANNEL A' (Get-Field $moduleItems[0] 'Bank Label').DisplayValue 'First BankLabel remains separate'
Assert-Equal 'P0 CHANNEL B' (Get-Field $moduleItems[1] 'Bank Label').DisplayValue 'Second BankLabel remains separate'
Assert-True (-not (@($moduleItems[0].Fields.DisplayName) -contains 'Channel Mode')) 'RAM channel mode is not guessed'
Assert-Equal 'Crucial' (Get-Field $moduleItems[1] 'Inferred Manufacturer').DisplayValue 'Missing RAM manufacturer is inferred separately'
Assert-Equal 'NotAvailable' (Get-Field $moduleItems[1] 'Reported Manufacturer').CollectionStatus 'Missing reported RAM manufacturer stays unavailable'


$storageInference=Infer-ManufacturerFromModel 'WDC WD10SPZX-00Z10T0' 'Storage'
Assert-Equal 'Western Digital' $storageInference.Manufacturer 'Western Digital storage inference stays separate from reported manufacturer'
Assert-Equal 'Model-prefix database' $storageInference.InferenceSource 'Storage inference uses a safe default source when optional Note metadata is absent'
$samsungInference=Infer-ManufacturerFromModel 'SAMSUNG MZVLQ512HALU-00000' 'Storage'
Assert-Equal 'Samsung' $samsungInference.Manufacturer 'Samsung storage inference rule'
Assert-Equal 'SSD' (Infer-StorageMediaType 'Example NVMe SSD' 'NVMe').MediaType 'NVMe model fallback may infer SSD explicitly'
Assert-True ($null -eq (Infer-StorageMediaType 'Generic Fixed Disk Device' 'SATA')) 'Arbitrary fixed disk is not guessed as HDD or SSD'

$physicalClass=Get-NetworkClassification ([pscustomobject]@{Name='Ethernet';InterfaceDescription='Example PCIe Controller';HardwareInterface=$true})
Assert-Equal 'Physical' $physicalClass.Category 'Hardware network adapter classified as physical'
$pdanetClass=Get-NetworkClassification ([pscustomobject]@{Name='PdaNet Broadband';InterfaceDescription='PdaNet Adapter';HardwareInterface=$false})
Assert-Equal 'Virtual' $pdanetClass.Category 'PdaNet is recognized as a virtual software adapter'

$notZero=New-NumericField 'Unsupported Counter' $null 'hours' 'Mock' 'Counter'
Assert-Equal 'NotAvailable' $notZero.CollectionStatus 'Unsupported numeric data does not become zero'
Assert-True ($notZero.DisplayValue -ne '0 hours') 'Unavailable numeric value is never displayed as zero'

$veryLarge=[uint64]9223372036854775808
Assert-Equal $veryLarge (Convert-ToUInt64Safe $veryLarge) '64-bit unsigned capacity values are preserved'

$speed=Get-NetworkLinkSpeedResult '1 Gbps' $null 'Up'
Assert-Equal 'Available' $speed.Status 'Connected network speed is available'
Assert-Equal ([uint64]1000000000) $speed.BitsPerSecond '1 Gbps is normalized once to bits per second'
Assert-Equal '1 Gbps' $speed.Display '1 Gbps presentation remains correct'

$overflow=Get-NetworkLinkSpeedResult ([uint64]8796093022208000000) $null 'Up'
Assert-Equal 'InvalidValue' $overflow.Status 'Impossible network speed is rejected'
Assert-True ($overflow.Display -notmatch '8796093022208 Mbps') 'Impossible Mbps output is never displayed'

$down=Get-NetworkLinkSpeedResult ([uint64]1000000000) $null 'Disconnected'
Assert-Equal 'Disconnected' $down.Status 'Disconnected adapter has distinct status'
Assert-True ($down.Display -match 'disconnected') 'Disconnected adapter explains why speed is absent'

$connectedWord=Get-NetworkLinkSpeedResult '1 Gbps' $null 'Connected'
Assert-Equal 'Available' $connectedWord.Status 'Connected status is not misclassified as disconnected'
$notPresent=Get-NetworkLinkSpeedResult ([uint64]1000000000) $null 'Not Present'
Assert-Equal 'Disconnected' $notPresent.Status 'Not Present adapter state is classified as disconnected'

$mockErrorA=New-SectionError 'Mock A' 'Mock Source' 'QueryFailed' 'A' 'MockException' 1 1
$mockErrorB=New-SectionError 'Mock B' 'Mock Source' 'QueryFailed' 'B' 'MockException' 2 1
$mockErrorSections=@(
    New-InventorySection 'Mock A' @() @() @($mockErrorA) 1 'QueryFailed'
    New-InventorySection 'Mock B' @() @() @($mockErrorB) 1 'QueryFailed'
)
$materializedErrors=Get-AllSectionErrors $mockErrorSections
Assert-Equal 2 (@($materializedErrors).Count) 'Generic object-list errors materialize without argument-type binding failure'
Assert-Equal 'Mock A' (@($materializedErrors)[0].Section) 'Materialized error order is preserved'

$singleWarningSection=New-InventorySection 'Single Warning' @(New-InventoryItem -Title 'Item' -Fields @(New-TextField 'Value' 'Available' 'Mock' 'Value') -Warnings @('Exactly one warning')) @('Exactly one warning') @() 1 'Available'
$singleWarningAggregate=@(Get-AllSectionWarnings @($singleWarningSection))
Assert-Equal 1 $singleWarningAggregate.Count 'Exactly one warning remains an array at the aggregation boundary'
$singleWarningOutput=Collect-WarningsSection @($singleWarningSection)
Assert-True ($null -ne $singleWarningOutput) 'Warnings section accepts exactly one warning under StrictMode'
$singleError=New-SectionError 'Single Error' 'Mock Source' 'QueryFailed' 'Exactly one error' 'MockException' 3 1
$singleErrorSection=New-InventorySection 'Single Error' @() @() @($singleError) 1 'QueryFailed'
$singleErrorAggregate=@(Get-AllSectionErrors @($singleErrorSection))
Assert-Equal 1 $singleErrorAggregate.Count 'Exactly one error remains an array at the aggregation boundary'
$metadataStart=(Get-Date).AddSeconds(-1);$metadataEnd=Get-Date;$metadataWithSingletons=Collect-MetadataSection $metadataStart $metadataEnd @($singleWarningSection,$singleErrorSection)
Assert-True ($null -ne $metadataWithSingletons) 'Metadata collection accepts singleton warning and error results under StrictMode'

$health=Get-BatteryHealthResult 50000 40000
Assert-Equal 'Available' $health.Status 'Battery health calculated from capacity data'
Assert-Equal 80.0 $health.Percentage 'Battery health formula is correct'
$missingHealth=Get-BatteryHealthResult $null 40000
Assert-Equal 'NotAvailable' $missingHealth.Status 'Missing design capacity is not converted to zero health'
$overHealth=Get-BatteryHealthResult 50000 60000
Assert-True (-not [string]::IsNullOrWhiteSpace($overHealth.Warning)) 'Full-charge capacity above design capacity generates warning instead of clamping'

Assert-Equal '256.00 GB' (Format-BytesDecimal ([uint64]256000000000)) 'Decimal manufacturer capacity label'
Assert-Equal '238.42 GiB' (Format-BytesBinary ([uint64]256000000000)) 'Binary Windows capacity label'

$privacyOld=$script:PrivacyMode;$script:PrivacyMode=$true
$sensitive=New-TextField 'Serial Number' 'ABC123' 'Mock' 'Serial' $true
Assert-Equal 'Redacted' $sensitive.CollectionStatus 'Privacy mode redacts sensitive values'
Assert-Equal '[REDACTED]' $sensitive.RawValue 'Sensitive raw value is omitted from privacy-mode JSON model'
$script:PrivacyMode=$privacyOld

$speedField=New-InventoryField 'Negotiated Link Speed' $speed.BitsPerSecond $speed.BitsPerSecond 'bits per second' $speed.Source 'LinkSpeed' $speed.Status 'High' '' $false $false $speed.Display
$mockSection=New-InventorySection 'Mock Section' @(New-InventoryItem -Title 'Mock Item' -Fields @($field,$speedField)) @() @() 1 'Available'
$mockInventory=[pscustomobject][ordered]@{SchemaVersion=$script:SchemaVersion;Application=[pscustomobject]@{Name=$script:AppName;Version=$script:AppVersion;Credit=$script:BrandLine;GitHub=$script:GitHubUrl};Metadata=[pscustomobject]@{LocalCollectionTime=(Get-Date).ToString('o');ReportMode='Standard';PrivacyMode=$true};Privacy=[pscustomobject]@{Enabled=$true};SourcePriority=$script:SourcePriority;Sections=@($mockSection);Warnings=@();Errors=@()}
$temp=Join-Path ([IO.Path]::GetTempPath()) ('LouisMahdi_Test_'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $temp|Out-Null
try{
    $json=Join-Path $temp 'sample.json';$txt=Join-Path $temp 'sample.txt'
    Write-JsonReport $mockInventory $json;Write-TextReport $mockInventory $txt
    $parsed=Get-Content $json -Raw|ConvertFrom-Json
    Assert-Equal $script:SchemaVersion $parsed.SchemaVersion 'JSON uses stable schema version'
    $blankFields=@($mockInventory.Sections|ForEach-Object{$_.Items}|ForEach-Object{$_.Fields}|Where-Object{[string]::IsNullOrWhiteSpace([string]$_.DisplayValue)})
    Assert-Equal 0 $blankFields.Count 'Machine-readable model contains no blank display fields'
    Assert-True ((Get-Content $txt -Raw) -match 'Developed by LouisMahdi') 'TXT report contains professional footer'
    Assert-True ((Get-Content $txt -Raw) -match 'github.com/TheLouisMahdi') 'TXT report contains GitHub profile'
}finally{Remove-Item $temp -Recurse -Force -ErrorAction SilentlyContinue}

Write-Host ('='*65)
Write-Host "Passed: $script:Passed  Failed: $script:Failed" -ForegroundColor $(if($script:Failed -eq 0){'Green'}else{'Red'})
if($script:Failed -gt 0){exit 1}
