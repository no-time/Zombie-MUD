# --- Modules\SaveManager.psm1 ---

function Save-GameState {
    param(
        [Parameter(Mandatory=$true)][object]$Player,
        [Parameter(Mandatory=$true)][object]$WorldMap,
        [Parameter(Mandatory=$true)][object]$LegacyBonuses
    )

    $SavePath = Join-Path $PSScriptRoot "..\Data\savegame.json"

    # Ensure LegacyBonuses is treated as an object for conversion
    $SaveData = [PSCustomObject]@{
        Player        = $Player
        WorldMap      = $WorldMap
        LegacyBonuses = [PSCustomObject]$LegacyBonuses 
    }

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