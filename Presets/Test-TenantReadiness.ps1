<#
.SYNOPSIS
    Prüft, ob der Tenant für das Purview-Setup vorbereitet ist (Phase 1). Nur lesend.

.DESCRIPTION
    Prüft ohne Änderungen am Tenant:
      1. Version des Moduls ExchangeOnlineManagement (mind. 3.7 für -DisableWAM)
      2. Gruppen aus config/tenant.psd1: vorhanden, erwarteter Typ, Mitglieder
      3. Pilotkonten aus UseCases/Testkonten.md: vorhanden und Gruppenmitgliedschaften
      4. Incident-Report-Empfänger vorhanden, einheitliches Überwachungsprotokoll aktiv
      5. RMS-Vorlage (EncryptionTemplate) vorhanden, Azure RMS aktiv
      6. Sensitivity-Label-Integration für SharePoint/OneDrive (EnableAIPIntegration),
         sofern das SharePoint-Online-Modul installiert ist

    Ergebnis: Konsole, Log und Bericht (CSV und Textdatei) im Ordner Logs\.
    Die Textdatei kann direkt weitergegeben werden.

.PARAMETER UserPrincipalName
    Admin-Konto für die Anmeldung an Exchange Online und SharePoint Online.

.PARAMETER SharePointAdminUrl
    URL des SharePoint-Admin-Centers. Standard: https://<TenantName>-admin.sharepoint.com
    aus config/tenant.psd1.

.PARAMETER SkipSharePoint
    SharePoint-Prüfung überspringen.

.PARAMETER ConfigPath
    Tenant-Konfiguration (Standard: config/tenant.psd1).

.PARAMETER LogPath
    Zielordner für Log und Bericht.

.EXAMPLE
    .\Presets\Test-TenantReadiness.ps1 -UserPrincipalName admin@contoso.onmicrosoft.com
#>
#requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$UserPrincipalName,

    [string]$SharePointAdminUrl,

    [switch]$SkipSharePoint,

    [string]$ConfigPath,

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Test-TenantReadiness-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

#region Initialization
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Path $PSScriptRoot -Parent
Import-Module (Join-Path -Path $repoRoot -ChildPath 'Modules/PurviewSetup/PurviewSetup.psd1') -Force

$LogFile = Initialize-PurviewLog -Path $LogPath -FileName 'Test-TenantReadiness.log'
Write-PurviewLog "Logdatei: $LogFile"
$config = Import-PurviewConfig -Path $ConfigPath

$results = [System.Collections.Generic.List[object]]::new()
function Add-Check {
    param(
        [Parameter(Mandatory = $true)][string]$Area,
        [Parameter(Mandatory = $true)][string]$Check,
        [Parameter(Mandatory = $true)][ValidateSet('OK', 'WARN', 'FAIL', 'SKIP')][string]$Status,
        [string]$Detail = ''
    )
    $results.Add([pscustomobject]@{ Area = $Area; Check = $Check; Status = $Status; Detail = $Detail })
    $level = switch ($Status) { 'OK' { 'OK' } 'FAIL' { 'ERROR' } default { 'WARN' } }
    Write-PurviewLog -Level $level ("[{0}] {1}: {2} {3}" -f $Area, $Check, $Status, $Detail)
}

# Pilotkonten aus UseCases/Testkonten.md lesen (alle UPNs in Backticks).
$pilotAccounts = @()
$testAccountsFile = Join-Path -Path $repoRoot -ChildPath 'UseCases/Testkonten.md'
if (Test-Path -LiteralPath $testAccountsFile) {
    $pilotAccounts = @([regex]::Matches((Get-Content -LiteralPath $testAccountsFile -Raw -Encoding UTF8), '`([^`\s]+@[^`\s]+)`') |
        ForEach-Object { $_.Groups[1].Value } | Where-Object { $_ -notmatch '^[^@]+@(pm|proton)\.me$' } | Sort-Object -Unique)
}
#endregion Initialization

$exoConnected = $false
try {
    #region 1 Module
    $exoModule = Get-Module -ListAvailable -Name ExchangeOnlineManagement | Sort-Object Version -Descending | Select-Object -First 1
    if ($null -eq $exoModule) {
        Add-Check -Area 'Modul' -Check 'ExchangeOnlineManagement' -Status 'FAIL' -Detail 'nicht installiert: Install-Module ExchangeOnlineManagement -Scope CurrentUser'
        throw 'ExchangeOnlineManagement ist nicht installiert.'
    } elseif ($exoModule.Version -lt [version]'3.7.0') {
        Add-Check -Area 'Modul' -Check 'ExchangeOnlineManagement' -Status 'WARN' -Detail "Version $($exoModule.Version); für -DisableWAM mind. 3.7: Update-Module ExchangeOnlineManagement"
    } else {
        Add-Check -Area 'Modul' -Check 'ExchangeOnlineManagement' -Status 'OK' -Detail "Version $($exoModule.Version)"
    }
    Add-Check -Area 'Modul' -Check 'PowerShell' -Status 'OK' -Detail "Version $($PSVersionTable.PSVersion) ($($PSVersionTable.PSEdition))"
    #endregion

    #region Exchange Online connection
    Import-Module ExchangeOnlineManagement -ErrorAction Stop
    $connectParams = @{ UserPrincipalName = $UserPrincipalName; ShowBanner = $false; ErrorAction = 'Stop' }
    if ($config.DisableWam -and $exoModule.Version -ge [version]'3.7.0') { $connectParams.DisableWAM = $true }
    Connect-ExchangeOnline @connectParams
    $exoConnected = $true
    #endregion

    #region 2 Groups
    $groupMembers = @{}
    foreach ($groupKey in @('Legal', 'Finance', 'Leadership')) {
        $group = $config.Groups[$groupKey]
        try {
            $recipient = Get-Recipient -Identity $group.Identity -ErrorAction Stop
        } catch {
            Add-Check -Area 'Gruppen' -Check "$groupKey ($($group.Identity))" -Status 'FAIL' -Detail "nicht gefunden: $($_.Exception.Message)"
            continue
        }

        $type = [string]$recipient.RecipientTypeDetails
        $expectedTypes = if ($group.Kind -eq 'ModernGroup') { @('GroupMailbox') } else { @('MailUniversalDistributionGroup', 'MailUniversalSecurityGroup') }
        $typeStatus = if ($expectedTypes -contains $type) { 'OK' } else { 'FAIL' }
        Add-Check -Area 'Gruppen' -Check "$groupKey Typ" -Status $typeStatus -Detail "$type (erwartet: $($expectedTypes -join ' oder ') für Kind '$($group.Kind)')"

        $members = if ($type -eq 'GroupMailbox') {
            @(Get-UnifiedGroupLinks -Identity $group.Identity -LinkType Members -ResultSize Unlimited -ErrorAction Stop)
        } else {
            @(Get-DistributionGroupMember -Identity $group.Identity -ResultSize Unlimited -ErrorAction Stop)
        }
        $groupMembers[$groupKey] = @($members | ForEach-Object { ([string]$_.PrimarySmtpAddress).ToLowerInvariant() })
        $memberStatus = if ($members.Count -gt 0) { 'OK' } else { 'WARN' }
        Add-Check -Area 'Gruppen' -Check "$groupKey Mitglieder ($($members.Count))" -Status $memberStatus -Detail (($members | ForEach-Object { [string]$_.DisplayName } | Sort-Object) -join ', ')
    }
    #endregion

    #region 3 Pilot accounts
    if ($pilotAccounts.Count -eq 0) {
        Add-Check -Area 'Pilotkonten' -Check 'Testkonten.md' -Status 'SKIP' -Detail 'keine Konten gefunden'
    }
    foreach ($account in $pilotAccounts) {
        try {
            $user = Get-Recipient -Identity $account -ErrorAction Stop
            $smtp = ([string]$user.PrimarySmtpAddress).ToLowerInvariant()
            $memberOf = @($groupMembers.Keys | Where-Object { $groupMembers[$_] -contains $smtp } | Sort-Object)
            $memberText = if ($memberOf.Count -gt 0) { $memberOf -join ', ' } else { 'keine Fachgruppe' }
            Add-Check -Area 'Pilotkonten' -Check "$($user.DisplayName) <$account>" -Status 'OK' -Detail "Gruppen: $memberText"
        } catch {
            Add-Check -Area 'Pilotkonten' -Check $account -Status 'FAIL' -Detail 'nicht gefunden'
        }
    }
    #endregion

    #region 4 Incident recipient
    try {
        $incident = Get-Recipient -Identity $config.IncidentReportRecipient -ErrorAction Stop
        Add-Check -Area 'DLP' -Check 'IncidentReportRecipient' -Status 'OK' -Detail "$($incident.DisplayName) ($($incident.RecipientTypeDetails))"
    } catch {
        Add-Check -Area 'DLP' -Check 'IncidentReportRecipient' -Status 'FAIL' -Detail "$($config.IncidentReportRecipient) nicht gefunden"
    }
    #endregion

    #region 4b Audit
    # DLP-Alerts, Activity Explorer und Simulationsergebnisse setzen das
    # einheitliche Überwachungsprotokoll voraus.
    try {
        $audit = Get-AdminAuditLogConfig -ErrorAction Stop
        $auditStatus = if ($audit.UnifiedAuditLogIngestionEnabled) { 'OK' } else { 'FAIL' }
        $auditHint = if ($audit.UnifiedAuditLogIngestionEnabled) { '' } else { '; aktivieren: Set-AdminAuditLogConfig -UnifiedAuditLogIngestionEnabled $true' }
        Add-Check -Area 'Audit' -Check 'UnifiedAuditLogIngestionEnabled' -Status $auditStatus -Detail ("{0}{1}" -f $audit.UnifiedAuditLogIngestionEnabled, $auditHint)
    } catch {
        Add-Check -Area 'Audit' -Check 'Get-AdminAuditLogConfig' -Status 'WARN' -Detail $_.Exception.Message
    }
    #endregion

    #region 5 RMS
    try {
        $irm = Get-IRMConfiguration -ErrorAction Stop
        $rmsStatus = if ($irm.AzureRMSLicensingEnabled) { 'OK' } else { 'FAIL' }
        Add-Check -Area 'RMS' -Check 'AzureRMSLicensingEnabled' -Status $rmsStatus -Detail ([string]$irm.AzureRMSLicensingEnabled)
    } catch {
        Add-Check -Area 'RMS' -Check 'Get-IRMConfiguration' -Status 'WARN' -Detail $_.Exception.Message
    }
    try {
        # Die Namen der integrierten Vorlagen sind lokalisiert (z. B. 'Verschlüsseln' statt
        # 'Encrypt'); die GUID ist sprachunabhängig und wird deshalb mit ausgegeben.
        $templates = @(Get-RMSTemplate -ErrorAction Stop | ForEach-Object {
                $template = $_
                $id = foreach ($property in @('Guid', 'TemplateGuid', 'Identity')) {
                    if ($template.PSObject.Properties[$property] -and -not [string]::IsNullOrWhiteSpace([string]$template.$property)) { [string]$template.$property; break }
                }
                [pscustomobject]@{ Name = [string]$template.Name; Id = [string]$id }
            })
        $available = 'verfügbar: ' + (($templates | ForEach-Object { '{0} [{1}]' -f $_.Name, $_.Id }) -join ', ')
        $wanted = [string]$config.EncryptionTemplate
        $aliases = @{ 'encrypt' = 'verschlüsseln'; 'verschlüsseln' = 'encrypt'; 'do not forward' = 'nicht weiterleiten'; 'nicht weiterleiten' = 'do not forward' }
        $exact = @($templates | Where-Object { $_.Name -eq $wanted -or $_.Id -eq $wanted })
        $alias = if ($aliases.ContainsKey($wanted.ToLowerInvariant())) { @($templates | Where-Object { $_.Name -eq $aliases[$wanted.ToLowerInvariant()] }) } else { @() }
        if ($exact.Count -gt 0) {
            Add-Check -Area 'RMS' -Check "Vorlage '$wanted'" -Status 'OK' -Detail $available
        } elseif ($alias.Count -gt 0) {
            Add-Check -Area 'RMS' -Check "Vorlage '$wanted'" -Status 'WARN' -Detail ("heißt in dieser Sitzung '{0}'. Sprachunabhängig in config/tenant.psd1 eintragen: EncryptionTemplate = '{1}'. {2}" -f $alias[0].Name, $alias[0].Id, $available)
        } else {
            Add-Check -Area 'RMS' -Check "Vorlage '$wanted'" -Status 'FAIL' -Detail $available
        }
    } catch {
        Add-Check -Area 'RMS' -Check 'Get-RMSTemplate' -Status 'FAIL' -Detail $_.Exception.Message
    }
    #endregion
}
catch {
    Write-PurviewLog -Level ERROR "Prüfung abgebrochen: $($_.Exception.Message)"
}
finally {
    if ($exoConnected) { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue }
}

#region 6 SharePoint
if ($SkipSharePoint) {
    Add-Check -Area 'SharePoint' -Check 'EnableAIPIntegration' -Status 'SKIP' -Detail '-SkipSharePoint'
} elseif (-not (Get-Module -ListAvailable -Name Microsoft.Online.SharePoint.PowerShell)) {
    Add-Check -Area 'SharePoint' -Check 'EnableAIPIntegration' -Status 'SKIP' -Detail 'Modul Microsoft.Online.SharePoint.PowerShell fehlt; manuell: Connect-SPOService -Url <Admin-URL>; Get-SPOTenant | Select-Object EnableAIPIntegration'
} else {
    if ([string]::IsNullOrWhiteSpace($SharePointAdminUrl)) {
        $SharePointAdminUrl = 'https://{0}-admin.sharepoint.com' -f ([string]$config.TenantName).ToLowerInvariant()
    }
    try {
        # Mit vollem Pfad importieren: Windows PowerShell kennt die Modulordner von PowerShell 7 nicht.
        # Unter PowerShell 7 zuerst direkt laden (aktuelle Modulversionen), sonst über die
        # Windows-PowerShell-Kompatibilität. -ModernAuth mit AuthenticationUrl vermeidet
        # "No valid OAuth 2.0 authentication session exists".
        $spoModule = Get-Module -ListAvailable -Name Microsoft.Online.SharePoint.PowerShell | Sort-Object Version -Descending | Select-Object -First 1
        $spoConnect = @{ Url = $SharePointAdminUrl; ModernAuth = $true; AuthenticationUrl = 'https://login.microsoftonline.com/organizations'; ErrorAction = 'Stop' }
        $attempts = if ($PSVersionTable.PSEdition -eq 'Core') { @($false, $true) } else { @($false) }
        $spoTenant = $null
        $spoErrors = @()
        foreach ($useWindowsPowerShell in $attempts) {
            try {
                Remove-Module -Name Microsoft.Online.SharePoint.PowerShell -Force -ErrorAction SilentlyContinue
                $spoImport = @{ Name = $spoModule.Path; ErrorAction = 'Stop'; WarningAction = 'SilentlyContinue' }
                if ($useWindowsPowerShell) { $spoImport.UseWindowsPowerShell = $true }
                Import-Module @spoImport
                Connect-SPOService @spoConnect
                $spoTenant = Get-SPOTenant -ErrorAction Stop
                break
            } catch {
                $spoErrors += '{0}: {1}' -f $(if ($useWindowsPowerShell) { 'Windows PowerShell' } else { 'direkt' }), $_.Exception.Message
            }
        }
        if ($null -eq $spoTenant) { throw ($spoErrors -join ' | ') }
        $aipStatus = if ($spoTenant.EnableAIPIntegration) { 'OK' } else { 'FAIL' }
        Add-Check -Area 'SharePoint' -Check 'EnableAIPIntegration' -Status $aipStatus -Detail ("{0}{1}" -f $spoTenant.EnableAIPIntegration, $(if (-not $spoTenant.EnableAIPIntegration) { '; aktivieren: Set-SPOTenant -EnableAIPIntegration $true' } else { '' }))
        Disconnect-SPOService -ErrorAction SilentlyContinue
    } catch {
        Add-Check -Area 'SharePoint' -Check 'EnableAIPIntegration' -Status 'WARN' -Detail "nicht geprüft ($SharePointAdminUrl): $($_.Exception.Message). Alternativ im Purview-Portal: Information Protection > Sensitivity labels (Hinweis zum Aktivieren erscheint, solange die Integration aus ist)"
    }
}
#endregion

#region Manual checks
Add-Check -Area 'Endpoint' -Check 'Geräte onboardet / eingeschränkte Dienstdomänen' -Status 'SKIP' -Detail 'manuell im Purview-Portal prüfen (Settings > Device onboarding; DLP > Endpoint DLP settings > Service domains)'
#endregion

#region Report
$csvPath = Join-Path -Path $LogPath -ChildPath 'TenantReadiness.csv'
$textPath = Join-Path -Path $LogPath -ChildPath 'TenantReadiness.txt'
$results | Export-Csv -LiteralPath $csvPath -NoTypeInformation -Encoding UTF8

$summary = $results | Group-Object Status | Sort-Object Name | ForEach-Object { '{0}: {1}' -f $_.Name, $_.Count }
$lines = @(
    "Tenant-Bereitschaft $($config.TenantName) - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    "Zusammenfassung: $($summary -join ', ')"
    ''
) + @($results | ForEach-Object { '[{0}] {1} | {2} | {3}' -f $_.Status, $_.Area, $_.Check, $_.Detail })
$lines | Set-Content -LiteralPath $textPath -Encoding UTF8

Write-PurviewLog "Zusammenfassung: $($summary -join ', ')"
Write-PurviewLog "Bericht: $textPath"
#endregion
