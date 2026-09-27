<#
.SYNOPSIS
    Erstellt produktive Microsoft-Purview-Publishing-Policies.

.DESCRIPTION
    Definiert Publishing-Policies für Exchange, Legal, Finance und Leadership.
    Ohne -Execute wird nur eine Vorschau ausgegeben. Bereits vorhandene Policies
    werden übersprungen.

    Die Team-Policies (Legal, Finance, Leadership) werden zunächst mit
    ExchangeLocation 'All' angelegt, weil New-LabelPolicy die Verteilergruppen
    im Tenant nicht direkt auflöst. Direkt danach schränkt
    Set-PublishingPolicyGroups.ps1 sie auf die jeweilige Gruppe ein. Dieser
    Schritt läuft standardmäßig mit; schlägt er fehl, wird ein ERROR geloggt.

.PARAMETER UserPrincipalName
    UPN des Kontos für die Security-and-Compliance-PowerShell-Verbindung.

.PARAMETER Execute
    Erstellt die Policies tatsächlich. Ohne diesen Schalter bleibt das Skript
    im Vorschau-Modus.

.PARAMETER SkipGroupAssignment
    Überspringt die Gruppenzuordnung. Nur für Diagnosezwecke: Die Team-Policies
    gelten dann für alle Benutzer.

.PARAMETER LabelPrefix
    Präfix vor allen Labelnamen, z. B. 'Test-' für die Testlabels.

.PARAMETER PolicyPrefix
    Präfix vor allen Policy-Namen, z. B. 'Test '. Wird auch an
    Set-PublishingPolicyGroups.ps1 weitergegeben.

.PARAMETER LogPath
    Zielordner für das Ausführungslog.

.EXAMPLE
    .\Create-PublishingPolicies.ps1 -UserPrincipalName admin@contoso.com

.EXAMPLE
    .\Create-PublishingPolicies.ps1 -UserPrincipalName admin@contoso.com -Execute

.NOTES
    Labelgruppen (General, Confidential, Strictly-Confidential) können nicht
    veröffentlicht werden; es werden nur die Unterlabels aufgeführt.
    defaultlabelid und outlookdefaultlabel erwarten Label-GUIDs; die Namen werden
    zur Laufzeit aufgelöst.
#>
#requires -Version 5.1
#region Parameters
[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [switch]$Execute,

    [switch]$SkipGroupAssignment,

    [string]$LabelPrefix = '',

    [string]$PolicyPrefix = '',

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Create-PublishingPolicies-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)
#endregion Parameters

#region Initialization
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Logordner vorbereiten, bevor eine Verbindung zum Tenant hergestellt wird.
New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
$LogFile = Join-Path $LogPath 'Create-PublishingPolicies.log'
#endregion Initialization

#region Functions
function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'OK')][string]$Level = 'INFO'
    )

    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}

function Resolve-LabelId {
    param(
        [Parameter(Mandatory = $true)][string]$LabelName,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Labels
    )

    # Nur ueber den eindeutigen Namen aufloesen: Anzeigenamen wie 'Intern' kommen
    # in mehreren Labelgruppen vor.
    $label = $Labels | Where-Object { [string]$_.Name -eq $LabelName } | Select-Object -First 1
    if ($null -eq $label) {
        throw "Sensitivity label '$LabelName' wurde im Tenant nicht gefunden."
    }

    if ($label.PSObject.Properties['ImmutableId'] -and $label.ImmutableId) {
        return [string]$label.ImmutableId
    }

    if ($label.PSObject.Properties['Guid'] -and $label.Guid) {
        return [string]$label.Guid
    }

    throw "Sensitivity label '$LabelName' hat keine gültige GUID für defaultlabelid."
}
#endregion Functions

#region PolicyDefinitions
# Die Policies referenzieren die produktiven Labels über ihre Namen. GroupTarget
# markiert Team-Policies, die Set-PublishingPolicyGroups.ps1 danach einschränkt.
$policyTemplates = @(
    [pscustomobject]@{
        Name        = 'Policy All, no Standard, No Inheritence'
        Labels      = @('Public', 'General-Intern', 'General-Extern', 'Confidential-Intern', 'Confidential-Extern', 'Confidential-Legal', 'Confidential-Finance', 'Strictly-Confidential-Intern', 'Strictly-Confidential-Personalized')
        GroupTarget = $false
        Settings    = @{ requiredowngradejustification = 'true'; customurl = 'https://learn.microsoft.com/de-de/purview/sensitivity-labels' }
    },
    [pscustomobject]@{
        Name        = 'Legal, Intern Standard, Highest Inheritence for Mails'
        Labels      = @('Public', 'General-Intern', 'Confidential-Legal')
        GroupTarget = $true
        Settings    = @{ mandatory = 'true'; outlookdefaultlabel = 'General-Intern'; defaultlabelid = 'General-Intern'; attachmentaction = 'automatic'; requiredowngradejustification = 'true'; customurl = 'https://learn.microsoft.com/de-de/purview/sensitivity-labels' }
    },
    [pscustomobject]@{
        Name        = 'Finance, Confidential Intern, Perdefinded but Inheritence'
        Labels      = @('Public', 'Confidential-Intern', 'Confidential-Finance')
        GroupTarget = $true
        Settings    = @{ mandatory = 'true'; outlookdefaultlabel = 'Confidential-Intern'; defaultlabelid = 'Confidential-Intern'; attachmentaction = 'recommended'; requiredowngradejustification = 'true'; customurl = 'https://learn.microsoft.com/de-de/purview/sensitivity-labels' }
    },
    [pscustomobject]@{
        Name        = 'Leadership, Intern , Inheritence'
        Labels      = @('Public', 'General-Intern', 'Confidential-Intern', 'Confidential-Legal', 'Confidential-Finance', 'Strictly-Confidential-Intern')
        GroupTarget = $true
        Settings    = @{ mandatory = 'true'; outlookdefaultlabel = 'General-Intern'; defaultlabelid = 'General-Intern'; attachmentaction = 'automatic'; requiredowngradejustification = 'true'; customurl = 'https://learn.microsoft.com/de-de/purview/sensitivity-labels' }
    }
)
foreach ($policy in $policyTemplates) {
    $policy.Name = $PolicyPrefix + $policy.Name
    $policy.Labels = @($policy.Labels | ForEach-Object { $LabelPrefix + $_ })
    foreach ($key in @('defaultlabelid', 'outlookdefaultlabel')) {
        if ($policy.Settings.ContainsKey($key)) { $policy.Settings[$key] = $LabelPrefix + $policy.Settings[$key] }
    }
}
#endregion PolicyDefinitions

#region Connection
Write-Log -Message "Logpfad: $LogPath"
if (-not $Execute) {
    Write-Log -Level WARN -Message 'Vorschau-Modus: Es werden keine Publishing-Policies erstellt. Für die Erstellung -Execute verwenden.'
}

if ($Execute -or $UserPrincipalName) {
    if ($UserPrincipalName) {
        Connect-IPPSSession -UserPrincipalName $UserPrincipalName -ErrorAction Stop
    } else {
        Connect-IPPSSession -ErrorAction Stop
    }
}
#endregion Connection

#region PolicyCreation
# Labels und vorhandene Policies einmalig laden, statt pro Policy Get-* -Identity
# aufzurufen: ein "nicht gefunden" kann dort je nach Modulversion terminierend sein.
$tenantLabels = @()
$existingPolicyNames = @()
if ($Execute) {
    try {
        $tenantLabels = @(Get-Label -ErrorAction Stop)
        $existingPolicyNames = @(Get-LabelPolicy -ErrorAction Stop | ForEach-Object { [string]$_.Name })
    } catch {
        Write-Log -Level ERROR -Message "Labels oder Publishing-Policies konnten nicht gelesen werden: $($_.Exception.Message)"
        throw
    }
}

# Policies einzeln prüfen, damit ein Fehler die übrigen Einträge nicht verdeckt.
foreach ($policy in $policyTemplates) {
    if (-not $Execute) {
        $target = if ($policy.GroupTarget) { 'All, danach Gruppenzuordnung' } else { 'All' }
        Write-Log -Level WARN -Message ("Vorschau: '{0}' mit {1} Labels würde erstellt werden (Exchange: {2})." -f $policy.Name, $policy.Labels.Count, $target)
        continue
    }

    try {
        if ($existingPolicyNames -contains $policy.Name) {
            Write-Log -Level WARN -Message "Publishing-Policy '$($policy.Name)' existiert bereits."
            continue
        }

        $settings = $policy.Settings.Clone()
        foreach ($key in @('defaultlabelid', 'outlookdefaultlabel')) {
            if ($settings.ContainsKey($key)) {
                $settings[$key] = Resolve-LabelId -LabelName ([string]$settings[$key]) -Labels $tenantLabels
            }
        }

        $policyParams = @{
            Name             = $policy.Name
            Labels           = $policy.Labels
            ExchangeLocation = @('All')
            AdvancedSettings = $settings
        }
        New-LabelPolicy @policyParams -ErrorAction Stop | Out-Null
        Write-Log -Level OK -Message "Publishing-Policy '$($policy.Name)' erstellt."
    } catch {
        Write-Log -Level ERROR -Message "Publishing-Policy '$($policy.Name)': $($_.Exception.Message)"
    }
}
#endregion PolicyCreation

#region GroupAssignment
# Ohne diesen Schritt bleiben die Team-Policies (inkl. Leadership-Labels und
# Pflicht-Labeling) für alle Benutzer aktiv. Fehler werden daher als ERROR geloggt.
if ($SkipGroupAssignment) {
    Write-Log -Level WARN -Message 'Gruppenzuordnung übersprungen (-SkipGroupAssignment). Die Team-Policies gelten für alle Benutzer.'
} else {
    $groupScript = Join-Path -Path $PSScriptRoot -ChildPath 'Set-PublishingPolicyGroups.ps1'
    $groupLogPath = Join-Path -Path $LogPath -ChildPath 'GroupAssignment'
    if (-not (Test-Path -LiteralPath $groupScript -PathType Leaf)) {
        Write-Log -Level ERROR -Message "Gruppenskript nicht gefunden: $groupScript"
    } else {
        Write-Log -Message 'Starte Gruppenzuordnung der Team-Policies.'
        & $groupScript -Execute:([bool]$Execute) -PolicyNamePrefix $PolicyPrefix -LogPath $groupLogPath

        $groupLog = Join-Path -Path $groupLogPath -ChildPath 'Set-PublishingPolicyGroups.log'
        $groupErrors = @(Select-String -LiteralPath $groupLog -Pattern '[ERROR]' -SimpleMatch -ErrorAction SilentlyContinue)
        if ($groupErrors.Count -gt 0) {
            Write-Log -Level ERROR -Message "Gruppenzuordnung meldet $($groupErrors.Count) Fehler. Die betroffenen Team-Policies gelten weiterhin für alle Benutzer. Details: $groupLog"
        } else {
            Write-Log -Level OK -Message ('Gruppenzuordnung abgeschlossen{0}.' -f $(if ($Execute) { '' } else { ' (Vorschau)' }))
        }
    }
}
#endregion GroupAssignment

#region Completion
Write-Log -Message 'Skript beendet.'
#endregion Completion
