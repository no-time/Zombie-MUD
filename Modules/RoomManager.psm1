# --- Modules\RoomManager.psm1 ---

function ConvertTo-Hashtable {
    param([object]$InputObject)
    $Hash = @{}
    if ($null -ne $InputObject) {
        foreach ($Property in $InputObject.psobject.properties) {
            # NEW: Only map the property if it has a value. This allows us to "delete" locks by nullifying them.
            if ($null -ne $Property.Value -and $Property.Value -ne "") {
                $Hash[$Property.Name] = $Property.Value
            }
        }
    }
    return $Hash
}

function Load-WorldMap {
    $MapPath = Join-Path $PSScriptRoot "..\Data\rooms.json"
    if (-not (Test-Path $MapPath)) {
        Write-Error "CRITICAL: Could not find rooms.json at $MapPath"
        return $null
    }
    
    # Read the raw JSON and convert it normally
    $RawJson = Get-Content $MapPath -Raw
    $WorldMapObject = ConvertFrom-Json $RawJson 
    
    # Convert the top level to a hashtable manually
    return (ConvertTo-Hashtable $WorldMapObject)
}

function Get-RoomState {
    param(
        [Parameter(Mandatory=$true)][hashtable]$WorldMap,
        [Parameter(Mandatory=$true)][string]$RoomID
    )
    
    if ($WorldMap.ContainsKey($RoomID)) {
        $RoomData = $WorldMap[$RoomID]
        
        # Convert nested objects to hashtables so Client.ps1 can read them
        $ExitMap          = ConvertTo-Hashtable $RoomData.Exits
        $InteractablesMap = ConvertTo-Hashtable $RoomData.Interactables
        $LockedMap        = ConvertTo-Hashtable $RoomData.Locked

        # --- NEW: Dynamically build the Exits list so "open" items always render! ---
        $ExitsList = [System.Collections.ArrayList]@($ExitMap.Keys)
        if ($null -ne $InteractablesMap) {
            foreach ($Obj in $InteractablesMap.Keys) {
                if ($InteractablesMap[$Obj].State -eq "open") {
                    $ExitsList.Add($Obj) | Out-Null
                }
            }
        }

        $FormattedRoom = [PSCustomObject]@{
            ID            = $RoomID
            Name          = $RoomData.Name
            Description   = $RoomData.Description
            Exits         = @($ExitsList) # Uses the dynamic list now
            ExitMap       = $ExitMap
            Interactables = $InteractablesMap
            Locked        = $LockedMap
            NPC           = $RoomData.NPC
            # --- NEW: Map MinLevel from JSON to the Room Object ---
            MinLevel      = if ($null -ne $RoomData.MinLevel) { $RoomData.MinLevel } else { $null }
        }
        return $FormattedRoom
    }
    
    return $null
}