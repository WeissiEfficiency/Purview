<#
.SYNOPSIS
    Exportiert DLP-Aktivitäten aus Microsoft Purview als CSV,
    ohne die Spalte "User".

.VORAUSSETZUNG
    Install-Module ExchangeOnlineManagement -Scope CurrentUser
#>

[CmdletBinding()]
param (
    [ValidateRange(1, 30)]
    [int]$Days = 30,

    [string]$OutputPath = (
        Join-Path $PWD (
            "DLP-Activities_{0}.csv" -f (Get-Date -Format "yyyyMMdd_HHmmss")
        )
    )
)

$ErrorActionPreference = "Stop"

# Aktivitätstypen, die im Activity Explorer DLP-Ereignisse darstellen.
$DlpActivities = @(
    "DLPInfo"
    "DLPRuleMatch"
    "DLPRuleEnforce"
    "DLPRuleUndo"
    "DlpClassification"
)

# Ausschließlich UTC verwenden:
# - Endzeit fünf Minuten vor der aktuellen Zeit, damit sie niemals
#   durch Zeitverschiebung oder Uhrabweichung als Zukunft erkannt wird.
# - Bei 30 Tagen eine Sicherheitsreserve zur ältesten zulässigen
#   Grenze vorsehen.
$NowUtc               = [DateTime]::UtcNow
$EndTimeUtc           = $NowUtc.AddMinutes(-5)
$RequestedStartUtc    = $EndTimeUtc.AddDays(-$Days)
$EarliestSafeStartUtc = $NowUtc.AddDays(-30).AddMinutes(15)

if ($RequestedStartUtc -lt $EarliestSafeStartUtc) {
    $StartTimeUtc = $EarliestSafeStartUtc
}
else {
    $StartTimeUtc = $RequestedStartUtc
}

if ($StartTimeUtc -ge $EndTimeUtc) {
    throw "Die berechnete Startzeit muss vor der Endzeit liegen."
}

# Zielverzeichnis bei Bedarf erstellen.
$OutputDirectory = Split-Path -Parent $OutputPath

if (
    -not [string]::IsNullOrWhiteSpace($OutputDirectory) -and
    -not (Test-Path -LiteralPath $OutputDirectory)
) {
    $null = New-Item `
        -Path $OutputDirectory `
        -ItemType Directory `
        -Force
}

Import-Module ExchangeOnlineManagement -ErrorAction Stop

try {
    Write-Host "Verbindung mit Microsoft Purview wird hergestellt..."
    Connect-IPPSSession -ErrorAction Stop

    $JsonPages  = [System.Collections.Generic.List[string]]::new()
    $PageCookie = $null
    $PageNumber = 0

    do {
        $PageNumber++

        $ExportParameters = @{
            StartTime    = $StartTimeUtc
            EndTime      = $EndTimeUtc
            OutputFormat = "Json"
            PageSize     = 5000
            Filter1      = @("Activity") + $DlpActivities
            ErrorAction  = "Stop"
        }

        if (-not [string]::IsNullOrWhiteSpace($PageCookie)) {
            $ExportParameters["PageCookie"] = $PageCookie
        }

        Write-Host "DLP-Datenseite $PageNumber wird abgerufen..."

        $Response = Export-ActivityExplorerData @ExportParameters

        if (-not [string]::IsNullOrWhiteSpace([string]$Response.ResultData)) {
            $JsonPages.Add([string]$Response.ResultData)
        }

        # Boolean- und String-Ausgaben gleichermaßen behandeln.
        $IsLastPage = ([string]$Response.LastPage -eq "True")

        if (-not $IsLastPage) {
            $NextPageCookie = [string]$Response.WaterMark

            if ([string]::IsNullOrWhiteSpace($NextPageCookie)) {
                throw (
                    "Die Antwort meldet weitere Seiten, enthält aber " +
                    "keinen WaterMark für den nächsten Aufruf."
                )
            }

            if ($NextPageCookie -eq $PageCookie) {
                throw "Der WaterMark hat sich nicht geändert. Der Export wurde abgebrochen."
            }

            $PageCookie = $NextPageCookie
        }
    }
    while (-not $IsLastPage)

    # JSON erst nach dem Abruf aller Seiten auswerten.
    # Dadurch wird der jeweilige WaterMark möglichst schnell weiterverwendet.
    $Records = [System.Collections.Generic.List[object]]::new()

    foreach ($JsonPage in $JsonPages) {
        $PageRecords = @($JsonPage | ConvertFrom-Json)

        foreach ($Record in $PageRecords) {
            $Records.Add($Record)
        }
    }

    if ($Records.Count -eq 0) {
        Write-Warning (
            "Im Zeitraum {0:u} bis {1:u} wurden keine DLP-Aktivitäten gefunden." -f
            $StartTimeUtc,
            $EndTimeUtc
        )
        return
    }

    # Gesamte Top-Level-Spaltenmenge ermitteln, aber "User" ausschließen.
    # Dadurch fehlt die Spalte auch dann, wenn sie nur in einzelnen
    # Ereignistypen vorkommt.
    $Columns = @(
        $Records |
            ForEach-Object { $_.PSObject.Properties.Name } |
            Where-Object { $_ -ine "User" } |
            Sort-Object -Unique
    )

    $Records |
        Select-Object -Property $Columns |
        Export-Csv `
            -LiteralPath $OutputPath `
            -NoTypeInformation `
            -Encoding UTF8

    Write-Host ""
    Write-Host ("Exportierte Datensätze: {0}" -f $Records.Count)
    Write-Host ("UTC-Zeitraum: {0:u} bis {1:u}" -f $StartTimeUtc, $EndTimeUtc)
    Write-Host ("Ausgabedatei: {0}" -f (Resolve-Path -LiteralPath $OutputPath))
}
finally {
    if (Get-Command Disconnect-ExchangeOnline -ErrorAction SilentlyContinue) {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
    }
}