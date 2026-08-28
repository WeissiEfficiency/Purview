#requires -Version 5.1
<#
.SYNOPSIS
    Nimmt einen mailfähigen Adminaccount in alle statischen Distribution Groups
    des Exchange-Online-Tenants auf.

.DESCRIPTION
    - Standardmäßig nur Vorschau, keine Änderung.
    - Änderungen werden erst mit -Execute durchgeführt.
    - Bereits vorhandene Mitgliedschaften werden übersprungen.
    - Dynamische Distribution Groups und Microsoft 365 Groups sind nicht enthalten.
    - Verzeichnissynchronisierte Gruppen werden übersprungen, da ihre Mitgliedschaft
      in der autoritativen lokalen Umgebung geändert werden muss.
    - Mail-enabled Security Groups werden nur mit
      -IncludeMailEnabledSecurityGroups einbezogen.
    - Room Lists werden nicht einbezogen.
    - Alle Ergebnisse werden als CSV protokolliert.

.EXAMPLE
    .\Add-AdminToAllDistributionGroups.ps1 `
        -AdminAccount admin@contoso.com

    Erstellt nur eine Vorschau.

.EXAMPLE
    .\Add-AdminToAllDistributionGroups.ps1 `
        -AdminAccount admin@contoso.com `
        -Execute

    Nimmt den Account in alle cloudverwalteten statischen Distribution Groups auf.

.EXAMPLE
    .\Add-AdminToAllDistributionGroups.ps1 `
        -AdminAccount admin@contoso.com `
        -ConnectionAccount exoadmin@contoso.com `
        -IncludeMailEnabledSecurityGroups `
        -Execute
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$AdminAccount,

    [ValidateNotNullOrEmpty()]
    [string]$ConnectionAccount = $AdminAccount,

    [switch]$IncludeMailEnabledSecurityGroups,

    [switch]$Execute,

    [ValidateNotNullOrEmpty()]
    [string]$ReportPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Add-AdminToAllDistributionGroups-{0}\DistributionGroupMembership.csv" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))),

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Add-AdminToAllDistributionGroups-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$connected = $false
$results = [System.Collections.Generic.List[object]]::new()

New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
$LogFile = Join-Path $LogPath 'Add-AdminToAllDistributionGroups.log'

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

function Add-Result {
    param(
        [Parameter(Mandatory = $true)]$Group,
        [Parameter(Mandatory = $true)][string]$Status,
        [string]$Message
    )

    $results.Add([pscustomobject]@{
        Timestamp            = Get-Date
        GroupName            = [string]$Group.DisplayName
        GroupPrimarySmtp     = [string]$Group.PrimarySmtpAddress
        GroupType            = [string]$Group.RecipientTypeDetails
        ExternalDirectoryId  = [string]$Group.ExternalDirectoryObjectId
        AdminAccount         = $AdminAccount
        Status               = $Status
        Message              = $Message
    })
}

function Test-IsDirectorySynchronized {
    param([Parameter(Mandatory = $true)]$Group)

    $property = $Group.PSObject.Properties['IsDirSynced']
    return ($null -ne $property -and $property.Value -eq $true)
}

try {
    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        throw "Das Modul 'ExchangeOnlineManagement' ist nicht installiert. Installation: Install-Module ExchangeOnlineManagement -Scope CurrentUser"
    }

    Import-Module ExchangeOnlineManagement -ErrorAction Stop
    Connect-ExchangeOnline -UserPrincipalName $ConnectionAccount -ShowBanner:$false -ErrorAction Stop
    $connected = $true

    foreach ($requiredCommand in @(
        'Get-Recipient',
        'Get-DistributionGroup',
        'Get-DistributionGroupMember',
        'Add-DistributionGroupMember'
    )) {
        if (-not (Get-Command -Name $requiredCommand -ErrorAction SilentlyContinue)) {
            throw "Das Cmdlet '$requiredCommand' ist in der aktuellen Exchange-Online-Sitzung nicht verfügbar. Prüfe die RBAC-Rollen des Verbindungskontos."
        }
    }

    # Der Zielaccount muss ein Exchange-Empfänger sein, damit er Mitglied einer
    # Distribution Group werden kann.
    $targetRecipient = Get-Recipient -Identity $AdminAccount -ErrorAction Stop

    if ([string]::IsNullOrWhiteSpace([string]$targetRecipient.PrimarySmtpAddress)) {
        throw "Der Zielaccount '$AdminAccount' ist kein mailfähiger Exchange-Empfänger mit PrimarySmtpAddress."
    }

    $recipientTypes = [System.Collections.Generic.List[string]]::new()
    $recipientTypes.Add('MailUniversalDistributionGroup')
    if ($IncludeMailEnabledSecurityGroups) {
        $recipientTypes.Add('MailUniversalSecurityGroup')
    }

    $groups = @(
        Get-DistributionGroup `
            -RecipientTypeDetails $recipientTypes.ToArray() `
            -ResultSize Unlimited `
            -ErrorAction Stop
    )

    Write-Log -Message ("Gefunden: {0} passende statische Gruppe(n)." -f $groups.Count)
    if (-not $Execute) {
        Write-Log -Level WARN -Message 'VORSCHAUMODUS: Es werden keine Mitgliedschaften geändert. Für die Ausführung -Execute verwenden.'
    }

    foreach ($group in $groups) {
        $groupIdentity = if (-not [string]::IsNullOrWhiteSpace([string]$group.ExternalDirectoryObjectId)) {
            [string]$group.ExternalDirectoryObjectId
        }
        elseif (-not [string]::IsNullOrWhiteSpace([string]$group.PrimarySmtpAddress)) {
            [string]$group.PrimarySmtpAddress
        }
        else {
            [string]$group.Identity
        }

        try {
            if (Test-IsDirectorySynchronized -Group $group) {
                Add-Result -Group $group -Status 'Skipped-DirSynced' -Message 'Verzeichnissynchronisierte Gruppe; Änderung in der autoritativen lokalen Umgebung erforderlich.'
                Write-Log -Level WARN -Message ("Übersprungen (DirSync): {0}" -f $group.DisplayName)
                continue
            }

            $members = @(
                Get-DistributionGroupMember `
                    -Identity $groupIdentity `
                    -ResultSize Unlimited `
                    -ErrorAction Stop
            )

            $alreadyMember = $false

            if (-not [string]::IsNullOrWhiteSpace([string]$targetRecipient.ExternalDirectoryObjectId)) {
                $alreadyMember = $null -ne ($members | Where-Object {
                    [string]$_.ExternalDirectoryObjectId -eq [string]$targetRecipient.ExternalDirectoryObjectId
                } | Select-Object -First 1)
            }

            if (-not $alreadyMember) {
                $targetSmtp = [string]$targetRecipient.PrimarySmtpAddress
                $alreadyMember = $null -ne ($members | Where-Object {
                    -not [string]::IsNullOrWhiteSpace([string]$_.PrimarySmtpAddress) -and
                    [string]$_.PrimarySmtpAddress -ieq $targetSmtp
                } | Select-Object -First 1)
            }

            if ($alreadyMember) {
                Add-Result -Group $group -Status 'AlreadyMember' -Message 'Der Account ist bereits direktes Mitglied.'
                Write-Log -Message ("Bereits Mitglied: {0}" -f $group.DisplayName)
                continue
            }

            if (-not $Execute) {
                Add-Result -Group $group -Status 'WouldAdd' -Message 'Würde im Ausführungsmodus hinzugefügt.'
                Write-Log -Level WARN -Message ("Vorschau, würde hinzufügen: {0}" -f $group.DisplayName)
                continue
            }

            Add-DistributionGroupMember `
                -Identity $groupIdentity `
                -Member $targetRecipient.Identity `
                -BypassSecurityGroupManagerCheck `
                -Confirm:$false `
                -ErrorAction Stop

            Add-Result -Group $group -Status 'Added' -Message 'Mitgliedschaft erfolgreich hinzugefügt.'
            Write-Log -Level OK -Message ("Hinzugefügt: {0}" -f $group.DisplayName)
        }
        catch {
            Add-Result -Group $group -Status 'Failed' -Message $_.Exception.Message
            Write-Log -Level ERROR -Message ("Fehler bei Gruppe '{0}': {1}" -f $group.DisplayName, $_.Exception.Message)
        }
    }

    $reportDirectory = Split-Path -Path $ReportPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($reportDirectory) -and -not (Test-Path -LiteralPath $reportDirectory)) {
        New-Item -ItemType Directory -Path $reportDirectory -Force | Out-Null
    }

    $results | Export-Csv -LiteralPath $ReportPath -NoTypeInformation -Encoding UTF8

    $summary = $results | Group-Object Status | Sort-Object Name
    Write-Log -Message 'Zusammenfassung:'
    $summary | ForEach-Object {
        Write-Log -Message ("  {0}: {1}" -f $_.Name, $_.Count)
    }
    Write-Log -Message ("Report: {0}" -f $ReportPath)
}
finally {
    if ($connected) {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    }
}
