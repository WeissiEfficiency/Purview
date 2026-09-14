<#
.SYNOPSIS
    Konvertiert einen Microsoft-Purview-DLP-CSV-Export in eine Excel-Datei.

.DESCRIPTION
    Liest die CSV-Spalten dynamisch ein und erstellt eine formatierte XLSX-Datei
    mit Autofilter, eingefrorener Kopfzeile und automatisch angepassten Spalten.

.EXAMPLE
    .\Convert-DlpCsvToExcel.ps1 -InputPath .\DLP-Activities_20260903_135056.csv

.EXAMPLE
    .\Convert-DlpCsvToExcel.ps1 `
        -InputPath .\DLP-Activities_20260903_135056.csv `
        -OutputPath .\DLP-Activities.xlsx

.NOTES
    Voraussetzung: Install-Module ImportExcel -Scope CurrentUser
#>

[CmdletBinding()]
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Leaf })]
    [string]$InputPath,

    [Parameter(Position = 1)]
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $OutputPath = [IO.Path]::ChangeExtension((Resolve-Path -LiteralPath $InputPath).Path, ".xlsx")
}

if (-not (Get-Module -ListAvailable -Name ImportExcel)) {
    throw (
        "Das Modul 'ImportExcel' wurde nicht gefunden. Installieren Sie es mit " +
        "'Install-Module ImportExcel -Scope CurrentUser' und starten Sie das Skript erneut."
    )
}

Import-Module ImportExcel -ErrorAction Stop

$ResolvedInputPath = (Resolve-Path -LiteralPath $InputPath).Path
$OutputDirectory = Split-Path -Parent $OutputPath

if (
    -not [string]::IsNullOrWhiteSpace($OutputDirectory) -and
    -not (Test-Path -LiteralPath $OutputDirectory)
) {
    $null = New-Item -Path $OutputDirectory -ItemType Directory -Force
}

$Records = @(Import-Csv -LiteralPath $ResolvedInputPath -Encoding UTF8)

if ($Records.Count -eq 0) {
    throw "Die CSV-Datei enthält keine Datensätze."
}

# Purview exportiert Happened als deutsches Datum mit Uhrzeit.
foreach ($Record in $Records) {
    if (-not [string]::IsNullOrWhiteSpace([string]$Record.Happened)) {
        $ParsedDate = [DateTime]::MinValue

        if ([DateTime]::TryParse(
                [string]$Record.Happened,
                [Globalization.CultureInfo]::GetCultureInfo("de-DE"),
                [Globalization.DateTimeStyles]::None,
                [ref]$ParsedDate
            )) {
            $Record.Happened = $ParsedDate
        }
    }
}

$ExcelPackage = $Records |
    Export-Excel `
        -Path $OutputPath `
        -WorksheetName "DLP Activities" `
        -TableName "DlpActivities" `
        -AutoFilter `
        -FreezeTopRow `
        -BoldTopRow `
        -PassThru

try {
    $Worksheet = $ExcelPackage.Workbook.Worksheets["DLP Activities"]
    $Worksheet.View.ShowGridLines = $false

    for ($ColumnIndex = 1; $ColumnIndex -le $Worksheet.Dimension.End.Column; $ColumnIndex++) {
        if ($Worksheet.Cells[1, $ColumnIndex].Value -eq "Happened") {
            $Worksheet.Cells[
                2,
                $ColumnIndex,
                $Worksheet.Dimension.End.Row,
                $ColumnIndex
            ].Style.Numberformat.Format = "dd.mm.yyyy hh:mm:ss"
            break
        }
    }

    # Lange Exportwerte sollen die Tabelle lesbar halten.
    foreach ($ColumnName in @("ItemMetadata", "PolicyMatchInfo", "SessionMetadata")) {
        $Column = $Worksheet.Cells[1, 1, 1, $Worksheet.Dimension.End.Column] |
            Where-Object { $_.Value -eq $ColumnName } |
            Select-Object -First 1

        if ($null -ne $Column) {
            $Worksheet.Column($Column.Start.Column).Width = 35
        }
    }

    Close-ExcelPackage $ExcelPackage
}
catch {
    if ($null -ne $ExcelPackage) {
        Close-ExcelPackage $ExcelPackage -NoSave
    }

    throw
}

Write-Host ""
Write-Host ("Konvertierte Datensätze: {0}" -f $Records.Count)
Write-Host ("Ausgabedatei: {0}" -f (Resolve-Path -LiteralPath $OutputPath))