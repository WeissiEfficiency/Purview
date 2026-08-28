#requires -Version 5.1
<#
.SYNOPSIS
    Entfernt tenantweit Purview DLP-Policies, Sensitivity-Label-Publishing-Policies
    und anschließend alle über Security & Compliance PowerShell verwaltbaren
    Sensitivity Labels.

.DESCRIPTION
    Hochdestruktives Cleanup-Skript mit folgenden Schutzmaßnahmen:
    - Standardmäßig nur Inventarisierung, keine Löschung.
    - Für die Löschung sind -Execute und eine exakte Bestätigungsphrase erforderlich.
    - Vorheriger Export der gefundenen Objekte als CLIXML, JSON und CSV.
    - Abhängigkeitsgerechte Reihenfolge: DLP-Policies -> Publishing-Policies -> Labels.
    - Wiederholungsversuche und abschließende Verifikation.

    Hinweis: Das Entfernen einer Labeldefinition entfernt das Label nicht aus bereits
    gekennzeichneten Inhalten und hebt bestehende Schutz-/Verschlüsselungseinstellungen
    auf diesen Inhalten nicht automatisch auf.

.EXAMPLE
    .\Remove-AllPurviewLabelsAndPolicies.ps1 -UserPrincipalName admin@contoso.com

    Erstellt nur Inventar und Backup. Es wird nichts gelöscht.

.EXAMPLE
    .\Remove-AllPurviewLabelsAndPolicies.ps1 `
        -UserPrincipalName admin@contoso.com `
        -Execute `
        -ConfirmationText "DELETE ALL PURVIEW POLICIES AND LABELS"

    Führt die tenantweite Löschung aus.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$UserPrincipalName,

    [switch]$Execute,

    [string]$ConfirmationText,

    [ValidateRange(1, 20)]
    [int]$MaxAttempts = 6,

    [ValidateRange(1, 300)]
    [int]$RetryDelaySeconds = 20,

    [ValidateNotNullOrEmpty()]
    [string]$BackupPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\PurviewCleanup-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$RequiredPhrase = 'DELETE ALL PURVIEW POLICIES AND LABELS'
$script:DeletionResults = [System.Collections.Generic.List[object]]::new()

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO','WARN','ERROR','OK')][string]$Level = 'INFO'
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $line = '[{0}] [{1}] {2}' -f $timestamp, $Level, $Message
    Write-Host $line

    if (Test-Path -LiteralPath $BackupPath) {
        Add-Content -LiteralPath (Join-Path $BackupPath 'PurviewCleanup.log') -Value $line -Encoding UTF8
    }
}

function Get-ObjectIdentity {
    param([Parameter(Mandatory = $true)]$InputObject)

    foreach ($propertyName in 'Guid','ImmutableId','Id','Identity','Name') {
        $property = $InputObject.PSObject.Properties[$propertyName]
        if ($null -ne $property -and $null -ne $property.Value -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return [string]$property.Value
        }
    }

    throw 'Für das Objekt konnte keine eindeutige Identität ermittelt werden.'
}

function Get-ObjectDisplayName {
    param([Parameter(Mandatory = $true)]$InputObject)

    foreach ($propertyName in 'DisplayName','Name','Identity','Guid','Id') {
        $property = $InputObject.PSObject.Properties[$propertyName]
        if ($null -ne $property -and $null -ne $property.Value -and -not [string]::IsNullOrWhiteSpace([string]$property.Value)) {
            return [string]$property.Value
        }
    }

    return '<unbekannt>'
}

function Export-Inventory {
    param(
        [Parameter(Mandatory = $true)][string]$BaseName,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][array]$InputObjects
    )

    $clixmlPath = Join-Path $BackupPath ("{0}.clixml" -f $BaseName)
    $jsonPath   = Join-Path $BackupPath ("{0}.json" -f $BaseName)
    $csvPath    = Join-Path $BackupPath ("{0}.csv" -f $BaseName)

    @($InputObjects) | Export-Clixml -LiteralPath $clixmlPath -Depth 8
    @($InputObjects) | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $jsonPath -Encoding UTF8
    @($InputObjects) |
        Select-Object Name, DisplayName, Guid, ImmutableId, Id, Identity, ParentId, ContentType, Mode, Enabled |
        Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8
}

function Invoke-RemoveObject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$ObjectType,
        [Parameter(Mandatory = $true)][string]$RemoveCommand,
        [ValidateRange(1, 20)][int]$Attempts = $MaxAttempts
    )

    $identity = Get-ObjectIdentity -InputObject $InputObject
    $displayName = Get-ObjectDisplayName -InputObject $InputObject
    $lastError = $null

    for ($attempt = 1; $attempt -le $Attempts; $attempt++) {
        try {
            & $RemoveCommand -Identity $identity -Confirm:$false -ErrorAction Stop

            $script:DeletionResults.Add([pscustomobject]@{
                ObjectType = $ObjectType
                Name       = $displayName
                Identity   = $identity
                Status     = 'Removed'
                Attempts   = $attempt
                Error      = $null
            })
            Write-Log -Level OK -Message "$ObjectType '$displayName' wurde entfernt."
            return $true
        }
        catch {
            $lastError = $_.Exception.Message
            Write-Log -Level WARN -Message ("Versuch {0}/{1} für {2} '{3}' fehlgeschlagen: {4}" -f $attempt, $Attempts, $ObjectType, $displayName, $lastError)
            if ($attempt -lt $Attempts) {
                Start-Sleep -Seconds $RetryDelaySeconds
            }
        }
    }

    $script:DeletionResults.Add([pscustomobject]@{
        ObjectType = $ObjectType
        Name       = $displayName
        Identity   = $identity
        Status     = 'Failed'
        Attempts   = $Attempts
        Error      = $lastError
    })
    Write-Log -Level ERROR -Message "$ObjectType '$displayName' konnte nicht entfernt werden."
    return $false
}

$connected = $false
try {
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        throw "Das Modul 'ExchangeOnlineManagement' ist nicht installiert. Installiere es vorab mit: Install-Module ExchangeOnlineManagement -Scope CurrentUser"
    }

    Import-Module ExchangeOnlineManagement -ErrorAction Stop
    Connect-IPPSSession -UserPrincipalName $UserPrincipalName -ErrorAction Stop
    $connected = $true

    $requiredCommands = @(
        'Get-DlpCompliancePolicy', 'Remove-DlpCompliancePolicy',
        'Get-LabelPolicy', 'Remove-LabelPolicy',
        'Get-Label', 'Remove-Label'
    )

    foreach ($command in $requiredCommands) {
        if (-not (Get-Command -Name $command -ErrorAction SilentlyContinue)) {
            throw "Das erforderliche Cmdlet '$command' ist in der aktuellen Security-&-Compliance-Sitzung nicht verfügbar. Prüfe RBAC-Berechtigungen und die Verbindung."
        }
    }

    New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
    Write-Log -Message "Backup- und Protokollpfad: $BackupPath"

    $dlpPolicies   = @(Get-DlpCompliancePolicy -ErrorAction Stop)
    $labelPolicies = @(Get-LabelPolicy -ErrorAction Stop)
    $labels        = @(Get-Label -ErrorAction Stop)

    Export-Inventory -BaseName 'DlpCompliancePolicies' -InputObjects $dlpPolicies
    Export-Inventory -BaseName 'LabelPublishingPolicies' -InputObjects $labelPolicies
    Export-Inventory -BaseName 'SensitivityLabels' -InputObjects $labels

    Write-Log -Message ("Inventar: {0} DLP-Policies, {1} Publishing-Policies, {2} Sensitivity Labels." -f $dlpPolicies.Count, $labelPolicies.Count, $labels.Count)

    if (-not $Execute) {
        Write-Log -Level WARN -Message 'Nur Inventarisierung. Für die Löschung zusätzlich -Execute und die Bestätigungsphrase angeben.'
        Write-Log -Message "Erforderliche Bestätigungsphrase: $RequiredPhrase"
        return
    }

    if ([string]::IsNullOrWhiteSpace($ConfirmationText)) {
        $ConfirmationText = Read-Host "Zum endgültigen Löschen exakt eingeben: $RequiredPhrase"
    }

    if ($ConfirmationText -cne $RequiredPhrase) {
        throw 'Die Bestätigungsphrase stimmt nicht exakt überein. Es wurde nichts gelöscht.'
    }

    Write-Log -Level WARN -Message 'Löschmodus aktiv. Die Aktionen sind tenantweit und nicht automatisch rückgängig zu machen.'

    # 1. DLP-Policies zuerst entfernen, da DLP-Regeln Sensitivity Labels referenzieren können.
    foreach ($policy in $dlpPolicies) {
        [void](Invoke-RemoveObject -InputObject $policy -ObjectType 'DLP-Policy' -RemoveCommand 'Remove-DlpCompliancePolicy')
    }

    # 2. Publishing-Policies entfernen, bevor die darin veröffentlichten Labels gelöscht werden.
    foreach ($policy in $labelPolicies) {
        [void](Invoke-RemoveObject -InputObject $policy -ObjectType 'Label-Publishing-Policy' -RemoveCommand 'Remove-LabelPolicy')
    }

    # 3. Labels iterativ entfernen. Dadurch werden Sublabels/abhängige Labels zuerst abgebaut,
    #    auch wenn Get-Label keine verlässliche hierarchische Sortierung liefert.
    $pendingLabels = [System.Collections.Generic.List[object]]::new()
    foreach ($label in $labels) { $pendingLabels.Add($label) }

    for ($pass = 1; $pass -le $MaxAttempts -and $pendingLabels.Count -gt 0; $pass++) {
        Write-Log -Message ("Label-Löschdurchlauf {0}: {1} Objekt(e) ausstehend." -f $pass, $pendingLabels.Count)
        $nextPending = [System.Collections.Generic.List[object]]::new()

        foreach ($label in @($pendingLabels)) {
            $removed = Invoke-RemoveObject -InputObject $label -ObjectType 'Sensitivity-Label' -RemoveCommand 'Remove-Label' -Attempts 1
            if (-not $removed) {
                $nextPending.Add($label)
            }
        }

        $pendingLabels = $nextPending
        if ($pendingLabels.Count -gt 0 -and $pass -lt $MaxAttempts) {
            Start-Sleep -Seconds $RetryDelaySeconds
        }
    }

    $resultPath = Join-Path $BackupPath 'DeletionResults.csv'
    $script:DeletionResults | Export-Csv -LiteralPath $resultPath -NoTypeInformation -Encoding UTF8

    # Abschließende Verifikation über erneute Abfrage.
    $remainingDlpPolicies   = @(Get-DlpCompliancePolicy -ErrorAction Stop)
    $remainingLabelPolicies = @(Get-LabelPolicy -ErrorAction Stop)
    $remainingLabels        = @(Get-Label -ErrorAction Stop)

    [pscustomobject]@{
        VerifiedAt              = Get-Date
        RemainingDlpPolicies    = $remainingDlpPolicies.Count
        RemainingLabelPolicies  = $remainingLabelPolicies.Count
        RemainingLabels         = $remainingLabels.Count
    } | Export-Clixml -LiteralPath (Join-Path $BackupPath 'Verification.clixml')

    Export-Inventory -BaseName 'Remaining-DlpCompliancePolicies' -InputObjects $remainingDlpPolicies
    Export-Inventory -BaseName 'Remaining-LabelPublishingPolicies' -InputObjects $remainingLabelPolicies
    Export-Inventory -BaseName 'Remaining-SensitivityLabels' -InputObjects $remainingLabels

    Write-Log -Message ("Verifikation: {0} DLP-Policies, {1} Publishing-Policies und {2} Labels verbleiben." -f $remainingDlpPolicies.Count, $remainingLabelPolicies.Count, $remainingLabels.Count)

    if (($remainingDlpPolicies.Count + $remainingLabelPolicies.Count + $remainingLabels.Count) -gt 0) {
        throw "Das Cleanup ist nicht vollständig. Details stehen unter '$BackupPath'."
    }

    Write-Log -Level OK -Message 'Cleanup vollständig abgeschlossen und verifiziert.'
}
catch {
    if (-not (Test-Path -LiteralPath $BackupPath)) {
        New-Item -ItemType Directory -Path $BackupPath -Force | Out-Null
    }
    Write-Log -Level ERROR -Message $_.Exception.Message
    throw
}
finally {
    if ($connected) {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    }
}
