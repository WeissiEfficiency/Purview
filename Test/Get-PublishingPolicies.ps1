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

New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
$LogFile = Join-Path $LogPath 'Get-PublishingPolicies.log'

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'OK')][string]$Level = 'INFO'
    )

    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}

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

function Get-PolicySetting {
    param([Parameter(Mandatory = $true)]$Policy)

    # Get-LabelPolicy liefert Settings je nach Modulversion als Eintraege der Form
    # "[key, value]" oder als XML (<setting key=".." value=".." />). Beides auswerten.
    $settings = [ordered]@{}
    foreach ($entry in @(Get-OptionalPropertyValue -InputObject $Policy -PropertyName 'Settings')) {
        $text = [string]$entry
        if ([string]::IsNullOrWhiteSpace($text)) { continue }

        if ($text -match '^\s*\[(?<key>[^,\]]+),\s*(?<value>.*)\]\s*$') {
            $settings[$Matches['key'].Trim().ToLowerInvariant()] = $Matches['value'].Trim()
            continue
        }

        if ($text.TrimStart().StartsWith('<')) {
            try {
                foreach ($setting in @(([xml]$text).SelectNodes('//setting'))) {
                    if ($setting.key) { $settings[([string]$setting.key).ToLowerInvariant()] = [string]$setting.value }
                }
            } catch {
                $settings['_parseerror'] = $_.Exception.Message
            }
            continue
        }

        $settings['_unparsed'] = (@($settings['_unparsed'], $text) | Where-Object { $_ }) -join ' | '
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

    return (@($locations) -join ' | ')
}

$connected = $false
try {
    Write-Log -Message "Logpfad: $LogPath"

    if ($UserPrincipalName) {
        Connect-IPPSSession -UserPrincipalName $UserPrincipalName -ErrorAction Stop
    } else {
        Connect-IPPSSession -ErrorAction Stop
    }
    $connected = $true

    Write-Log -Message 'Publishing-Policies und Labels werden gelesen.'
    $sensitivityPolicies = @(Get-LabelPolicy -ErrorAction Stop)

    # Label-GUIDs aus defaultlabelid/outlookdefaultlabel in lesbare Namen uebersetzen.
    $labelNamesById = @{}
    foreach ($label in @(Get-Label -ErrorAction Stop)) {
        foreach ($idProperty in @('ImmutableId', 'Guid')) {
            $id = [string](Get-OptionalPropertyValue -InputObject $label -PropertyName $idProperty)
            if ($id) { $labelNamesById[$id] = [string]$label.Name }
        }
    }

    $exportRows = foreach ($policy in $sensitivityPolicies) {
        $policySettings = Get-PolicySetting -Policy $policy
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
    Write-Log -Level OK -Message ("{0} Publishing-Policies exportiert nach: {1}" -f @($exportRows).Count, $CsvPath)
}
catch {
    Write-Log -Level ERROR -Message $_.Exception.Message
    throw
}
finally {
    if ($connected) {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    }
}
