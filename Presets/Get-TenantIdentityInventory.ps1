

#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [ValidateNotNullOrEmpty()]
    [string]$ExportPath = (Join-Path -Path (Get-Location) -ChildPath ("Exports\TenantInventory-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))),

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Get-TenantIdentityInventory-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$connected = $false

New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
$LogFile = Join-Path $LogPath 'Get-TenantIdentityInventory.log'

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'OK')][string]$Level = 'INFO'
    )

    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}

function Convert-ToText {
    param([AllowNull()]$Value)

    if ($null -eq $Value) {
        return ''
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        return (($Value | ForEach-Object { [string]$_ }) -join '; ')
    }

    return [string]$Value
}

function Get-OptionalProperty {
    param(
        [Parameter(Mandatory = $true)]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name
    )

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return $property.Value
    }

    return $null
}

try {
    Write-Log -Message "Exportpfad: $ExportPath"

    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        throw "Das Modul 'ExchangeOnlineManagement' ist nicht installiert. Installation: Install-Module ExchangeOnlineManagement -Scope CurrentUser"
    }

    Import-Module ExchangeOnlineManagement -ErrorAction Stop
    if ($UserPrincipalName) {
        Connect-ExchangeOnline -UserPrincipalName $UserPrincipalName -ShowBanner:$false -ErrorAction Stop
    } else {
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
    }
    $connected = $true

    foreach ($command in @('Get-User', 'Get-Recipient', 'Get-UnifiedGroup', 'Get-DistributionGroup')) {
        if (-not (Get-Command -Name $command -ErrorAction SilentlyContinue)) {
            throw "Das erforderliche Cmdlet '$command' ist nicht verfügbar. Prüfe die Exchange-Online-Rollen des Verbindungskontos."
        }
    }

    $users = @(Get-User -ResultSize Unlimited -ErrorAction Stop)
    $recipients = @(Get-Recipient -ResultSize Unlimited -ErrorAction Stop)
    $m365Groups = @(Get-UnifiedGroup -ResultSize Unlimited -ErrorAction Stop)
    $distributionGroups = @(Get-DistributionGroup -ResultSize Unlimited -ErrorAction Stop)

    $userSummary = foreach ($user in $users) {
        [pscustomobject]@{
            DisplayName           = Convert-ToText (Get-OptionalProperty -InputObject $user -Name 'DisplayName')
            UserPrincipalName     = Convert-ToText (Get-OptionalProperty -InputObject $user -Name 'UserPrincipalName')
            PrimarySmtpAddress    = Convert-ToText (Get-OptionalProperty -InputObject $user -Name 'PrimarySmtpAddress')
            RecipientTypeDetails  = Convert-ToText (Get-OptionalProperty -InputObject $user -Name 'RecipientTypeDetails')
            ExternalDirectoryId   = Convert-ToText (Get-OptionalProperty -InputObject $user -Name 'ExternalDirectoryObjectId')
            AccountDisabled       = Convert-ToText (Get-OptionalProperty -InputObject $user -Name 'AccountDisabled')
        }
    }

    $recipientSummary = foreach ($recipient in $recipients) {
        [pscustomobject]@{
            DisplayName          = Convert-ToText (Get-OptionalProperty -InputObject $recipient -Name 'DisplayName')
            PrimarySmtpAddress   = Convert-ToText (Get-OptionalProperty -InputObject $recipient -Name 'PrimarySmtpAddress')
            RecipientType        = Convert-ToText (Get-OptionalProperty -InputObject $recipient -Name 'RecipientType')
            RecipientTypeDetails = Convert-ToText (Get-OptionalProperty -InputObject $recipient -Name 'RecipientTypeDetails')
            ExternalDirectoryId  = Convert-ToText (Get-OptionalProperty -InputObject $recipient -Name 'ExternalDirectoryObjectId')
        }
    }

    $m365GroupSummary = foreach ($group in $m365Groups) {
        [pscustomobject]@{
            DisplayName          = Convert-ToText (Get-OptionalProperty -InputObject $group -Name 'DisplayName')
            PrimarySmtpAddress   = Convert-ToText (Get-OptionalProperty -InputObject $group -Name 'PrimarySmtpAddress')
            ExternalDirectoryId  = Convert-ToText (Get-OptionalProperty -InputObject $group -Name 'ExternalDirectoryObjectId')
            AccessType           = Convert-ToText (Get-OptionalProperty -InputObject $group -Name 'AccessType')
            HiddenFromAddressListsEnabled = Convert-ToText (Get-OptionalProperty -InputObject $group -Name 'HiddenFromAddressListsEnabled')
        }
    }

    $distributionGroupSummary = foreach ($group in $distributionGroups) {
        [pscustomobject]@{
            DisplayName          = Convert-ToText (Get-OptionalProperty -InputObject $group -Name 'DisplayName')
            PrimarySmtpAddress   = Convert-ToText (Get-OptionalProperty -InputObject $group -Name 'PrimarySmtpAddress')
            RecipientTypeDetails = Convert-ToText (Get-OptionalProperty -InputObject $group -Name 'RecipientTypeDetails')
            ExternalDirectoryId  = Convert-ToText (Get-OptionalProperty -InputObject $group -Name 'ExternalDirectoryObjectId')
            IsDirSynced          = Convert-ToText (Get-OptionalProperty -InputObject $group -Name 'IsDirSynced')
        }
    }

    $userSummary | Export-Csv -LiteralPath (Join-Path $ExportPath 'Users.csv') -NoTypeInformation -Encoding UTF8
    $recipientSummary | Export-Csv -LiteralPath (Join-Path $ExportPath 'Recipients.csv') -NoTypeInformation -Encoding UTF8
    $m365GroupSummary | Export-Csv -LiteralPath (Join-Path $ExportPath 'Microsoft365Groups.csv') -NoTypeInformation -Encoding UTF8
    $distributionGroupSummary | Export-Csv -LiteralPath (Join-Path $ExportPath 'DistributionGroups.csv') -NoTypeInformation -Encoding UTF8

    [pscustomobject]@{
        ExportedAt       = Get-Date
        Users            = $userSummary.Count
        Recipients       = $recipientSummary.Count
        Microsoft365Groups = $m365GroupSummary.Count
        DistributionGroups = $distributionGroupSummary.Count
    } | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $ExportPath 'Summary.json') -Encoding UTF8

    Write-Log -Level OK -Message ("Inventur abgeschlossen: {0} Benutzer, {1} Empfänger, {2} M365-Gruppen, {3} Verteilergruppen." -f $userSummary.Count, $recipientSummary.Count, $m365GroupSummary.Count, $distributionGroupSummary.Count)
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
