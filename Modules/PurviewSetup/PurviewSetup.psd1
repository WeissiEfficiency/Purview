@{
    RootModule        = 'PurviewSetup.psm1'
    ModuleVersion     = '1.0.0'
    GUID              = '3f5c2d0e-6a51-4b7e-9d3c-8a1f2e4b6c70'
    Author            = 'Weissi'
    Description       = 'Gemeinsame Funktionen für die Purview-Setup-Skripte (Logging, Verbindung, Konfiguration, Soll/Ist-Vergleich).'
    PowerShellVersion = '5.1'
    FunctionsToExport = @(
        'Initialize-PurviewLog', 'Write-PurviewLog', 'Import-PurviewConfig', 'Connect-PurviewSession',
        'Resolve-PurviewLabelId', 'Get-PurviewLabelNameMap', 'Get-PurviewPolicySetting', 'Resolve-PurviewSensitiveInfoType',
        'ConvertTo-PurviewComparableValue', 'Compare-PurviewDesiredState', 'Format-PurviewDrift'
    )
    CmdletsToExport   = @()
    VariablesToExport = @()
    AliasesToExport   = @()
}
