# --- Modules\InventoryManager.psm1 ---

$global:ItemDatabase = $null

function ConvertTo-Hashtable {
    param([object]$InputObject)
    $Hash = @{}
    if ($null -ne $InputObject) {
        foreach ($Property in $InputObject.psobject.properties) { $Hash[$Property.Name] = $Property.Value }
    }
    return $Hash
}

function Load-ItemDatabase {
    $Path = Join-Path $PSScriptRoot "..\Data\items.json"
    if (-not (Test-Path $Path)) { return }
    try {
        $RawJson = Get-Content $Path -Raw
        $Parsed = ConvertFrom-Json $RawJson
        if ($Parsed -is [array]) { return }
        $global:ItemDatabase = ConvertTo-Hashtable $Parsed
    } catch { }
}

function Get-ItemStats {
    param([string]$ItemName)
    if ($null -eq $global:ItemDatabase) { Load-ItemDatabase }

    $BaseName = $ItemName; $Upgrades = 0; $RandomStat = ""
    
    # Mad Inventor Parser: Detects "Machete +3 [STR]"
    if ($ItemName -match '^(.*?)\s+\+(\d+)(?:\s+\[(.*?)\])?$') {
        $BaseName = $Matches[1]
        $Upgrades = [int]$Matches[2]
        if ($Matches.Count -ge 4) { $RandomStat = $Matches[3] }
    }

    if ($null -ne $global:ItemDatabase -and $global:ItemDatabase.ContainsKey($BaseName)) {
        $BaseItem = $global:ItemDatabase[$BaseName]
        
        $ClonedItem = [PSCustomObject]@{
            Type = $BaseItem.Type; Value = $BaseItem.Value; BasePrice = $BaseItem.BasePrice; 
            SellMultiplier = $BaseItem.SellMultiplier; Element = $BaseItem.Element;
            UpgradeLevel = $Upgrades; Modifiers = @{}
        }
        if ($null -ne $BaseItem.Modifiers) {
            foreach ($K in $BaseItem.Modifiers.psobject.properties) { $ClonedItem.Modifiers[$K.Name] = $K.Value }
        }

        # Apply Mad Inventor Scaling Math
        if ($Upgrades -gt 0) {
            if ($ClonedItem.Type -eq "Weapon") { $ClonedItem.Value += (5 * $Upgrades) } 
            elseif ($ClonedItem.Type -in @("Armor", "Shoulders", "Boots", "Trinket")) { $ClonedItem.Value += (1 * $Upgrades) } 
            elseif ($ClonedItem.Type -eq "Necklace" -and $null -ne $ClonedItem.Element) { $ClonedItem.Value += (10 * $Upgrades) }
            
            if (-not [string]::IsNullOrWhiteSpace($RandomStat)) {
                if ($ClonedItem.Modifiers.ContainsKey($RandomStat)) { $ClonedItem.Modifiers[$RandomStat] += $Upgrades } 
                else { $ClonedItem.Modifiers[$RandomStat] = $Upgrades }
            }
        }
        return $ClonedItem
    }
    return $null
}

function Get-ShopInventory {
    if ($null -eq $global:ItemDatabase) { Load-ItemDatabase }
    $ShopStockNames = @("Bandage", "Energy Drink", "Rusty Pipe", "Machete", "Pistol Ammo")
    $ShopStock = @{}
    foreach ($Item in $ShopStockNames) {
        $Stats = Get-ItemStats -ItemName $Item
        if ($null -ne $Stats) { $ShopStock[$Item] = $Stats.BasePrice }
    }
    return $ShopStock
}