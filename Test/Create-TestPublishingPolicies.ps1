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

# Die Labels werden über ihre Namen angegeben. Labelgruppen (Test-General,
# Test-Confidential, Test-Strictly-Confidential) können nicht veröffentlicht werden.
# Team-Policies werden zunächst mit ExchangeLocation 'All' angelegt und danach von
# Main Setup/Set-PublishingPolicyGroups.ps1 auf die jeweilige Gruppe eingeschränkt.
$policies = @(
    [pscustomobject]@{
        Name          = 'Test Policy All, no Standard, No Inheritence'
        Labels        = @('Test-Public', 'Test-General-Intern', 'Test-General-Extern', 'Test-Confidential-Intern', 'Test-Confidential-Extern', 'Test-Strictly-Confidential-Personalized')
        Settings      = @{ requiredowngradejustification = 'true'; customurl = 'https://learn.microsoft.com/de-de/purview/sensitivity-labels' }
    },
    [pscustomobject]@{
        Name          = 'Test Legal, Intern Standard, Highest Inheritence for Mails'
        Labels        = @('Test-General-Intern', 'Test-Confidential-Legal')
        Settings      = @{ mandatory = 'true'; outlookdefaultlabel = 'Test-General-Intern'; defaultlabelid = 'Test-General-Intern'; attachmentaction = 'automatic'; requiredowngradejustification = 'true'; customurl = 'https://learn.microsoft.com/de-de/purview/sensitivity-labels' }
    },
    [pscustomobject]@{
        Name          = 'Test Finance, Confidential Intern, Perdefinded but Inheritence'
        Labels        = @('Test-Confidential-Intern', 'Test-Confidential-Finance')
        Settings      = @{ mandatory = 'true'; outlookdefaultlabel = 'Test-Confidential-Intern'; defaultlabelid = 'Test-Confidential-Intern'; attachmentaction = 'recommended'; requiredowngradejustification = 'true'; customurl = 'https://learn.microsoft.com/de-de/purview/sensitivity-labels' }
    },
    [pscustomobject]@{
        Name          = 'Test Leadership, Intern , Inheritence'
        Labels        = @('Test-General-Intern', 'Test-Confidential-Legal', 'Test-Confidential-Finance', 'Test-Strictly-Confidential-Intern')
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

# Labels und vorhandene Policies einmalig laden; defaultlabelid und
# outlookdefaultlabel erwarten Label-GUIDs statt Namen.
$tenantLabels = @()
$existingPolicyNames = @()
if ($Execute) {
    $tenantLabels = @(Get-Label -ErrorAction Stop)
    $existingPolicyNames = @(Get-LabelPolicy -ErrorAction Stop | ForEach-Object { [string]$_.Name })
}

foreach ($policy in $policies) {
    if (-not $Execute) {
        Write-Log -Level WARN -Message ("Vorschau: '{0}' mit {1} Labels würde erstellt werden." -f $policy.Name, $policy.Labels.Count)
        continue
    }

    try {
        if ($existingPolicyNames -contains $policy.Name) {
            Write-Log -Level WARN -Message "Publishing-Policy '$($policy.Name)' existiert bereits."
            continue
        }

        $settings = [hashtable]::new($policy.Settings)
        foreach ($key in @('defaultlabelid', 'outlookdefaultlabel')) {
            if ($settings.ContainsKey($key)) {
                $labelName = [string]$settings[$key]
                $label = $tenantLabels | Where-Object { [string]$_.Name -eq $labelName } | Select-Object -First 1
                if ($null -eq $label) { throw "Sensitivity label '$labelName' wurde im Tenant nicht gefunden." }
                $settings[$key] = if ($label.PSObject.Properties['ImmutableId'] -and $label.ImmutableId) { [string]$label.ImmutableId } else { [string]$label.Guid }
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

# Team-Policies auf die Gruppen einschränken; sonst gelten sie für alle Benutzer.
$groupScript = Join-Path -Path $PSScriptRoot -ChildPath '..\Main Setup\Set-PublishingPolicyGroups.ps1'
$groupLogPath = Join-Path -Path $LogPath -ChildPath 'GroupAssignment'
if (-not (Test-Path -LiteralPath $groupScript -PathType Leaf)) {
    Write-Log -Level ERROR -Message "Gruppenskript nicht gefunden: $groupScript"
} else {
    & $groupScript -Execute:([bool]$Execute) -PolicyNamePrefix 'Test ' -LogPath $groupLogPath
    $groupErrors = @(Select-String -LiteralPath (Join-Path $groupLogPath 'Set-PublishingPolicyGroups.log') -Pattern '[ERROR]' -SimpleMatch -ErrorAction SilentlyContinue)
    if ($groupErrors.Count -gt 0) {
        Write-Log -Level ERROR -Message "Gruppenzuordnung meldet $($groupErrors.Count) Fehler. Die betroffenen Test-Policies gelten weiterhin für alle Benutzer."
    }
}

Write-Log -Message 'Skript beendet.'
