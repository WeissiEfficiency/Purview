#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [switch]$Execute,

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Create-PublishingPolicies-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
$LogFile = Join-Path $LogPath 'Create-PublishingPolicies.log'

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'OK')][string]$Level = 'INFO'
    )

    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}

# Die Labels werden direkt über ihre Namen angegeben.
$policies = @(
    [pscustomobject]@{
        Name          = 'Policy All, no Standard, No Inheritence'
        Labels        = @('Test-General', 'Test-General-Intern', 'Test-General-Extern', 'Test-Confidential', 'Test-Confidential-Intern', 'Test-Confidential-Extern', 'Test-Strictly-Confidential', 'Test-Strictly-Confidential-Personalized')
        Exchange      = @('All')
        Settings      = @{ requiredowngradejustification = 'true'; customurl = 'https://learn.microsoft.com/de-de/purview/sensitivity-labels' }
    },
    [pscustomobject]@{
        Name          = 'Legal, Intern Standard, Highest Inheritence for Mails'
        Labels        = @('Test-General', 'Test-General-Intern', 'Test-Confidential', 'Test-Confidential-Legal')
        ModernGroups  = @('LegalTeam@M365DS410216.onmicrosoft.com')
        Settings      = @{ mandatory = 'true'; outlookdefaultlabel = 'Test-General-Intern'; defaultlabelid = 'Test-General-Intern'; attachmentaction = 'automatic'; requiredowngradejustification = 'true'; customurl = 'https://learn.microsoft.com/de-de/purview/sensitivity-labels' }
    },
    [pscustomobject]@{
        Name          = 'Finance, Confidential Intern, Perdefinded but Inheritence'
        Labels        = @('Test-Confidential', 'Test-Confidential-Intern', 'Test-Confidential-Finance')
        ModernGroups  = @('FinanceTeam@M365DS410216.onmicrosoft.com')
        Settings      = @{ mandatory = 'true'; outlookdefaultlabel = 'Test-Confidential-Intern'; defaultlabelid = 'Test-Confidential-Intern'; attachmentaction = 'recommended'; requiredowngradejustification = 'true'; customurl = 'https://learn.microsoft.com/de-de/purview/sensitivity-labels' }
    },
    [pscustomobject]@{
        Name          = 'Leadership, Intern , Inheritence'
        Labels        = @('Test-General', 'Test-General-Intern', 'Test-Confidential', 'Test-Confidential-Legal', 'Test-Confidential-Finance', 'Test-Strictly-Confidential', 'Test-Strictly-Confidential-Intern')
        ModernGroups  = @('Leadership@m365ds410216.onmicrosoft.com')
        Settings      = @{ mandatory = 'true'; outlookdefaultlabel = 'Test-General-Intern'; defaultlabelid = 'Test-General-Intern'; attachmentaction = 'automatic'; requiredowngradejustification = 'true'; customurl = 'https://learn.microsoft.com/de-de/purview/sensitivity-labels' }
    }
)

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

foreach ($policy in $policies) {
    $policyParams = @{
        Name   = $policy.Name
        Labels = $policy.Labels
    }

    if ($policy.PSObject.Properties['Exchange'] -and $policy.Exchange.Count -gt 0) { $policyParams.ExchangeLocation = $policy.Exchange }
    if ($policy.PSObject.Properties['ModernGroups'] -and $policy.ModernGroups.Count -gt 0) { $policyParams.ModernGroupLocation = $policy.ModernGroups }
    if ($policy.Settings.Count -gt 0) { $policyParams.AdvancedSettings = $policy.Settings }

    if (-not $Execute) {
        Write-Log -Level WARN -Message ("Vorschau: '{0}' mit {1} Labels würde erstellt werden." -f $policy.Name, $policy.Labels.Count)
        continue
    }

    try {
        if (Get-LabelPolicy -Identity $policy.Name -ErrorAction SilentlyContinue) {
            Write-Log -Level WARN -Message "Publishing-Policy '$($policy.Name)' existiert bereits."
            continue
        }

        New-LabelPolicy @policyParams -ErrorAction Stop | Out-Null
        Write-Log -Level OK -Message "Publishing-Policy '$($policy.Name)' erstellt."
    } catch {
        Write-Log -Level ERROR -Message "Publishing-Policy '$($policy.Name)': $($_.Exception.Message)"
    }
}

Write-Log -Message 'Skript beendet.'