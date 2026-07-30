#requires -version 5.1
[CmdletBinding()]
param(
    [switch]$LibraryOnly,
    [switch]$NoGui,
    [ValidateSet('Standard','Extended')]
    [string]$Mode = 'Standard',
    [switch]$DisablePrivacy,
    [string]$OutputDirectory,
    [switch]$IncludeHtml,
    [switch]$OpenOutput,
    [switch]$RetainDiagnostics
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$script:AppName = 'LouisMahdi System Inspector'
$script:AppVersion = '2.2.0'
$script:SchemaVersion = '2.1'
$script:BrandLine = 'Developed by LouisMahdi'
$script:GitHubUrl = 'https://github.com/TheLouisMahdi'
$script:GitHubLabel = 'github.com/TheLouisMahdi'
$script:BrandSignature = 'Developed by LouisMahdi · github.com/TheLouisMahdi'
$script:PrivacyMode = -not $DisablePrivacy
$script:ReportMode = $Mode
$script:RetainDiagnostics = [bool]$RetainDiagnostics
$script:QueryTimeoutSec = 12
$script:ProgressCallback = $null
$script:DeveloperLog = New-Object 'System.Collections.Generic.List[object]'
$script:NativeInteropLoaded = $false
$script:LastOutput = $null

$script:CollectionStates = @(
    'Available','NotAvailable','NotSupported','PermissionDenied','QueryFailed',
    'InvalidValue','NotApplicable','Disconnected','VendorToolUnavailable','Redacted'
)

$script:PlaceholderValues = @(
    'to be filled by o.e.m.','to be filled by oem','default string',
    'system product name','not applicable','not specified','unknown','none',
    '00000000','invalid','n/a','na','null','undefined'
)

$script:ManufacturerNormalization = [ordered]@{
    'LENOVO' = 'Lenovo'
    'ASUSTeK COMPUTER INC.' = 'ASUS'
    'ASUS' = 'ASUS'
    'Micro-Star International Co., Ltd.' = 'MSI'
    'Micro-Star International Co.,Ltd.' = 'MSI'
    'MSI' = 'MSI'
    'Hewlett-Packard' = 'HP'
    'HP Inc.' = 'HP'
    'HP' = 'HP'
    'Dell Inc.' = 'Dell'
    'Dell' = 'Dell'
    'WDC' = 'Western Digital'
    'Western Digital Technologies' = 'Western Digital'
    'Western Digital' = 'Western Digital'
    'ATA Samsung' = 'Samsung'
    'SAMSUNG' = 'Samsung'
    'Samsung Electronics' = 'Samsung'
    'INTEL' = 'Intel'
    'Intel Corporation' = 'Intel'
    'Advanced Micro Devices, Inc.' = 'AMD'
    'Advanced Micro Devices, Inc' = 'AMD'
    'AMD' = 'AMD'
    'NVIDIA Corporation' = 'NVIDIA'
    'NVIDIA' = 'NVIDIA'
    'Kingston Technology' = 'Kingston'
    'Kingston' = 'Kingston'
    'Crucial' = 'Crucial'
    'Micron Technology' = 'Micron'
    'Micron' = 'Micron'
    'Seagate' = 'Seagate'
    'Seagate Technology' = 'Seagate'
    'TOSHIBA' = 'Toshiba'
    'SanDisk' = 'SanDisk'
    'SK hynix' = 'SK hynix'
    'Hynix' = 'SK hynix'
    'Realtek' = 'Realtek'
    'Qualcomm' = 'Qualcomm'
    'Broadcom' = 'Broadcom'
}

$script:StorageInferenceRules = @(
    @{ Pattern = '^(WDC|WD\s|Western Digital)'; Manufacturer = 'Western Digital'; Confidence = 'High' },
    @{ Pattern = '^(SAMSUNG|Samsung|MZ[A-Z0-9])'; Manufacturer = 'Samsung'; Confidence = 'High' },
    @{ Pattern = '^(CT[0-9A-Z]+|Crucial)'; Manufacturer = 'Crucial'; Confidence = 'High' },
    @{ Pattern = '^(KINGSTON|Kingston)'; Manufacturer = 'Kingston'; Confidence = 'High' },
    @{ Pattern = '^(ST[0-9]|Seagate)'; Manufacturer = 'Seagate'; Confidence = 'Medium' },
    @{ Pattern = '^(TOSHIBA|KIOXIA)'; Manufacturer = 'Kioxia/Toshiba'; Confidence = 'Medium' },
    @{ Pattern = '^(SKHynix|HFS|HFM|SK hynix)'; Manufacturer = 'SK hynix'; Confidence = 'Medium' },
    @{ Pattern = '^(SanDisk|SDSS|WDS)'; Manufacturer = 'SanDisk/Western Digital'; Confidence = 'Medium' }
)

$script:MemoryInferenceRules = @(
    @{ Pattern = '^CT[0-9A-Z]+$'; Manufacturer = 'Crucial'; Confidence = 'High'; Note = 'Part-number prefix database' },
    @{ Pattern = '^M[0-9A-Z]{8,}$'; Manufacturer = 'Samsung'; Confidence = 'Low'; Note = 'Part-number pattern database' },
    @{ Pattern = '^KVR|^KF[0-9A-Z]'; Manufacturer = 'Kingston'; Confidence = 'Medium'; Note = 'Part-number prefix database' },
    @{ Pattern = '^HMA|^HMC'; Manufacturer = 'SK hynix'; Confidence = 'Medium'; Note = 'Part-number prefix database' }
)

$script:SourcePriority = [ordered]@{
    ComputerIdentity = @('Win32_ComputerSystem','Win32_ComputerSystemProduct','Win32_SystemEnclosure','Win32_BaseBoard')
    Windows = @('CurrentVersion registry','Win32_OperatingSystem','Get-ComputerInfo')
    Processor = @('Win32_Processor','Performance counters when explicitly sampled')
    PhysicalMemory = @('Win32_PhysicalMemory','Win32_PhysicalMemoryArray')
    GpuVram = @('Installed vendor tool','Native display API','Display registry','Win32_VideoController.AdapterRAM','Unavailable')
    Displays = @('Windows display configuration API','WmiMonitorID','WmiMonitorBasicDisplayParams','System.Windows.Forms.Screen')
    Firmware = @('GetFirmwareType API','PEFirmwareType registry','Win32_BIOS')
    SecureBoot = @('Confirm-SecureBootUEFI','Independent firmware mode')
    Tpm = @('Get-Tpm','Win32_Tpm')
    PhysicalStorage = @('Get-PhysicalDisk','Get-Disk','Win32_DiskDrive','PnP information','Model inference')
    StorageHealth = @('Get-StorageReliabilityCounter','Storage HealthStatus','OperationalStatus','WMI SMART prediction')
    Battery = @('powercfg batteryreport XML','WMI battery classes','Win32_Battery')
    Network = @('Get-NetAdapter','Win32_NetworkAdapter','Win32_PnPSignedDriver')
}

function Get-StatusDisplayText {
    param([string]$Status, [string]$ErrorMessage)
    switch ($Status) {
        'Available' { return $null }
        'NotAvailable' { return 'Not available' }
        'NotSupported' { return 'Not supported by this device' }
        'PermissionDenied' { return 'Administrator permission required' }
        'QueryFailed' { if ($ErrorMessage) { return "Query failed: $ErrorMessage" }; return 'Query failed' }
        'InvalidValue' { return 'Invalid value reported by provider' }
        'NotApplicable' { return 'Not applicable' }
        'Disconnected' { return 'Adapter disconnected' }
        'VendorToolUnavailable' { return 'Vendor tool unavailable' }
        'Redacted' { return 'Redacted by privacy mode' }
        default { return 'Not available' }
    }
}

function Test-IsPlaceholder {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return $true }
    $text = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $true }
    return $script:PlaceholderValues -contains $text.ToLowerInvariant()
}

function Get-ExceptionStatus {
    param([System.Exception]$Exception)
    if ($null -eq $Exception) { return 'QueryFailed' }
    $name = $Exception.GetType().FullName
    $message = [string]$Exception.Message
    if ($Exception -is [System.UnauthorizedAccessException] -or $message -match 'access.*denied|permission|privilege') {
        return 'PermissionDenied'
    }
    if ($name -match 'CommandNotFoundException|TypeLoadException' -or $message -match 'not recognized|not found|unsupported|not supported') {
        return 'NotSupported'
    }
    return 'QueryFailed'
}

function Get-SanitizedErrorMessage {
    param([AllowNull()][object]$ErrorRecord)
    if ($null -eq $ErrorRecord) { return '' }
    $message = ''
    try { $message = [string]$ErrorRecord.Exception.Message } catch { $message = [string]$ErrorRecord }
    if ([string]::IsNullOrWhiteSpace($message)) { return 'Unspecified provider error' }
    $message = $message -replace [regex]::Escape($env:USERPROFILE), '%USERPROFILE%'
    $message = $message -replace '[\r\n]+', ' '
    if ($message.Length -gt 240) { $message = $message.Substring(0,240) + '...' }
    return $message.Trim()
}

function Write-DeveloperLog {
    param(
        [string]$Level,
        [string]$Section,
        [string]$Source,
        [string]$Message,
        [AllowNull()][object]$Exception,
        [long]$DurationMs = 0,
        [bool]$FallbackAttempted = $false,
        [string]$FallbackResult = ''
    )
    $exceptionType = ''
    $hresult = $null
    $stack = ''
    if ($Exception) {
        try {
            $exceptionType = $Exception.GetType().FullName
            $hresult = $Exception.HResult
            if ($script:RetainDiagnostics) { $stack = [string]$Exception.StackTrace }
        } catch {}
    }
    $entry = [pscustomobject][ordered]@{
        TimestampUtc = [datetime]::UtcNow.ToString('o',[Globalization.CultureInfo]::InvariantCulture)
        Level = $Level
        Section = $Section
        Source = $Source
        Message = $Message
        ExceptionType = $exceptionType
        HResult = $hresult
        QueryDurationMs = $DurationMs
        FallbackAttempted = $FallbackAttempted
        FallbackResult = $FallbackResult
        StackTrace = $stack
    }
    $script:DeveloperLog.Add($entry) | Out-Null
}

function Invoke-SafeQuery {
    param(
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][scriptblock]$ScriptBlock,
        [bool]$FallbackAttempted = $false
    )
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $items = @(& $ScriptBlock)
        $sw.Stop()
        return [pscustomobject][ordered]@{
            Items = $items
            Status = 'Available'
            ErrorMessage = ''
            ExceptionType = ''
            HResult = $null
            DurationMs = [long]$sw.ElapsedMilliseconds
            Source = $Source
        }
    } catch {
        $sw.Stop()
        $status = Get-ExceptionStatus $_.Exception
        $message = Get-SanitizedErrorMessage $_
        Write-DeveloperLog -Level 'Error' -Section $Section -Source $Source -Message $message -Exception $_.Exception -DurationMs $sw.ElapsedMilliseconds -FallbackAttempted $FallbackAttempted
        return [pscustomobject][ordered]@{
            Items = @()
            Status = $status
            ErrorMessage = $message
            ExceptionType = $_.Exception.GetType().FullName
            HResult = $_.Exception.HResult
            DurationMs = [long]$sw.ElapsedMilliseconds
            Source = $Source
        }
    }
}

function Invoke-CimQuery {
    param(
        [Parameter(Mandatory)][string]$Section,
        [Parameter(Mandatory)][string]$ClassName,
        [string]$Namespace = 'root/cimv2',
        [string]$Filter,
        [string[]]$Property
    )
    $source = if ($Namespace -eq 'root/cimv2') { $ClassName } else { "$Namespace\$ClassName" }
    return Invoke-SafeQuery -Section $Section -Source $source -ScriptBlock {
        $params = @{
            Namespace = $Namespace
            ClassName = $ClassName
            ErrorAction = 'Stop'
        }
        if ($Filter) { $params.Filter = $Filter }
        if ($Property) { $params.Property = $Property }
        try {
            $params.OperationTimeoutSec = $script:QueryTimeoutSec
            Get-CimInstance @params
        } catch [System.Management.Automation.ParameterBindingException] {
            $params.Remove('OperationTimeoutSec')
            Get-CimInstance @params
        }
    }
}

function New-InventoryField {
    param(
        [Parameter(Mandatory)][string]$DisplayName,
        [AllowNull()][object]$RawValue,
        [AllowNull()][object]$NormalizedValue,
        [string]$Unit = '',
        [string]$Source = '',
        [string]$SourceProperty = '',
        [string]$CollectionStatus = 'Available',
        [ValidateSet('High','Medium','Low','Unknown')]
        [string]$Confidence = 'High',
        [string]$ErrorMessage = '',
        [bool]$IsSensitive = $false,
        [bool]$IsInferred = $false,
        [AllowNull()][object]$DisplayValue,
        [bool]$Redacted = $false
    )
    if ($script:CollectionStates -notcontains $CollectionStatus) { $CollectionStatus = 'QueryFailed' }

    if ($IsSensitive -and $script:PrivacyMode) {
        $RawValue = '[REDACTED]'
        $NormalizedValue = '[REDACTED]'
        $DisplayValue = 'Redacted by privacy mode'
        $CollectionStatus = 'Redacted'
        $Redacted = $true
    }

    if ($CollectionStatus -eq 'Available') {
        if ($null -eq $NormalizedValue -or ([string]$NormalizedValue).Trim().Length -eq 0) {
            $CollectionStatus = 'NotAvailable'
        }
    }

    if ($null -eq $DisplayValue -or ([string]$DisplayValue).Trim().Length -eq 0) {
        if ($CollectionStatus -eq 'Available') {
            $DisplayValue = [string]$NormalizedValue
            if ($Unit -and $DisplayValue -notmatch [regex]::Escape($Unit) + '$') {
                $DisplayValue = "$DisplayValue $Unit"
            }
        } else {
            $DisplayValue = Get-StatusDisplayText -Status $CollectionStatus -ErrorMessage $ErrorMessage
        }
    }

    if ([string]::IsNullOrWhiteSpace([string]$DisplayValue)) { $DisplayValue = 'Not available' }
    if ([string]::IsNullOrWhiteSpace($Source)) { $Source = 'Not specified' }
    if ([string]::IsNullOrWhiteSpace($SourceProperty)) { $SourceProperty = 'Not specified' }

    return [pscustomobject][ordered]@{
        DisplayName = $DisplayName
        RawValue = $RawValue
        NormalizedValue = $NormalizedValue
        Unit = $Unit
        Source = $Source
        SourceProperty = $SourceProperty
        CollectionStatus = $CollectionStatus
        Confidence = $Confidence
        ErrorMessage = $ErrorMessage
        IsSensitive = $IsSensitive
        IsInferred = $IsInferred
        IsRedacted = $Redacted
        DisplayValue = [string]$DisplayValue
    }
}

function New-TextField {
    param(
        [string]$DisplayName,
        [AllowNull()][object]$Value,
        [string]$Source,
        [string]$SourceProperty,
        [bool]$Sensitive = $false,
        [bool]$NormalizeManufacturer = $false,
        [string]$FallbackStatus = 'NotAvailable'
    )
    if (Test-IsPlaceholder $Value) {
        $raw = if ($null -eq $Value) { $null } else { [string]$Value }
        $status = if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) { $FallbackStatus } else { 'InvalidValue' }
        return New-InventoryField -DisplayName $DisplayName -RawValue $raw -NormalizedValue $null -Source $Source -SourceProperty $SourceProperty -CollectionStatus $status -Confidence 'High' -IsSensitive $Sensitive
    }
    $rawText = ([string]$Value).Trim()
    $normalized = if ($NormalizeManufacturer) { Normalize-Manufacturer $rawText } else { $rawText }
    return New-InventoryField -DisplayName $DisplayName -RawValue $rawText -NormalizedValue $normalized -Source $Source -SourceProperty $SourceProperty -IsSensitive $Sensitive
}

function New-NumericField {
    param(
        [string]$DisplayName,
        [AllowNull()][object]$Value,
        [string]$Unit,
        [string]$Source,
        [string]$SourceProperty,
        [double]$Minimum = [double]::NegativeInfinity,
        [double]$Maximum = [double]::PositiveInfinity,
        [string]$Format = '0.##',
        [bool]$Sensitive = $false
    )
    if ($null -eq $Value) {
        return New-InventoryField -DisplayName $DisplayName -RawValue $null -NormalizedValue $null -Unit $Unit -Source $Source -SourceProperty $SourceProperty -CollectionStatus 'NotAvailable' -IsSensitive $Sensitive
    }
    try {
        $number = [double]$Value
        if ([double]::IsNaN($number) -or [double]::IsInfinity($number) -or $number -lt $Minimum -or $number -gt $Maximum) {
            return New-InventoryField -DisplayName $DisplayName -RawValue $Value -NormalizedValue $null -Unit $Unit -Source $Source -SourceProperty $SourceProperty -CollectionStatus 'InvalidValue' -Confidence 'High' -IsSensitive $Sensitive
        }
        $display = $number.ToString($Format,[Globalization.CultureInfo]::InvariantCulture)
        if ($Unit) { $display = "$display $Unit" }
        return New-InventoryField -DisplayName $DisplayName -RawValue $Value -NormalizedValue $number -Unit $Unit -Source $Source -SourceProperty $SourceProperty -DisplayValue $display -IsSensitive $Sensitive
    } catch {
        return New-InventoryField -DisplayName $DisplayName -RawValue $Value -NormalizedValue $null -Unit $Unit -Source $Source -SourceProperty $SourceProperty -CollectionStatus 'InvalidValue' -ErrorMessage (Get-SanitizedErrorMessage $_) -IsSensitive $Sensitive
    }
}

function New-InventoryItem {
    param([string]$Title, [int]$Index = 0, [object[]]$Fields = @(), [string[]]$Warnings = @())
    return [pscustomobject][ordered]@{
        Title = $(if ([string]::IsNullOrWhiteSpace($Title)) { 'Item' } else { $Title })
        Index = $Index
        Fields = @($Fields)
        Warnings = @($Warnings)
    }
}

function New-InventorySection {
    param(
        [string]$Name,
        [object[]]$Items = @(),
        [string[]]$Warnings = @(),
        [object[]]$Errors = @(),
        [long]$DurationMs = 0,
        [string]$Status = 'Available'
    )
    if (@($Items).Count -eq 0 -and $Status -eq 'Available') { $Status = 'NotAvailable' }
    return [pscustomobject][ordered]@{
        Name = $Name
        Status = $Status
        DurationMs = $DurationMs
        Items = @($Items)
        Warnings = @($Warnings)
        Errors = @($Errors)
    }
}

function New-SectionError {
    param([string]$Section,[string]$Source,[string]$Status,[string]$Message,[string]$ExceptionType,[AllowNull()][object]$HResult,[long]$DurationMs,[bool]$FallbackAttempted=$false,[string]$FallbackResult='')
    return [pscustomobject][ordered]@{
        Section = $Section
        Source = $Source
        Status = $Status
        ExceptionType = $ExceptionType
        Message = $(if ($Message) { $Message } else { Get-StatusDisplayText $Status '' })
        HResult = $HResult
        AdministratorMayResolve = ($Status -eq 'PermissionDenied')
        QueryDurationMs = $DurationMs
        FallbackAttempted = $FallbackAttempted
        FallbackResult = $FallbackResult
    }
}

function Convert-ToUInt64Safe {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return $null }
    try {
        if ($Value -is [uint64]) { return [uint64]$Value }
        if ($Value -is [int32] -and [int32]$Value -lt 0) { return [uint64][uint32][int32]$Value }
        $decimal = [decimal]::Parse(([string]$Value),[Globalization.NumberStyles]::Any,[Globalization.CultureInfo]::InvariantCulture)
        if ($decimal -lt 0 -or $decimal -gt [uint64]::MaxValue) { return $null }
        return [uint64]$decimal
    } catch { return $null }
}

function Format-BytesBinary {
    param([AllowNull()][object]$Bytes, [int]$Decimals = 2)
    $value = Convert-ToUInt64Safe $Bytes
    if ($null -eq $value) { return 'Not available' }
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $KiB = [double]1024
    $MiB = $KiB * 1024
    $GiB = $MiB * 1024
    $TiB = $GiB * 1024
    $PiB = $TiB * 1024
    if ($value -ge $PiB) { return (([double]$value / $PiB).ToString("F$Decimals",$culture) + ' PiB') }
    if ($value -ge $TiB) { return (([double]$value / $TiB).ToString("F$Decimals",$culture) + ' TiB') }
    if ($value -ge $GiB) { return (([double]$value / $GiB).ToString("F$Decimals",$culture) + ' GiB') }
    if ($value -ge $MiB) { return (([double]$value / $MiB).ToString("F$Decimals",$culture) + ' MiB') }
    if ($value -ge $KiB) { return (([double]$value / $KiB).ToString("F$Decimals",$culture) + ' KiB') }
    return ($value.ToString('N0',$culture) + ' bytes')
}

function Format-BytesDecimal {
    param([AllowNull()][object]$Bytes, [int]$Decimals = 2)
    $value = Convert-ToUInt64Safe $Bytes
    if ($null -eq $value) { return 'Not available' }
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $KB = [decimal]1000
    $MB = [decimal]1000000
    $GB = [decimal]1000000000
    $TB = [decimal]1000000000000
    $PB = [decimal]1000000000000000
    $d = [decimal]$value
    if ($d -ge $PB) { return (($d / $PB).ToString("F$Decimals",$culture) + ' PB') }
    if ($d -ge $TB) { return (($d / $TB).ToString("F$Decimals",$culture) + ' TB') }
    if ($d -ge $GB) { return (($d / $GB).ToString("F$Decimals",$culture) + ' GB') }
    if ($d -ge $MB) { return (($d / $MB).ToString("F$Decimals",$culture) + ' MB') }
    if ($d -ge $KB) { return (($d / $KB).ToString("F$Decimals",$culture) + ' kB') }
    return ($value.ToString('N0',$culture) + ' bytes')
}

function New-ByteCapacityField {
    param([string]$DisplayName,[AllowNull()][object]$Bytes,[string]$Source,[string]$SourceProperty,[ValidateSet('Binary','Decimal','Both')][string]$DisplayMode='Binary',[bool]$Sensitive=$false)
    $u = Convert-ToUInt64Safe $Bytes
    if ($null -eq $u -or $u -eq 0) {
        $status = if ($null -eq $Bytes) { 'NotAvailable' } else { 'InvalidValue' }
        return New-InventoryField -DisplayName $DisplayName -RawValue $Bytes -NormalizedValue $null -Unit 'bytes' -Source $Source -SourceProperty $SourceProperty -CollectionStatus $status -IsSensitive $Sensitive
    }
    $display = switch ($DisplayMode) {
        'Decimal' { Format-BytesDecimal $u }
        'Both' { "$(Format-BytesDecimal $u) / $(Format-BytesBinary $u)" }
        default { Format-BytesBinary $u }
    }
    return New-InventoryField -DisplayName $DisplayName -RawValue $u -NormalizedValue $u -Unit 'bytes' -Source $Source -SourceProperty $SourceProperty -DisplayValue $display -IsSensitive $Sensitive
}

function Test-PercentageValue {
    param([AllowNull()][object]$Value,[double]$Minimum=0,[double]$Maximum=100)
    if ($null -eq $Value) { return $false }
    try {
        $n = [double]$Value
        return (-not [double]::IsNaN($n)) -and (-not [double]::IsInfinity($n)) -and $n -ge $Minimum -and $n -le $Maximum
    } catch { return $false }
}

function Normalize-Manufacturer {
    param([AllowNull()][object]$Value)
    if (Test-IsPlaceholder $Value) { return $null }
    $text = ([string]$Value).Trim()
    foreach ($key in $script:ManufacturerNormalization.Keys) {
        if ($text.Equals([string]$key,[StringComparison]::OrdinalIgnoreCase)) { return $script:ManufacturerNormalization[$key] }
    }
    return $text
}

function Infer-ManufacturerFromModel {
    param([AllowNull()][object]$Model,[ValidateSet('Storage','Memory')][string]$Category)
    if (Test-IsPlaceholder $Model) { return $null }
    $text = ([string]$Model).Trim()
    $rules = if ($Category -eq 'Memory') { $script:MemoryInferenceRules } else { $script:StorageInferenceRules }
    foreach ($rule in $rules) {
        $pattern = Get-PropertyValue $rule 'Pattern'
        $manufacturer = Get-PropertyValue $rule 'Manufacturer'
        $confidence = Get-PropertyValue $rule 'Confidence'
        $note = Get-PropertyValue $rule 'Note'
        if ([string]::IsNullOrWhiteSpace([string]$pattern) -or [string]::IsNullOrWhiteSpace([string]$manufacturer)) { continue }
        if ($text -match [string]$pattern) {
            if ([string]::IsNullOrWhiteSpace([string]$confidence)) { $confidence = 'Unknown' }
            if ([string]::IsNullOrWhiteSpace([string]$note)) { $note = 'Model-prefix database' }
            return [pscustomobject][ordered]@{
                Manufacturer = [string]$manufacturer
                Confidence = [string]$confidence
                InferenceSource = [string]$note
                Pattern = [string]$pattern
            }
        }
    }
    return $null
}

function Infer-StorageMediaType {
    param([AllowNull()][object]$Model,[AllowNull()][object]$BusType)
    if (Test-IsPlaceholder $Model) { return $null }
    $text = (([string]$Model)+' '+([string]$BusType)).Trim()
    if ($text -match '(?i)\bNVMe\b|\bSSD\b|Solid[ -]?State') {
        return [pscustomobject]@{ MediaType='SSD'; Confidence='High'; Source='Model-string inference rule' }
    }
    if ($text -match '(?i)\beMMC\b|Embedded MultiMediaCard') {
        return [pscustomobject]@{ MediaType='eMMC'; Confidence='High'; Source='Model-string inference rule' }
    }
    if ($text -match '(?i)\bHDD\b|Hard[ -]?Disk|Rotational') {
        return [pscustomobject]@{ MediaType='HDD'; Confidence='Medium'; Source='Model-string inference rule' }
    }
    return $null
}

function Convert-WmiDateSafe {
    param([AllowNull()][object]$Value,[switch]$DateOnly)
    if ($null -eq $Value) { return $null }
    try {
        $dt = $null
        if ($Value -is [datetime]) { $dt = [datetime]$Value }
        else {
            $text = ([string]$Value).Trim()
            if ($text -match '^\d{14}\.\d{6}[+-]\d{3}$') {
                $dt = [System.Management.ManagementDateTimeConverter]::ToDateTime($text)
            } else {
                $dt = [datetime]::Parse($text,[Globalization.CultureInfo]::InvariantCulture)
            }
        }
        if ($dt.Year -lt 1980 -or $dt -gt (Get-Date).AddYears(2)) { return $null }
        if ($DateOnly) { return $dt.ToString('yyyy-MM-dd',[Globalization.CultureInfo]::InvariantCulture) }
        return $dt.ToString('yyyy-MM-ddTHH:mm:ssK',[Globalization.CultureInfo]::InvariantCulture)
    } catch { return $null }
}

function Get-AdminStatus {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch { return $false }
}

function Get-ProcessArchitecture {
    try { return [Runtime.InteropServices.RuntimeInformation]::ProcessArchitecture.ToString() } catch {
        if ([Environment]::Is64BitProcess) { return 'X64' }
        return 'X86'
    }
}

function Get-OsArchitecture {
    try { return [Runtime.InteropServices.RuntimeInformation]::OSArchitecture.ToString() } catch {
        if ([Environment]::Is64BitOperatingSystem) { return 'X64' }
        return 'X86'
    }
}

function Set-InventoryProgressCallback {
    param([AllowNull()][scriptblock]$Callback)
    $script:ProgressCallback = $Callback
}

function Write-InventoryProgress {
    param([int]$Percent,[string]$Section)
    if ($script:ProgressCallback) {
        try { & $script:ProgressCallback $Percent $Section } catch {}
    }
}

function Get-PropertyValue {
    param([AllowNull()][object]$Object,[string]$PropertyName)
    if ($null -eq $Object) { return $null }
    try {
        if ($Object -is [System.Collections.IDictionary]) {
            if ($Object.Contains($PropertyName)) { return $Object[$PropertyName] }
        }
        $p = $Object.PSObject.Properties[$PropertyName]
        if ($p) { return $p.Value }
    } catch {}
    return $null
}

function Get-EnumText {
    param([AllowNull()][object]$Value,[hashtable]$Map,[string]$Prefix='Code')
    if ($null -eq $Value) { return $null }
    try {
        $n = [int]$Value
        if ($Map.ContainsKey($n)) { return $Map[$n] }
        return "$Prefix $n"
    } catch { return [string]$Value }
}

function Get-MemoryTypeName {
    param([AllowNull()][object]$Code)
    $map = @{
        0='Unknown';1='Other';2='DRAM';3='Synchronous DRAM';4='Cache DRAM';5='EDO';6='EDRAM';7='VRAM';8='SRAM';9='RAM';10='ROM';11='Flash';12='EEPROM';13='FEPROM';14='EPROM';15='CDRAM';16='3DRAM';17='SDRAM';18='SGRAM';19='RDRAM';20='DDR';21='DDR2';22='DDR2 FB-DIMM';24='DDR3';25='FBD2';26='DDR4';27='LPDDR';28='LPDDR2';29='LPDDR3';30='LPDDR4';31='Logical non-volatile device';32='HBM';33='HBM2';34='DDR5';35='LPDDR5';36='HBM3'
    }
    return Get-EnumText $Code $map 'SMBIOS type'
}

function Get-MemoryFormFactorName {
    param([AllowNull()][object]$Code)
    $map = @{0='Unknown';1='Other';2='SIP';3='DIP';4='ZIP';5='SOJ';6='Proprietary';7='SIMM';8='DIMM';9='TSOP';10='PGA';11='RIMM';12='SODIMM';13='SRIMM';14='SMD';15='SSMP';16='QFP';17='TQFP';18='SOIC';19='LCC';20='PLCC';21='BGA';22='FPBGA';23='LGA'}
    return Get-EnumText $Code $map 'Form factor'
}

function Get-ProcessorArchitectureName {
    param([AllowNull()][object]$Code)
    $map = @{0='x86';1='MIPS';2='Alpha';3='PowerPC';5='ARM';6='IA64';9='x64';12='ARM64'}
    return Get-EnumText $Code $map 'Architecture'
}

function Get-ChassisTypeName {
    param([AllowNull()][object]$Codes)
    $map = @{1='Other';2='Unknown';3='Desktop';4='Low-profile desktop';5='Pizza box';6='Mini tower';7='Tower';8='Portable';9='Laptop';10='Notebook';11='Handheld';12='Docking station';13='All-in-one';14='Sub-notebook';15='Space-saving';16='Lunch box';17='Main system chassis';18='Expansion chassis';19='Subchassis';20='Bus expansion chassis';21='Peripheral chassis';22='Storage chassis';23='Rack-mount chassis';24='Sealed-case PC';30='Tablet';31='Convertible';32='Detachable';33='IoT gateway';34='Embedded PC';35='Mini PC';36='Stick PC'}
    $result = @()
    foreach ($code in @($Codes)) { $result += (Get-EnumText $code $map 'Chassis type') }
    return ($result -join ', ')
}

function Convert-EdidString {
    param([AllowNull()][object]$Array)
    if ($null -eq $Array) { return $null }
    try {
        $chars = foreach ($n in @($Array)) { if ([int]$n -gt 0) { [char][int]$n } }
        $text = (-join $chars).Trim([char]0).Trim()
        if ([string]::IsNullOrWhiteSpace($text)) { return $null }
        return $text
    } catch { return $null }
}

function Get-BooleanDisplay {
    param([AllowNull()][object]$Value)
    if ($null -eq $Value) { return $null }
    try { if ([bool]$Value) { return 'Yes' } else { return 'No' } } catch { return [string]$Value }
}

function Get-NetworkLinkSpeedResult {
    param(
        [AllowNull()][object]$PreferredValue,
        [AllowNull()][object]$FallbackBitsPerSecond,
        [string]$OperationalStatus
    )
    $statusText = if ($null -eq $OperationalStatus) { '' } else { ([string]$OperationalStatus).Trim() }
    if ($statusText -match '^(?i:Disconnected|Down|Not Present|LowerLayerDown|Dormant|Media Disconnected)$') {
        return [pscustomobject]@{ Status='Disconnected'; BitsPerSecond=$null; Display='Not negotiated - adapter disconnected'; Source='Operational status' }
    }

    $bps = $null
    $source = 'Get-NetAdapter.LinkSpeed'
    if ($null -ne $PreferredValue) {
        if ($PreferredValue -is [byte] -or $PreferredValue -is [int16] -or $PreferredValue -is [int32] -or $PreferredValue -is [int64] -or $PreferredValue -is [uint16] -or $PreferredValue -is [uint32] -or $PreferredValue -is [uint64] -or $PreferredValue -is [double] -or $PreferredValue -is [decimal]) {
            try { $bps = [decimal]$PreferredValue } catch {}
        } else {
            $text = ([string]$PreferredValue).Trim()
            if ($text -match '^([0-9]+(?:\.[0-9]+)?)\s*(Kbps|Mbps|Gbps|Tbps|bps)$') {
                $n = [decimal]::Parse($matches[1],[Globalization.CultureInfo]::InvariantCulture)
                switch ($matches[2]) {
                    'Kbps' { $bps = $n * 1000 }
                    'Mbps' { $bps = $n * 1000000 }
                    'Gbps' { $bps = $n * 1000000000 }
                    'Tbps' { $bps = $n * 1000000000000 }
                    default { $bps = $n }
                }
            }
        }
    }
    if ($null -eq $bps -and $null -ne $FallbackBitsPerSecond) {
        try { $bps = [decimal]$FallbackBitsPerSecond; $source = 'Win32_NetworkAdapter.Speed' } catch {}
    }
    if ($null -eq $bps) {
        return [pscustomobject]@{ Status='NotAvailable'; BitsPerSecond=$null; Display='Not available'; Source=$source }
    }
    if ($bps -le 0 -or $bps -gt 10000000000000) {
        return [pscustomobject]@{ Status='InvalidValue'; BitsPerSecond=$bps; Display='Invalid value reported by provider'; Source=$source }
    }
    $culture = [Globalization.CultureInfo]::InvariantCulture
    $display = if ($bps -ge 1000000000000) { (($bps/1000000000000).ToString('0.##',$culture) + ' Tbps') }
        elseif ($bps -ge 1000000000) { (($bps/1000000000).ToString('0.##',$culture) + ' Gbps') }
        elseif ($bps -ge 1000000) { (($bps/1000000).ToString('0.##',$culture) + ' Mbps') }
        elseif ($bps -ge 1000) { (($bps/1000).ToString('0.##',$culture) + ' Kbps') }
        else { ($bps.ToString('0',$culture) + ' bps') }
    return [pscustomobject]@{ Status='Available'; BitsPerSecond=[uint64]$bps; Display=$display; Source=$source }
}

function Get-BatteryHealthResult {
    param([AllowNull()][object]$DesignCapacity,[AllowNull()][object]$FullChargeCapacity)
    $design = Convert-ToUInt64Safe $DesignCapacity
    $full = Convert-ToUInt64Safe $FullChargeCapacity
    if ($null -eq $design -or $null -eq $full) {
        return [pscustomobject]@{ Status='NotAvailable'; Percentage=$null; Display='Not available'; Warning='' }
    }
    if ($design -eq 0 -or $full -eq 0) {
        return [pscustomobject]@{ Status='InvalidValue'; Percentage=$null; Display='Invalid capacity data'; Warning='Design and full-charge capacities must both be greater than zero.' }
    }
    $pct = [math]::Round(([double]$full/[double]$design)*100,1)
    $warning = ''
    if ($pct -gt 110) { $warning = 'Full-charge capacity exceeds design capacity by more than 10%; firmware calibration or unit mismatch may be involved.' }
    return [pscustomobject]@{ Status='Available'; Percentage=$pct; Display=($pct.ToString('0.0',[Globalization.CultureInfo]::InvariantCulture)+'%'); Warning=$warning }
}

function Convert-RawMemoryModules {
    param([object[]]$Modules)
    $items = @()
    $index = 1
    foreach ($ram in @($Modules)) {
        $fields = @()
        $fields += New-NumericField 'Report Index' $index '' 'Application' 'ReportIndex' -Minimum 1 -Maximum 4096 -Format '0'
        $fields += New-TextField 'Device Locator' (Get-PropertyValue $ram 'DeviceLocator') 'Win32_PhysicalMemory' 'DeviceLocator'
        $fields += New-TextField 'Bank Label' (Get-PropertyValue $ram 'BankLabel') 'Win32_PhysicalMemory' 'BankLabel'
        $fields += New-TextField 'Tag' (Get-PropertyValue $ram 'Tag') 'Win32_PhysicalMemory' 'Tag'

        $reportedManufacturer = Get-PropertyValue $ram 'Manufacturer'
        if (Test-IsPlaceholder $reportedManufacturer) {
            $fields += New-InventoryField 'Reported Manufacturer' $reportedManufacturer $null '' 'Win32_PhysicalMemory' 'Manufacturer' 'NotAvailable' 'High' '' $false $false
            $partForInference = Get-PropertyValue $ram 'PartNumber'
            $inference = Infer-ManufacturerFromModel $partForInference 'Memory'
            if ($inference) {
                $fields += New-InventoryField 'Inferred Manufacturer' $partForInference $inference.Manufacturer '' $inference.InferenceSource 'PartNumber' 'Available' $inference.Confidence '' $false $true $inference.Manufacturer
                $fields += New-TextField 'Inference Source' $inference.InferenceSource 'Application inference table' 'Rule'
            }
        } else {
            $fields += New-TextField 'Manufacturer' $reportedManufacturer 'Win32_PhysicalMemory' 'Manufacturer' $false $true
        }

        $fields += New-TextField 'Part Number' (Get-PropertyValue $ram 'PartNumber') 'Win32_PhysicalMemory' 'PartNumber'
        $fields += New-TextField 'Serial Number' (Get-PropertyValue $ram 'SerialNumber') 'Win32_PhysicalMemory' 'SerialNumber' $true
        $fields += New-ByteCapacityField 'Capacity' (Get-PropertyValue $ram 'Capacity') 'Win32_PhysicalMemory' 'Capacity' 'Binary'
        $fields += New-NumericField 'Configured Clock Speed' (Get-PropertyValue $ram 'ConfiguredClockSpeed') 'MHz' 'Win32_PhysicalMemory' 'ConfiguredClockSpeed' -Minimum 1 -Maximum 20000 -Format '0'
        $fields += New-NumericField 'SMBIOS-Reported Speed' (Get-PropertyValue $ram 'Speed') 'MHz' 'Win32_PhysicalMemory' 'Speed' -Minimum 1 -Maximum 20000 -Format '0'
        $fields += New-TextField 'Memory Type' (Get-MemoryTypeName (Get-PropertyValue $ram 'SMBIOSMemoryType')) 'Win32_PhysicalMemory' 'SMBIOSMemoryType'
        $fields += New-NumericField 'SMBIOS Memory Type Code' (Get-PropertyValue $ram 'SMBIOSMemoryType') '' 'Win32_PhysicalMemory' 'SMBIOSMemoryType' -Minimum 0 -Maximum 255 -Format '0'
        $fields += New-TextField 'Form Factor' (Get-MemoryFormFactorName (Get-PropertyValue $ram 'FormFactor')) 'Win32_PhysicalMemory' 'FormFactor'
        $fields += New-NumericField 'Data Width' (Get-PropertyValue $ram 'DataWidth') 'bits' 'Win32_PhysicalMemory' 'DataWidth' -Minimum 1 -Maximum 1024 -Format '0'
        $fields += New-NumericField 'Total Width' (Get-PropertyValue $ram 'TotalWidth') 'bits' 'Win32_PhysicalMemory' 'TotalWidth' -Minimum 1 -Maximum 1024 -Format '0'
        $fields += New-NumericField 'Configured Voltage' (Get-PropertyValue $ram 'ConfiguredVoltage') 'mV' 'Win32_PhysicalMemory' 'ConfiguredVoltage' -Minimum 1 -Maximum 5000 -Format '0'
        $fields += New-NumericField 'Minimum Voltage' (Get-PropertyValue $ram 'MinVoltage') 'mV' 'Win32_PhysicalMemory' 'MinVoltage' -Minimum 1 -Maximum 5000 -Format '0'
        $fields += New-NumericField 'Maximum Voltage' (Get-PropertyValue $ram 'MaxVoltage') 'mV' 'Win32_PhysicalMemory' 'MaxVoltage' -Minimum 1 -Maximum 5000 -Format '0'
        $fields += New-TextField 'Replaceable' (Get-BooleanDisplay (Get-PropertyValue $ram 'Replaceable')) 'Win32_PhysicalMemory' 'Replaceable'
        $items += New-InventoryItem -Title "Memory Module $index" -Index $index -Fields $fields
        $index++
    }
    return @($items)
}

function Initialize-NativeInterop {
    if ($script:NativeInteropLoaded) { return $true }
    $code = @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;

namespace LouisMahdi.SystemInspector.Native
{
    public sealed class DisplayRecord
    {
        public string AdapterName;
        public string AdapterString;
        public string AdapterDeviceId;
        public string MonitorName;
        public string MonitorString;
        public string MonitorDeviceId;
        public bool IsPrimary;
        public bool IsAttached;
        public int Width;
        public int Height;
        public int RefreshRate;
        public int BitsPerPixel;
        public int PositionX;
        public int PositionY;
    }

    public static class NativeMethods
    {
        private const int ENUM_CURRENT_SETTINGS = -1;
        private const int DISPLAY_DEVICE_ATTACHED_TO_DESKTOP = 0x1;
        private const int DISPLAY_DEVICE_PRIMARY_DEVICE = 0x4;

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct DISPLAY_DEVICE
        {
            public int cb;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string DeviceName;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceString;
            public int StateFlags;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceID;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 128)] public string DeviceKey;
        }

        [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
        private struct DEVMODE
        {
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmDeviceName;
            public short dmSpecVersion;
            public short dmDriverVersion;
            public short dmSize;
            public short dmDriverExtra;
            public int dmFields;
            public int dmPositionX;
            public int dmPositionY;
            public int dmDisplayOrientation;
            public int dmDisplayFixedOutput;
            public short dmColor;
            public short dmDuplex;
            public short dmYResolution;
            public short dmTTOption;
            public short dmCollate;
            [MarshalAs(UnmanagedType.ByValTStr, SizeConst = 32)] public string dmFormName;
            public short dmLogPixels;
            public int dmBitsPerPel;
            public int dmPelsWidth;
            public int dmPelsHeight;
            public int dmDisplayFlags;
            public int dmDisplayFrequency;
            public int dmICMMethod;
            public int dmICMIntent;
            public int dmMediaType;
            public int dmDitherType;
            public int dmReserved1;
            public int dmReserved2;
            public int dmPanningWidth;
            public int dmPanningHeight;
        }

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern bool EnumDisplayDevices(string lpDevice, uint iDevNum, ref DISPLAY_DEVICE lpDisplayDevice, uint dwFlags);

        [DllImport("user32.dll", CharSet = CharSet.Unicode)]
        private static extern bool EnumDisplaySettings(string deviceName, int modeNum, ref DEVMODE devMode);

        [DllImport("kernel32.dll", SetLastError = true)]
        private static extern bool GetFirmwareType(out uint firmwareType);

        public static int ReadFirmwareType()
        {
            uint type;
            if (!GetFirmwareType(out type)) return 0;
            return (int)type;
        }

        public static DisplayRecord[] GetActiveDisplays()
        {
            var output = new List<DisplayRecord>();
            uint adapterIndex = 0;
            while (true)
            {
                var adapter = new DISPLAY_DEVICE();
                adapter.cb = Marshal.SizeOf(typeof(DISPLAY_DEVICE));
                if (!EnumDisplayDevices(null, adapterIndex, ref adapter, 0)) break;
                adapterIndex++;
                bool attached = (adapter.StateFlags & DISPLAY_DEVICE_ATTACHED_TO_DESKTOP) != 0;
                if (!attached) continue;

                var monitor = new DISPLAY_DEVICE();
                monitor.cb = Marshal.SizeOf(typeof(DISPLAY_DEVICE));
                bool hasMonitor = EnumDisplayDevices(adapter.DeviceName, 0, ref monitor, 0);

                var mode = new DEVMODE();
                mode.dmSize = (short)Marshal.SizeOf(typeof(DEVMODE));
                bool hasMode = EnumDisplaySettings(adapter.DeviceName, ENUM_CURRENT_SETTINGS, ref mode);

                output.Add(new DisplayRecord {
                    AdapterName = adapter.DeviceName,
                    AdapterString = adapter.DeviceString,
                    AdapterDeviceId = adapter.DeviceID,
                    MonitorName = hasMonitor ? monitor.DeviceName : "",
                    MonitorString = hasMonitor ? monitor.DeviceString : "",
                    MonitorDeviceId = hasMonitor ? monitor.DeviceID : "",
                    IsPrimary = (adapter.StateFlags & DISPLAY_DEVICE_PRIMARY_DEVICE) != 0,
                    IsAttached = attached,
                    Width = hasMode ? mode.dmPelsWidth : 0,
                    Height = hasMode ? mode.dmPelsHeight : 0,
                    RefreshRate = hasMode ? mode.dmDisplayFrequency : 0,
                    BitsPerPixel = hasMode ? mode.dmBitsPerPel : 0,
                    PositionX = hasMode ? mode.dmPositionX : 0,
                    PositionY = hasMode ? mode.dmPositionY : 0
                });
            }
            return output.ToArray();
        }
    }
}
'@
    try {
        Add-Type -TypeDefinition $code -Language CSharp -ErrorAction Stop
        $script:NativeInteropLoaded = $true
        return $true
    } catch {
        Write-DeveloperLog -Level 'Warning' -Section 'Displays and Monitors' -Source 'Native display API' -Message (Get-SanitizedErrorMessage $_) -Exception $_.Exception
        return $false
    }
}

function Get-FirmwareModeResult {
    $raw = $null
    $source = 'GetFirmwareType API'
    if (Initialize-NativeInterop) {
        try { $raw = [LouisMahdi.SystemInspector.Native.NativeMethods]::ReadFirmwareType() } catch { $raw = $null }
    }
    if ($null -eq $raw -or [int]$raw -eq 0) {
        try {
            $reg = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control' -Name PEFirmwareType -ErrorAction Stop
            $raw = $reg.PEFirmwareType
            $source = 'PEFirmwareType registry'
        } catch {}
    }
    switch ([int]$raw) {
        1 { return [pscustomobject]@{ Status='Available'; Mode='Legacy BIOS'; Raw=$raw; Source=$source } }
        2 { return [pscustomobject]@{ Status='Available'; Mode='UEFI'; Raw=$raw; Source=$source } }
        default { return [pscustomobject]@{ Status='NotAvailable'; Mode=$null; Raw=$raw; Source=$source } }
    }
}

function Invoke-ExternalProcess {
    param([string]$FilePath,[string]$Arguments,[int]$TimeoutSeconds=15)
    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        $psi = New-Object Diagnostics.ProcessStartInfo
        $psi.FileName = $FilePath
        $psi.Arguments = $Arguments
        $psi.UseShellExecute = $false
        $psi.CreateNoWindow = $true
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
        $process = New-Object Diagnostics.Process
        $process.StartInfo = $psi
        [void]$process.Start()
        if (-not $process.WaitForExit($TimeoutSeconds*1000)) {
            try { $process.Kill() } catch {}
            throw "Process timed out after $TimeoutSeconds seconds."
        }
        $stdout = $process.StandardOutput.ReadToEnd()
        $stderr = $process.StandardError.ReadToEnd()
        $sw.Stop()
        return [pscustomobject]@{ ExitCode=$process.ExitCode; StdOut=$stdout; StdErr=$stderr; DurationMs=$sw.ElapsedMilliseconds }
    } catch {
        $sw.Stop()
        throw
    }
}

function Collect-ReportSummarySection {
    param([AllowNull()][object]$Inventory)
    $fields = @()
    $fields += New-TextField 'Application Name' $script:AppName 'Application' 'AppName'
    $fields += New-TextField 'Application Version' $script:AppVersion 'Application' 'AppVersion'
    $fields += New-TextField 'Report Schema Version' $script:SchemaVersion 'Application' 'SchemaVersion'
    $fields += New-TextField 'Report Mode' $script:ReportMode 'Application' 'ReportMode'
    $fields += New-TextField 'Privacy Mode' $(if ($script:PrivacyMode) { 'Enabled' } else { 'Disabled' }) 'Application' 'PrivacyMode'
    $fields += New-TextField 'Internet Access' 'Not used' 'Application design' 'NetworkPolicy'
    $fields += New-TextField 'System Modifications' 'None - read-only collection' 'Application design' 'ReadOnlyPolicy'
    return New-InventorySection -Name 'Report Summary' -Items @(New-InventoryItem -Title 'Summary' -Fields $fields)
}

function Collect-ComputerSection {
    $sectionName = 'Computer'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $errors = @(); $warnings = @(); $items = @()
    $csQ = Invoke-CimQuery $sectionName 'Win32_ComputerSystem'
    $productQ = Invoke-CimQuery $sectionName 'Win32_ComputerSystemProduct'
    $enclosureQ = Invoke-CimQuery $sectionName 'Win32_SystemEnclosure'
    $boardQ = Invoke-CimQuery $sectionName 'Win32_BaseBoard'
    foreach ($q in @($csQ,$productQ,$enclosureQ,$boardQ)) {
        if ($q.Status -ne 'Available') { $errors += New-SectionError $sectionName $q.Source $q.Status $q.ErrorMessage $q.ExceptionType $q.HResult $q.DurationMs }
    }
    $cs = @($csQ.Items) | Select-Object -First 1
    $product = @($productQ.Items) | Select-Object -First 1
    $enclosure = @($enclosureQ.Items) | Select-Object -First 1
    $board = @($boardQ.Items) | Select-Object -First 1
    $fields = @()
    $fields += New-TextField 'Computer Name' $env:COMPUTERNAME 'Environment' 'COMPUTERNAME'
    $fields += New-TextField 'System Manufacturer' (Get-PropertyValue $cs 'Manufacturer') 'Win32_ComputerSystem' 'Manufacturer' $false $true
    $fields += New-TextField 'Commercial Model Name' (Get-PropertyValue $cs 'Model') 'Win32_ComputerSystem' 'Model'
    $fields += New-TextField 'Manufacturer Model Code' (Get-PropertyValue $product 'Name') 'Win32_ComputerSystemProduct' 'Name'
    $fields += New-TextField 'Product Family' (Get-PropertyValue $cs 'SystemFamily') 'Win32_ComputerSystem' 'SystemFamily'
    $fields += New-TextField 'System SKU' (Get-PropertyValue $cs 'SystemSKUNumber') 'Win32_ComputerSystem' 'SystemSKUNumber'
    $fields += New-TextField 'Product Version' (Get-PropertyValue $product 'Version') 'Win32_ComputerSystemProduct' 'Version'
    $fields += New-TextField 'System Type' (Get-PropertyValue $cs 'SystemType') 'Win32_ComputerSystem' 'SystemType'
    $fields += New-TextField 'Chassis Type' (Get-ChassisTypeName (Get-PropertyValue $enclosure 'ChassisTypes')) 'Win32_SystemEnclosure' 'ChassisTypes'
    $fields += New-TextField 'Computer UUID' (Get-PropertyValue $product 'UUID') 'Win32_ComputerSystemProduct' 'UUID' $true
    $fields += New-TextField 'System Serial Number' (Get-PropertyValue $enclosure 'SerialNumber') 'Win32_SystemEnclosure' 'SerialNumber' $true
    $fields += New-ByteCapacityField 'System-Reported Physical Memory' (Get-PropertyValue $cs 'TotalPhysicalMemory') 'Win32_ComputerSystem' 'TotalPhysicalMemory' 'Binary'

    $osQ = Invoke-CimQuery $sectionName 'Win32_OperatingSystem'
    $os = @($osQ.Items) | Select-Object -First 1
    $visibleKb = Get-PropertyValue $os 'TotalVisibleMemorySize'
    if ($null -ne $visibleKb) {
        try { $fields += New-ByteCapacityField 'Memory Visible to Windows' ([uint64]$visibleKb * [uint64]1024) 'Win32_OperatingSystem' 'TotalVisibleMemorySize' 'Binary' } catch {
            $fields += New-InventoryField 'Memory Visible to Windows' $visibleKb $null 'bytes' 'Win32_OperatingSystem' 'TotalVisibleMemorySize' 'InvalidValue'
        }
    } else {
        $fields += New-InventoryField 'Memory Visible to Windows' $null $null 'bytes' 'Win32_OperatingSystem' 'TotalVisibleMemorySize' 'NotAvailable'
    }

    $manufacturer = [string](Get-PropertyValue $cs 'Manufacturer')
    $model = [string](Get-PropertyValue $cs 'Model')
    $vmPatterns = 'Virtual Machine|VMware|VirtualBox|KVM|QEMU|HVM domU|Parallels|Hyper-V|Xen|Bochs|BHYVE'
    $isVm = $false; $vmReason = 'No virtualization signature detected'; $vmConfidence = 'Medium'
    if (($manufacturer + ' ' + $model) -match $vmPatterns) { $isVm = $true; $vmReason = 'Manufacturer or model matches a known virtual-machine signature'; $vmConfidence = 'High' }
    elseif ((Get-PropertyValue $cs 'HypervisorPresent') -eq $true) { $isVm = $true; $vmReason = 'Windows reports a hypervisor present; this may also occur on physical hosts using VBS or Hyper-V'; $vmConfidence = 'Low' }
    $fields += New-InventoryField 'Virtual Machine Detection' ([bool]$isVm) $(if ($isVm) {'Likely virtual machine'} else {'Likely physical computer'}) '' 'Capability detection' 'Manufacturer, Model, HypervisorPresent' 'Available' $vmConfidence '' $false $true $(if ($isVm) {'Likely virtual machine'} else {'Likely physical computer'})
    $fields += New-TextField 'Detection Basis' $vmReason 'Capability detection' 'DetectionRules'

    if ($board) {
        $fields += New-TextField 'Motherboard Product (reference only)' (Get-PropertyValue $board 'Product') 'Win32_BaseBoard' 'Product'
    }
    $items += New-InventoryItem -Title 'Computer Identity' -Fields $fields
    $sw.Stop()
    $status = if ($items.Count -gt 0) { 'Available' } elseif ($errors.Count -gt 0) { 'QueryFailed' } else { 'NotAvailable' }
    return New-InventorySection $sectionName $items $warnings $errors $sw.ElapsedMilliseconds $status
}

function Collect-WindowsSection {
    $sectionName = 'Windows'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $errors = @(); $warnings = @(); $items = @(); $fields = @()
    $osQ = Invoke-CimQuery $sectionName 'Win32_OperatingSystem'
    $os = @($osQ.Items) | Select-Object -First 1
    if ($osQ.Status -ne 'Available') { $errors += New-SectionError $sectionName $osQ.Source $osQ.Status $osQ.ErrorMessage $osQ.ExceptionType $osQ.HResult $osQ.DurationMs }

    $regQ = Invoke-SafeQuery $sectionName 'CurrentVersion registry' {
        Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
    }
    $reg = @($regQ.Items) | Select-Object -First 1
    if ($regQ.Status -ne 'Available') { $errors += New-SectionError $sectionName $regQ.Source $regQ.Status $regQ.ErrorMessage $regQ.ExceptionType $regQ.HResult $regQ.DurationMs }

    $productName = Get-PropertyValue $reg 'ProductName'
    if (Test-IsPlaceholder $productName) { $productName = Get-PropertyValue $os 'Caption' }
    $editionId = Get-PropertyValue $reg 'EditionID'
    $displayVersion = Get-PropertyValue $reg 'DisplayVersion'
    if (Test-IsPlaceholder $displayVersion) { $displayVersion = Get-PropertyValue $reg 'ReleaseId' }
    $buildNumber = Get-PropertyValue $reg 'CurrentBuildNumber'
    if (Test-IsPlaceholder $buildNumber) { $buildNumber = Get-PropertyValue $os 'BuildNumber' }
    $ubr = Get-PropertyValue $reg 'UBR'
    $fullBuild = if (-not (Test-IsPlaceholder $buildNumber) -and $null -ne $ubr) { "$buildNumber.$ubr" } else { $buildNumber }

    $fields += New-TextField 'Windows Product Name' $productName 'CurrentVersion registry; Win32_OperatingSystem fallback' 'ProductName / Caption'
    $fields += New-TextField 'Edition' (Get-PropertyValue $os 'Caption') 'Win32_OperatingSystem' 'Caption'
    $fields += New-TextField 'Edition ID' $editionId 'CurrentVersion registry' 'EditionID'
    $fields += New-TextField 'Display Version' $displayVersion 'CurrentVersion registry' 'DisplayVersion / ReleaseId'
    $fields += New-TextField 'Full Version' (Get-PropertyValue $os 'Version') 'Win32_OperatingSystem' 'Version'
    $fields += New-TextField 'Build Number' $buildNumber 'CurrentVersion registry; Win32_OperatingSystem fallback' 'CurrentBuildNumber / BuildNumber'
    $fields += New-NumericField 'Update Build Revision (UBR)' $ubr '' 'CurrentVersion registry' 'UBR' -Minimum 0 -Maximum 1000000 -Format '0'
    $fields += New-TextField 'Complete Build String' $fullBuild 'Application composition' 'BuildNumber + UBR'

    $installDate = Convert-WmiDateSafe (Get-PropertyValue $os 'InstallDate')
    $lastBootDate = Convert-WmiDateSafe (Get-PropertyValue $os 'LastBootUpTime')
    $fields += New-InventoryField 'Installation Date' (Get-PropertyValue $os 'InstallDate') $installDate '' 'Win32_OperatingSystem' 'InstallDate' $(if ($installDate) {'Available'} else {'InvalidValue'}) 'High' '' $false $false $installDate
    $fields += New-InventoryField 'Last Boot Time' (Get-PropertyValue $os 'LastBootUpTime') $lastBootDate '' 'Win32_OperatingSystem' 'LastBootUpTime' $(if ($lastBootDate) {'Available'} else {'InvalidValue'}) 'High' '' $false $false $lastBootDate

    $uptimeDisplay = $null; $uptimeSeconds = $null
    try {
        if ($os -and (Get-PropertyValue $os 'LastBootUpTime')) {
            $boot = [datetime](Get-PropertyValue $os 'LastBootUpTime')
            $span = (Get-Date) - $boot
            if ($span.TotalSeconds -ge 0) {
                $uptimeSeconds = [uint64][math]::Floor($span.TotalSeconds)
                $uptimeDisplay = '{0} days, {1} hours, {2} minutes, {3} seconds' -f $span.Days,$span.Hours,$span.Minutes,$span.Seconds
            }
        }
    } catch {}
    $fields += New-InventoryField 'Calculated Uptime' $uptimeSeconds $uptimeSeconds 'seconds' 'Application calculation from Win32_OperatingSystem' 'LastBootUpTime' $(if ($null -ne $uptimeSeconds) {'Available'} else {'NotAvailable'}) 'High' '' $false $false $uptimeDisplay
    $fields += New-TextField 'Operating-System Architecture' (Get-PropertyValue $os 'OSArchitecture') 'Win32_OperatingSystem' 'OSArchitecture'
    $fields += New-TextField 'System Directory' (Get-PropertyValue $os 'SystemDirectory') 'Win32_OperatingSystem' 'SystemDirectory'
    $fields += New-TextField 'Boot Device' (Get-PropertyValue $os 'BootDevice') 'Win32_OperatingSystem' 'BootDevice'
    $fields += New-TextField 'Windows Directory' (Get-PropertyValue $os 'WindowsDirectory') 'Win32_OperatingSystem' 'WindowsDirectory'
    $fields += New-TextField 'Locale' (Get-PropertyValue $os 'Locale') 'Win32_OperatingSystem' 'Locale'
    $fields += New-TextField 'Time Zone' ([TimeZoneInfo]::Local.DisplayName) '.NET TimeZoneInfo' 'Local.DisplayName'
    $fields += New-TextField 'Windows Experience Status' (Get-PropertyValue $reg 'WinSAT') 'CurrentVersion registry' 'WinSAT'
    $items += New-InventoryItem -Title 'Operating System' -Fields $fields
    $sw.Stop()
    $status = if ($os -or $reg) { 'Available' } elseif ($errors.Count) { 'QueryFailed' } else { 'NotAvailable' }
    return New-InventorySection $sectionName $items $warnings $errors $sw.ElapsedMilliseconds $status
}

function Collect-ProcessorSection {
    $sectionName = 'Processor'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $q = Invoke-CimQuery $sectionName 'Win32_Processor'
    $errors = @(); $warnings = @(); $items = @()
    if ($q.Status -ne 'Available') { $errors += New-SectionError $sectionName $q.Source $q.Status $q.ErrorMessage $q.ExceptionType $q.HResult $q.DurationMs }
    $cpus = @($q.Items)
    $index = 1
    foreach ($cpu in $cpus) {
        $fields = @()
        $fields += New-NumericField 'Physical Socket Index' $index '' 'Application' 'ReportIndex' -Minimum 1 -Maximum 256 -Format '0'
        $fields += New-TextField 'Processor Name' (Get-PropertyValue $cpu 'Name') 'Win32_Processor' 'Name'
        $fields += New-TextField 'Manufacturer' (Get-PropertyValue $cpu 'Manufacturer') 'Win32_Processor' 'Manufacturer' $false $true
        $fields += New-TextField 'Processor ID' (Get-PropertyValue $cpu 'ProcessorId') 'Win32_Processor' 'ProcessorId' $true
        $fields += New-TextField 'Architecture' (Get-ProcessorArchitectureName (Get-PropertyValue $cpu 'Architecture')) 'Win32_Processor' 'Architecture'
        $fields += New-TextField 'Socket Designation' (Get-PropertyValue $cpu 'SocketDesignation') 'Win32_Processor' 'SocketDesignation'
        $fields += New-NumericField 'Physical Core Count' (Get-PropertyValue $cpu 'NumberOfCores') 'cores' 'Win32_Processor' 'NumberOfCores' -Minimum 1 -Maximum 4096 -Format '0'
        $fields += New-NumericField 'Logical Processor Count' (Get-PropertyValue $cpu 'NumberOfLogicalProcessors') 'threads' 'Win32_Processor' 'NumberOfLogicalProcessors' -Minimum 1 -Maximum 8192 -Format '0'
        $fields += New-TextField 'Virtualization Firmware Support' (Get-BooleanDisplay (Get-PropertyValue $cpu 'VirtualizationFirmwareEnabled')) 'Win32_Processor' 'VirtualizationFirmwareEnabled'
        $fields += New-TextField 'Second-Level Address Translation Support' (Get-BooleanDisplay (Get-PropertyValue $cpu 'SecondLevelAddressTranslationExtensions')) 'Win32_Processor' 'SecondLevelAddressTranslationExtensions'

        $currentMhz = Get-PropertyValue $cpu 'CurrentClockSpeed'
        if ($null -ne $currentMhz) {
            try {
                $ghz = [math]::Round(([double]$currentMhz/1000),3)
                $fields += New-InventoryField 'WMI-Reported Current Clock' $currentMhz $ghz 'GHz' 'Win32_Processor' 'CurrentClockSpeed' $(if ($ghz -gt 0 -and $ghz -lt 20) {'Available'} else {'InvalidValue'}) 'Low' '' $false $false $(if ($ghz -gt 0 -and $ghz -lt 20) { "$($ghz.ToString('0.###',[Globalization.CultureInfo]::InvariantCulture)) GHz (not a precise per-core live measurement)" } else { $null })
            } catch { $fields += New-InventoryField 'WMI-Reported Current Clock' $currentMhz $null 'GHz' 'Win32_Processor' 'CurrentClockSpeed' 'InvalidValue' }
        } else { $fields += New-InventoryField 'WMI-Reported Current Clock' $null $null 'GHz' 'Win32_Processor' 'CurrentClockSpeed' 'NotAvailable' }

        $maxMhz = Get-PropertyValue $cpu 'MaxClockSpeed'
        if ($null -ne $maxMhz) {
            try {
                $maxGhz = [math]::Round(([double]$maxMhz/1000),3)
                $fields += New-InventoryField 'SMBIOS-Reported Maximum Clock' $maxMhz $maxGhz 'GHz' 'Win32_Processor' 'MaxClockSpeed' $(if ($maxGhz -gt 0 -and $maxGhz -lt 20) {'Available'} else {'InvalidValue'}) 'Medium' '' $false $false $(if ($maxGhz -gt 0 -and $maxGhz -lt 20) { "$($maxGhz.ToString('0.###',[Globalization.CultureInfo]::InvariantCulture)) GHz" } else { $null })
            } catch { $fields += New-InventoryField 'SMBIOS-Reported Maximum Clock' $maxMhz $null 'GHz' 'Win32_Processor' 'MaxClockSpeed' 'InvalidValue' }
        } else { $fields += New-InventoryField 'SMBIOS-Reported Maximum Clock' $null $null 'GHz' 'Win32_Processor' 'MaxClockSpeed' 'NotAvailable' }
        $fields += New-InventoryField 'Live Frequency Sample' $null $null 'GHz' 'Application policy' 'Offline mode' 'NotAvailable' 'Unknown' 'No benchmark or live per-core sampling is performed without explicit permission.'
        $fields += New-InventoryField 'Advertised Boost Clock' $null $null 'GHz' 'Application policy' 'Offline mode' 'NotAvailable' 'Unknown' 'Not collected in offline mode.'

        $l2 = Get-PropertyValue $cpu 'L2CacheSize'; if ($null -ne $l2) { $fields += New-ByteCapacityField 'L2 Cache' ([uint64]$l2*1024) 'Win32_Processor' 'L2CacheSize' 'Binary' } else { $fields += New-InventoryField 'L2 Cache' $null $null 'bytes' 'Win32_Processor' 'L2CacheSize' 'NotAvailable' }
        $l3 = Get-PropertyValue $cpu 'L3CacheSize'; if ($null -ne $l3) { $fields += New-ByteCapacityField 'L3 Cache' ([uint64]$l3*1024) 'Win32_Processor' 'L3CacheSize' 'Binary' } else { $fields += New-InventoryField 'L3 Cache' $null $null 'bytes' 'Win32_Processor' 'L3CacheSize' 'NotAvailable' }
        $fields += New-NumericField 'Processor Load Snapshot' (Get-PropertyValue $cpu 'LoadPercentage') '%' 'Win32_Processor' 'LoadPercentage' -Minimum 0 -Maximum 100 -Format '0'
        $fields += New-TextField 'Processor Status' (Get-PropertyValue $cpu 'Status') 'Win32_Processor' 'Status'
        $items += New-InventoryItem -Title "Processor Socket $index" -Index $index -Fields $fields
        $index++
    }
    if ($cpus.Count -gt 0) {
        $summaryFields = @()
        $summaryFields += New-NumericField 'Physical Socket Count' $cpus.Count 'sockets' 'Win32_Processor enumeration' 'Count' -Minimum 1 -Maximum 256 -Format '0'
        $totalCores = 0; $totalLogical = 0
        foreach ($cpu in $cpus) { try { $totalCores += [int](Get-PropertyValue $cpu 'NumberOfCores') } catch {}; try { $totalLogical += [int](Get-PropertyValue $cpu 'NumberOfLogicalProcessors') } catch {} }
        $summaryFields += New-NumericField 'Total Physical Core Count' $totalCores 'cores' 'Application sum' 'NumberOfCores' -Minimum 1 -Maximum 4096 -Format '0'
        $summaryFields += New-NumericField 'Total Logical Processor Count' $totalLogical 'threads' 'Application sum' 'NumberOfLogicalProcessors' -Minimum 1 -Maximum 8192 -Format '0'
        $items = @(New-InventoryItem -Title 'Processor Summary' -Fields $summaryFields) + $items
    }
    $sw.Stop()
    $status = if ($items.Count) {'Available'} elseif ($q.Status -ne 'Available') {$q.Status} else {'NotAvailable'}
    return New-InventorySection $sectionName $items $warnings $errors $sw.ElapsedMilliseconds $status
}

function Collect-PhysicalMemorySection {
    $sectionName = 'Physical Memory'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $errors = @(); $warnings = @(); $items = @()
    $ramQ = Invoke-CimQuery $sectionName 'Win32_PhysicalMemory'
    $arrayQ = Invoke-CimQuery $sectionName 'Win32_PhysicalMemoryArray'
    $osQ = Invoke-CimQuery $sectionName 'Win32_OperatingSystem'
    $csQ = Invoke-CimQuery $sectionName 'Win32_ComputerSystem'
    foreach ($q in @($ramQ,$arrayQ,$osQ,$csQ)) {
        if ($q.Status -ne 'Available') { $errors += New-SectionError $sectionName $q.Source $q.Status $q.ErrorMessage $q.ExceptionType $q.HResult $q.DurationMs }
    }
    $modules = @($ramQ.Items)
    $moduleItems = Convert-RawMemoryModules $modules
    [uint64]$installed = 0
    foreach ($module in $modules) {
        $capacity = Convert-ToUInt64Safe (Get-PropertyValue $module 'Capacity')
        if ($null -ne $capacity) { $installed += $capacity }
    }
    [uint64]$slotCount = 0
    foreach ($array in @($arrayQ.Items)) {
        $n = Convert-ToUInt64Safe (Get-PropertyValue $array 'MemoryDevices')
        if ($null -ne $n) { $slotCount += $n }
    }
    $os = @($osQ.Items) | Select-Object -First 1
    $cs = @($csQ.Items) | Select-Object -First 1
    $visibleBytes = $null; $availableBytes = $null
    try { if ($os -and $null -ne (Get-PropertyValue $os 'TotalVisibleMemorySize')) { $visibleBytes = [uint64](Get-PropertyValue $os 'TotalVisibleMemorySize') * [uint64]1024 } } catch {}
    try { if ($os -and $null -ne (Get-PropertyValue $os 'FreePhysicalMemory')) { $availableBytes = [uint64](Get-PropertyValue $os 'FreePhysicalMemory') * [uint64]1024 } } catch {}
    $systemReported = Convert-ToUInt64Safe (Get-PropertyValue $cs 'TotalPhysicalMemory')

    $summaryFields = @()
    $summaryFields += New-ByteCapacityField 'Installed RAM (sum of valid modules)' $installed 'Application sum from Win32_PhysicalMemory' 'Capacity' 'Binary'
    $summaryFields += New-ByteCapacityField 'System-Reported Physical Memory' $systemReported 'Win32_ComputerSystem' 'TotalPhysicalMemory' 'Binary'
    $summaryFields += New-ByteCapacityField 'Usable / Visible RAM' $visibleBytes 'Win32_OperatingSystem' 'TotalVisibleMemorySize' 'Binary'
    $summaryFields += New-ByteCapacityField 'Available RAM at Collection Time' $availableBytes 'Win32_OperatingSystem' 'FreePhysicalMemory' 'Binary'
    $summaryFields += New-NumericField 'Installed Module Count' $modules.Count 'modules' 'Win32_PhysicalMemory enumeration' 'Count' -Minimum 0 -Maximum 4096 -Format '0'
    if ($slotCount -gt 0) { $summaryFields += New-NumericField 'Firmware-Reported Memory Device Slots' $slotCount 'slots' 'Win32_PhysicalMemoryArray' 'MemoryDevices' -Minimum 1 -Maximum 4096 -Format '0' }
    else { $summaryFields += New-InventoryField 'Firmware-Reported Memory Device Slots' $slotCount $null 'slots' 'Win32_PhysicalMemoryArray' 'MemoryDevices' 'NotAvailable' }
    $summaryFields += New-InventoryField 'Memory Channel Mode' $null $null '' 'Application policy' 'No reliable provider selected' 'NotAvailable' 'Unknown' 'Not inferred from module capacities or slot labels.'

    if ($installed -gt 0 -and $systemReported -and $systemReported -gt 0) {
        $difference = [math]::Abs([double]$installed - [double]$systemReported)
        if ($difference -gt 64MB) {
            $warnings += "Installed memory calculated from modules differs from the system-reported total by $(Format-BytesBinary ([uint64]$difference))."
        }
    }
    if ($installed -gt 0 -and $visibleBytes -and $installed -ge $visibleBytes) {
        $reserved = $installed - $visibleBytes
        $summaryFields += New-ByteCapacityField 'Calculated Hardware-Reserved Difference' $reserved 'Application calculation' 'Installed minus visible memory' 'Binary'
    } else {
        $summaryFields += New-InventoryField 'Calculated Hardware-Reserved Difference' $null $null 'bytes' 'Application calculation' 'Installed minus visible memory' 'NotAvailable' 'Unknown' 'Required source values are unavailable or inconsistent.'
    }

    $items += New-InventoryItem -Title 'Memory Summary' -Fields $summaryFields -Warnings $warnings
    $items += $moduleItems
    $sw.Stop()
    $status = if ($items.Count -gt 1 -or $modules.Count) {'Available'} elseif ($ramQ.Status -ne 'Available') {$ramQ.Status} else {'NotAvailable'}
    return New-InventorySection $sectionName $items $warnings $errors $sw.ElapsedMilliseconds $status
}

function Get-GpuClassification {
    param([string]$Name,[string]$PnpDeviceId)
    $text = "$Name $PnpDeviceId"
    if ($text -match 'Remote Display|RDP|RemoteFX|Basic Display|VirtualBox|VMware|Parallels|Hyper-V|Virtual') { return [pscustomobject]@{Value='Virtual or remote display adapter';Confidence='High';Inferred=$true} }
    if ($text -match 'Intel\(R\).*Graphics|Intel.*UHD|Intel.*Iris|AMD Radeon\(TM\) Graphics|Vega [0-9]+ Graphics|Radeon Graphics') { return [pscustomobject]@{Value='Integrated GPU (inferred)';Confidence='Medium';Inferred=$true} }
    if ($text -match 'NVIDIA|GeForce|Quadro|RTX|GTX|Tesla|Radeon RX|Radeon Pro|Intel Arc') { return [pscustomobject]@{Value='Dedicated or discrete GPU (inferred)';Confidence='Medium';Inferred=$true} }
    return [pscustomobject]@{Value='Unknown';Confidence='Low';Inferred=$true}
}

function Get-NvidiaGpuData {
    $command = Get-Command 'nvidia-smi.exe' -ErrorAction SilentlyContinue
    if (-not $command) { return [pscustomobject]@{ Status='VendorToolUnavailable'; Items=@(); Error='nvidia-smi is not installed or not on PATH.' } }
    try {
        $result = Invoke-ExternalProcess $command.Source '--query-gpu=index,name,memory.total,driver_version,temperature.gpu,utilization.gpu --format=csv,noheader,nounits' 12
        if ($result.ExitCode -ne 0) { throw "nvidia-smi exited with code $($result.ExitCode): $($result.StdErr)" }
        $items = @()
        foreach ($line in ($result.StdOut -split '[\r\n]+' | Where-Object { $_.Trim() })) {
            $parts = $line -split ','
            if ($parts.Count -ge 6) {
                [double]$memMiB = 0; [double]$temp = 0; [double]$load = 0
                [void][double]::TryParse($parts[2].Trim(),[Globalization.NumberStyles]::Any,[Globalization.CultureInfo]::InvariantCulture,[ref]$memMiB)
                [void][double]::TryParse($parts[4].Trim(),[Globalization.NumberStyles]::Any,[Globalization.CultureInfo]::InvariantCulture,[ref]$temp)
                [void][double]::TryParse($parts[5].Trim(),[Globalization.NumberStyles]::Any,[Globalization.CultureInfo]::InvariantCulture,[ref]$load)
                $items += [pscustomobject]@{
                    Index = $parts[0].Trim(); Name = $parts[1].Trim(); MemoryBytes = $(if ($memMiB -gt 0) {[uint64]($memMiB*1MB)} else {$null});
                    DriverVersion = $parts[3].Trim(); TemperatureC = $temp; LoadPercent = $load
                }
            }
        }
        return [pscustomobject]@{ Status='Available'; Items=$items; Error='' }
    } catch {
        return [pscustomobject]@{ Status=(Get-ExceptionStatus $_.Exception); Items=@(); Error=(Get-SanitizedErrorMessage $_) }
    }
}

function Get-RegistryGpuMemoryMap {
    $map = @{}
    try {
        $roots = Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Video' -ErrorAction Stop
        foreach ($root in $roots) {
            foreach ($sub in @(Get-ChildItem $root.PSPath -ErrorAction SilentlyContinue)) {
                try {
                    $p = Get-ItemProperty $sub.PSPath -ErrorAction Stop
                    $name = Get-PropertyValue $p 'HardwareInformation.AdapterString'
                    $memory = Get-PropertyValue $p 'HardwareInformation.qwMemorySize'
                    $u = Convert-ToUInt64Safe $memory
                    if (-not (Test-IsPlaceholder $name) -and $u -and $u -gt 0 -and $u -lt 256GB) { $map[[string]$name] = $u }
                } catch {}
            }
        }
    } catch {}
    return $map
}

function Collect-GraphicsSection {
    $sectionName = 'Graphics Adapters'
    $sw = [Diagnostics.Stopwatch]::StartNew()
    $errors=@();$warnings=@();$items=@()
    $gpuQ = Invoke-CimQuery $sectionName 'Win32_VideoController'
    $driverQ = Invoke-CimQuery $sectionName 'Win32_PnPSignedDriver' 'root/cimv2' "DeviceClass='DISPLAY'"
    if ($gpuQ.Status -ne 'Available') { $errors += New-SectionError $sectionName $gpuQ.Source $gpuQ.Status $gpuQ.ErrorMessage $gpuQ.ExceptionType $gpuQ.HResult $gpuQ.DurationMs }
    if ($driverQ.Status -ne 'Available') { $errors += New-SectionError $sectionName $driverQ.Source $driverQ.Status $driverQ.ErrorMessage $driverQ.ExceptionType $driverQ.HResult $driverQ.DurationMs }
    $nvidia = Get-NvidiaGpuData
    $registryMemory = Get-RegistryGpuMemoryMap
    $index=1
    foreach ($gpu in @($gpuQ.Items)) {
        $fields=@();$itemWarnings=@()
        $name=[string](Get-PropertyValue $gpu 'Name');$pnp=[string](Get-PropertyValue $gpu 'PNPDeviceID')
        $driver = @($driverQ.Items | Where-Object { ([string](Get-PropertyValue $_ 'DeviceID')) -eq $pnp } | Select-Object -First 1)
        $driverObj = if ($driver.Count) {$driver[0]} else {$null}
        $classification = Get-GpuClassification $name $pnp
        $fields += New-NumericField 'GPU Index' $index '' 'Application' 'ReportIndex' -Minimum 1 -Maximum 256 -Format '0'
        $fields += New-TextField 'GPU Name' $name 'Win32_VideoController' 'Name'
        $fields += New-TextField 'Manufacturer' (Get-PropertyValue $gpu 'AdapterCompatibility') 'Win32_VideoController' 'AdapterCompatibility' $false $true
        $fields += New-TextField 'PnP Device ID' $pnp 'Win32_VideoController' 'PNPDeviceID' $true
        $fields += New-InventoryField 'Adapter Classification' $name $classification.Value '' 'Application capability rules' 'Name / PNPDeviceID' 'Available' $classification.Confidence '' $false $true $classification.Value
        $fields += New-TextField 'Driver Version' $(if ($driverObj) {Get-PropertyValue $driverObj 'DriverVersion'} else {Get-PropertyValue $gpu 'DriverVersion'}) $(if ($driverObj) {'Win32_PnPSignedDriver'} else {'Win32_VideoController'}) 'DriverVersion'
        $driverDateRaw = if ($driverObj) {Get-PropertyValue $driverObj 'DriverDate'} else {Get-PropertyValue $gpu 'DriverDate'}
        $driverDate = Convert-WmiDateSafe $driverDateRaw -DateOnly
        $fields += New-InventoryField 'Driver Date' $driverDateRaw $driverDate '' $(if ($driverObj) {'Win32_PnPSignedDriver'} else {'Win32_VideoController'}) 'DriverDate' $(if ($driverDate) {'Available'} else {'NotAvailable'}) 'High' '' $false $false $driverDate
        $fields += New-TextField 'Driver Provider' (Get-PropertyValue $driverObj 'DriverProviderName') 'Win32_PnPSignedDriver' 'DriverProviderName'
        $fields += New-TextField 'Device Status' (Get-PropertyValue $gpu 'Status') 'Win32_VideoController' 'Status'

        $vendorMatch = @($nvidia.Items | Where-Object { $name -and (($_.Name -like "*$name*") -or ($name -like "*$($_.Name)*")) } | Select-Object -First 1)
        if ($vendorMatch.Count -gt 0 -and $vendorMatch[0].MemoryBytes) {
            $fields += New-ByteCapacityField 'NVIDIA-Reported Dedicated VRAM' $vendorMatch[0].MemoryBytes 'nvidia-smi (already installed)' 'memory.total' 'Binary'
            $fields += New-NumericField 'GPU Load Snapshot' $vendorMatch[0].LoadPercent '%' 'nvidia-smi (already installed)' 'utilization.gpu' -Minimum 0 -Maximum 100 -Format '0'
            $fields += New-NumericField 'GPU Temperature Snapshot' $vendorMatch[0].TemperatureC '°C' 'nvidia-smi (already installed)' 'temperature.gpu' -Minimum -20 -Maximum 150 -Format '0'
        } else {
            $status = if ($name -match 'NVIDIA') {$nvidia.Status} else {'NotApplicable'}
            $fields += New-InventoryField 'Vendor-Reported Dedicated VRAM' $null $null 'bytes' 'Optional installed vendor tool' 'Dedicated memory' $status 'Unknown' $nvidia.Error
            $fields += New-InventoryField 'GPU Load Snapshot' $null $null '%' 'Optional installed vendor tool' 'Utilization' $status 'Unknown' $nvidia.Error
            $fields += New-InventoryField 'GPU Temperature Snapshot' $null $null '°C' 'Optional installed vendor tool' 'Temperature' $status 'Unknown' $nvidia.Error
        }

        $registryValue=$null;$registryKey=''
        foreach ($key in $registryMemory.Keys) { if ($name -like "*$key*" -or $key -like "*$name*") { $registryValue=$registryMemory[$key];$registryKey=$key;break } }
        if ($registryValue) {
            $fields += New-ByteCapacityField 'Registry-Reported Adapter Memory' $registryValue 'Display adapter registry' 'HardwareInformation.qwMemorySize' 'Binary'
        } else {
            $fields += New-InventoryField 'Registry-Reported Adapter Memory' $null $null 'bytes' 'Display adapter registry' 'HardwareInformation.qwMemorySize' 'NotAvailable'
        }

        $wmiRaw = Get-PropertyValue $gpu 'AdapterRAM'
        $wmiBytes = Convert-ToUInt64Safe $wmiRaw
        $wmiStatus='NotAvailable';$wmiDisplay=$null;$wmiConfidence='Low'
        if ($null -ne $wmiRaw -and $wmiBytes -and $wmiBytes -gt 0 -and $wmiBytes -lt 256GB) {
            $wmiStatus='Available';$wmiDisplay=Format-BytesBinary $wmiBytes
            if ($wmiBytes -eq [uint64]4GB -or $wmiBytes -eq [uint64]2GB) { $itemWarnings += 'WMI AdapterRAM may be truncated or represent preallocated/shared graphics memory.' }
        } elseif ($null -ne $wmiRaw) { $wmiStatus='InvalidValue' }
        $fields += New-InventoryField 'WMI-Reported Adapter Memory' $wmiRaw $wmiBytes 'bytes' 'Win32_VideoController' 'AdapterRAM' $wmiStatus $wmiConfidence '' $false $false $wmiDisplay
        if ($classification.Value -like 'Integrated*') {
            $fields += New-InventoryField 'Shared System Graphics Memory' $null $null 'bytes' 'Windows display memory API' 'SharedSystemMemory' 'NotAvailable' 'Unknown' 'Integrated GPU preallocated memory is not treated as total usable graphics memory.'
        } else {
            $fields += New-InventoryField 'Shared System Graphics Memory' $null $null 'bytes' 'Windows display memory API' 'SharedSystemMemory' 'NotAvailable'
        }
        $fields += New-InventoryField 'Active Display Connection' $null $null '' 'Displays section' 'Display path association' 'NotAvailable' 'Unknown' 'Display resolution and refresh rate are reported separately and are not assigned to this GPU without a reliable path association.'
        $items += New-InventoryItem -Title "Graphics Adapter $index" -Index $index -Fields $fields -Warnings $itemWarnings
        $warnings += $itemWarnings
        $index++
    }
    $sw.Stop();$status=if($items.Count){'Available'}elseif($gpuQ.Status -ne 'Available'){$gpuQ.Status}else{'NotAvailable'}
    return New-InventorySection $sectionName $items $warnings $errors $sw.ElapsedMilliseconds $status
}

function Collect-DisplaysSection {
    $sectionName='Displays and Monitors'
    $sw=[Diagnostics.Stopwatch]::StartNew();$errors=@();$warnings=@();$items=@()
    $nativeRecords=@()
    if (Initialize-NativeInterop) {
        try { $nativeRecords=@([LouisMahdi.SystemInspector.Native.NativeMethods]::GetActiveDisplays()) }
        catch {
            $errors += New-SectionError $sectionName 'Windows display configuration API' (Get-ExceptionStatus $_.Exception) (Get-SanitizedErrorMessage $_) $_.Exception.GetType().FullName $_.Exception.HResult 0
        }
    }
    $idQ=Invoke-CimQuery $sectionName 'WmiMonitorID' 'root/wmi'
    $paramsQ=Invoke-CimQuery $sectionName 'WmiMonitorBasicDisplayParams' 'root/wmi'
    if($idQ.Status -ne 'Available'){$errors+=New-SectionError $sectionName $idQ.Source $idQ.Status $idQ.ErrorMessage $idQ.ExceptionType $idQ.HResult $idQ.DurationMs}
    if($paramsQ.Status -ne 'Available'){$errors+=New-SectionError $sectionName $paramsQ.Source $paramsQ.Status $paramsQ.ErrorMessage $paramsQ.ExceptionType $paramsQ.HResult $paramsQ.DurationMs}
    $monitorIds=@($idQ.Items);$monitorParams=@($paramsQ.Items)
    if($nativeRecords.Count -eq 0){
        try{
            Add-Type -AssemblyName System.Windows.Forms -ErrorAction Stop
            foreach($screen in [Windows.Forms.Screen]::AllScreens){
                $nativeRecords += [pscustomobject]@{
                    AdapterName=$screen.DeviceName;AdapterString='Not available';AdapterDeviceId='';MonitorName='';MonitorString='';MonitorDeviceId='';
                    IsPrimary=$screen.Primary;IsAttached=$true;Width=$screen.Bounds.Width;Height=$screen.Bounds.Height;RefreshRate=0;BitsPerPixel=$screen.BitsPerPixel;PositionX=$screen.Bounds.X;PositionY=$screen.Bounds.Y
                }
            }
            if($nativeRecords.Count){$warnings+='Native display enumeration was unavailable; System.Windows.Forms.Screen fallback was used.'}
        }catch{
            $errors+=New-SectionError $sectionName 'System.Windows.Forms.Screen' (Get-ExceptionStatus $_.Exception) (Get-SanitizedErrorMessage $_) $_.Exception.GetType().FullName $_.Exception.HResult 0
        }
    }
    $index=1
    foreach($display in $nativeRecords){
        $fields=@();$itemWarnings=@()
        $deviceId=[string]$display.MonitorDeviceId
        $pnpToken=''
        if($deviceId -match 'MONITOR\\([^\\]+)\\'){$pnpToken=$matches[1]}
        $idMatch=@($monitorIds|Where-Object{ $instance=[string](Get-PropertyValue $_ 'InstanceName'); ($pnpToken -and $instance -match [regex]::Escape($pnpToken)) }|Select-Object -First 1)
        if($idMatch.Count -eq 0 -and $monitorIds.Count -eq $nativeRecords.Count){$idMatch=@($monitorIds[$index-1]);$itemWarnings+='EDID identity was associated by display order because a stable path match was unavailable.'}
        $idObj=if($idMatch.Count){$idMatch[0]}else{$null}
        $paramMatch=@()
        if($idObj){
            $instance=[string](Get-PropertyValue $idObj 'InstanceName')
            $paramMatch=@($monitorParams|Where-Object{[string](Get-PropertyValue $_ 'InstanceName') -eq $instance}|Select-Object -First 1)
        }
        if($paramMatch.Count -eq 0 -and $monitorParams.Count -eq $nativeRecords.Count){$paramMatch=@($monitorParams[$index-1])}
        $paramObj=if($paramMatch.Count){$paramMatch[0]}else{$null}
        $manufacturer=Convert-EdidString (Get-PropertyValue $idObj 'ManufacturerName')
        $friendly=Convert-EdidString (Get-PropertyValue $idObj 'UserFriendlyName')
        $serial=Convert-EdidString (Get-PropertyValue $idObj 'SerialNumberID')
        $widthCm=Get-PropertyValue $paramObj 'MaxHorizontalImageSize';$heightCm=Get-PropertyValue $paramObj 'MaxVerticalImageSize'
        $diagonal=$null
        try{if([double]$widthCm -gt 0 -and [double]$heightCm -gt 0){$diagonal=[math]::Round(([math]::Sqrt(([double]$widthCm*0.3937008)*([double]$widthCm*0.3937008)+([double]$heightCm*0.3937008)*([double]$heightCm*0.3937008))),1)}}catch{}
        $fields+=New-NumericField 'Display Index' $index '' 'Application' 'ReportIndex' -Minimum 1 -Maximum 128 -Format '0'
        $fields+=New-TextField 'Monitor Manufacturer' $manufacturer 'WmiMonitorID' 'ManufacturerName'
        $fields+=New-TextField 'Monitor Model / Friendly Name' $(if($friendly){$friendly}elseif($display.MonitorString){$display.MonitorString}else{$display.AdapterString}) 'WmiMonitorID; Windows display API fallback' 'UserFriendlyName / DeviceString'
        $fields+=New-TextField 'Connection State' $(if($display.IsAttached){'Connected and active'}else{'Disconnected'}) 'Windows display configuration API' 'StateFlags'
        $fields+=New-TextField 'Primary Display' (Get-BooleanDisplay $display.IsPrimary) 'Windows display configuration API' 'DISPLAY_DEVICE_PRIMARY_DEVICE'
        if([int]$display.Width -gt 0 -and [int]$display.Height -gt 0){
            $fields+=New-InventoryField 'Active Resolution' "$($display.Width)x$($display.Height)" "$($display.Width)x$($display.Height)" 'pixels' 'Windows display configuration API' 'dmPelsWidth / dmPelsHeight' 'Available' 'High' '' $false $false "$($display.Width) × $($display.Height)"
        }else{$fields+=New-InventoryField 'Active Resolution' $null $null 'pixels' 'Windows display configuration API' 'dmPelsWidth / dmPelsHeight' 'NotAvailable'}
        if([int]$display.RefreshRate -gt 0 -and [int]$display.RefreshRate -lt 1000){$fields+=New-NumericField 'Refresh Rate' $display.RefreshRate 'Hz' 'Windows display configuration API' 'dmDisplayFrequency' -Minimum 1 -Maximum 1000 -Format '0'}else{$fields+=New-InventoryField 'Refresh Rate' $display.RefreshRate $null 'Hz' 'Windows display configuration API' 'dmDisplayFrequency' $(if([int]$display.RefreshRate -eq 0){'NotAvailable'}else{'InvalidValue'})}
        $fields+=New-NumericField 'Color Depth' $display.BitsPerPixel 'bits per pixel' 'Windows display configuration API' 'dmBitsPerPel' -Minimum 1 -Maximum 128 -Format '0'
        $fields+=New-NumericField 'Physical Width' $widthCm 'cm' 'WmiMonitorBasicDisplayParams' 'MaxHorizontalImageSize' -Minimum 1 -Maximum 1000 -Format '0.#'
        $fields+=New-NumericField 'Physical Height' $heightCm 'cm' 'WmiMonitorBasicDisplayParams' 'MaxVerticalImageSize' -Minimum 1 -Maximum 1000 -Format '0.#'
        $fields+=New-NumericField 'Approximate Diagonal Size' $diagonal 'inches' 'Application calculation from EDID dimensions' 'Pythagorean calculation' -Minimum 1 -Maximum 500 -Format '0.0'
        $fields+=New-InventoryField 'HDR Status' $null $null '' 'Windows advanced color API' 'HDR state' 'NotAvailable' 'Unknown' 'Not exposed by the selected offline collector on this system.'
        $fields+=New-InventoryField 'Connection Type' $null $null '' 'Windows display path API' 'Output technology' 'NotAvailable' 'Unknown' 'Not reliably exposed by the selected provider.'
        $fields+=New-TextField 'Monitor Serial Number' $serial 'WmiMonitorID' 'SerialNumberID' $true
        $fields+=New-TextField 'EDID Data Source' $(if($idObj){'WmiMonitorID'}else{'Not available'}) 'Application' 'EDID source'
        $fields+=New-TextField 'Associated Graphics Path' $(if($display.AdapterName){$display.AdapterName}else{'Not reliably associated'}) 'Windows display configuration API' 'AdapterName'
        $items+=New-InventoryItem -Title "Display $index" -Index $index -Fields $fields -Warnings $itemWarnings
        $warnings+=$itemWarnings;$index++
    }
    $sw.Stop();$status=if($items.Count){'Available'}elseif($errors.Count){'QueryFailed'}else{'NotAvailable'}
    return New-InventorySection $sectionName $items $warnings $errors $sw.ElapsedMilliseconds $status
}

function Collect-MotherboardSection {
    $sectionName='Motherboard';$sw=[Diagnostics.Stopwatch]::StartNew();$q=Invoke-CimQuery $sectionName 'Win32_BaseBoard';$errors=@();$items=@()
    if($q.Status -ne 'Available'){$errors+=New-SectionError $sectionName $q.Source $q.Status $q.ErrorMessage $q.ExceptionType $q.HResult $q.DurationMs}
    $index=1
    foreach($board in @($q.Items)){
        $fields=@()
        $fields+=New-TextField 'Manufacturer' (Get-PropertyValue $board 'Manufacturer') 'Win32_BaseBoard' 'Manufacturer' $false $true
        $fields+=New-TextField 'Product' (Get-PropertyValue $board 'Product') 'Win32_BaseBoard' 'Product'
        $fields+=New-TextField 'Version' (Get-PropertyValue $board 'Version') 'Win32_BaseBoard' 'Version'
        $fields+=New-TextField 'Part Number' (Get-PropertyValue $board 'PartNumber') 'Win32_BaseBoard' 'PartNumber'
        $fields+=New-TextField 'Serial Number' (Get-PropertyValue $board 'SerialNumber') 'Win32_BaseBoard' 'SerialNumber' $true
        $fields+=New-TextField 'Hosting Board' (Get-BooleanDisplay (Get-PropertyValue $board 'HostingBoard')) 'Win32_BaseBoard' 'HostingBoard'
        $fields+=New-TextField 'Replaceable' (Get-BooleanDisplay (Get-PropertyValue $board 'Replaceable')) 'Win32_BaseBoard' 'Replaceable'
        $fields+=New-TextField 'Removable' (Get-BooleanDisplay (Get-PropertyValue $board 'Removable')) 'Win32_BaseBoard' 'Removable'
        $items+=New-InventoryItem -Title $(if(@($q.Items).Count -gt 1){"Baseboard $index"}else{'Baseboard'}) -Index $index -Fields $fields;$index++
    }
    $sw.Stop();$status=if($items.Count){'Available'}else{$q.Status};return New-InventorySection $sectionName $items @() $errors $sw.ElapsedMilliseconds $status
}

function Collect-BiosSection {
    $sectionName='BIOS and Firmware';$sw=[Diagnostics.Stopwatch]::StartNew();$q=Invoke-CimQuery $sectionName 'Win32_BIOS';$errors=@();$warnings=@();$items=@()
    if($q.Status -ne 'Available'){$errors+=New-SectionError $sectionName $q.Source $q.Status $q.ErrorMessage $q.ExceptionType $q.HResult $q.DurationMs}
    $bios=@($q.Items)|Select-Object -First 1
    if($bios){
        $releaseRaw=Get-PropertyValue $bios 'ReleaseDate';$release=Convert-WmiDateSafe $releaseRaw -DateOnly
        if($releaseRaw -and -not $release){$warnings+='The BIOS release date was invalid or outside the accepted range and was not displayed.'}
        $fields=@()
        $fields+=New-TextField 'BIOS Manufacturer' (Get-PropertyValue $bios 'Manufacturer') 'Win32_BIOS' 'Manufacturer' $false $true
        $fields+=New-TextField 'BIOS Name' (Get-PropertyValue $bios 'Name') 'Win32_BIOS' 'Name'
        $fields+=New-TextField 'BIOS Version' ((@((Get-PropertyValue $bios 'BIOSVersion'))|Where-Object{$_}) -join ', ') 'Win32_BIOS' 'BIOSVersion'
        $fields+=New-TextField 'SMBIOS BIOS Version' (Get-PropertyValue $bios 'SMBIOSBIOSVersion') 'Win32_BIOS' 'SMBIOSBIOSVersion'
        $fields+=New-InventoryField 'BIOS Release Date' $releaseRaw $release '' 'Win32_BIOS' 'ReleaseDate' $(if($release){'Available'}elseif($releaseRaw){'InvalidValue'}else{'NotAvailable'}) 'High' '' $false $false $release
        $major=Get-PropertyValue $bios 'SMBIOSMajorVersion';$minor=Get-PropertyValue $bios 'SMBIOSMinorVersion'
        $smbios=if($null -ne $major -and $null -ne $minor){"$major.$minor"}else{$null}
        $fields+=New-TextField 'SMBIOS Version' $smbios 'Win32_BIOS' 'SMBIOSMajorVersion / SMBIOSMinorVersion'
        $ecMajor=Get-PropertyValue $bios 'EmbeddedControllerMajorVersion';$ecMinor=Get-PropertyValue $bios 'EmbeddedControllerMinorVersion'
        $ec=if($null -ne $ecMajor -and $null -ne $ecMinor -and [int]$ecMajor -ne 255){"$ecMajor.$ecMinor"}else{$null}
        $fields+=New-TextField 'Embedded Controller Version' $ec 'Win32_BIOS' 'EmbeddedControllerMajorVersion / EmbeddedControllerMinorVersion'
        $firmware=Get-FirmwareModeResult
        $fields+=New-InventoryField 'Firmware Mode' $firmware.Raw $firmware.Mode '' $firmware.Source 'FirmwareType' $firmware.Status 'High' '' $false $false $firmware.Mode
        $characteristics=Get-PropertyValue $bios 'BiosCharacteristics'
        $fields+=New-TextField 'BIOS Characteristics Codes' $(if($characteristics){(@($characteristics)-join ', ')}else{$null}) 'Win32_BIOS' 'BiosCharacteristics'
        $items+=New-InventoryItem -Title 'BIOS and Firmware' -Fields $fields -Warnings $warnings
    }
    $sw.Stop();$status=if($items.Count){'Available'}else{$q.Status};return New-InventorySection $sectionName $items $warnings $errors $sw.ElapsedMilliseconds $status
}

function Collect-SecuritySection {
    $sectionName='Security: UEFI, Secure Boot, and TPM';$sw=[Diagnostics.Stopwatch]::StartNew();$errors=@();$warnings=@();$items=@();$fields=@()
    $firmware=Get-FirmwareModeResult
    $fields+=New-InventoryField 'Firmware Mode' $firmware.Raw $firmware.Mode '' $firmware.Source 'FirmwareType' $firmware.Status 'High' '' $false $false $firmware.Mode

    $sbSupportedStatus='NotAvailable';$sbSupportedValue=$null;$sbEnabledStatus='NotAvailable';$sbEnabledValue=$null;$sbQueryStatus='NotAvailable';$sbError='';$sbSource='Confirm-SecureBootUEFI'
    if($firmware.Status -eq 'Available' -and $firmware.Mode -eq 'Legacy BIOS'){
        $sbSupportedStatus='NotApplicable';$sbEnabledStatus='NotApplicable';$sbQueryStatus='NotApplicable';$sbError='Secure Boot state is not applicable while Windows is booted in Legacy BIOS mode.'
    }elseif(-not (Get-Command 'Confirm-SecureBootUEFI' -ErrorAction SilentlyContinue)){
        $sbSupportedStatus='NotSupported';$sbEnabledStatus='NotSupported';$sbQueryStatus='NotSupported';$sbError='Confirm-SecureBootUEFI is unavailable in this runtime.'
    }else{
        try{
            $enabled=Confirm-SecureBootUEFI -ErrorAction Stop
            $sbSupportedStatus='Available';$sbSupportedValue=$true;$sbEnabledStatus='Available';$sbEnabledValue=[bool]$enabled;$sbQueryStatus='Available'
        }catch{
            $sbError=Get-SanitizedErrorMessage $_;$status=Get-ExceptionStatus $_.Exception
            if($status -eq 'PermissionDenied'){$sbSupportedStatus='NotAvailable';$sbEnabledStatus='PermissionDenied';$sbQueryStatus='PermissionDenied'}
            elseif($sbError -match 'not supported on this platform|unsupported platform'){$sbSupportedStatus='NotAvailable';$sbEnabledStatus='NotApplicable';$sbQueryStatus='NotSupported'}
            else{$sbSupportedStatus='NotAvailable';$sbEnabledStatus=$status;$sbQueryStatus=$status}
            $errors+=New-SectionError $sectionName $sbSource $sbQueryStatus $sbError $_.Exception.GetType().FullName $_.Exception.HResult 0
        }
    }
    $fields+=New-InventoryField 'Secure Boot Supported' $sbSupportedValue $(if($null -ne $sbSupportedValue){Get-BooleanDisplay $sbSupportedValue}else{$null}) '' $sbSource 'Support state' $sbSupportedStatus 'Medium' $sbError $false $false
    $fields+=New-InventoryField 'Secure Boot Enabled' $sbEnabledValue $(if($null -ne $sbEnabledValue){Get-BooleanDisplay $sbEnabledValue}else{$null}) '' $sbSource 'Enabled state' $sbEnabledStatus 'High' $sbError $false $false
    $fields+=New-InventoryField 'Secure Boot Query Status' $sbQueryStatus $sbQueryStatus '' $sbSource 'Query result' $sbQueryStatus 'High' $sbError $false $false $([string](Get-StatusDisplayText $sbQueryStatus $sbError))
    $fields+=New-TextField 'Secure Boot Source' $sbSource 'Application' 'Source selection'

    $tpmFields=@();$tpmErrors=@();$tpmSource='';$tpmStatus='NotAvailable';$tpmObj=$null;$tpmCim=$null
    $getTpm=Get-Command 'Get-Tpm' -ErrorAction SilentlyContinue
    if($getTpm){
        try{$tpmObj=Get-Tpm -ErrorAction Stop;$tpmSource='Get-Tpm';$tpmStatus='Available'}catch{
            $tpmStatus=Get-ExceptionStatus $_.Exception;$message=Get-SanitizedErrorMessage $_;$tpmErrors+=New-SectionError $sectionName 'Get-Tpm' $tpmStatus $message $_.Exception.GetType().FullName $_.Exception.HResult 0 $true 'Win32_Tpm fallback attempted'
        }
    }else{$tpmStatus='NotSupported';$tpmErrors+=New-SectionError $sectionName 'Get-Tpm' 'NotSupported' 'TrustedPlatformModule cmdlets are unavailable.' 'CommandNotFoundException' $null 0 $true 'Win32_Tpm fallback attempted'}
    $tpmQ=Invoke-CimQuery $sectionName 'Win32_Tpm' 'root/CIMV2/Security/MicrosoftTpm'
    if($tpmQ.Status -eq 'Available' -and @($tpmQ.Items).Count){$tpmCim=@($tpmQ.Items)|Select-Object -First 1;if(-not $tpmSource){$tpmSource='Win32_Tpm';$tpmStatus='Available'}}
    elseif($tpmQ.Status -ne 'Available'){$tpmErrors+=New-SectionError $sectionName $tpmQ.Source $tpmQ.Status $tpmQ.ErrorMessage $tpmQ.ExceptionType $tpmQ.HResult $tpmQ.DurationMs}
    $errors+=$tpmErrors

    if($tpmObj){
        $tpmFields+=New-TextField 'TPM Present' (Get-BooleanDisplay (Get-PropertyValue $tpmObj 'TpmPresent')) 'Get-Tpm' 'TpmPresent'
        $tpmFields+=New-TextField 'TPM Ready' (Get-BooleanDisplay (Get-PropertyValue $tpmObj 'TpmReady')) 'Get-Tpm' 'TpmReady'
        $tpmFields+=New-TextField 'TPM Enabled' (Get-BooleanDisplay (Get-PropertyValue $tpmObj 'TpmEnabled')) 'Get-Tpm' 'TpmEnabled'
        $tpmFields+=New-TextField 'TPM Activated' (Get-BooleanDisplay (Get-PropertyValue $tpmObj 'TpmActivated')) 'Get-Tpm' 'TpmActivated'
        $tpmFields+=New-TextField 'TPM Owned' (Get-BooleanDisplay (Get-PropertyValue $tpmObj 'TpmOwned')) 'Get-Tpm' 'TpmOwned'
        $tpmFields+=New-TextField 'Auto-Provisioning Status' (Get-PropertyValue $tpmObj 'AutoProvisioning') 'Get-Tpm' 'AutoProvisioning'
        $tpmFields+=New-TextField 'Restart Pending' (Get-BooleanDisplay (Get-PropertyValue $tpmObj 'RestartPending')) 'Get-Tpm' 'RestartPending'
    }else{
        foreach($label in @('TPM Present','TPM Ready','TPM Enabled','TPM Activated','TPM Owned','Auto-Provisioning Status','Restart Pending')){$tpmFields+=New-InventoryField $label $null $null '' 'Get-Tpm' $label $tpmStatus 'Unknown' $(if($tpmErrors.Count){$tpmErrors[0].Message}else{'TPM provider unavailable.'})}
    }
    if($tpmCim){
        $spec=Get-PropertyValue $tpmCim 'SpecVersion';$manufacturerId=Get-PropertyValue $tpmCim 'ManufacturerId';$manufacturerName=$null
        try{
            if($manufacturerId){
                $id=[uint32]$manufacturerId
                $chars=@([char](($id -shr 24)-band 255),[char](($id -shr 16)-band 255),[char](($id -shr 8)-band 255),[char]($id-band 255))
                $candidate=(-join $chars).Trim([char]0).Trim();if($candidate -match '^[ -~]{2,4}$'){$manufacturerName=$candidate}
            }
        }catch{}
        $tpmFields+=New-TextField 'TPM Specification Version' $spec 'Win32_Tpm' 'SpecVersion'
        $tpmFields+=New-NumericField 'TPM Manufacturer ID' $manufacturerId '' 'Win32_Tpm' 'ManufacturerId' -Minimum 0 -Maximum 4294967295 -Format '0'
        $tpmFields+=New-TextField 'TPM Manufacturer Name' $manufacturerName 'Application mapping from Win32_Tpm.ManufacturerId' 'ManufacturerId'
        $tpmFields+=New-TextField 'TPM Manufacturer Version' (Get-PropertyValue $tpmCim 'ManufacturerVersion') 'Win32_Tpm' 'ManufacturerVersion'
        $tpmFields+=New-TextField 'TPM Physical Presence Version Info' (Get-PropertyValue $tpmCim 'PhysicalPresenceVersionInfo') 'Win32_Tpm' 'PhysicalPresenceVersionInfo'
    }else{
        foreach($label in @('TPM Specification Version','TPM Manufacturer ID','TPM Manufacturer Name','TPM Manufacturer Version','TPM Physical Presence Version Info')){$tpmFields+=New-InventoryField $label $null $null '' 'Win32_Tpm' $label $tpmQ.Status 'Unknown' $tpmQ.ErrorMessage}
    }
    $tpmFields+=New-TextField 'TPM Collection Source' $(if($tpmSource){$tpmSource}else{'No provider succeeded'}) 'Application' 'Source selection'
    $tpmFields+=New-InventoryField 'TPM Query Status' $tpmStatus $tpmStatus '' 'Application' 'Aggregated provider status' $tpmStatus 'High' $(if($tpmErrors.Count){$tpmErrors[0].Message}else{''}) $false $false $([string](Get-StatusDisplayText $tpmStatus $(if($tpmErrors.Count){$tpmErrors[0].Message}else{''})))

    $items+=New-InventoryItem -Title 'Firmware and Secure Boot' -Fields $fields
    $items+=New-InventoryItem -Title 'Trusted Platform Module' -Fields $tpmFields
    $sw.Stop();return New-InventorySection $sectionName $items $warnings $errors $sw.ElapsedMilliseconds 'Available'
}

function Get-StorageMatch {
    param([object]$Disk,[object[]]$PhysicalDisks,[object[]]$WmiDisks)
    $diskNumber=Get-PropertyValue $Disk 'Number';$diskSerial=[string](Get-PropertyValue $Disk 'SerialNumber');$diskUnique=[string](Get-PropertyValue $Disk 'UniqueId');$diskName=[string](Get-PropertyValue $Disk 'FriendlyName');$diskSize=Convert-ToUInt64Safe (Get-PropertyValue $Disk 'Size')
    $physical=$null;$confidence='Low';$method='No reliable correlation'
    foreach($p in @($PhysicalDisks)){
        $pSerial=[string](Get-PropertyValue $p 'SerialNumber');$pUnique=[string](Get-PropertyValue $p 'UniqueId')
        if($diskSerial -and $pSerial -and $diskSerial.Trim() -eq $pSerial.Trim()){$physical=$p;$confidence='High';$method='Serial number';break}
        if($diskUnique -and $pUnique -and $diskUnique.Trim() -eq $pUnique.Trim()){$physical=$p;$confidence='High';$method='Unique ID';break}
    }
    if(-not $physical){
        $candidates=@($PhysicalDisks|Where-Object{
            $pName=[string](Get-PropertyValue $_ 'FriendlyName');$pSize=Convert-ToUInt64Safe (Get-PropertyValue $_ 'Size')
            $nameMatch=$diskName -and $pName -and (($diskName -like "*$pName*") -or ($pName -like "*$diskName*"))
            $sizeMatch=$diskSize -and $pSize -and ([math]::Abs([double]$diskSize-[double]$pSize) -lt 16MB)
            $nameMatch -and $sizeMatch
        })
        if($candidates.Count -eq 1){$physical=$candidates[0];$confidence='Medium';$method='Friendly name and size'}
    }
    $wmi=@($WmiDisks|Where-Object{(Get-PropertyValue $_ 'Index') -eq $diskNumber}|Select-Object -First 1)
    $wmiObj=if($wmi.Count){$wmi[0]}else{$null}
    if(-not $wmiObj){
        $candidates=@($WmiDisks|Where-Object{
            $wName=[string](Get-PropertyValue $_ 'Model');$wSize=Convert-ToUInt64Safe (Get-PropertyValue $_ 'Size')
            $nameMatch=$diskName -and $wName -and (($diskName -like "*$wName*") -or ($wName -like "*$diskName*"))
            $sizeMatch=$diskSize -and $wSize -and ([math]::Abs([double]$diskSize-[double]$wSize) -lt 16MB)
            $nameMatch -and $sizeMatch
        })
        if($candidates.Count -eq 1){$wmiObj=$candidates[0];if($confidence -eq 'Low'){$confidence='Medium';$method='WMI model and size'}}
    }
    return [pscustomobject]@{PhysicalDisk=$physical;WmiDisk=$wmiObj;Confidence=$confidence;Method=$method}
}

function Get-StorageReliabilityFields {
    param([AllowNull()][object]$PhysicalDisk)
    $fields=@();$warnings=@()
    if($null -eq $PhysicalDisk -or -not (Get-Command 'Get-StorageReliabilityCounter' -ErrorAction SilentlyContinue)){
        $fields+=New-InventoryField 'Detailed Reliability Data' $null $null '' 'Get-StorageReliabilityCounter' 'Capability' 'NotSupported' 'Unknown' 'Not supported or not exposed by the storage driver.'
        return [pscustomobject]@{Fields=$fields;Warnings=$warnings}
    }
    try{
        $r=$PhysicalDisk|Get-StorageReliabilityCounter -ErrorAction Stop
        $fields+=New-TextField 'Detailed Reliability Data' 'Available' 'Get-StorageReliabilityCounter' 'Capability'
        $temp=Get-PropertyValue $r 'Temperature';$tempMax=Get-PropertyValue $r 'TemperatureMax'
        $fields+=New-NumericField 'Temperature' $temp '°C' 'Get-StorageReliabilityCounter' 'Temperature' -Minimum -20 -Maximum 150 -Format '0'
        $fields+=New-NumericField 'Maximum Recorded Temperature' $tempMax '°C' 'Get-StorageReliabilityCounter' 'TemperatureMax' -Minimum -20 -Maximum 180 -Format '0'
        $wear=Get-PropertyValue $r 'Wear';$fields+=New-NumericField 'Wear Percentage' $wear '%' 'Get-StorageReliabilityCounter' 'Wear' -Minimum 0 -Maximum 100 -Format '0'
        $hours=Get-PropertyValue $r 'PowerOnHours';$fields+=New-NumericField 'Power-On Hours' $hours 'hours' 'Get-StorageReliabilityCounter' 'PowerOnHours' -Minimum 0 -Maximum 10000000 -Format '0'
        $reliabilityProperties = @(
            [pscustomobject]@{Label='Read Errors Total';Property='ReadErrorsTotal'},
            [pscustomobject]@{Label='Write Errors Total';Property='WriteErrorsTotal'},
            [pscustomobject]@{Label='Uncorrectable Read Errors';Property='ReadErrorsUncorrected'},
            [pscustomobject]@{Label='Uncorrectable Write Errors';Property='WriteErrorsUncorrected'},
            [pscustomobject]@{Label='Read Latency Maximum';Property='ReadLatencyMax'},
            [pscustomobject]@{Label='Write Latency Maximum';Property='WriteLatencyMax'},
            [pscustomobject]@{Label='Flush Latency Maximum';Property='FlushLatencyMax'},
            [pscustomobject]@{Label='Start-Stop Cycle Count';Property='StartStopCycleCount'},
            [pscustomobject]@{Label='Load-Unload Cycle Count';Property='LoadUnloadCycleCount'},
            [pscustomobject]@{Label='Device Power-Cycle Count';Property='DevicePowerCycleCount'}
        )
        foreach($pair in $reliabilityProperties){
            $fields+=New-NumericField $pair.Label (Get-PropertyValue $r $pair.Property) '' 'Get-StorageReliabilityCounter' $pair.Property -Minimum 0 -Maximum ([double]::MaxValue) -Format '0'
        }
    }catch{
        $status=Get-ExceptionStatus $_.Exception;$fields+=New-InventoryField 'Detailed Reliability Data' $null $null '' 'Get-StorageReliabilityCounter' 'Capability' $status 'Unknown' (Get-SanitizedErrorMessage $_)
    }
    return [pscustomobject]@{Fields=$fields;Warnings=$warnings}
}

function Collect-PhysicalStorageSection {
    $sectionName='Physical Storage';$sw=[Diagnostics.Stopwatch]::StartNew();$errors=@();$warnings=@();$items=@()
    $getDiskQ=if(Get-Command 'Get-Disk' -ErrorAction SilentlyContinue){Invoke-SafeQuery $sectionName 'Get-Disk' {Get-Disk -ErrorAction Stop}}else{[pscustomobject]@{Items=@();Status='NotSupported';ErrorMessage='Storage module Get-Disk cmdlet is unavailable.';ExceptionType='CommandNotFoundException';HResult=$null;DurationMs=0;Source='Get-Disk'}}
    $physicalQ=if(Get-Command 'Get-PhysicalDisk' -ErrorAction SilentlyContinue){Invoke-SafeQuery $sectionName 'Get-PhysicalDisk' {Get-PhysicalDisk -ErrorAction Stop}}else{[pscustomobject]@{Items=@();Status='NotSupported';ErrorMessage='Storage module Get-PhysicalDisk cmdlet is unavailable.';ExceptionType='CommandNotFoundException';HResult=$null;DurationMs=0;Source='Get-PhysicalDisk'}}
    $wmiQ=Invoke-CimQuery $sectionName 'Win32_DiskDrive'
    $smartQ=Invoke-CimQuery $sectionName 'MSStorageDriver_FailurePredictStatus' 'root/wmi'
    foreach($q in @($getDiskQ,$physicalQ,$wmiQ,$smartQ)){if($q.Status -ne 'Available'){$errors+=New-SectionError $sectionName $q.Source $q.Status $q.ErrorMessage $q.ExceptionType $q.HResult $q.DurationMs}}
    $disks=@($getDiskQ.Items);$physical=@($physicalQ.Items);$wmi=@($wmiQ.Items);$smartItems=@($smartQ.Items)
    if($disks.Count -eq 0){
        foreach($wd in $wmi){
            $disks+=[pscustomobject]@{Number=Get-PropertyValue $wd 'Index';FriendlyName=Get-PropertyValue $wd 'Model';SerialNumber=Get-PropertyValue $wd 'SerialNumber';UniqueId=Get-PropertyValue $wd 'PNPDeviceID';Size=Get-PropertyValue $wd 'Size';BusType=Get-PropertyValue $wd 'InterfaceType';PartitionStyle=$null;IsBoot=$null;IsSystem=$null;IsReadOnly=$null;IsOffline=$null;FirmwareVersion=Get-PropertyValue $wd 'FirmwareRevision'}
        }
        if($disks.Count){$warnings+='Get-Disk was unavailable; Win32_DiskDrive fallback was used as the primary disk enumeration source.'}
    }
    $index=1
    foreach($disk in $disks){
        $match=Get-StorageMatch $disk $physical $wmi;$pd=$match.PhysicalDisk;$wd=$match.WmiDisk;$fields=@();$itemWarnings=@()
        $model=Get-PropertyValue $disk 'FriendlyName';if(Test-IsPlaceholder $model){$model=Get-PropertyValue $wd 'Model'}
        $reportedManufacturer=Get-PropertyValue $pd 'Manufacturer';if(Test-IsPlaceholder $reportedManufacturer){$reportedManufacturer=Get-PropertyValue $wd 'Manufacturer'}
        $size=Convert-ToUInt64Safe (Get-PropertyValue $disk 'Size');if(-not $size){$size=Convert-ToUInt64Safe (Get-PropertyValue $pd 'Size')};if(-not $size){$size=Convert-ToUInt64Safe (Get-PropertyValue $wd 'Size')}
        $media=Get-PropertyValue $pd 'MediaType';$bus=Get-PropertyValue $disk 'BusType';if(Test-IsPlaceholder $bus){$bus=Get-PropertyValue $pd 'BusType'}
        $fields+=New-NumericField 'Disk Index' $index '' 'Application' 'ReportIndex' -Minimum 1 -Maximum 4096 -Format '0'
        $fields+=New-NumericField 'Windows Disk Number' (Get-PropertyValue $disk 'Number') '' 'Get-Disk / Win32_DiskDrive' 'Number / Index' -Minimum 0 -Maximum 4096 -Format '0'
        $fields+=New-TextField 'Model' $model 'Get-Disk; Win32_DiskDrive fallback' 'FriendlyName / Model'
        if(Test-IsPlaceholder $reportedManufacturer){
            $fields+=New-InventoryField 'Reported Manufacturer' $reportedManufacturer $null '' 'Get-PhysicalDisk; Win32_DiskDrive fallback' 'Manufacturer' 'NotAvailable'
            $inference=Infer-ManufacturerFromModel $model 'Storage'
            if($inference){
                $fields+=New-InventoryField 'Inferred Manufacturer' $model $inference.Manufacturer '' $inference.InferenceSource 'Model' 'Available' $inference.Confidence '' $false $true $inference.Manufacturer
                $fields+=New-TextField 'Inference Source' $inference.InferenceSource 'Application inference table' 'Rule'
            }else{$fields+=New-InventoryField 'Inferred Manufacturer' $model $null '' 'Model-prefix database' 'Model' 'NotAvailable' 'Unknown' '' $false $true}
        }else{$fields+=New-TextField 'Manufacturer' $reportedManufacturer 'Get-PhysicalDisk; Win32_DiskDrive fallback' 'Manufacturer' $false $true}
        $serial=Get-PropertyValue $disk 'SerialNumber';if(Test-IsPlaceholder $serial){$serial=Get-PropertyValue $pd 'SerialNumber'};if(Test-IsPlaceholder $serial){$serial=Get-PropertyValue $wd 'SerialNumber'}
        $fields+=New-TextField 'Serial Number' $serial 'Get-Disk; Get-PhysicalDisk; Win32_DiskDrive fallback' 'SerialNumber' $true
        $firmware=Get-PropertyValue $disk 'FirmwareVersion';if(Test-IsPlaceholder $firmware){$firmware=Get-PropertyValue $wd 'FirmwareRevision'}
        $fields+=New-TextField 'Firmware Revision' $firmware 'Get-Disk; Win32_DiskDrive fallback' 'FirmwareVersion / FirmwareRevision'
        if(Test-IsPlaceholder $media -or ([string]$media -match 'Unspecified|Unknown')){
            $fields+=New-InventoryField 'Reported Media Type' $media $null '' 'Get-PhysicalDisk' 'MediaType' 'NotAvailable' 'High'
            $mediaInference=Infer-StorageMediaType $model $bus
            if($mediaInference){
                $fields+=New-InventoryField 'Inferred Media Type' $model $mediaInference.MediaType '' $mediaInference.Source 'Model / BusType' 'Available' $mediaInference.Confidence '' $false $true $mediaInference.MediaType
            }else{
                $fields+=New-InventoryField 'Inferred Media Type' $model $null '' 'Model-string inference rules' 'Model / BusType' 'NotAvailable' 'Unknown' '' $false $true
            }
        }else{
            $fields+=New-TextField 'Media Type' $media 'Get-PhysicalDisk' 'MediaType'
        }
        $fields+=New-TextField 'Bus Type' $bus 'Get-Disk; Get-PhysicalDisk fallback' 'BusType'
        $fields+=New-TextField 'Interface Type' (Get-PropertyValue $wd 'InterfaceType') 'Win32_DiskDrive' 'InterfaceType'
        $fields+=New-TextField 'Device Type' (Get-PropertyValue $wd 'MediaType') 'Win32_DiskDrive' 'MediaType'
        if($size){
            $fields+=New-InventoryField 'Manufacturer Capacity' $size $size 'bytes' 'Get-Disk; Get-PhysicalDisk; Win32_DiskDrive fallback' 'Size' 'Available' 'High' '' $false $false (Format-BytesDecimal $size)
            $fields+=New-InventoryField 'Windows Binary Size' $size $size 'bytes' 'Application binary conversion' 'Size' 'Available' 'High' '' $false $false (Format-BytesBinary $size)
            $fields+=New-InventoryField 'Exact Capacity' $size $size 'bytes' 'Provider exact value' 'Size' 'Available' 'High' '' $false $false ($size.ToString('N0',[Globalization.CultureInfo]::InvariantCulture)+' bytes')
        }else{
            foreach($label in @('Manufacturer Capacity','Windows Binary Size','Exact Capacity')){$fields+=New-InventoryField $label $null $null 'bytes' 'Disk provider' 'Size' 'NotAvailable'}
        }
        $fields+=New-TextField 'Partition Style' (Get-PropertyValue $disk 'PartitionStyle') 'Get-Disk' 'PartitionStyle'
        $fields+=New-TextField 'Boot Disk' (Get-BooleanDisplay (Get-PropertyValue $disk 'IsBoot')) 'Get-Disk' 'IsBoot'
        $fields+=New-TextField 'System Disk' (Get-BooleanDisplay (Get-PropertyValue $disk 'IsSystem')) 'Get-Disk' 'IsSystem'
        $fields+=New-TextField 'Read-Only' (Get-BooleanDisplay (Get-PropertyValue $disk 'IsReadOnly')) 'Get-Disk' 'IsReadOnly'
        $fields+=New-TextField 'Offline' (Get-BooleanDisplay (Get-PropertyValue $disk 'IsOffline')) 'Get-Disk' 'IsOffline'
        $fields+=New-TextField 'Storage HealthStatus' (Get-PropertyValue $pd 'HealthStatus') 'Get-PhysicalDisk' 'HealthStatus'
        $fields+=New-TextField 'OperationalStatus' ((@((Get-PropertyValue $pd 'OperationalStatus'))|Where-Object{$_}) -join ', ') 'Get-PhysicalDisk' 'OperationalStatus'
        $fields+=New-TextField 'Windows Device Status' (Get-PropertyValue $wd 'Status') 'Win32_DiskDrive' 'Status'
                $smartMatch=$null
        $pnpId=[string](Get-PropertyValue $wd 'PNPDeviceID')
        if($pnpId){
            $tokens=@(($pnpId -split '[\\&]')|Where-Object{$_.Length -ge 4})
            $smartCandidates=@($smartItems|Where-Object{
                $instance=[string](Get-PropertyValue $_ 'InstanceName')
                $matched=$false
                foreach($token in $tokens){if($instance -match [regex]::Escape($token)){$matched=$true;break}}
                $matched
            })
            if($smartCandidates.Count -eq 1){$smartMatch=$smartCandidates[0]}
        }
        if($smartMatch){
            $predict=[bool](Get-PropertyValue $smartMatch 'PredictFailure')
            $smartText=$(if($predict){'Predicted failure reported'}else{'No predicted failure reported'})
            $fields+=New-InventoryField 'SMART Prediction Status' $predict $smartText '' 'MSStorageDriver_FailurePredictStatus' 'PredictFailure' 'Available' 'Medium' 'This is a prediction flag, not a complete health assessment.' $false $false $smartText
            $fields+=New-NumericField 'SMART Prediction Reason Code' (Get-PropertyValue $smartMatch 'Reason') '' 'MSStorageDriver_FailurePredictStatus' 'Reason' -Minimum 0 -Maximum 4294967295 -Format '0'
        }else{
            $smartStatus=$(if($smartQ.Status -eq 'Available'){'NotAvailable'}else{$smartQ.Status})
            $fields+=New-InventoryField 'SMART Prediction Status' $null $null '' 'MSStorageDriver_FailurePredictStatus' 'PredictFailure' $smartStatus 'Unknown' $(if($smartQ.ErrorMessage){$smartQ.ErrorMessage}else{'Not all storage drivers expose a correlatable SMART prediction instance.'})
            $fields+=New-InventoryField 'SMART Prediction Reason Code' $null $null '' 'MSStorageDriver_FailurePredictStatus' 'Reason' $smartStatus 'Unknown' $smartQ.ErrorMessage
        }
        $reliability=Get-StorageReliabilityFields $pd;$fields+=$reliability.Fields;$itemWarnings+=$reliability.Warnings
        $fields+=New-TextField 'Correlation Method' $match.Method 'Application correlation' 'Stable identifiers / model and size fallback'
        $fields+=New-TextField 'Correlation Confidence' $match.Confidence 'Application correlation' 'Confidence'
        if($match.Confidence -eq 'Low'){$itemWarnings+='Disk sources could not be correlated using a stable identifier; some enrichment fields may remain unavailable.'}
        $items+=New-InventoryItem -Title "Physical Disk $index" -Index $index -Fields $fields -Warnings $itemWarnings;$warnings+=$itemWarnings;$index++
    }
    $sw.Stop();$status=if($items.Count){'Available'}elseif($errors.Count){'QueryFailed'}else{'NotAvailable'}
    return New-InventorySection $sectionName $items $warnings $errors $sw.ElapsedMilliseconds $status
}

function Collect-VolumesSection {
    $sectionName='Volumes and Partitions';$sw=[Diagnostics.Stopwatch]::StartNew();$errors=@();$warnings=@();$items=@()
    $volQ=if(Get-Command 'Get-Volume' -ErrorAction SilentlyContinue){Invoke-SafeQuery $sectionName 'Get-Volume' {Get-Volume -ErrorAction Stop}}else{[pscustomobject]@{Items=@();Status='NotSupported';ErrorMessage='Get-Volume is unavailable.';ExceptionType='CommandNotFoundException';HResult=$null;DurationMs=0;Source='Get-Volume'}}
    $partQ=if(Get-Command 'Get-Partition' -ErrorAction SilentlyContinue){Invoke-SafeQuery $sectionName 'Get-Partition' {Get-Partition -ErrorAction Stop}}else{[pscustomobject]@{Items=@();Status='NotSupported';ErrorMessage='Get-Partition is unavailable.';ExceptionType='CommandNotFoundException';HResult=$null;DurationMs=0;Source='Get-Partition'}}
    $wmiVolQ=Invoke-CimQuery $sectionName 'Win32_LogicalDisk' 'root/cimv2' 'DriveType=3'
    $pageQ=Invoke-CimQuery $sectionName 'Win32_PageFileUsage'
    foreach($q in @($volQ,$partQ,$wmiVolQ,$pageQ)){if($q.Status -ne 'Available'){$errors+=New-SectionError $sectionName $q.Source $q.Status $q.ErrorMessage $q.ExceptionType $q.HResult $q.DurationMs}}
    $volumes=@($volQ.Items);$partitions=@($partQ.Items);$pageFiles=@($pageQ.Items)
    if($volumes.Count -eq 0){
        foreach($v in @($wmiVolQ.Items)){$volumes+=[pscustomobject]@{DriveLetter=([string](Get-PropertyValue $v 'DeviceID')).TrimEnd(':');Path=(Get-PropertyValue $v 'DeviceID');FileSystemLabel=Get-PropertyValue $v 'VolumeName';FileSystem=Get-PropertyValue $v 'FileSystem';Size=Get-PropertyValue $v 'Size';SizeRemaining=Get-PropertyValue $v 'FreeSpace';HealthStatus=$null;DriveType='Fixed'}}
        if($volumes.Count){$warnings+='Get-Volume was unavailable; Win32_LogicalDisk fallback was used.'}
    }
    $index=1
    foreach($vol in $volumes){
        $drive=[string](Get-PropertyValue $vol 'DriveLetter');$path=[string](Get-PropertyValue $vol 'Path')
        if(-not $drive -and -not $path){continue}
        $size=Convert-ToUInt64Safe (Get-PropertyValue $vol 'Size');$free=Convert-ToUInt64Safe (Get-PropertyValue $vol 'SizeRemaining')
        $used=$null;$usedPct=$null;$freePct=$null;$itemWarnings=@()
        if($size -and $size -gt 0 -and $null -ne $free){
            if($free -le $size){$used=$size-$free;$usedPct=[math]::Round(([double]$used/[double]$size)*100,1);$freePct=[math]::Round(([double]$free/[double]$size)*100,1)}else{$itemWarnings+='Free space exceeds volume capacity; percentage calculations were suppressed.'}
        }
        $partition=@($partitions|Where-Object{ $drive -and ([string](Get-PropertyValue $_ 'DriveLetter')).Equals($drive,[StringComparison]::OrdinalIgnoreCase)}|Select-Object -First 1)
        $p=if($partition.Count){$partition[0]}else{$null}
        $fields=@()
        $fields+=New-NumericField 'Volume Index' $index '' 'Application' 'ReportIndex' -Minimum 1 -Maximum 4096 -Format '0'
        $mount=if($drive){$drive+':'}elseif($path){$path}else{$null}
        $fields+=New-TextField 'Drive Letter or Mount Point' $mount 'Get-Volume' 'DriveLetter / Path'
        $fields+=New-TextField 'Volume Label' (Get-PropertyValue $vol 'FileSystemLabel') 'Get-Volume' 'FileSystemLabel'
        $fields+=New-TextField 'File System' (Get-PropertyValue $vol 'FileSystem') 'Get-Volume' 'FileSystem'
        $fields+=New-ByteCapacityField 'Capacity' $size 'Get-Volume' 'Size' 'Binary'
        $fields+=New-ByteCapacityField 'Used Space' $used 'Application calculation' 'Size - SizeRemaining' 'Binary'
        $fields+=New-ByteCapacityField 'Free Space' $free 'Get-Volume' 'SizeRemaining' 'Binary'
        $fields+=New-NumericField 'Used Percentage' $usedPct '%' 'Application calculation' 'Used / Size' -Minimum 0 -Maximum 100 -Format '0.0'
        $fields+=New-NumericField 'Free Percentage' $freePct '%' 'Application calculation' 'Free / Size' -Minimum 0 -Maximum 100 -Format '0.0'
        $fields+=New-TextField 'Volume Health Status' (Get-PropertyValue $vol 'HealthStatus') 'Get-Volume' 'HealthStatus'
        $fields+=New-NumericField 'Disk Number' (Get-PropertyValue $p 'DiskNumber') '' 'Get-Partition' 'DiskNumber' -Minimum 0 -Maximum 4096 -Format '0'
        $fields+=New-NumericField 'Partition Number' (Get-PropertyValue $p 'PartitionNumber') '' 'Get-Partition' 'PartitionNumber' -Minimum 0 -Maximum 4096 -Format '0'
        $fields+=New-TextField 'Boot Partition' (Get-BooleanDisplay (Get-PropertyValue $p 'IsBoot')) 'Get-Partition' 'IsBoot'
        $fields+=New-TextField 'System Partition' (Get-BooleanDisplay (Get-PropertyValue $p 'IsSystem')) 'Get-Partition' 'IsSystem'
        $pagePresent=$false
        foreach($pf in $pageFiles){$n=[string](Get-PropertyValue $pf 'Name');if($drive -and $n -like "$drive`:\*"){$pagePresent=$true;break}}
        $fields+=New-TextField 'Page File Present' (Get-BooleanDisplay $pagePresent) 'Win32_PageFileUsage' 'Name'
        if($script:ReportMode -eq 'Extended' -and (Get-Command 'Get-BitLockerVolume' -ErrorAction SilentlyContinue) -and $drive){
            try{$bl=Get-BitLockerVolume -MountPoint ($drive+':') -ErrorAction Stop;$fields+=New-TextField 'BitLocker Status' $bl.VolumeStatus 'Get-BitLockerVolume' 'VolumeStatus'}catch{$fields+=New-InventoryField 'BitLocker Status' $null $null '' 'Get-BitLockerVolume' 'VolumeStatus' (Get-ExceptionStatus $_.Exception) 'Unknown' (Get-SanitizedErrorMessage $_)}
        }else{$fields+=New-InventoryField 'BitLocker Status' $null $null '' 'Get-BitLockerVolume' 'VolumeStatus' 'NotApplicable' 'Unknown' 'Collected only in Extended mode when the cmdlet is available.'}
        $items+=New-InventoryItem -Title "Volume $index" -Index $index -Fields $fields -Warnings $itemWarnings;$warnings+=$itemWarnings;$index++
    }
    $sw.Stop();$status=if($items.Count){'Available'}elseif($errors.Count){'QueryFailed'}else{'NotAvailable'}
    return New-InventorySection $sectionName $items $warnings $errors $sw.ElapsedMilliseconds $status
}

function Get-BatteryReportXmlData {
    $powercfg=Get-Command 'powercfg.exe' -ErrorAction SilentlyContinue
    if(-not $powercfg){return [pscustomobject]@{Status='NotSupported';Items=@();Error='powercfg.exe is unavailable.'}}
    $temp=[IO.Path]::Combine([IO.Path]::GetTempPath(),('LouisMahdi_Battery_'+[guid]::NewGuid().ToString('N')+'.xml'))
    try{
        $r=Invoke-ExternalProcess $powercfg.Source ("/batteryreport /xml /output `"$temp`"") 20
        if($r.ExitCode -ne 0 -or -not (Test-Path $temp)){throw "powercfg battery report failed with exit code $($r.ExitCode): $($r.StdErr)"}
        [xml]$xml=Get-Content -LiteralPath $temp -Raw -ErrorAction Stop
        $nodes=@($xml.SelectNodes("//*[local-name()='Battery']"));$items=@()
        foreach($node in $nodes){
            $record=[ordered]@{}
            foreach($name in @('Id','Name','Manufacturer','SerialNumber','Chemistry','DesignCapacity','FullChargeCapacity','CycleCount')){
                $child=$node.SelectSingleNode("./*[local-name()='$name']");$record[$name]=if($child){$child.InnerText}else{$null}
            }
            $items+=[pscustomobject]$record
        }
        return [pscustomobject]@{Status=$(if($items.Count){'Available'}else{'NotAvailable'});Items=$items;Error='' }
    }catch{return [pscustomobject]@{Status=(Get-ExceptionStatus $_.Exception);Items=@();Error=(Get-SanitizedErrorMessage $_)}}
    finally{if((Test-Path $temp) -and -not $script:RetainDiagnostics){Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue}}
}

function Collect-BatterySection {
    $sectionName='Battery';$sw=[Diagnostics.Stopwatch]::StartNew();$errors=@();$warnings=@();$items=@()
    $xmlData=Get-BatteryReportXmlData
    $winQ=Invoke-CimQuery $sectionName 'Win32_Battery'
    $staticQ=Invoke-CimQuery $sectionName 'BatteryStaticData' 'root/wmi'
    $fullQ=Invoke-CimQuery $sectionName 'BatteryFullChargedCapacity' 'root/wmi'
    $cycleQ=Invoke-CimQuery $sectionName 'BatteryCycleCount' 'root/wmi'
    $statusQ=Invoke-CimQuery $sectionName 'BatteryStatus' 'root/wmi'
    foreach($q in @($winQ,$staticQ,$fullQ,$cycleQ,$statusQ)){if($q.Status -ne 'Available'){$errors+=New-SectionError $sectionName $q.Source $q.Status $q.ErrorMessage $q.ExceptionType $q.HResult $q.DurationMs}}
    $win=@($winQ.Items);$xmlItems=@($xmlData.Items);$count=[math]::Max($win.Count,$xmlItems.Count)
    if($count -eq 0){
        $fields=@()
        $fields+=New-InventoryField 'Battery Detection' $null $null '' 'powercfg and Win32_Battery' 'Enumeration' 'NotApplicable' 'High' 'No physical battery was reported. This is normal for most desktop computers.'
        $items+=New-InventoryItem -Title 'Battery Status' -Fields $fields
        $sw.Stop();return New-InventorySection $sectionName $items $warnings $errors $sw.ElapsedMilliseconds 'NotApplicable'
    }
    for($i=0;$i -lt $count;$i++){
        $w=if($i -lt $win.Count){$win[$i]}else{$null};$x=if($i -lt $xmlItems.Count){$xmlItems[$i]}else{$null}
        $s=if($i -lt @($staticQ.Items).Count){@($staticQ.Items)[$i]}else{$null};$f=if($i -lt @($fullQ.Items).Count){@($fullQ.Items)[$i]}else{$null};$c=if($i -lt @($cycleQ.Items).Count){@($cycleQ.Items)[$i]}else{$null};$bs=if($i -lt @($statusQ.Items).Count){@($statusQ.Items)[$i]}else{$null}
        $design=Get-PropertyValue $x 'DesignCapacity';if(-not $design){$design=Get-PropertyValue $s 'DesignedCapacity'}
        $full=Get-PropertyValue $x 'FullChargeCapacity';if(-not $full){$full=Get-PropertyValue $f 'FullChargedCapacity'}
        $health=Get-BatteryHealthResult $design $full;$itemWarnings=@();if($health.Warning){$itemWarnings+=$health.Warning}
        $fields=@();$idx=$i+1
        $fields+=New-NumericField 'Battery Index' $idx '' 'Application' 'ReportIndex' -Minimum 1 -Maximum 64 -Format '0'
        $name=Get-PropertyValue $x 'Name';if(Test-IsPlaceholder $name){$name=Get-PropertyValue $w 'Name'};if(Test-IsPlaceholder $name){$name=Get-PropertyValue $x 'Id'}
        $fields+=New-TextField 'Battery Name' $name 'powercfg battery report; Win32_Battery fallback' 'Name / Id'
        $batteryClass=$(if(([string]$name+' '+[string](Get-PropertyValue $w 'DeviceID')) -match '(?i)UPS|Uninterruptible'){'UPS-reported or specialty battery'}else{'System battery'})
        $fields+=New-InventoryField 'Battery Device Classification' $name $batteryClass '' 'Application classification rules' 'Name / DeviceID' 'Available' 'Medium' '' $false $true $batteryClass
        $manufacturer=Get-PropertyValue $x 'Manufacturer';if(Test-IsPlaceholder $manufacturer){$manufacturer=Get-PropertyValue $w 'ManufacturerName'}
        $fields+=New-TextField 'Manufacturer' $manufacturer 'powercfg battery report; Win32_Battery fallback' 'Manufacturer' $false $true
        $fields+=New-TextField 'Chemistry' (Get-PropertyValue $x 'Chemistry') 'powercfg battery report XML' 'Chemistry'
        $fields+=New-TextField 'Serial Number' (Get-PropertyValue $x 'SerialNumber') 'powercfg battery report XML' 'SerialNumber' $true
        if($design){$fields+=New-InventoryField 'Design Capacity' $design $design 'mWh' 'powercfg battery report; BatteryStaticData fallback' 'DesignCapacity / DesignedCapacity' 'Available' 'High' '' $false $false "$design mWh"}else{$fields+=New-InventoryField 'Design Capacity' $null $null 'mWh' 'Battery providers' 'DesignCapacity' 'NotAvailable'}
        if($full){$fields+=New-InventoryField 'Full-Charge Capacity' $full $full 'mWh' 'powercfg battery report; BatteryFullChargedCapacity fallback' 'FullChargeCapacity / FullChargedCapacity' 'Available' 'High' '' $false $false "$full mWh"}else{$fields+=New-InventoryField 'Full-Charge Capacity' $null $null 'mWh' 'Battery providers' 'FullChargeCapacity' 'NotAvailable'}
        $remaining=Get-PropertyValue $bs 'RemainingCapacity';$fields+=New-InventoryField 'Remaining Capacity' $remaining $remaining 'mWh' 'BatteryStatus' 'RemainingCapacity' $(if($remaining){'Available'}else{'NotAvailable'}) 'Medium' '' $false $false $(if($remaining){"$remaining mWh"}else{$null})
        $fields+=New-InventoryField 'Battery Health Percentage' $health.Percentage $health.Percentage '%' 'Application calculation' 'FullChargeCapacity / DesignCapacity × 100' $health.Status 'High' $health.Warning $false $false $health.Display
        $fields+=New-NumericField 'Current Charge Percentage' (Get-PropertyValue $w 'EstimatedChargeRemaining') '%' 'Win32_Battery' 'EstimatedChargeRemaining' -Minimum 0 -Maximum 100 -Format '0'
        $cycle=Get-PropertyValue $x 'CycleCount';if(-not $cycle){$cycle=Get-PropertyValue $c 'CycleCount'}
        if($null -ne $cycle -and [string]$cycle -ne ''){$fields+=New-NumericField 'Cycle Count' $cycle 'cycles' 'powercfg battery report; BatteryCycleCount fallback' 'CycleCount' -Minimum 0 -Maximum 1000000 -Format '0'}else{$fields+=New-InventoryField 'Cycle Count' $null $null 'cycles' 'Battery firmware' 'CycleCount' 'NotAvailable' 'Unknown' 'Not reported by battery firmware.'}
        $fields+=New-NumericField 'Voltage' (Get-PropertyValue $w 'DesignVoltage') 'mV' 'Win32_Battery' 'DesignVoltage' -Minimum 1 -Maximum 100000 -Format '0'
        $charging=Get-PropertyValue $bs 'Charging';$discharging=Get-PropertyValue $bs 'Discharging';$state=if($charging -eq $true){'Charging'}elseif($discharging -eq $true){'Discharging'}else{Get-PropertyValue $w 'Status'}
        $fields+=New-TextField 'Charging or Discharging State' $state 'BatteryStatus; Win32_Battery fallback' 'Charging / Discharging / Status'
        $runtime=Get-PropertyValue $w 'EstimatedRunTime';if($runtime -eq 71582788){$runtime=$null}
        $fields+=New-NumericField 'Estimated Runtime' $runtime 'minutes' 'Win32_Battery' 'EstimatedRunTime' -Minimum 0 -Maximum 5256000 -Format '0'
        $fields+=New-TextField 'Battery Device Status' (Get-PropertyValue $w 'Status') 'Win32_Battery' 'Status'
        $fields+=New-TextField 'Capacity Data Source' $(if($x){'powercfg battery report XML'}elseif($s -or $f){'WMI battery classes'}else{'Not available'}) 'Application' 'Source selection'
        $items+=New-InventoryItem -Title "Battery $idx" -Index $idx -Fields $fields -Warnings $itemWarnings;$warnings+=$itemWarnings
    }
    $sw.Stop();return New-InventorySection $sectionName $items $warnings $errors $sw.ElapsedMilliseconds 'Available'
}

function Get-NetworkClassification {
    param([object]$Adapter)
    $name=[string](Get-PropertyValue $Adapter 'Name');$desc=[string](Get-PropertyValue $Adapter 'InterfaceDescription');if(-not $desc){$desc=[string](Get-PropertyValue $Adapter 'Description')}
    $text="$name $desc"
    $hardware=Get-PropertyValue $Adapter 'HardwareInterface'
    if($text -match 'Bluetooth'){return [pscustomobject]@{Category='Virtual';Type='Bluetooth or specialty adapter';Confidence='High'}}
    if($text -match 'PdaNet|VPN|TAP-|TUN|WireGuard|OpenVPN|Hyper-V|vEthernet|VMware|VirtualBox|Loopback|Teredo|ISATAP|6to4|WAN Miniport|Npcap|Docker|WSL|Virtual|Tunneling'){
        return [pscustomobject]@{Category='Virtual';Type='Virtual or software adapter';Confidence='High'}
    }
    if($hardware -eq $true){return [pscustomobject]@{Category='Physical';Type='Physical hardware interface';Confidence='High'}}
    if($hardware -eq $false){return [pscustomobject]@{Category='Virtual';Type='Software or non-hardware interface';Confidence='Medium'}}
    return [pscustomobject]@{Category='Virtual';Type='Classification unknown; placed with virtual/specialty adapters';Confidence='Low'}
}

function Collect-NetworkSections {
    $sectionName='Network Adapters';$sw=[Diagnostics.Stopwatch]::StartNew();$errors=@();$warnings=@();$physicalItems=@();$virtualItems=@()
    $netQ=if(Get-Command 'Get-NetAdapter' -ErrorAction SilentlyContinue){Invoke-SafeQuery $sectionName 'Get-NetAdapter' {Get-NetAdapter -IncludeHidden -ErrorAction Stop}}else{[pscustomobject]@{Items=@();Status='NotSupported';ErrorMessage='Get-NetAdapter is unavailable.';ExceptionType='CommandNotFoundException';HResult=$null;DurationMs=0;Source='Get-NetAdapter'}}
    $wmiQ=Invoke-CimQuery $sectionName 'Win32_NetworkAdapter'
    $driverQ=Invoke-CimQuery $sectionName 'Win32_PnPSignedDriver' 'root/cimv2' "DeviceClass='NET'"
    foreach($q in @($netQ,$wmiQ,$driverQ)){if($q.Status -ne 'Available'){$errors+=New-SectionError $sectionName $q.Source $q.Status $q.ErrorMessage $q.ExceptionType $q.HResult $q.DurationMs}}
    $adapters=@($netQ.Items)
    if($adapters.Count -eq 0){
        foreach($w in @($wmiQ.Items)){
            $adapters+=[pscustomobject]@{Name=Get-PropertyValue $w 'NetConnectionID';InterfaceDescription=Get-PropertyValue $w 'Name';InterfaceIndex=Get-PropertyValue $w 'InterfaceIndex';Status=$(if((Get-PropertyValue $w 'NetConnectionStatus') -eq 2){'Up'}else{'Disconnected'});LinkSpeed=$null;ReceiveLinkSpeed=$null;TransmitLinkSpeed=$null;MacAddress=Get-PropertyValue $w 'MACAddress';HardwareInterface=Get-PropertyValue $w 'PhysicalAdapter';PnPDeviceID=Get-PropertyValue $w 'PNPDeviceID'}
        }
        if($adapters.Count){$warnings+='Get-NetAdapter was unavailable; Win32_NetworkAdapter fallback was used.'}
    }
    $index=1
    foreach($adapter in $adapters){
        $fields=@();$itemWarnings=@();$name=Get-PropertyValue $adapter 'Name';$desc=Get-PropertyValue $adapter 'InterfaceDescription';$status=[string](Get-PropertyValue $adapter 'Status');$ifIndex=Get-PropertyValue $adapter 'InterfaceIndex';$pnp=Get-PropertyValue $adapter 'PnPDeviceID'
        $classification=Get-NetworkClassification $adapter
        $wmi=@($wmiQ.Items|Where-Object{($pnp -and ([string](Get-PropertyValue $_ 'PNPDeviceID')) -eq [string]$pnp) -or ($ifIndex -and (Get-PropertyValue $_ 'InterfaceIndex') -eq $ifIndex)}|Select-Object -First 1)
        $w=if($wmi.Count){$wmi[0]}else{$null}
        $driver=@($driverQ.Items|Where-Object{ $pnp -and ([string](Get-PropertyValue $_ 'DeviceID')) -eq [string]$pnp }|Select-Object -First 1)
        $d=if($driver.Count){$driver[0]}else{$null}
        $preferred=Get-PropertyValue $adapter 'LinkSpeed';if($null -eq $preferred){$preferred=Get-PropertyValue $adapter 'ReceiveLinkSpeed'}
        $speed=Get-NetworkLinkSpeedResult $preferred (Get-PropertyValue $w 'Speed') $status
        $fields+=New-NumericField 'Adapter Index' $index '' 'Application' 'ReportIndex' -Minimum 1 -Maximum 4096 -Format '0'
        $fields+=New-TextField 'Name' $name 'Get-NetAdapter' 'Name'
        $fields+=New-TextField 'Interface Description' $desc 'Get-NetAdapter' 'InterfaceDescription'
        $manufacturer=Get-PropertyValue $w 'Manufacturer';if(Test-IsPlaceholder $manufacturer){$manufacturer=Get-PropertyValue $d 'Manufacturer'}
        $fields+=New-TextField 'Manufacturer' $manufacturer 'Win32_NetworkAdapter; Win32_PnPSignedDriver fallback' 'Manufacturer' $false $true
        $fields+=New-InventoryField 'Physical or Virtual Classification' "$name $desc" $classification.Type '' 'Application classification rules' 'Name / InterfaceDescription / HardwareInterface' 'Available' $classification.Confidence '' $false $true $classification.Type
        $fields+=New-TextField 'HardwareInterface Flag' (Get-BooleanDisplay (Get-PropertyValue $adapter 'HardwareInterface')) 'Get-NetAdapter' 'HardwareInterface'
        $fields+=New-NumericField 'Interface Index' $ifIndex '' 'Get-NetAdapter' 'InterfaceIndex' -Minimum 0 -Maximum 1000000 -Format '0'
        $fields+=New-TextField 'Operational Status' $status 'Get-NetAdapter' 'Status'
        $media=if($status -match 'Up'){'Connected'}elseif($status){'Disconnected'}else{$null}
        $fields+=New-TextField 'Media Connection State' $media 'Get-NetAdapter' 'Status'
        $fields+=New-TextField 'Physical Media Type' (Get-PropertyValue $adapter 'PhysicalMediaType') 'Get-NetAdapter' 'PhysicalMediaType'
        $fields+=New-InventoryField 'Theoretical Adapter Capability' $null $null 'bits per second' 'Adapter driver properties' 'Maximum capability' 'NotAvailable' 'Unknown' 'The report shows negotiated link speed separately and does not infer maximum capability from it.'
        $fields+=New-InventoryField 'Wi-Fi Standard' $null $null '' 'Native Wi-Fi capability API' 'PHY type' 'NotAvailable' 'Unknown' 'Not reliably exposed by the selected provider on this system.'
        $fields+=New-InventoryField 'Negotiated Link Speed' $speed.BitsPerSecond $speed.BitsPerSecond 'bits per second' $speed.Source 'LinkSpeed / Speed' $speed.Status 'High' '' $false $false $speed.Display
        $fields+=New-TextField 'Driver Version' (Get-PropertyValue $d 'DriverVersion') 'Win32_PnPSignedDriver' 'DriverVersion'
        $driverDateRaw=Get-PropertyValue $d 'DriverDate';$driverDate=Convert-WmiDateSafe $driverDateRaw -DateOnly
        $fields+=New-InventoryField 'Driver Date' $driverDateRaw $driverDate '' 'Win32_PnPSignedDriver' 'DriverDate' $(if($driverDate){'Available'}else{'NotAvailable'}) 'High' '' $false $false $driverDate
        $mac=Get-PropertyValue $adapter 'MacAddress';if(Test-IsPlaceholder $mac){$mac=Get-PropertyValue $w 'MACAddress'}
        $fields+=New-TextField 'MAC Address' $mac 'Get-NetAdapter; Win32_NetworkAdapter fallback' 'MacAddress / MACAddress' $true
        if($script:ReportMode -eq 'Extended' -and -not $script:PrivacyMode -and $ifIndex -and (Get-Command 'Get-NetIPAddress' -ErrorAction SilentlyContinue)){
            try{
                $ips=@(Get-NetIPAddress -InterfaceIndex $ifIndex -ErrorAction Stop|Where-Object{$_.AddressState -eq 'Preferred'}|ForEach-Object{$_.IPAddress})
                $fields+=New-TextField 'IPv4 and IPv6 Addresses' ($ips -join ', ') 'Get-NetIPAddress' 'IPAddress' $true
            }catch{$fields+=New-InventoryField 'IPv4 and IPv6 Addresses' $null $null '' 'Get-NetIPAddress' 'IPAddress' (Get-ExceptionStatus $_.Exception) 'Unknown' (Get-SanitizedErrorMessage $_) $true}
        }else{$fields+=New-InventoryField 'IPv4 and IPv6 Addresses' $null $null '' 'Get-NetIPAddress' 'IPAddress' 'Redacted' 'High' 'Available only in unredacted Extended mode.' $true}
        if($script:ReportMode -eq 'Extended' -and $ifIndex -and (Get-Command 'Get-NetIPInterface' -ErrorAction SilentlyContinue)){
            try{$ipif=Get-NetIPInterface -InterfaceIndex $ifIndex -AddressFamily IPv4 -ErrorAction Stop|Select-Object -First 1;$fields+=New-TextField 'DHCP State' $ipif.Dhcp 'Get-NetIPInterface' 'Dhcp'}catch{$fields+=New-InventoryField 'DHCP State' $null $null '' 'Get-NetIPInterface' 'Dhcp' (Get-ExceptionStatus $_.Exception) 'Unknown' (Get-SanitizedErrorMessage $_)}
        }else{$fields+=New-InventoryField 'DHCP State' $null $null '' 'Get-NetIPInterface' 'Dhcp' 'NotApplicable' 'Unknown' 'Collected only in Extended mode.'}
        $rxErr=Get-PropertyValue $adapter 'ReceivedPacketErrors';$txErr=Get-PropertyValue $adapter 'OutboundPacketErrors';$rxDisc=Get-PropertyValue $adapter 'ReceivedDiscardedPackets';$txDisc=Get-PropertyValue $adapter 'OutboundDiscardedPackets'
        $fields+=New-NumericField 'Received Packet Errors' $rxErr 'packets' 'Get-NetAdapter' 'ReceivedPacketErrors' -Minimum 0 -Maximum ([double]::MaxValue) -Format '0'
        $fields+=New-NumericField 'Outbound Packet Errors' $txErr 'packets' 'Get-NetAdapter' 'OutboundPacketErrors' -Minimum 0 -Maximum ([double]::MaxValue) -Format '0'
        $fields+=New-NumericField 'Received Discarded Packets' $rxDisc 'packets' 'Get-NetAdapter' 'ReceivedDiscardedPackets' -Minimum 0 -Maximum ([double]::MaxValue) -Format '0'
        $fields+=New-NumericField 'Outbound Discarded Packets' $txDisc 'packets' 'Get-NetAdapter' 'OutboundDiscardedPackets' -Minimum 0 -Maximum ([double]::MaxValue) -Format '0'
        $fields+=New-InventoryField 'Internet Speed Test' $null $null '' 'Application policy' 'NetworkPolicy' 'NotApplicable' 'High' 'No internet speed test or external IP lookup is performed.'
        $item=New-InventoryItem -Title "Network Adapter $index" -Index $index -Fields $fields -Warnings $itemWarnings
        if($classification.Category -eq 'Physical'){$physicalItems+=$item}else{$virtualItems+=$item}
        $warnings+=$itemWarnings;$index++
    }
    $sw.Stop()
    $physicalStatus=if($physicalItems.Count){'Available'}elseif($netQ.Status -ne 'Available'){$netQ.Status}else{'NotAvailable'}
    $virtualStatus=if($virtualItems.Count){'Available'}elseif($netQ.Status -ne 'Available'){$netQ.Status}else{'NotAvailable'}
    $resultSections = @()
    $resultSections += New-InventorySection 'Physical Network Adapters' $physicalItems $warnings $errors $sw.ElapsedMilliseconds $physicalStatus
    $resultSections += New-InventorySection 'Virtual Network Adapters' $virtualItems $warnings $errors $sw.ElapsedMilliseconds $virtualStatus
    return $resultSections
}

function Get-AllSectionWarnings {
    param([object[]]$Sections)
    $list=New-Object 'System.Collections.Generic.List[string]'
    foreach($section in @($Sections)){
        foreach($warning in @($section.Warnings)){if(-not [string]::IsNullOrWhiteSpace([string]$warning)){$list.Add([string]$warning)|Out-Null}}
        foreach($item in @($section.Items)){foreach($warning in @($item.Warnings)){if(-not [string]::IsNullOrWhiteSpace([string]$warning)){$list.Add([string]$warning)|Out-Null}}}
    }
    return @($list.ToArray()|Select-Object -Unique)
}

function Get-AllSectionErrors {
    param([object[]]$Sections)
    $list=New-Object 'System.Collections.Generic.List[object]'
    foreach($section in @($Sections)){foreach($error in @($section.Errors)){$list.Add($error)|Out-Null}}
    return $list.ToArray()
}

function Collect-WarningsSection {
    param([object[]]$ExistingSections)
    $warnings=@(Get-AllSectionWarnings $ExistingSections);$errors=@(Get-AllSectionErrors $ExistingSections);$items=@();$index=1
    if($warnings.Count){
        $fields=@();foreach($w in $warnings){$fields+=New-TextField ("Warning $index") $w 'Validation and collection layer' 'Warning';$index++}
        $items+=New-InventoryItem -Title 'Warnings' -Fields $fields
    }else{$items+=New-InventoryItem -Title 'Warnings' -Fields @(New-TextField 'Warnings' 'No section-level warnings were recorded.' 'Validation layer' 'WarningCount')}
    if($errors.Count){
        $fields=@();$index=1
        foreach($e in $errors){
            $display="$($e.Section) | $($e.Source) | $($e.Status) | $($e.Message)"
            $fields+=New-TextField ("Collection Limitation $index") $display 'Structured error collection' 'SectionError';$index++
        }
        $items+=New-InventoryItem -Title 'Collection Limitations' -Fields $fields
    }else{$items+=New-InventoryItem -Title 'Collection Limitations' -Fields @(New-TextField 'Failed Queries' 'None' 'Structured error collection' 'ErrorCount')}
    return New-InventorySection 'Warnings and Collection Limitations' $items $warnings $errors 0 'Available'
}

function Collect-MetadataSection {
    param([datetime]$StartTime,[datetime]$EndTime,[object[]]$Sections)
    $isAdmin=Get-AdminStatus;$success=@($Sections|Where-Object{$_.Status -eq 'Available'}).Count;$warningItems=@(Get-AllSectionWarnings $Sections);$errorItems=@(Get-AllSectionErrors $Sections);$warnings=$warningItems.Count;$errors=$errorItems.Count
    $fields=@()
    $fields+=New-TextField 'Application Name' $script:AppName 'Application' 'AppName'
    $fields+=New-TextField 'Application Version' $script:AppVersion 'Application' 'AppVersion'
    $fields+=New-TextField 'Report Schema Version' $script:SchemaVersion 'Application' 'SchemaVersion'
    $fields+=New-TextField 'Project URL' $script:GitHubUrl 'Application' 'GitHubUrl'
    $fields+=New-TextField 'Collection Time (Local ISO 8601)' $EndTime.ToString('o',[Globalization.CultureInfo]::InvariantCulture) 'Application clock' 'LocalTime'
    $fields+=New-TextField 'Collection Time (UTC)' $EndTime.ToUniversalTime().ToString('o',[Globalization.CultureInfo]::InvariantCulture) 'Application clock' 'UtcTime'
    $fields+=New-TextField 'Computer Name' $env:COMPUTERNAME 'Environment' 'COMPUTERNAME'
    $fields+=New-TextField 'Current Windows User' ([Security.Principal.WindowsIdentity]::GetCurrent().Name) 'Windows identity' 'Name' $true
    $fields+=New-TextField 'Administrator Status' (Get-BooleanDisplay $isAdmin) 'Windows principal' 'Administrator role'
    $fields+=New-TextField 'Process Architecture' (Get-ProcessArchitecture) '.NET RuntimeInformation' 'ProcessArchitecture'
    $fields+=New-TextField 'Operating-System Architecture' (Get-OsArchitecture) '.NET RuntimeInformation' 'OSArchitecture'
    $fields+=New-TextField 'PowerShell or Runtime Version' $PSVersionTable.PSVersion.ToString() 'PowerShell' 'PSVersion'
    $fields+=New-TextField 'PowerShell Edition' (Get-PropertyValue $PSVersionTable 'PSEdition') 'PowerShell' 'PSEdition'
    $fields+=New-TextField 'Report Mode' $script:ReportMode 'Application' 'ReportMode'
    $fields+=New-TextField 'Privacy Mode Status' $(if($script:PrivacyMode){'Enabled'}else{'Disabled'}) 'Application' 'PrivacyMode'
    $duration=[math]::Round(($EndTime-$StartTime).TotalMilliseconds)
    $fields+=New-NumericField 'Collection Duration' $duration 'ms' 'Application stopwatch' 'Duration' -Minimum 0 -Maximum 86400000 -Format '0'
    $fields+=New-NumericField 'Successful Sections' $success 'sections' 'Application summary' 'SuccessCount' -Minimum 0 -Maximum 1000 -Format '0'
    $fields+=New-NumericField 'Warnings' $warnings 'warnings' 'Application summary' 'WarningCount' -Minimum 0 -Maximum 100000 -Format '0'
    $fields+=New-NumericField 'Failed Queries' $errors 'queries' 'Application summary' 'ErrorCount' -Minimum 0 -Maximum 100000 -Format '0'
    return New-InventorySection 'Report Metadata' @(New-InventoryItem -Title 'Metadata' -Fields $fields) @() @() $duration 'Available'
}

function Collect-FooterSection {
    $fields=@(
        New-TextField 'Credit' $script:BrandLine 'Application' 'BrandLine'
        New-TextField 'GitHub Profile' $script:GitHubUrl 'Application' 'GitHubUrl'
    )
    return New-InventorySection 'Footer' @(New-InventoryItem -Title 'Footer' -Fields $fields) @() @() 0 'Available'
}

function Invoke-SystemInventoryCollection {
    param([ValidateSet('Standard','Extended')][string]$ReportMode='Standard',[bool]$PrivacyMode=$true)
    $script:ReportMode=$ReportMode;$script:PrivacyMode=$(if($ReportMode -eq 'Extended'){$PrivacyMode}else{$true});$script:DeveloperLog.Clear()
    $start=Get-Date;$sections=New-Object 'System.Collections.Generic.List[object]'
    $plan=@(
        @{P=2;N='Report Summary';F={Collect-ReportSummarySection $null}},
        @{P=7;N='Computer';F={Collect-ComputerSection}},
        @{P=13;N='Windows';F={Collect-WindowsSection}},
        @{P=19;N='Processor';F={Collect-ProcessorSection}},
        @{P=26;N='Physical Memory';F={Collect-PhysicalMemorySection}},
        @{P=34;N='Graphics Adapters';F={Collect-GraphicsSection}},
        @{P=42;N='Displays and Monitors';F={Collect-DisplaysSection}},
        @{P=47;N='Motherboard';F={Collect-MotherboardSection}},
        @{P=52;N='BIOS and Firmware';F={Collect-BiosSection}},
        @{P=59;N='Security';F={Collect-SecuritySection}},
        @{P=69;N='Physical Storage';F={Collect-PhysicalStorageSection}},
        @{P=77;N='Volumes and Partitions';F={Collect-VolumesSection}},
        @{P=84;N='Battery';F={Collect-BatterySection}}
    )
    foreach($step in $plan){
        Write-InventoryProgress $step.P $step.N
        try{$section=& $step.F;$sections.Add($section)|Out-Null}catch{
            $message=Get-SanitizedErrorMessage $_
            $error=New-SectionError $step.N 'Section collector' (Get-ExceptionStatus $_.Exception) $message $_.Exception.GetType().FullName $_.Exception.HResult 0
            $sections.Add((New-InventorySection $step.N @() @() @($error) 0 'QueryFailed'))|Out-Null
            Write-DeveloperLog 'Error' $step.N 'Section collector' $message $_.Exception
        }
    }
    Write-InventoryProgress 90 'Network Adapters'
    try{foreach($section in @(Collect-NetworkSections)){$sections.Add($section)|Out-Null}}catch{
        $message=Get-SanitizedErrorMessage $_;$error=New-SectionError 'Network Adapters' 'Section collector' (Get-ExceptionStatus $_.Exception) $message $_.Exception.GetType().FullName $_.Exception.HResult 0
        $sections.Add((New-InventorySection 'Physical Network Adapters' @() @() @($error) 0 'QueryFailed'))|Out-Null
        $sections.Add((New-InventorySection 'Virtual Network Adapters' @() @() @($error) 0 'QueryFailed'))|Out-Null
    }
    Write-InventoryProgress 94 'Warnings and Collection Limitations'
    $sectionSnapshot=$sections.ToArray()
    $sections.Add((Collect-WarningsSection $sectionSnapshot))|Out-Null
    $end=Get-Date
    $sectionSnapshot=$sections.ToArray()
    $sections.Add((Collect-MetadataSection $start $end $sectionSnapshot))|Out-Null
    $sections.Add((Collect-FooterSection))|Out-Null
    $sectionSnapshot=$sections.ToArray()
    $allWarnings=@(Get-AllSectionWarnings $sectionSnapshot);$allErrors=@(Get-AllSectionErrors $sectionSnapshot)
    $metadata=[pscustomobject][ordered]@{
        ApplicationName=$script:AppName;ApplicationVersion=$script:AppVersion;SchemaVersion=$script:SchemaVersion
        LocalCollectionTime=$end.ToString('o',[Globalization.CultureInfo]::InvariantCulture)
        UtcCollectionTime=$end.ToUniversalTime().ToString('o',[Globalization.CultureInfo]::InvariantCulture)
        ComputerName=$env:COMPUTERNAME;CurrentUser=$(if($script:PrivacyMode){'[REDACTED]'}else{[Security.Principal.WindowsIdentity]::GetCurrent().Name})
        Administrator=(Get-AdminStatus);ProcessArchitecture=(Get-ProcessArchitecture);OperatingSystemArchitecture=(Get-OsArchitecture)
        RuntimeVersion=$PSVersionTable.PSVersion.ToString();ReportMode=$script:ReportMode;PrivacyMode=$script:PrivacyMode
        CollectionDurationMs=[long](($end-$start).TotalMilliseconds);SuccessfulSections=@($sectionSnapshot|Where-Object{$_.Status -eq 'Available'}).Count
        WarningCount=$allWarnings.Count;FailedQueryCount=$allErrors.Count
    }
    Write-InventoryProgress 97 'Finalizing'
    return [pscustomobject][ordered]@{
        SchemaVersion=$script:SchemaVersion;Application=[pscustomobject][ordered]@{Name=$script:AppName;Version=$script:AppVersion;Credit=$script:BrandLine;GitHub=$script:GitHubUrl}
        Metadata=$metadata;Privacy=[pscustomobject][ordered]@{Enabled=$script:PrivacyMode;SensitiveValuesRedacted=$script:PrivacyMode;Policy='No upload, telemetry, internet lookup, benchmark, or system modification.'}
        SourcePriority=$script:SourcePriority;Sections=$sectionSnapshot;Warnings=@($allWarnings);Errors=@($allErrors)
    }
}

function Convert-FieldToTextValue {
    param([object]$Field)
    $value=[string]$Field.DisplayValue
    if([string]::IsNullOrWhiteSpace($value)){$value=Get-StatusDisplayText $Field.CollectionStatus $Field.ErrorMessage}
    if($Field.IsInferred){$value+=" [Inferred; confidence: $($Field.Confidence); source: $($Field.Source)]"}
    elseif($Field.CollectionStatus -ne 'Available' -and $Field.ErrorMessage){$value+=" [Source: $($Field.Source)]"}
    return $value
}

function Write-TextReport {
    param([object]$Inventory,[string]$Path)
    $lines=New-Object 'System.Collections.Generic.List[string]'
    $lines.Add($script:AppName)|Out-Null;$lines.Add(('='*88))|Out-Null
    $lines.Add("Application Version : $script:AppVersion")|Out-Null
    $lines.Add("Schema Version      : $script:SchemaVersion")|Out-Null
    $lines.Add("Project             : $script:GitHubUrl")|Out-Null
    $lines.Add("Generated           : $($Inventory.Metadata.LocalCollectionTime)")|Out-Null
    $lines.Add("Mode / Privacy      : $($Inventory.Metadata.ReportMode) / $(if($Inventory.Metadata.PrivacyMode){'Enabled'}else{'Disabled'})")|Out-Null
    $lines.Add('')|Out-Null
    foreach($section in @($Inventory.Sections)){
        $lines.Add(('='*88))|Out-Null;$lines.Add($section.Name.ToUpperInvariant())|Out-Null;$lines.Add(('='*88))|Out-Null
        if($section.Status -ne 'Available'){$lines.Add(('Section Status'.PadRight(34)+': '+(Get-StatusDisplayText $section.Status '')))|Out-Null}
        foreach($item in @($section.Items)){
            $lines.Add('')|Out-Null;$lines.Add("[$($item.Title)]")|Out-Null
            foreach($field in @($item.Fields)){
                $label=[string]$field.DisplayName;if($label.Length -gt 32){$label=$label.Substring(0,32)}
                $lines.Add(($label.PadRight(34)+': '+(Convert-FieldToTextValue $field)))|Out-Null
            }
            foreach($warning in @($item.Warnings)){$lines.Add(('Warning'.PadRight(34)+': '+$warning))|Out-Null}
        }
        foreach($warning in @($section.Warnings)){$lines.Add(('Warning'.PadRight(34)+': '+$warning))|Out-Null}
    }
    $lines.Add('')|Out-Null;$lines.Add(('='*88))|Out-Null;$lines.Add($script:BrandLine)|Out-Null;$lines.Add($script:GitHubUrl)|Out-Null
    [IO.File]::WriteAllLines($Path,$lines,(New-Object Text.UTF8Encoding($true)))
}

function Write-JsonReport {
    param([object]$Inventory,[string]$Path)
    $json=$Inventory|ConvertTo-Json -Depth 18
    [IO.File]::WriteAllText($Path,$json,(New-Object Text.UTF8Encoding($false)))
}

function ConvertTo-HtmlEncoded {
    param([AllowNull()][object]$Value)
    if($null -eq $Value){return ''}
    return [Net.WebUtility]::HtmlEncode([string]$Value)
}

function Write-HtmlReport {
    param([object]$Inventory,[string]$Path)
    $sb=New-Object Text.StringBuilder
    [void]$sb.AppendLine('<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">')
    [void]$sb.AppendLine('<title>LouisMahdi System Inspector Report</title><style>:root{color-scheme:dark;--bg:#0d1117;--surface:#161b22;--surface2:#1c2128;--border:#30363d;--green:#3fb950;--green2:#238636;--text:#f0f6fc;--muted:#8b949e;--warning:#d29922}*{box-sizing:border-box}body{font-family:Segoe UI,Arial,sans-serif;margin:0;background:radial-gradient(circle at 15% 0,#12351d 0,transparent 34%),var(--bg);color:var(--text);min-height:100vh}.wrap{max-width:1220px;margin:28px auto;padding:0 20px 88px}.hero{position:relative;overflow:hidden;background:linear-gradient(135deg,#0d1117 0,#17251b 60%,#0d1117 100%);padding:30px 34px;border:1px solid #2ea043;border-radius:16px;box-shadow:0 0 0 1px #3fb95022,0 18px 50px #0008}.hero:before{content:"";position:absolute;inset:0;background-image:linear-gradient(#3fb9500c 1px,transparent 1px),linear-gradient(90deg,#3fb9500c 1px,transparent 1px);background-size:24px 24px;mask-image:linear-gradient(to bottom,#000,transparent)}.hero>*{position:relative}.hero h1{margin:0 0 10px;font-size:30px;letter-spacing:.2px}.accent{color:var(--green)}.meta{color:var(--muted);font-size:14px;line-height:1.65}.project{display:inline-block;margin-top:12px;color:var(--green);text-decoration:none;border:1px solid #2ea043;padding:7px 11px;border-radius:8px;background:#23863618}.project:hover{background:#23863635;box-shadow:0 0 18px #3fb95033}.section{background:linear-gradient(180deg,var(--surface),#11161c);border:1px solid var(--border);border-radius:13px;margin-top:18px;overflow:hidden;box-shadow:0 10px 24px #0004;transition:border-color .2s,transform .2s}.section:hover{border-color:#3fb95088;transform:translateY(-1px)}.section h2{margin:0;padding:15px 19px;background:linear-gradient(90deg,#1f2d23,#161b22);border-bottom:1px solid var(--border);font-size:19px}.item{padding:15px 19px;border-top:1px solid #21262d}.item:first-of-type{border-top:0}.item h3{margin:0 0 11px;font-size:16px;color:var(--green)}.row{display:grid;grid-template-columns:minmax(230px,34%) 1fr;gap:15px;padding:8px 0;border-bottom:1px dotted #30363d}.row:last-child{border-bottom:0}.label{font-weight:600;color:#c9d1d9}.value{word-break:break-word}.status{font-size:12px;color:var(--muted);margin-top:3px}.warn{background:#d2992214;border-left:4px solid var(--warning);padding:9px 12px;margin-top:9px;color:#e3b341}.watermark{position:fixed;right:16px;bottom:12px;background:#161b22e8;color:#fff;padding:8px 12px;border:1px solid #2ea043;border-radius:9px;font-size:12px;box-shadow:0 0 20px #3fb95024}.watermark a{color:var(--green);text-decoration:none}@media(max-width:680px){.row{grid-template-columns:1fr;gap:3px}.hero{padding:24px}.watermark{position:static;margin:18px 20px;text-align:center}}</style></head><body><div class="wrap">')
    [void]$sb.AppendLine("<div class='hero'><h1><span class='accent'>LouisMahdi</span> System Inspector</h1><div class='meta'>Version $(ConvertTo-HtmlEncoded $script:AppVersion) · Schema $(ConvertTo-HtmlEncoded $script:SchemaVersion) · $(ConvertTo-HtmlEncoded $Inventory.Metadata.LocalCollectionTime)</div><div class='meta'>Mode: $(ConvertTo-HtmlEncoded $Inventory.Metadata.ReportMode) · Privacy: $(if($Inventory.Metadata.PrivacyMode){'Enabled'}else{'Disabled'}) · Read-only offline collection</div><a class='project' href='$(ConvertTo-HtmlEncoded $script:GitHubUrl)'>$(ConvertTo-HtmlEncoded $script:GitHubLabel)</a></div>")
    foreach($section in @($Inventory.Sections)){
        [void]$sb.AppendLine("<section class='section'><h2>$(ConvertTo-HtmlEncoded $section.Name)</h2>")
        foreach($item in @($section.Items)){
            [void]$sb.AppendLine("<div class='item'><h3>$(ConvertTo-HtmlEncoded $item.Title)</h3>")
            foreach($field in @($item.Fields)){
                $value=Convert-FieldToTextValue $field
                [void]$sb.AppendLine("<div class='row'><div class='label'>$(ConvertTo-HtmlEncoded $field.DisplayName)</div><div class='value'>$(ConvertTo-HtmlEncoded $value)<div class='status'>Status: $(ConvertTo-HtmlEncoded $field.CollectionStatus) · Source: $(ConvertTo-HtmlEncoded $field.Source)</div></div></div>")
            }
            foreach($warning in @($item.Warnings)){[void]$sb.AppendLine("<div class='warn'>Warning: $(ConvertTo-HtmlEncoded $warning)</div>")}
            [void]$sb.AppendLine('</div>')
        }
        [void]$sb.AppendLine('</section>')
    }
    [void]$sb.AppendLine("</div><div class='watermark'>$(ConvertTo-HtmlEncoded $script:BrandLine) · <a href='$(ConvertTo-HtmlEncoded $script:GitHubUrl)'>$(ConvertTo-HtmlEncoded $script:GitHubLabel)</a></div></body></html>")
    [IO.File]::WriteAllText($Path,$sb.ToString(),(New-Object Text.UTF8Encoding($false)))
}

function Write-DeveloperLogFile {
    param([string]$Path)
    $lines=foreach($entry in $script:DeveloperLog){$entry|ConvertTo-Json -Compress -Depth 8}
    [IO.File]::WriteAllLines($Path,@($lines),(New-Object Text.UTF8Encoding($false)))
}

function Export-SystemInventory {
    param([object]$Inventory,[string]$Directory,[bool]$CreateHtml=$true,[bool]$CreateZip=$true)
    if([string]::IsNullOrWhiteSpace($Directory)){$Directory=[Environment]::GetFolderPath('Desktop')}
    if(-not (Test-Path -LiteralPath $Directory)){New-Item -ItemType Directory -Path $Directory -Force|Out-Null}
    $stamp=Get-Date -Format 'yyyy-MM-dd_HH-mm-ss';$safeName=($env:COMPUTERNAME -replace '[^A-Za-z0-9_-]','_');$folder=Join-Path $Directory "LouisMahdi_System_Report_${safeName}_$stamp"
    New-Item -ItemType Directory -Path $folder -Force|Out-Null
    $txt=Join-Path $folder 'System_Report.txt';$json=Join-Path $folder 'System_Report.json';$html=Join-Path $folder 'System_Report.html';$log=Join-Path $folder 'Developer_Diagnostics.jsonl'
    Write-TextReport $Inventory $txt;Write-JsonReport $Inventory $json
    if($CreateHtml){Write-HtmlReport $Inventory $html}else{$html=$null}
    if($script:RetainDiagnostics){Write-DeveloperLogFile $log}else{$log=$null}
    $zip=$null
    if($CreateZip){$zip="$folder.zip";if(Test-Path $zip){Remove-Item $zip -Force};Compress-Archive -Path (Join-Path $folder '*') -DestinationPath $zip -Force}
    $result=[pscustomobject][ordered]@{Folder=$folder;TextReport=$txt;JsonReport=$json;HtmlReport=$html;DiagnosticLog=$log;ZipFile=$zip}
    $script:LastOutput=$result;return $result
}

function Show-SystemInspectorGui {
    Add-Type -AssemblyName System.Windows.Forms
    Add-Type -AssemblyName System.Drawing
    [Windows.Forms.Application]::EnableVisualStyles()

    $colorBackground=[Drawing.Color]::FromArgb(13,17,23)
    $colorSurface=[Drawing.Color]::FromArgb(22,27,34)
    $colorSurfaceLight=[Drawing.Color]::FromArgb(28,33,40)
    $colorBorder=[Drawing.Color]::FromArgb(48,54,61)
    $colorText=[Drawing.Color]::FromArgb(240,246,252)
    $colorMuted=[Drawing.Color]::FromArgb(139,148,158)
    $colorGreen=[Drawing.Color]::FromArgb(63,185,80)
    $colorGreenDark=[Drawing.Color]::FromArgb(35,134,54)
    $colorGreenHover=[Drawing.Color]::FromArgb(46,160,67)

    $form=New-Object Windows.Forms.Form
    $form.Text="$script:AppName $script:AppVersion"
    $form.StartPosition='CenterScreen'
    $form.Size=New-Object Drawing.Size(780,650)
    $form.MinimumSize=New-Object Drawing.Size(780,650)
    $form.BackColor=$colorBackground
    $form.ForeColor=$colorText
    $form.Font=New-Object Drawing.Font('Segoe UI',9)
    $form.Opacity=1
    $form.ShowInTaskbar=$true
    $form.WindowState='Normal'
    try{if(-not [string]::IsNullOrWhiteSpace($env:LOUISMAHDI_ICON_PATH) -and (Test-Path -LiteralPath $env:LOUISMAHDI_ICON_PATH -PathType Leaf)){$form.Icon=New-Object Drawing.Icon($env:LOUISMAHDI_ICON_PATH)}else{$form.Icon=[Drawing.Icon]::ExtractAssociatedIcon([Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)}}catch{}

    $header=New-Object Windows.Forms.Panel
    $header.Dock='Top'
    $header.Height=116
    $header.BackColor=$colorBackground
    $header.Add_Paint({
        param($sender,$eventArgs)
        $rectangle=$sender.ClientRectangle
        if($rectangle.Width -le 0 -or $rectangle.Height -le 0){return}
        $brush=New-Object Drawing.Drawing2D.LinearGradientBrush($rectangle,[Drawing.Color]::FromArgb(13,17,23),[Drawing.Color]::FromArgb(20,46,27),0)
        $eventArgs.Graphics.FillRectangle($brush,$rectangle)
        $brush.Dispose()
        $pen=New-Object Drawing.Pen([Drawing.Color]::FromArgb(63,185,80),2)
        $eventArgs.Graphics.DrawLine($pen,0,$rectangle.Height-2,$rectangle.Width,$rectangle.Height-2)
        $pen.Dispose()
    })
    $form.Controls.Add($header)

    $logo=New-Object Windows.Forms.Label
    $logo.Text='LM'
    $logo.ForeColor=$colorGreen
    $logo.BackColor=[Drawing.Color]::FromArgb(20,27,23)
    $logo.BorderStyle='FixedSingle'
    $logo.Font=New-Object Drawing.Font('Segoe UI Black',16)
    $logo.TextAlign='MiddleCenter'
    $logo.Location=New-Object Drawing.Point(24,21)
    $logo.Size=New-Object Drawing.Size(66,66)
    $header.Controls.Add($logo)

    $title=New-Object Windows.Forms.Label
    $title.Text=$script:AppName
    $title.ForeColor=$colorText
    $title.Font=New-Object Drawing.Font('Segoe UI Semibold',21)
    $title.AutoSize=$true
    $title.Location=New-Object Drawing.Point(108,18)
    $header.Controls.Add($title)

    $subtitle=New-Object Windows.Forms.Label
    $subtitle.Text='Professional read-only Windows system inventory'
    $subtitle.ForeColor=$colorMuted
    $subtitle.AutoSize=$true
    $subtitle.Location=New-Object Drawing.Point(111,58)
    $header.Controls.Add($subtitle)

    $version=New-Object Windows.Forms.Label
    $version.Text="Version $script:AppVersion"
    $version.ForeColor=$colorGreen
    $version.AutoSize=$true
    $version.Location=New-Object Drawing.Point(111,80)
    $header.Controls.Add($version)

    $panel=New-Object Windows.Forms.Panel
    $panel.Location=New-Object Drawing.Point(24,138)
    $panel.Size=New-Object Drawing.Size(716,385)
    $panel.Anchor='Top,Left,Right'
    $panel.BackColor=$colorSurface
    $panel.Add_Paint({
        param($sender,$eventArgs)
        $rectangle=New-Object Drawing.Rectangle(0,0,[math]::Max(0,$sender.ClientSize.Width-1),[math]::Max(0,$sender.ClientSize.Height-1))
        $pen=New-Object Drawing.Pen([Drawing.Color]::FromArgb(63,185,80),1)
        $eventArgs.Graphics.DrawRectangle($pen,$rectangle)
        $pen.Dispose()
    })
    $form.Controls.Add($panel)

    $modeLabel=New-Object Windows.Forms.Label
    $modeLabel.Text='Report mode'
    $modeLabel.ForeColor=$colorText
    $modeLabel.AutoSize=$true
    $modeLabel.Location=New-Object Drawing.Point(24,25)
    $panel.Controls.Add($modeLabel)

    $modeBox=New-Object Windows.Forms.ComboBox
    $modeBox.DropDownStyle='DropDownList'
    [void]$modeBox.Items.AddRange(@('Standard','Extended'))
    $modeBox.SelectedItem=$script:ReportMode
    $modeBox.Location=New-Object Drawing.Point(166,21)
    $modeBox.Width=190
    $modeBox.BackColor=$colorSurfaceLight
    $modeBox.ForeColor=$colorText
    $modeBox.FlatStyle='Flat'
    $panel.Controls.Add($modeBox)

    $privacy=New-Object Windows.Forms.CheckBox
    $privacy.Text='Enable privacy mode (recommended)'
    $privacy.Checked=$true
    $privacy.AutoSize=$true
    $privacy.ForeColor=$colorText
    $privacy.Location=New-Object Drawing.Point(24,67)
    $panel.Controls.Add($privacy)

    $htmlCheck=New-Object Windows.Forms.CheckBox
    $htmlCheck.Text='Create self-contained HTML report'
    $htmlCheck.Checked=$true
    $htmlCheck.AutoSize=$true
    $htmlCheck.ForeColor=$colorText
    $htmlCheck.Location=New-Object Drawing.Point(24,98)
    $panel.Controls.Add($htmlCheck)

    $diagCheck=New-Object Windows.Forms.CheckBox
    $diagCheck.Text='Retain developer diagnostics'
    $diagCheck.Checked=$false
    $diagCheck.AutoSize=$true
    $diagCheck.ForeColor=$colorText
    $diagCheck.Location=New-Object Drawing.Point(24,129)
    $panel.Controls.Add($diagCheck)

    $folderLabel=New-Object Windows.Forms.Label
    $folderLabel.Text='Output folder'
    $folderLabel.ForeColor=$colorText
    $folderLabel.AutoSize=$true
    $folderLabel.Location=New-Object Drawing.Point(24,170)
    $panel.Controls.Add($folderLabel)

    $folderBox=New-Object Windows.Forms.TextBox
    $folderBox.Text=[Environment]::GetFolderPath('Desktop')
    $folderBox.Location=New-Object Drawing.Point(24,194)
    $folderBox.Width=552
    $folderBox.Anchor='Top,Left,Right'
    $folderBox.BackColor=$colorBackground
    $folderBox.ForeColor=$colorText
    $folderBox.BorderStyle='FixedSingle'
    $panel.Controls.Add($folderBox)

    $browse=New-Object Windows.Forms.Button
    $browse.Text='Browse'
    $browse.Location=New-Object Drawing.Point(588,191)
    $browse.Size=New-Object Drawing.Size(101,30)
    $browse.Anchor='Top,Right'
    $panel.Controls.Add($browse)

    $progress=New-Object Windows.Forms.ProgressBar
    $progress.Location=New-Object Drawing.Point(24,247)
    $progress.Size=New-Object Drawing.Size(665,20)
    $progress.Anchor='Top,Left,Right'
    $progress.Minimum=0
    $progress.Maximum=100
    $progress.Style='Continuous'
    $progress.ForeColor=$colorGreen
    $panel.Controls.Add($progress)

    $statusDot=New-Object Windows.Forms.Label
    $statusDot.Text='●'
    $statusDot.Font=New-Object Drawing.Font('Segoe UI',12)
    $statusDot.ForeColor=$colorGreen
    $statusDot.AutoSize=$true
    $statusDot.Location=New-Object Drawing.Point(24,280)
    $panel.Controls.Add($statusDot)

    $status=New-Object Windows.Forms.Label
    $status.Text='Ready. Collection is offline and no network request is made.'
    $status.ForeColor=$colorMuted
    $status.AutoSize=$false
    $status.Location=New-Object Drawing.Point(48,282)
    $status.Size=New-Object Drawing.Size(641,38)
    $status.Anchor='Top,Left,Right'
    $panel.Controls.Add($status)

    $generate=New-Object Windows.Forms.Button
    $generate.Text='Generate System Report'
    $generate.Font=New-Object Drawing.Font('Segoe UI Semibold',10)
    $generate.Location=New-Object Drawing.Point(24,329)
    $generate.Size=New-Object Drawing.Size(224,38)
    $panel.Controls.Add($generate)

    $open=New-Object Windows.Forms.Button
    $open.Text='Open Last Output'
    $open.Enabled=$false
    $open.Location=New-Object Drawing.Point(260,329)
    $open.Size=New-Object Drawing.Size(158,38)
    $panel.Controls.Add($open)

    $close=New-Object Windows.Forms.Button
    $close.Text='Close'
    $close.Location=New-Object Drawing.Point(565,329)
    $close.Size=New-Object Drawing.Size(124,38)
    $close.Anchor='Top,Right'
    $panel.Controls.Add($close)

    $buttonTheme={
        param($button,[bool]$Primary)
        $button.FlatStyle='Flat'
        $button.FlatAppearance.BorderSize=1
        $button.Cursor='Hand'
        $button.ForeColor=$colorText
        if($Primary){$normal=$colorGreenDark;$hover=$colorGreenHover;$button.FlatAppearance.BorderColor=$colorGreen}else{$normal=$colorSurfaceLight;$hover=[Drawing.Color]::FromArgb(38,44,52);$button.FlatAppearance.BorderColor=$colorBorder}
        $button.BackColor=$normal
        $button.Tag=[pscustomobject]@{Normal=$normal;Hover=$hover}
        $button.Add_MouseEnter({param($sender,$eventArgs)$sender.BackColor=$sender.Tag.Hover})
        $button.Add_MouseLeave({param($sender,$eventArgs)$sender.BackColor=$sender.Tag.Normal})
    }
    & $buttonTheme $generate $true
    & $buttonTheme $open $false
    & $buttonTheme $browse $false
    & $buttonTheme $close $false

    $privacyNote=New-Object Windows.Forms.Label
    $privacyNote.Text='Privacy mode redacts usernames, serial numbers, UUIDs, MAC addresses, IP addresses, SSIDs, and other identifiers.'
    $privacyNote.AutoSize=$false
    $privacyNote.Location=New-Object Drawing.Point(29,541)
    $privacyNote.Size=New-Object Drawing.Size(710,34)
    $privacyNote.ForeColor=$colorMuted
    $privacyNote.Anchor='Left,Right,Bottom'
    $form.Controls.Add($privacyNote)

    $credit=New-Object Windows.Forms.Label
    $credit.Text=$script:BrandLine
    $credit.AutoSize=$true
    $credit.Font=New-Object Drawing.Font('Segoe UI Semibold',9)
    $credit.ForeColor=$colorText
    $credit.Anchor='Left,Bottom'
    $credit.Location=New-Object Drawing.Point(29,592)
    $form.Controls.Add($credit)

    $github=New-Object Windows.Forms.LinkLabel
    $github.Text=$script:GitHubLabel
    $github.AutoSize=$true
    $github.Font=New-Object Drawing.Font('Segoe UI Semibold',9)
    $github.LinkColor=$colorGreen
    $github.ActiveLinkColor=[Drawing.Color]::FromArgb(86,211,100)
    $github.VisitedLinkColor=$colorGreen
    $github.LinkBehavior='HoverUnderline'
    $github.Cursor='Hand'
    $github.Anchor='Right,Bottom'
    $github.Location=New-Object Drawing.Point(568,592)
    $form.Controls.Add($github)

    $toolTip=New-Object Windows.Forms.ToolTip
    $toolTip.SetToolTip($github,'Open the LouisMahdi GitHub profile in your default browser')

    $form.Add_Shown({
        param($sender,$eventArgs)
        $sender.Opacity=1
        $sender.ShowInTaskbar=$true
        $sender.WindowState='Normal'
        $sender.Activate()
        $sender.BringToFront()
    })

    $pulseTimer=New-Object Windows.Forms.Timer
    $pulseTimer.Interval=650
    $pulseTimer.Tag=[pscustomobject]@{Dot=$statusDot;Bright=$true;Green=$colorGreen;Dim=[Drawing.Color]::FromArgb(35,134,54)}
    $pulseTimer.Add_Tick({
        param($sender,$eventArgs)
        if($sender.Tag.Bright){$sender.Tag.Dot.ForeColor=$sender.Tag.Dim;$sender.Tag.Bright=$false}else{$sender.Tag.Dot.ForeColor=$sender.Tag.Green;$sender.Tag.Bright=$true}
    })
    $pulseTimer.Start()

    $browse.Add_Click({$dialog=New-Object Windows.Forms.FolderBrowserDialog;$dialog.Description='Choose where reports will be saved';$dialog.SelectedPath=$folderBox.Text;if($dialog.ShowDialog() -eq 'OK'){$folderBox.Text=$dialog.SelectedPath}})
    $close.Add_Click({$form.Close()})
    $open.Add_Click({if($script:LastOutput -and (Test-Path $script:LastOutput.Folder)){Start-Process explorer.exe $script:LastOutput.Folder}})
    $github.Add_LinkClicked({try{Start-Process $script:GitHubUrl}catch{[Windows.Forms.MessageBox]::Show("Unable to open $script:GitHubUrl",$script:AppName,'OK','Warning')|Out-Null}})
    $form.Add_FormClosed({$pulseTimer.Stop();$pulseTimer.Dispose()})
    $generate.Add_Click({
        $generate.Enabled=$false;$open.Enabled=$false;$progress.Value=0;$status.Text='Starting collection...';$form.UseWaitCursor=$true
        $script:RetainDiagnostics=$diagCheck.Checked
        Set-InventoryProgressCallback {
            param($percent,$section)
            $progress.Value=[math]::Min(100,[math]::Max(0,[int]$percent));$status.Text="Collecting: $section";[Windows.Forms.Application]::DoEvents()
        }
        try{
            $effectivePrivacy=$privacy.Checked -or ([string]$modeBox.SelectedItem -eq 'Standard')
            $inventory=Invoke-SystemInventoryCollection -ReportMode ([string]$modeBox.SelectedItem) -PrivacyMode $effectivePrivacy
            $status.Text='Writing reports...';$progress.Value=98;[Windows.Forms.Application]::DoEvents()
            $result=Export-SystemInventory $inventory $folderBox.Text $htmlCheck.Checked $true
            $progress.Value=100;$status.Text="Completed. ZIP: $($result.ZipFile)";$open.Enabled=$true
            [Windows.Forms.MessageBox]::Show("Report created successfully.`r`n`r`n$($result.ZipFile)",$script:AppName,'OK','Information')|Out-Null
        }catch{
            $message=Get-SanitizedErrorMessage $_;$status.Text="Failed: $message";[Windows.Forms.MessageBox]::Show($message,$script:AppName,'OK','Error')|Out-Null
        }finally{$generate.Enabled=$true;$form.UseWaitCursor=$false;Set-InventoryProgressCallback $null}
    })
    $form.Opacity=1
    $form.ShowInTaskbar=$true
    $form.WindowState='Normal'
    [void]$form.ShowDialog()
}

function Invoke-CommandLineMode {
    $privacy=$(if($Mode -eq 'Extended'){-not $DisablePrivacy}else{$true})
    $inventory=Invoke-SystemInventoryCollection -ReportMode $Mode -PrivacyMode $privacy
    $dir=if([string]::IsNullOrWhiteSpace($OutputDirectory)){[Environment]::GetFolderPath('Desktop')}else{$OutputDirectory}
    $result=Export-SystemInventory $inventory $dir ([bool]$IncludeHtml) $true
    Write-Output "Report created: $($result.ZipFile)"
    if($OpenOutput){Start-Process explorer.exe $result.Folder}
}

if(-not $LibraryOnly){
    if($NoGui){Invoke-CommandLineMode}else{Show-SystemInspectorGui}
}
