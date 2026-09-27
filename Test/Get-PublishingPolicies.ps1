#requires -Version 5.1
<#
.SYNOPSIS
    Exportiert alle Sensitivity-Label-Publishing-Policies als CSV.

.DESCRIPTION
    Liest Get-LabelPolicy aus, wertet die AdvancedSettings aus (inkl. Pflicht-
    und Standardlabel) und uebersetzt Label-GUIDs in Labelnamen.

.EXAMPLE
    .\Get-PublishingPolicies.ps1 -UserPrincipalName admin@contoso.com
#>
[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [ValidateNotNullOrEmpty()]
    [string]$CsvPath = (Join-Path -Path (Get-Location) -ChildPath 'SensitivityLabelPublishingPolicies.csv'),

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Get-PublishingPolicies-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../Modules/PurviewSetup/PurviewSetup.psd1') -Force
$LogFile = Initialize-PurviewLog -Path $LogPath -FileName 'Get-PublishingPolicies.log'

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

    $items = if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) { @($Value) } else { @($Value) }
    return (@($items | ForEach-Object {
        $displayProperty = $_.PSObject.Properties['DisplayName']
        $nameProperty = $_.PSObject.Properties['Name']
        if ($null -ne $displayProperty -and $displayProperty.Value) { [string]$displayProperty.Value }
        elseif ($null -ne $nameProperty -and $nameProperty.Value) { [string]$nameProperty.Value }
        else { [string]$_ }
    }) -join '; ')
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

    return (@($locations) -join ' | ')
}

$connected = $false
try {
    Write-PurviewLog "Logdatei: $LogFile"

    if ($UserPrincipalName) {
        Connect-IPPSSession -UserPrincipalName $UserPrincipalName -ErrorAction Stop
    } else {
        Connect-IPPSSession -ErrorAction Stop
    }
    $connected = $true

    Write-PurviewLog 'Publishing-Policies und Labels werden gelesen.'
    $sensitivityPolicies = @(Get-LabelPolicy -ErrorAction Stop)

    # Label-GUIDs aus defaultlabelid/outlookdefaultlabel in lesbare Namen uebersetzen.
    $labelNamesById = Get-PurviewLabelNameMap -Labels @(Get-Label -ErrorAction Stop)

    $exportRows = foreach ($policy in $sensitivityPolicies) {
        $policySettings = Get-PurviewPolicySetting -Policy $policy
        $defaultLabelId = if ($policySettings.Contains('defaultlabelid')) { [string]$policySettings['defaultlabelid'] } else { '' }
        $outlookDefaultId = if ($policySettings.Contains('outlookdefaultlabel')) { [string]$policySettings['outlookdefaultlabel'] } else { '' }

        [PSCustomObject]@{
            PolicyName              = [string]$policy.Name
            LabelsPublished         = Convert-ToCsvValue -Value (Get-OptionalPropertyValue -InputObject $policy -PropertyName 'Labels')
            PublishedTo             = Get-ConfiguredLocationText -Policy $policy
            Mandatory               = if ($policySettings.Contains('mandatory')) { [string]$policySettings['mandatory'] } else { '' }
            DefaultLabelId          = $defaultLabelId
            DefaultLabel            = if ($labelNamesById.ContainsKey($defaultLabelId)) { $labelNamesById[$defaultLabelId] } else { '' }
            OutlookDefaultLabel     = if ($labelNamesById.ContainsKey($outlookDefaultId)) { $labelNamesById[$outlookDefaultId] } else { $outlookDefaultId }
            PolicySettings          = (@($policySettings.GetEnumerator() | ForEach-Object { '{0}={1}' -f $_.Key, $_.Value }) -join '; ')
            PolicyConfigurationJson = ($policy | ConvertTo-Json -Compress -Depth 10)
        }
    }

    foreach ($row in @($exportRows)) {
        $row | Format-List
    }

    $csvDirectory = Split-Path -Parent $CsvPath
    if ($csvDirectory) {
        New-Item -ItemType Directory -Path $csvDirectory -Force | Out-Null
    }
    @($exportRows) | Export-Csv -LiteralPath $CsvPath -NoTypeInformation -Encoding UTF8
    Write-PurviewLog -Level OK -Message ("{0} Publishing-Policies exportiert nach: {1}" -f @($exportRows).Count, $CsvPath)
}
catch {
    Write-PurviewLog -Level ERROR -Message $_.Exception.Message
    throw
}
finally {
    if ($connected) {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    }
}
