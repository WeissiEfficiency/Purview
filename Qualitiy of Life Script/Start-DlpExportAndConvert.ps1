<#
.SYNOPSIS
    Ruft DLP-Aktivitäten ab und konvertiert die CSV-Ausgabe in eine XLSX-Datei.

.EXAMPLE
    .\Start-DlpExportAndConvert.ps1 -Days 7

.NOTES
    Voraussetzung: ExchangeOnlineManagement und ImportExcel.
#>

[CmdletBinding()]
param (
    [ValidateRange(1, 30)]
    [int]$Days = 30,

    [string]$OutputDirectory = $PWD.Path
)

$ErrorActionPreference = "Stop"

$ScriptDirectory = Split-Path -Parent $MyInvocation.MyCommand.Path
$GetDlpAlertsScript = Join-Path $ScriptDirectory "Get-DLPalerts.ps1"
$ConvertScript = Join-Path $ScriptDirectory "Convert-DlpCsvToExcel.ps1"
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$CsvPath = Join-Path $OutputDirectory ("DLP-Activities_{0}.csv" -f $TimeStamp)
$ExcelPath = [IO.Path]::ChangeExtension($CsvPath, ".xlsx")

if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    $null = New-Item -Path $OutputDirectory -ItemType Directory -Force
}

Write-Host "DLP-Aktivitäten werden abgerufen..."

# Dot-Sourcing übernimmt die Parameter und den Ausgabepfad des Abrufskripts.
. $GetDlpAlertsScript -Days $Days -OutputPath $CsvPath

if (-not (Test-Path -LiteralPath $CsvPath -PathType Leaf)) {
    Write-Warning "Es wurden keine DLP-Aktivitäten exportiert. Die Konvertierung wird übersprungen."
    return
}

$CsvItem = Get-Item -LiteralPath $CsvPath

if ($CsvItem.Length -eq 0) {
    Write-Warning "Die DLP-CSV ist leer. Die Konvertierung wird übersprungen."
    return
}

Write-Host "DLP-CSV wurde erstellt. Konvertierung nach Excel wird gestartet..."

# Dot-Sourcing startet die Konvertierung mit dem zuvor erzeugten CSV-Pfad.
. $ConvertScript -InputPath $CsvPath -OutputPath $ExcelPath

Write-Host ""
Write-Host ("CSV:   {0}" -f $CsvPath)
Write-Host ("Excel: {0}" -f $ExcelPath)