[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [ValidateNotNullOrEmpty()]
    [string]$CsvPath = (Join-Path -Path (Get-Location) -ChildPath 'SensitivityLabelPublishingPolicies.csv'),

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Get-PublishingPolicies-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
$LogFile = Join-Path $LogPath 'Get-PublishingPolicies.log'

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'OK')][string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = '[{0}] [{1}] {2}' -f $timestamp, $Level, $Message
    Write-Host $line
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}

Write-Log -Message "Logpfad: $LogPath"

# 1. Connect to Microsoft Purview Security & Compliance PowerShell
if ($UserPrincipalName) {
    Connect-IPPSSession -UserPrincipalName $UserPrincipalName -ErrorAction Stop
} else {
    Connect-IPPSSession -ErrorAction Stop
}

Write-Log -Message '=== FETCHING SENSITIVITY LABEL PUBLISHING POLICIES ==='
# Retrieve all sensitivity label publishing policies
$SensitivityPolicies = @(Get-LabelPolicy -ErrorAction Stop)

function Get-OptionalPropertyValue {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$PropertyName
    )

    $property = $InputObject.PSObject.Properties[$PropertyName]
    if ($null -ne $property) {
        return $property.Value
    }

    return $null
}

function Convert-ToCsvValue {
    param([AllowNull()]$Value)

    if ($null -eq $Value) {
        return ''
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return (($Value | ForEach-Object {
            $displayProperty = $_.PSObject.Properties['DisplayName']
            $nameProperty = $_.PSObject.Properties['Name']
            if ($null -ne $displayProperty -and $displayProperty.Value) { [string]$displayProperty.Value }
            elseif ($null -ne $nameProperty -and $nameProperty.Value) { [string]$nameProperty.Value }
            else { [string]$_ }
        }) -join '; ')
    }

    $displayProperty = $Value.PSObject.Properties['DisplayName']
    $nameProperty = $Value.PSObject.Properties['Name']
    if ($null -ne $displayProperty -and $displayProperty.Value) { return [string]$displayProperty.Value }
    if ($null -ne $nameProperty -and $nameProperty.Value) { return [string]$nameProperty.Value }

    return [string]$Value
}

function Get-PolicySettings {
    param([Parameter(Mandatory = $true)]$Policy)

    $settingsValue = Get-OptionalPropertyValue -InputObject $Policy -PropertyName 'Settings'
    $settings = [ordered]@{}
    if ([string]::IsNullOrWhiteSpace([string]$settingsValue)) {
        return $settings
    }

    try {
        $settingsXml = [xml](($settingsValue | ForEach-Object { [string]$_ }) -join '')
        foreach ($setting in @($settingsXml.SelectNodes('//setting'))) {
            if ($setting.key) {
                $settings[[string]$setting.key] = [string]$setting.value
            }
        }
    } catch {
        $settings['_parseError'] = $_.Exception.Message
    }

    return $settings
}

function Get-ConfiguredLocationText {
    param([Parameter(Mandatory = $true)]$Policy)

    $locations = foreach ($property in $Policy.PSObject.Properties) {
        if ($property.Name -match 'Location$' -and $null -ne $property.Value) {
            $value = Convert-ToCsvValue -Value $property.Value
            if (-not [string]::IsNullOrWhiteSpace($value)) {
                '{0}: {1}' -f $property.Name, $value
            }
        }
    }

    return ($locations -join ' | ')
}

$ExportRows = foreach ($policy in $SensitivityPolicies) {
    $defaultLabel = Get-OptionalPropertyValue -InputObject $policy -PropertyName 'DefaultLabel'
    $mandatory = Get-OptionalPropertyValue -InputObject $policy -PropertyName 'Mandatory'
    $policySettings = Get-PolicySettings -Policy $policy
    $defaultLabelId = if ($policySettings.Contains('defaultlabelid')) { $policySettings['defaultlabelid'] } else { '' }
    $mandatorySettings = @($policySettings.GetEnumerator() | Where-Object { $_.Key -match 'mandatory' } | ForEach-Object { '{0}={1}' -f $_.Key, $_.Value }) -join '; '

    [PSCustomObject]@{
        PolicyName               = $policy.Name
        LabelsPublished          = Convert-ToCsvValue -Value $policy.Labels
        PublishedTo              = Get-ConfiguredLocationText -Policy $policy
        TargetGroupsUsers        = Convert-ToCsvValue -Value $policy.ExchangeLocation
        Workloads                = Convert-ToCsvValue -Value $policy.Workload
        Mandatory                = Convert-ToCsvValue -Value $mandatory
        MandatoryConfigured      = ($null -ne $mandatory)
        DefaultLabel             = Convert-ToCsvValue -Value $defaultLabel
        DefaultLabelConfigured   = ($null -ne $defaultLabel)
        DefaultLabelId           = $defaultLabelId
        MandatorySettings        = $mandatorySettings
        PolicySettings           = ($policySettings.GetEnumerator() | ForEach-Object { '{0}={1}' -f $_.Key, $_.Value }) -join '; '
        PolicyConfigurationJson  = ($policy | ConvertTo-Json -Compress -Depth 10)
    }
}

foreach ($row in $ExportRows) {
    $row | Format-List
}

$CsvDirectory = Split-Path -Parent $CsvPath
if ($CsvDirectory) {
    New-Item -ItemType Directory -Path $CsvDirectory -Force | Out-Null
}
$ExportRows | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8
Write-Log -Level OK -Message "CSV exportiert nach: $CsvPath"

# Always disconnect your session when done
Disconnect-ExchangeOnline -Confirm:$false
