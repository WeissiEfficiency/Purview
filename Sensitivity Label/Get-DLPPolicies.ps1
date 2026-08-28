#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [ValidateNotNullOrEmpty()]
    [string]$ExportPath = (Join-Path -Path (Get-Location) -ChildPath ("Exports\DLP-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss'))),

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Get-DLPPolicies-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
$LogFile = Join-Path $LogPath 'Get-DLPPolicies.log'

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'OK')][string]$Level = 'INFO'
    )

    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
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

$connected = $false
try {
    Write-Log -Message "Exportpfad: $ExportPath"

    if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
        throw "Das Modul 'ExchangeOnlineManagement' ist nicht installiert."
    }

    Import-Module ExchangeOnlineManagement -ErrorAction Stop
    if ($UserPrincipalName) {
        Connect-IPPSSession -UserPrincipalName $UserPrincipalName -ErrorAction Stop
    } else {
        Connect-IPPSSession -ErrorAction Stop
    }
    $connected = $true

    foreach ($command in @('Get-DlpCompliancePolicy', 'Get-DlpComplianceRule')) {
        if (-not (Get-Command -Name $command -ErrorAction SilentlyContinue)) {
            throw "Das erforderliche Cmdlet '$command' ist nicht verfügbar."
        }
    }

    $policies = @(Get-DlpCompliancePolicy -ErrorAction Stop)
    $rules = @(Get-DlpComplianceRule -ErrorAction Stop)

    $policies | Export-Clixml -LiteralPath (Join-Path $ExportPath 'DlpCompliancePolicies.clixml') -Depth 20
    $policies | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $ExportPath 'DlpCompliancePolicies.json') -Encoding UTF8
    $rules | Export-Clixml -LiteralPath (Join-Path $ExportPath 'DlpComplianceRules.clixml') -Depth 20
    $rules | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $ExportPath 'DlpComplianceRules.json') -Encoding UTF8

    $policySummary = foreach ($policy in $policies) {
        [pscustomobject]@{
            Name               = Convert-ToText (Get-OptionalProperty -InputObject $policy -Name 'Name')
            Mode               = Convert-ToText (Get-OptionalProperty -InputObject $policy -Name 'Mode')
            State              = Convert-ToText (Get-OptionalProperty -InputObject $policy -Name 'State')
            Enabled            = Convert-ToText (Get-OptionalProperty -InputObject $policy -Name 'Enabled')
            Workload           = Convert-ToText (Get-OptionalProperty -InputObject $policy -Name 'Workload')
            ExchangeLocation   = Convert-ToText (Get-OptionalProperty -InputObject $policy -Name 'ExchangeLocation')
            SharePointLocation = Convert-ToText (Get-OptionalProperty -InputObject $policy -Name 'SharePointLocation')
            OneDriveLocation   = Convert-ToText (Get-OptionalProperty -InputObject $policy -Name 'OneDriveLocation')
            ModernGroupLocation = Convert-ToText (Get-OptionalProperty -InputObject $policy -Name 'ModernGroupLocation')
            Comment            = Convert-ToText (Get-OptionalProperty -InputObject $policy -Name 'Comment')
            CreatedBy          = Convert-ToText (Get-OptionalProperty -InputObject $policy -Name 'CreatedBy')
            LastModifiedBy     = Convert-ToText (Get-OptionalProperty -InputObject $policy -Name 'LastModifiedBy')
            ConfigurationJson  = $policy | ConvertTo-Json -Compress -Depth 20
        }
    }

    $ruleSummary = foreach ($rule in $rules) {
        [pscustomobject]@{
            Name              = Convert-ToText (Get-OptionalProperty -InputObject $rule -Name 'Name')
            Policy            = Convert-ToText (Get-OptionalProperty -InputObject $rule -Name 'Policy')
            PolicyName        = Convert-ToText (Get-OptionalProperty -InputObject $rule -Name 'PolicyName')
            Mode              = Convert-ToText (Get-OptionalProperty -InputObject $rule -Name 'Mode')
            State             = Convert-ToText (Get-OptionalProperty -InputObject $rule -Name 'State')
            ContentContainsSensitiveInformation = Convert-ToText (Get-OptionalProperty -InputObject $rule -Name 'ContentContainsSensitiveInformation')
            Actions           = Convert-ToText (Get-OptionalProperty -InputObject $rule -Name 'Actions')
            ConfigurationJson = $rule | ConvertTo-Json -Compress -Depth 20
        }
    }

    $policySummary | Export-Csv -LiteralPath (Join-Path $ExportPath 'DlpCompliancePolicies.csv') -NoTypeInformation -Encoding UTF8
    $ruleSummary | Export-Csv -LiteralPath (Join-Path $ExportPath 'DlpComplianceRules.csv') -NoTypeInformation -Encoding UTF8

    Write-Log -Level OK -Message ("Export abgeschlossen: {0} DLP-Policies und {1} DLP-Regeln." -f $policies.Count, $rules.Count)
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
