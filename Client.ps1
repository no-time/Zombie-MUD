# --- Client.ps1 ---

$RequiredModules = @(
    "CharacterCreator.psm1", "Renderer.psm1", "CombatEngine.psm1",
    "SkillEngine.psm1", "RoomManager.psm1", "Bestiary.psm1",
    "InventoryManager.psm1", "SaveManager.psm1", "InputHandler.psm1", "StateManager.psm1"        
)

foreach ($Mod in $RequiredModules) {
    $ModPath = Join-Path $PSScriptRoot "Modules\$Mod"
    if (-not (Test-Path $ModPath)) { Write-Host "`n[!] FATAL ERROR: Could not find $Mod" -ForegroundColor Red; exit }
    try { Import-Module $ModPath -Force -ErrorAction Stop } 
    catch { Write-Host "`n[!] SYNTAX ERROR IN: $Mod" -ForegroundColor Red; exit }
}

$banner="%%%%######*******###%%%@@@@%%####***##**########
%#####***###%%%@@@@@@@@@@@@@@@@@%##**#*****#####
#####****@@@@@@@@@@%%%#####%##@@@@@@%##********#
###*****@@@@@@@@@@%##+=++++++++*#%%@@%#%**##**##
##***+*@@@@@@%@@@%*=============++*%%@@*%#***###
***+*#@@@@@@%%@@#*=====-=====++++++*#%@@%#*+****
****#@@@@@@%%%%*+*++++==++=+*%#+++**###@@#*++++*
*+++%@@@@@@%%%*+++++===++====+*+++*##*#%@@%*++++
*++#@@@@@@@%%#++++==---::---+**+*+*#+=+#%%*+++++
+++#@@@@@@%%%*==+=-:::-:-=+##*+*@%%*=-==*##+++++
+++@@@@@@@@%%+===:-+*#%%%%%#+*==*##**%@%*##+++++
++*@@@@@@@@%*=++=+%@@@@@@@%#**#%@@@@@@@@@%#+++++
+**@@@@@@@@#+-=+%@@#++*%@@#*=-*@@@@%##%@@@*+++++
**#@@@@@@@%+--+#@@#==-*%@%#=:.-%@@%+==+%@@#++++*
++*%%%@@%%#*+=#+*%%@@@@@#+=:-:-+@@@%##%@@%#**++*
+*%%#**%%#=:::.=++*%%%@%%=-:...-*#%@@@@%%#*##++*
+*#*=#%##*+==---::=-*+++**=.=*+*%**%%#*+**##*++*
*+****+=***%#**++=+=+**=-:=%@@#@@@***###%%@%+++*
++++*+=*#%##%%%%%%#**+=++-*#*#%%@@@###%%@@%*++**
++++*##*%@%#%@@@@@%#%*+--:-::+#*##%%%%%@@#+++***
++++=+**+*%##%#%@%@@#+==+===++***####%@%++++****
*++++=====*#*##%%+*@%##*%#@@@@@%@@@%%%@*++++****
**+++=====+##@@@@%@@%#%@*******@@@@@%%%+++******
**++====-+%%*#+%#%@%@%@@@ \\\\@@@@@@@@%#+****###
*++=====+#@@****#*##@@##@%@+@*%%#%@@%%*+***#####
*++++===*%@@*##*++=+*@%*#*%*%%%%###@%#***#######
+++*++==*%@+##%##*++#%*++-==-*#++++%%*+++*##%%%%
***++===*@#+##@@@@#=##+++=-=***==++%%#*+++++**##
***+====#%#%*@@%@%@%++*+%++==++==*%%####****++++
##*++===#%**@@%##%@@@*-::*-%%=:-+##@##%###******
##*+===+##+%@%**#@@@@@@%##=--=*##%@@%##%########
#**++==+#@@@@#**%@%%%##@@@@@@@@%@@@@@##%%#######
#*+++==+*@@%%#++@@#%%#%@@@@@@@%%@@@@@%##%%%%%###"

Clear-Host; Write-Host $banner -ForegroundColor DarkRed; Write-Host "`n"
Read-Host "Press [Enter] to awaken..."

$ExistingSave = Get-SavedGame

if ($null -ne $ExistingSave) {
    Write-Host "A previous save file was detected." -ForegroundColor DarkCyan
    $LoadChoice = Read-Host "(C)ontinue or (N)ew Game?"
    if ($LoadChoice.ToLower().Trim() -eq 'c') {
        $Player = $ExistingSave.Player
        $WorldMap = ConvertTo-Hashtable $ExistingSave.WorldMap
        $LegacyBonuses = ConvertTo-Hashtable $ExistingSave.LegacyBonuses
        $LegacyBonuses.UnlockedTiers = ConvertTo-Hashtable $ExistingSave.LegacyBonuses.UnlockedTiers
        if ($null -eq $LegacyBonuses.UnlockedClasses) { $LegacyBonuses.UnlockedClasses = @() }
        if ($null -eq $LegacyBonuses.Stash) { $LegacyBonuses.Stash = @() } else { $LegacyBonuses.Stash = @($LegacyBonuses.Stash) }
        if ($null -eq $LegacyBonuses.MaxLevelReached) { $LegacyBonuses.MaxLevelReached = $Player.Level }
        if ($null -eq $LegacyBonuses.Bonechips) { $LegacyBonuses.Bonechips = 0 }
        if ($null -eq $LegacyBonuses.Gunpowder) { $LegacyBonuses.Gunpowder = 0 }
        if ($null -eq $LegacyBonuses.EnergyOrbs) { $LegacyBonuses.EnergyOrbs = 0 }
        if ($null -eq $LegacyBonuses.ToxicGarnets) { $LegacyBonuses.ToxicGarnets = 0 }
        if ($null -eq $LegacyBonuses.PlayerCorpse) { $LegacyBonuses.PlayerCorpse = $null }
        if ($null -eq $LegacyBonuses.HasOuroboros) { $LegacyBonuses.HasOuroboros = $false }
        if ($null -eq $LegacyBonuses.ForesightMob) { $LegacyBonuses.ForesightMob = $null }
        Write-Host "Game loaded successfully." -ForegroundColor Green; Start-Sleep -Seconds 1
    } else {
        $LegacyBonuses = @{ Scrap = 0; UnlockedTiers = @{}; UnlockedClasses = @(); Stash = @(); MaxLevelReached = 1; Bonechips = 0; Gunpowder = 0; EnergyOrbs = 0; ToxicGarnets = 0; PlayerCorpse = $null; HasOuroboros = $false; ForesightMob = $null }
        $Player = New-PlayerCharacter -UnlockedClasses $LegacyBonuses.UnlockedClasses -HasLegendaryPet ($LegacyBonuses.HasLegendaryPet -eq $true)
        $WorldMap = Load-WorldMap
    }
} else {
    $LegacyBonuses = @{ Scrap = 0; UnlockedTiers = @{}; UnlockedClasses = @(); Stash = @(); MaxLevelReached = 1; Bonechips = 0; Gunpowder = 0; EnergyOrbs = 0; ToxicGarnets = 0; PlayerCorpse = $null; HasOuroboros = $false; ForesightMob = $null }
    $Player = New-PlayerCharacter -UnlockedClasses $LegacyBonuses.UnlockedClasses -HasLegendaryPet ($LegacyBonuses.HasLegendaryPet -eq $true)
    $WorldMap = Load-WorldMap
}

$NewSlots = @("EquippedArmor", "EquippedShoulders", "EquippedBoots", "EquippedTrinket", "EquippedNecklace")
foreach ($Slot in $NewSlots) { if (-not (Get-Member -InputObject $Player -Name $Slot -ErrorAction SilentlyContinue)) { $Player | Add-Member -MemberType NoteProperty -Name $Slot -Value "None" } }
if (-not (Get-Member -InputObject $Player -Name "LearnedSkills" -ErrorAction SilentlyContinue)) { $Player | Add-Member -MemberType NoteProperty -Name "LearnedSkills" -Value @(Get-ClassSkills -ClassName $Player.Class -PlayerLevel $Player.Level) }

if (-not (Get-Member -InputObject $Player -Name "Bonechips" -ErrorAction SilentlyContinue)) {
    $Player | Add-Member -MemberType NoteProperty -Name "Bonechips" -Value $LegacyBonuses.Bonechips
    $Player | Add-Member -MemberType NoteProperty -Name "AppliedBonechipTiers" -Value ([math]::Floor($LegacyBonuses.Bonechips / 100))
    $Player | Add-Member -MemberType NoteProperty -Name "Gunpowder" -Value $LegacyBonuses.Gunpowder
    $Player | Add-Member -MemberType NoteProperty -Name "AppliedGunpowderTiers" -Value ([math]::Floor($LegacyBonuses.Gunpowder / 100))
    $Player | Add-Member -MemberType NoteProperty -Name "EnergyOrbs" -Value $LegacyBonuses.EnergyOrbs
    $Player | Add-Member -MemberType NoteProperty -Name "AppliedOrbTiers" -Value ([math]::Floor($LegacyBonuses.EnergyOrbs / 100))
    $Player | Add-Member -MemberType NoteProperty -Name "ToxicGarnets" -Value $LegacyBonuses.ToxicGarnets
    $Player | Add-Member -MemberType NoteProperty -Name "AppliedGarnetTiers" -Value ([math]::Floor($LegacyBonuses.ToxicGarnets / 100))
    $Player | Add-Member -MemberType NoteProperty -Name "PetBonusHP" -Value 0
    $Player | Add-Member -MemberType NoteProperty -Name "BaseWeaponDamage" -Value 0
    $Player | Add-Member -MemberType NoteProperty -Name "IsStealthed" -Value $false
    $Player | Add-Member -MemberType NoteProperty -Name "EquippedOffhand" -Value "None"
    $Player | Add-Member -MemberType NoteProperty -Name "ShockAuraHits" -Value 0
    
    if ($Player.Class -eq "Immune Human") {
        $Player.MaxAmmo += ([math]::Floor($Player.Gunpowder / 100)); $Player.Ammo += ([math]::Floor($Player.Gunpowder / 100))
        $Player.BaseWeaponDamage += ([math]::Floor($Player.Gunpowder / 100)); $Player.Damage += ([math]::Floor($Player.Gunpowder / 100))
        $Player.BaseInfectivity += ([math]::Floor($Player.ToxicGarnets / 100)); $Player.Infectivity += ([math]::Floor($Player.ToxicGarnets / 100))
    } else {
        $DmgBoost = [math]::Floor(1.5 * [math]::Floor($Player.Gunpowder / 100))
        $Player.BaseWeaponDamage += $DmgBoost; $Player.Damage += $DmgBoost
        $Player.PetBonusHP += (10 * [math]::Floor($Player.ToxicGarnets / 100))
        if ($null -ne $Player.ActivePet) { $Player.ActivePet.MaxHP += (10 * [math]::Floor($Player.ToxicGarnets / 100)); $Player.ActivePet.HP += (10 * [math]::Floor($Player.ToxicGarnets / 100)) }
    }
    $Player.MaxHP += (10 * [math]::Floor($Player.Bonechips / 100)); $Player.HP += (10 * [math]::Floor($Player.Bonechips / 100))
    $Player.MaxSP += (1 * [math]::Floor($Player.EnergyOrbs / 100)); $Player.SP += (1 * [math]::Floor($Player.EnergyOrbs / 100))
}

$CurrentRoomID = "1"
$CurrentRoom = Get-RoomState -WorldMap $WorldMap -RoomID $CurrentRoomID

$GameIsRunning = $true
$LastActionMessage = "You have woken up. The nightmare begins. Type 'search' to look for trouble."
$TimePassed = $false 

# --- THE GAME ENGINE LOOP ---
while ($GameIsRunning) {
    Out-MudScreen -PlayerState $Player -RoomState $CurrentRoom -SystemMessage $LastActionMessage -MobState $CurrentMob

    Write-Host "`n"
    $Command = Read-Host "What would you like to do?"
    
    # 1. PARSE COMMAND
    $InputResult = Invoke-PlayerCommand -Command $Command -Player $Player -Mob $CurrentMob -NPC $CurrentNPC -Room $CurrentRoom -RoomID $CurrentRoomID -WorldMap $WorldMap -LegacyBonuses $LegacyBonuses
    
    $CurrentMob = $InputResult.Mob
    $CurrentNPC = $InputResult.NPC
    if ($CurrentRoomID -ne $InputResult.RoomID) {
        $CurrentRoomID = $InputResult.RoomID
        $CurrentRoom = Get-RoomState -WorldMap $WorldMap -RoomID $CurrentRoomID
    }
    $GameIsRunning = $InputResult.IsRunning
    $TimePassed = $InputResult.TurnPassed
    $LastActionMessage = $InputResult.Message

    # 2. END OF TURN STATE CALCULATION
    $TickResult = Invoke-GameTick -Player $Player -Mob $CurrentMob -TurnPassed $TimePassed -LegacyBonuses $LegacyBonuses
    
    if (-not [string]::IsNullOrWhiteSpace($TickResult.Message)) { $LastActionMessage += "`n> " + $TickResult.Message }
    if ($TickResult.MobDied) { $CurrentMob = $null }

    # 3. DEATH CHECK
    if ($Player.HP -le 0) {
        Write-Host "`nYOU HAVE DIED." -ForegroundColor Red -BackgroundColor Black
        
        Sync-LegacyCurrencies -Player $Player -LegacyBonuses $LegacyBonuses
        
        $CorpseInventory = @($Player.Inventory)
        $EquipSlots = @("EquippedWeapon", "EquippedOffhand", "EquippedArmor", "EquippedShoulders", "EquippedBoots", "EquippedTrinket", "EquippedNecklace")
        foreach ($Slot in $EquipSlots) { if ($Player.$Slot -ne "None" -and $Player.$Slot -ne "Fists" -and $null -ne $Player.$Slot) { $CorpseInventory += $Player.$Slot } }
        
        $CorpseMob = [PSCustomObject]@{ Name="Zombified $($Player.Name)"; Level=$Player.Level; HP=$Player.MaxHP; MaxHP=$Player.MaxHP; Damage=[math]::Max(5, $Player.Damage); Armor=$Player.Armor; BaseDamage=[math]::Max(5, $Player.Damage); BaseArmor=$Player.Armor; XP=($Player.Level * 50); Scrap=[math]::Floor($Player.Currency / 2); LootTable=$CorpseInventory; ActiveEffects=@(); Type="Zombie"; IsBoss=$true; IsImmune=$true; Skills=@("Slam", "Eat Flesh", "Toxic Cloud"); IsPlayerCorpse=$true }
        $LegacyBonuses.PlayerCorpse = [PSCustomObject]@{ RoomID = $CurrentRoomID; Mob = $CorpseMob }

        $InheritedScrap = [math]::Floor($Player.Currency * 0.10)
        $TrinketMessage = ""

        if ($null -ne $Player.ActivePet -and $Player.ActivePet.Level -ge 100) { $LegacyBonuses.HasLegendaryPet = $true; $InheritedScrap += 5000; $TrinketMessage += "Your Level 100 $($Player.ActivePet.Name) returns to the shadows, leaving 5000 scrap behind! " }
        $LegacyBonuses.Scrap += $InheritedScrap
        
        $LevelTiers = [math]::Floor($Player.Level / 25)
        $CurrentRecord = 0; if ($LegacyBonuses.UnlockedTiers.ContainsKey($Player.Class)) { $CurrentRecord = $LegacyBonuses.UnlockedTiers[$Player.Class] }
        if ($LevelTiers -gt $CurrentRecord) { $LegacyBonuses.UnlockedTiers[$Player.Class] = $LevelTiers; $TrinketMessage += "NEW LEGACY LANDMARK! Your achievements as a $($Player.Class) permanently empower future lives." }

        Write-Host "Death claims you, but your legacy survives." -ForegroundColor DarkGray
        Write-Host "> Your zombified corpse now wanders the very room you died in..." -ForegroundColor DarkRed
        Write-Host "> $InheritedScrap scrap coins were left behind for the next survivor." -ForegroundColor Yellow
        if (-not [string]::IsNullOrWhiteSpace($TrinketMessage)) { Write-Host "> $TrinketMessage" -ForegroundColor Magenta }
        Read-Host "`nPress [Enter] to awaken in a new body..."
        
        $Player = New-PlayerCharacter -UnlockedClasses $LegacyBonuses.UnlockedClasses -HasLegendaryPet ($LegacyBonuses.HasLegendaryPet -eq $true)
        $Player.Currency += $LegacyBonuses.Scrap
        
        if (-not (Get-Member -InputObject $Player -Name "Bonechips" -ErrorAction SilentlyContinue)) {
            $Player | Add-Member -MemberType NoteProperty -Name "Bonechips" -Value 0; $Player | Add-Member -MemberType NoteProperty -Name "AppliedBonechipTiers" -Value 0; $Player | Add-Member -MemberType NoteProperty -Name "Gunpowder" -Value 0; $Player | Add-Member -MemberType NoteProperty -Name "AppliedGunpowderTiers" -Value 0; $Player | Add-Member -MemberType NoteProperty -Name "EnergyOrbs" -Value 0; $Player | Add-Member -MemberType NoteProperty -Name "AppliedOrbTiers" -Value 0; $Player | Add-Member -MemberType NoteProperty -Name "ToxicGarnets" -Value 0; $Player | Add-Member -MemberType NoteProperty -Name "AppliedGarnetTiers" -Value 0; $Player | Add-Member -MemberType NoteProperty -Name "PetBonusHP" -Value 0; $Player | Add-Member -MemberType NoteProperty -Name "BaseWeaponDamage" -Value 0; $Player | Add-Member -MemberType NoteProperty -Name "IsStealthed" -Value $false; $Player | Add-Member -MemberType NoteProperty -Name "EquippedOffhand" -Value "None"; $Player | Add-Member -MemberType NoteProperty -Name "ShockAuraHits" -Value 0
        }

        $Player.Bonechips = $LegacyBonuses.Bonechips; $Player.AppliedBonechipTiers = [math]::Floor($Player.Bonechips / 100); $Player.Gunpowder = $LegacyBonuses.Gunpowder; $Player.AppliedGunpowderTiers = [math]::Floor($Player.Gunpowder / 100); $Player.EnergyOrbs = $LegacyBonuses.EnergyOrbs; $Player.AppliedOrbTiers = [math]::Floor($Player.EnergyOrbs / 100); $Player.ToxicGarnets = $LegacyBonuses.ToxicGarnets; $Player.AppliedGarnetTiers = [math]::Floor($Player.ToxicGarnets / 100)
        
        $TotalStr = 0; $TotalDex = 0; $TotalCon = 0; $TotalCha = 0; $TotalTac = 0; $TotalInt = 0; $TotalLuck = 0; $TotalInf = 0; $TotalHp = 0; $TotalSp = 0; $RawBp = 0; $RawAmmo = 0

        foreach ($ClassName in $LegacyBonuses.UnlockedTiers.Keys) {
            $Tiers = $LegacyBonuses.UnlockedTiers[$ClassName]
            switch ($ClassName) {
                'Bruiser'       { $TotalStr += (1 * $Tiers); $TotalHp += (5 * $Tiers) }
                'Tank'          { $TotalCon += (1 * $Tiers); $TotalHp += (16 * $Tiers) }
                'Popular'       { $TotalCha += (1 * $Tiers); $TotalSp += (2 * $Tiers) }
                'Stealthy'      { $TotalDex += (1 * $Tiers); $TotalHp += (2 * $Tiers); $TotalSp += (2 * $Tiers) }
                'Tactician'     { $TotalTac += (1 * $Tiers); $TotalSp += (2 * $Tiers) }
                'Technologist'  { $TotalInt += (1 * $Tiers); $TotalSp += (2 * $Tiers) }
                'Charmed'       { $TotalLuck += (1 * $Tiers); $TotalHp += (6 * $Tiers) }
                'Lobber'        { $TotalDex += (1 * $Tiers); $TotalStr += (1 * $Tiers) }
                'Plaguebringer' { $TotalInf += (2 * $Tiers); $TotalHp += (2 * $Tiers) }
                'Beserker'      { $TotalStr += (2 * $Tiers); $TotalHp += (6 * $Tiers) }
                'Vampire'       { $TotalStr += (1 * $Tiers); $TotalDex += (1 * $Tiers); $TotalCha += (1 * $Tiers); $TotalHp += (1 * $Tiers); $TotalSp += (1 * $Tiers); $RawBp += ($Tiers * 0.25) }
                'Immune Human'  { $TotalStr += (1 * $Tiers); $TotalDex += (1 * $Tiers); $TotalCon += (1 * $Tiers); $TotalCha += (1 * $Tiers); $TotalTac += (1 * $Tiers); $TotalInt += (1 * $Tiers); $TotalLuck += (1 * $Tiers); $TotalHp += (5 * $Tiers); $TotalSp += (1 * $Tiers); $RawAmmo += ($Tiers * 0.25) }
            }
        }
        $TotalBp = [math]::Floor($RawBp); $TotalAmmo = [math]::Floor($RawAmmo)

        $TotalHp += (10 * $Player.AppliedBonechipTiers); $TotalSp += (1 * $Player.AppliedOrbTiers)
        if ($Player.Class -eq "Immune Human") { $TotalAmmo += (1 * $Player.AppliedGunpowderTiers); $Player.BaseWeaponDamage += (1 * $Player.AppliedGunpowderTiers); $Player.Damage += (1 * $Player.AppliedGunpowderTiers); $TotalInf += (1 * $Player.AppliedGarnetTiers) } else { $DmgBoost = [math]::Floor(1.5 * $Player.AppliedGunpowderTiers); $Player.BaseWeaponDamage += $DmgBoost; $Player.Damage += $DmgBoost; $Player.PetBonusHP += (10 * $Player.AppliedGarnetTiers) }
        if ($LegacyBonuses.HasOuroboros) { $TotalStr += 5; $TotalDex += 5; $TotalCon += 5; $TotalCha += 5; $TotalTac += 5; $TotalInt += 5; $TotalLuck += 5 }

        $BonusMessage = @()
        if ($TotalStr -gt 0) { $Player.BaseStrength += $TotalStr; $Player.Strength = $Player.BaseStrength; $BonusMessage += "+$TotalStr STR" }
        if ($TotalDex -gt 0) { $Player.BaseDexterity += $TotalDex; $Player.Dexterity = $Player.BaseDexterity; $BonusMessage += "+$TotalDex DEX" }
        if ($TotalCon -gt 0) { $Player.BaseCON += $TotalCon; $Player.CON = $Player.BaseCON; $BonusMessage += "+$TotalCon CON" }
        if ($TotalCha -gt 0) { $Player.BaseCHA += $TotalCha; $Player.CHA = $Player.BaseCHA; $BonusMessage += "+$TotalCha CHA" }
        if ($TotalTac -gt 0) { $Player.BaseTactics += $TotalTac; $Player.Tactics = $Player.BaseTactics; $BonusMessage += "+$TotalTac TAC" }
        if ($TotalInt -gt 0) { $Player.BaseInt += $TotalInt; $Player.Int = $Player.BaseInt; $BonusMessage += "+$TotalInt INT" }
        if ($TotalLuck -gt 0) { $Player.BaseLuck += $TotalLuck; $Player.Luck = $Player.BaseLuck; $BonusMessage += "+$TotalLuck LUCK" }
        if ($TotalInf -gt 0) { $Player.BaseInfectivity += $TotalInf; $Player.Infectivity = $Player.BaseInfectivity; $BonusMessage += "+$TotalInf INF/RES" }
        if ($TotalHp -gt 0) { $Player.MaxHP += $TotalHp; $Player.HP = $Player.MaxHP; $BonusMessage += "+$TotalHp HP" }
        if ($TotalSp -gt 0) { $Player.MaxSP += $TotalSp; $Player.SP = $Player.MaxSP; $BonusMessage += "+$TotalSp SP" }
        if ($TotalBp -gt 0 -and $Player.Class -eq "Vampire") { $Player.MaxBP += $TotalBp; $Player.BP = $Player.MaxBP; $BonusMessage += "+$TotalBp BP" }
        if ($TotalAmmo -gt 0 -and $Player.Class -eq "Immune Human") { $Player.MaxAmmo += $TotalAmmo; $Player.Ammo = $Player.MaxAmmo; $BonusMessage += "+$TotalAmmo AMMO" }

        $Player.BaseArmor = [math]::Floor($Player.BaseDexterity / 3) + [math]::Floor($Player.BaseCON / 10)
        
        $NewSlots = @("EquippedArmor", "EquippedShoulders", "EquippedBoots", "EquippedTrinket", "EquippedNecklace")
        foreach ($Slot in $NewSlots) { if (-not (Get-Member -InputObject $Player -Name $Slot -ErrorAction SilentlyContinue)) { $Player | Add-Member -MemberType NoteProperty -Name $Slot -Value "None" } }
        if (-not (Get-Member -InputObject $Player -Name "LearnedSkills" -ErrorAction SilentlyContinue)) { $Player | Add-Member -MemberType NoteProperty -Name "LearnedSkills" -Value @(Get-ClassSkills -ClassName $Player.Class -PlayerLevel $Player.Level) }
        $Player.Armor = $Player.BaseArmor

        if ($BonusMessage.Count -gt 0) { $MsgString = $BonusMessage -join ", "; Write-Host "`n> The ancestral trinkets glow... You inherited: $MsgString!" -ForegroundColor Magenta }

        $CurrentRoomID = "1"; $CurrentRoom = Get-RoomState -WorldMap $WorldMap -RoomID $CurrentRoomID; $CurrentMob = $null; $CurrentNPC = $null; $LastActionMessage = "Death was only a temporary setback. You feel the strength of your past lives."; $TimePassed = $false
        continue 
    }
}