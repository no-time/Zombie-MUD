# --- Modules\Bestiary.psm1 ---

function Get-RandomMob {
    param([int]$MaxLevel = 999, [int]$MinLevel = 1) 

    $MapPath = Join-Path $PSScriptRoot "..\Data\bestiary.json"
    
    if (-not (Test-Path $MapPath)) {
        Write-Host "`n[!] CRITICAL ERROR: Cannot find bestiary.json at $MapPath" -ForegroundColor Red -BackgroundColor Black
        Read-Host "Press [Enter] to acknowledge..."
        return $null
    }

    $RawJson = Get-Content $MapPath -Raw
    $MobTemplates = ConvertFrom-Json $RawJson
    if ($MobTemplates -isnot [array]) { $MobTemplates = @($MobTemplates) }

    # --- MIN/MAX LEVEL FILTERING ---
    $ValidMobs = $MobTemplates | Where-Object { $_.Level -le $MaxLevel -and $_.Level -ge $MinLevel }
    
    # Fallback just in case no mobs fit the exact bracket
    if ($null -eq $ValidMobs -or $ValidMobs.Count -eq 0) { 
        $ValidMobs = $MobTemplates | Where-Object { $_.Level -le $MaxLevel } 
    }

    $Template = $ValidMobs | Get-Random

    $Mob = [PSCustomObject]@{
        Name      = $Template.Name
        Level     = $Template.Level
        HP        = $Template.BaseHP
        MaxHP     = $Template.BaseHP
        Damage    = $Template.BaseDamage
        Armor     = $Template.BaseArmor
        BaseDamage= $Template.BaseDamage 
        BaseArmor = $Template.BaseArmor  
        XP        = $Template.BaseXP    
        Scrap     = $Template.Scrap     
        LootTable = $Template.LootTable 
        ActiveEffects = @()              
        
        Type      = if ($null -ne $Template.Type) { $Template.Type } else { "Zombie" }
        IsBoss    = if ($null -ne $Template.IsBoss) { $Template.IsBoss } else { $false }
        IsImmune  = if ($null -ne $Template.IsImmune) { $Template.IsImmune } else { $false }
        Skills    = if ($null -ne $Template.Skills) { @($Template.Skills) } else { @() }
    }

    return $Mob
}