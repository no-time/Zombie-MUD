# --- Modules\SaveManager.psm1 ---

function Save-GameState {
    param(
        [Parameter(Mandatory=$true)][object]$Player,
        [Parameter(Mandatory=$true)][hashtable]$WorldMap,
        [Parameter(Mandatory=$true)][hashtable]$LegacyBonuses
    )

    $SavePath = Join-Path $PSScriptRoot "..\Data\savegame.json"

    $SaveData = [PSCustomObject]@{
        Player        = $Player
        WorldMap      = $WorldMap
        LegacyBonuses = $LegacyBonuses
    }

    # -Depth 100 prevents PowerShell from truncating deeply nested Exits/Locked objects
    $SaveData | ConvertTo-Json -Depth 100 | Set-Content $SavePath -Force
}

function Get-SavedGame {
    $SavePath = Join-Path $PSScriptRoot "..\Data\savegame.json"
    if (Test-Path $SavePath) {
        $RawJson = Get-Content $SavePath -Raw
        return ConvertFrom-Json $RawJson
    }
    return $null
}