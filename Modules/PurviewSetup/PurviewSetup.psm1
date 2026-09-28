# Gemeinsame Funktionen für die Skripte in "Main Setup" und "Test":
# Logging, Verbindung, Konfiguration, Auswertung von Policy-Settings und
# Soll/Ist-Vergleich. Wird von jedem Skript mit Import-Module -Force geladen.
Set-StrictMode -Version Latest

#region Logging
function Initialize-PurviewLog {
    <#
    .SYNOPSIS
        Legt den Logordner an und gibt den Pfad der Logdatei zurück.
    .DESCRIPTION
        Das aufrufende Skript speichert das Ergebnis in $LogFile. Write-PurviewLog
        findet diese Variable über den Scope des Aufrufers; das funktioniert auch,
        wenn Skripte verschachtelt oder per Dot-Sourcing laufen.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$FileName
    )

    New-Item -ItemType Directory -Path $Path -Force | Out-Null
    return (Join-Path -Path $Path -ChildPath $FileName)
}

function Write-PurviewLog {
    <#
    .SYNOPSIS
        Schreibt eine Logzeile auf die Konsole und in $LogFile des Aufrufers.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'OK')][string]$Level = 'INFO'
    )

    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line

    $logFile = $PSCmdlet.SessionState.PSVariable.GetValue('LogFile')
    if (-not [string]::IsNullOrWhiteSpace([string]$logFile)) {
        Add-Content -LiteralPath $logFile -Value $line -Encoding UTF8
    }
}
#endregion Logging

#region Configuration
function Import-PurviewConfig {
    <#
    .SYNOPSIS
        Lädt die Tenant-Konfiguration (Standard: config/tenant.psd1) und prüft sie.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        $Path = Join-Path -Path $PSScriptRoot -ChildPath '../../config/tenant.psd1'
    }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Konfigurationsdatei nicht gefunden: $Path"
    }

    $config = Import-PowerShellDataFile -LiteralPath $Path
    foreach ($key in @('IncidentReportRecipient', 'EncryptionTemplate', 'ProtonDomains', 'CustomHelpUrl', 'Groups')) {
        if (-not $config.ContainsKey($key) -or $null -eq $config[$key]) {
            throw "Konfiguration '$Path': Schlüssel '$key' fehlt."
        }
    }
    foreach ($group in @('Legal', 'Finance', 'Leadership')) {
        if (-not $config.Groups.ContainsKey($group)) {
            throw "Konfiguration '$Path': Gruppe '$group' fehlt unter Groups."
        }
        $entry = $config.Groups[$group]
        if ([string]::IsNullOrWhiteSpace([string]$entry.Identity) -or $entry.Kind -notin @('Exchange', 'ModernGroup')) {
            throw "Konfiguration '$Path': Gruppe '$group' braucht Identity und Kind ('Exchange' oder 'ModernGroup')."
        }
    }
    if (-not $config.ContainsKey('DisableWam')) { $config.DisableWam = $false }

    return $config
}
#endregion Configuration

#region Connection
function Connect-PurviewSession {
    <#
    .SYNOPSIS
        Stellt eine Security-&-Compliance-Verbindung her, falls noch keine besteht.
    .DESCRIPTION
        Gibt $true zurück, wenn danach eine Verbindung besteht. Ohne -Required und
        ohne UPN wird keine neue Verbindung aufgebaut (Vorschau ohne Anmeldung).
        Eine bestehende Sitzung wird wiederverwendet, damit der Orchestrator nur
        einmal nach Anmeldedaten fragt.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string]$UserPrincipalName,
        [switch]$Required,
        [switch]$DisableWam
    )

    if (Get-Command -Name Get-Label -ErrorAction SilentlyContinue) {
        return $true
    }
    if (-not $Required -and [string]::IsNullOrWhiteSpace($UserPrincipalName)) {
        return $false
    }

    $connectParams = @{ ErrorAction = 'Stop' }
    if (-not [string]::IsNullOrWhiteSpace($UserPrincipalName)) { $connectParams.UserPrincipalName = $UserPrincipalName }
    if ($DisableWam) { $connectParams.DisableWAM = $true }
    Connect-IPPSSession @connectParams
    return $true
}
#endregion Connection

#region Labels and settings
function Resolve-PurviewLabelId {
    <#
    .SYNOPSIS
        Übersetzt einen Labelnamen in die GUID (ImmutableId), die AdvancedSettings erwarten.
    .DESCRIPTION
        Sucht nur über den eindeutigen Namen: Anzeigenamen wie 'Intern' kommen in
        mehreren Labelgruppen vor.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$LabelName,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Labels
    )

    $label = $Labels | Where-Object { [string]$_.Name -eq $LabelName } | Select-Object -First 1
    if ($null -eq $label) {
        throw "Sensitivity label '$LabelName' wurde im Tenant nicht gefunden."
    }
    foreach ($idProperty in @('ImmutableId', 'Guid')) {
        $property = $label.PSObject.Properties[$idProperty]
        if ($null -ne $property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return [string]$property.Value
        }
    }
    throw "Sensitivity label '$LabelName' hat keine GUID."
}

function Get-PurviewLabelNameMap {
    <#
    .SYNOPSIS
        Liefert eine Zuordnung GUID/Name -> Labelname für alle Labels.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Labels)

    $map = @{}
    foreach ($label in $Labels) {
        $name = [string]$label.Name
        $map[$name] = $name
        foreach ($idProperty in @('ImmutableId', 'Guid')) {
            $property = $label.PSObject.Properties[$idProperty]
            if ($null -ne $property -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
                $map[[string]$property.Value] = $name
            }
        }
    }
    return $map
}

function Get-PurviewPolicySetting {
    <#
    .SYNOPSIS
        Wertet die Settings einer Publishing Policy aus (Get-LabelPolicy).
    .DESCRIPTION
        Je nach Modulversion kommen die Einträge als "[key, value]" oder als XML
        (<setting key=".." value=".." />). Schlüssel werden kleingeschrieben.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param([Parameter(Mandatory = $true)]$Policy)

    $settings = [ordered]@{}
    $property = $Policy.PSObject.Properties['Settings']
    if ($null -eq $property) { return $settings }

    foreach ($entry in @($property.Value)) {
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
function Resolve-PurviewSensitiveInfoType {
    <#
    .SYNOPSIS
        Ordnet die konfigurierten Sensitive Information Types den Typen im Tenant zu.
    .DESCRIPTION
        Ein Eintrag passt, wenn er dem Namen oder der GUID (Id) eines Typs aus
        Get-DlpSensitiveInformationType entspricht. Die Namen können je nach
        Sitzungssprache lokalisiert sein; die GUID ist sprachunabhängig.
        Gibt Found (Tenant-Namen) und Missing (nicht gefundene Einträge) zurück.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)][string[]]$Name,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Types
    )

    $found = [System.Collections.Generic.List[string]]::new()
    $missing = [System.Collections.Generic.List[string]]::new()
    foreach ($entry in $Name) {
        $match = $Types | Where-Object { [string]$_.Name -eq $entry -or [string]$_.Id -eq $entry } | Select-Object -First 1
        if ($null -eq $match) { $missing.Add($entry) } else { $found.Add([string]$match.Name) }
    }
    return [pscustomobject]@{ Found = @($found); Missing = @($missing) }
}
#endregion Labels and settings

#region Desired state
function ConvertTo-PurviewComparableValue {
    <#
    .SYNOPSIS
        Normalisiert Werte für den Soll/Ist-Vergleich (Groß-/Kleinschreibung,
        Reihenfolge von Listen, "a, b" vs. @('a','b'), $true vs. 'true').
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()]$Value)

    if ($null -eq $Value) { return '' }

    $items = [System.Collections.Generic.List[string]]::new()
    $values = if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) { @($Value) } else { @($Value) }
    foreach ($item in $values) {
        if ($null -eq $item) { continue }
        foreach ($part in ([string]$item -split ',')) {
            $trimmed = $part.Trim().ToLowerInvariant()
            if ($trimmed) { $items.Add($trimmed) }
        }
    }
    return ((@($items) | Sort-Object) -join ';')
}

function Compare-PurviewDesiredState {
    <#
    .SYNOPSIS
        Vergleicht ausgewählte Soll-Werte mit einem vorhandenen Tenant-Objekt.
    .DESCRIPTION
        Gibt je Abweichung ein Objekt mit Property, Desired und Actual zurück.
        Eigenschaften, die das Tenant-Objekt nicht liefert, werden übersprungen,
        weil sie sich nicht zuverlässig vergleichen lassen.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)][System.Collections.IDictionary]$Desired,
        [Parameter(Mandatory = $true)]$Actual,
        [Parameter(Mandatory = $true)][string[]]$Property
    )

    foreach ($name in $Property) {
        if (-not $Desired.Contains($name)) { continue }
        $actualProperty = $Actual.PSObject.Properties[$name]
        if ($null -eq $actualProperty) { continue }

        $desiredValue = ConvertTo-PurviewComparableValue -Value $Desired[$name]
        $actualValue = ConvertTo-PurviewComparableValue -Value $actualProperty.Value
        if ($desiredValue -ne $actualValue) {
            # Vergleich normalisiert, Ausgabe mit den Originalwerten.
            [pscustomobject]@{
                Property = $name
                Desired  = (@($Desired[$name]) | ForEach-Object { [string]$_ }) -join ', '
                Actual   = (@($actualProperty.Value) | Where-Object { $null -ne $_ } | ForEach-Object { [string]$_ }) -join ', '
            }
        }
    }
}

function Format-PurviewDrift {
    <#
    .SYNOPSIS
        Formatiert Abweichungen aus Compare-PurviewDesiredState für das Log.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Drift)

    return ((@($Drift) | ForEach-Object { "{0}: Ist '{1}', Soll '{2}'" -f $_.Property, $_.Actual, $_.Desired }) -join '; ')
}
#endregion Desired state

Export-ModuleMember -Function @(
    'Initialize-PurviewLog', 'Write-PurviewLog', 'Import-PurviewConfig', 'Connect-PurviewSession',
    'Resolve-PurviewLabelId', 'Get-PurviewLabelNameMap', 'Get-PurviewPolicySetting', 'Resolve-PurviewSensitiveInfoType',
    'ConvertTo-PurviewComparableValue', 'Compare-PurviewDesiredState', 'Format-PurviewDrift'
)
