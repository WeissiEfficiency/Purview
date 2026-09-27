@{
    Severity     = @('Error', 'Warning')
    ExcludeRules = @(
        # Konsolenausgabe ist bei diesen interaktiven Admin-Skripten gewollt; Logs
        # werden zusaetzlich per Add-Content geschrieben.
        'PSAvoidUsingWriteHost',
        # Die Skripte nutzen bewusst -Execute als Vorschau-/Ausfuehrungsschalter
        # statt -WhatIf/-Confirm.
        'PSUseShouldProcessForStateChangingFunctions',
        # Write-Log ist in jedem Skript eine lokale Hilfsfunktion; die gemeldete
        # Kollision betrifft nur ein Windows-Kompatibilitaetsmodul.
        'PSAvoidOverwritingBuiltInCmdlets'
    )
}
