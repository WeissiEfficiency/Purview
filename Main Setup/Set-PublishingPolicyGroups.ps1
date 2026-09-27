<#
.SYNOPSIS
    Assigns the target groups to existing Purview publishing policies.

.DESCRIPTION
    This is the second step after Create-PublishingPolicies.ps1. The policies
    are created first for the full directory. This script then applies the
    distribution groups through ExchangeLocation and the Microsoft 365 group
    through ModernGroupLocation.

.PARAMETER PolicyNamePrefix
    Prefix in front of the policy names, e.g. 'Test ' for the policies created by
    Test/Create-TestPublishingPolicies.ps1.
#>
#requires -Version 5.1
[CmdletBinding()]
param(
    [string]$UserPrincipalName,

    [switch]$Execute,

    [string]$PolicyNamePrefix = '',

    [ValidateNotNullOrEmpty()]
    [string]$LogPath = (Join-Path -Path (Get-Location) -ChildPath ("Logs\Set-PublishingPolicyGroups-{0}" -f (Get-Date -Format 'yyyyMMdd-HHmmss')))
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
$LogFile = Join-Path $LogPath 'Set-PublishingPolicyGroups.log'

function Write-Log {
    param(
        [Parameter(Mandatory = $true)][string]$Message,
        [ValidateSet('INFO', 'WARN', 'ERROR', 'OK')][string]$Level = 'INFO'
    )

    $line = '[{0}] [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $Level, $Message
    Write-Host $line
    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
}

function Resolve-RecipientAddress {
    param(
        [Parameter(Mandatory = $true)][string]$Identity,
        [ValidateSet('Exchange', 'ModernGroup')][string]$Kind
    )

    if ($Kind -eq 'ModernGroup') {
        $match = @(Get-UnifiedGroup -ResultSize Unlimited -ErrorAction Stop) | Where-Object {
            $_.DisplayName -eq $Identity -or
            $_.Name -eq $Identity -or
            $_.Alias -eq $Identity -or
            $_.PrimarySmtpAddress -eq $Identity
        } | Select-Object -First 1
    } else {
        $match = @(Get-Recipient -ResultSize Unlimited -ErrorAction Stop) | Where-Object {
            $_.DisplayName -eq $Identity -or
            $_.Name -eq $Identity -or
            $_.Alias -eq $Identity -or
            $_.PrimarySmtpAddress -eq $Identity
        } | Select-Object -First 1
    }

    if ($null -eq $match) {
        throw "Recipient '$Identity' was not found."
    }

    return ([string]$match.PrimarySmtpAddress).ToLowerInvariant()
}

$assignments = @(
    [pscustomobject]@{
        Policy = 'Legal, Intern Standard, Highest Inheritence for Mails'
        Kind   = 'Exchange'
        Group  = 'Legal Team'
    },
    [pscustomobject]@{
        Policy = 'Finance, Confidential Intern, Perdefinded but Inheritence'
        Kind   = 'Exchange'
        Group  = 'Finance Team'
    },
    [pscustomobject]@{
        Policy = 'Leadership, Intern , Inheritence'
        Kind   = 'ModernGroup'
        Group  = 'Leadership'
    }
)
foreach ($assignment in $assignments) {
    $assignment.Policy = $PolicyNamePrefix + $assignment.Policy
}

Write-Log -Message "Log path: $LogPath"
if (-not $Execute) {
    Write-Log -Level WARN -Message 'Preview mode: no policy is changed. Use -Execute to apply the group assignments.'
}

# Reuse an existing Security & Compliance session (e.g. when called from
# Create-PublishingPolicies.ps1) instead of prompting for a second sign-in.
$connected = [bool](Get-Command Get-LabelPolicy -ErrorAction SilentlyContinue)
if (-not $connected -and ($Execute -or $UserPrincipalName)) {
    if ($UserPrincipalName) {
        Connect-IPPSSession -UserPrincipalName $UserPrincipalName -ErrorAction Stop
    } else {
        Connect-IPPSSession -ErrorAction Stop
    }
    $connected = $true
}

if (-not $connected) {
    foreach ($assignment in $assignments) {
        Write-Log -Level WARN -Message ("Preview (not connected): '{0}' would be restricted to '{1}' ({2})." -f $assignment.Policy, $assignment.Group, $assignment.Kind)
    }
    Write-Log -Message 'Script finished.'
    return
}

foreach ($assignment in $assignments) {
    try {
        $policy = Get-LabelPolicy -Identity $assignment.Policy -ErrorAction Stop
        $address = Resolve-RecipientAddress -Identity $assignment.Group -Kind $assignment.Kind
        Write-Log -Message ("Resolved '{0}' to '{1}' for policy '{2}'." -f $assignment.Group, $address, $assignment.Policy)

        if (-not $Execute) {
            Write-Log -Level WARN -Message ("Preview: '{0}' would receive target '{1}'." -f $assignment.Policy, $address)
            continue
        }

        $setParams = @{
            Identity = $policy.Identity
            RemoveExchangeLocation = @('All')
            ErrorAction = 'Stop'
        }
        if ($assignment.Kind -eq 'ModernGroup') {
            $setParams.AddModernGroupLocation = @($address)
        } else {
            $setParams.AddExchangeLocation = @($address)
        }

        Set-LabelPolicy @setParams | Out-Null
        Write-Log -Level OK -Message ("Group target for policy '{0}' set to '{1}'." -f $assignment.Policy, $address)
    } catch {
        Write-Log -Level ERROR -Message ("Policy '{0}': {1}" -f $assignment.Policy, $_.Exception.Message)
    }
}

Write-Log -Message 'Script finished.'
