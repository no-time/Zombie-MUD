# --- Client.ps1 ---

$RequiredModules = @(
    "CharacterCreator.psm1", "Renderer.psm1", "CombatEngine.psm1",
    "SkillEngine.psm1", "RoomManager.psm1", "Bestiary.psm1",
    "InventoryManager.psm1", "SaveManager.psm1"        
)

foreach ($Mod in $RequiredModules) {
    $ModPath = Join-Path $PSScriptRoot "Modules\$Mod"
    if (-not (Test-Path $ModPath)) { Write-Host "`n[!] FATAL ERROR: Could not find $Mod" -ForegroundColor Red; exit }
    try { Import-Module $ModPath -Force -ErrorAction Stop } 
    catch { Write-Host "`n[!] SYNTAX ERROR IN: $Mod" -ForegroundColor Red; exit }
}

# --- INTRO BANNER ---
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

# --- GAME INITIALIZATION & PERSISTENCE ---
$ExistingSave = Get-SavedGame

if ($null -ne $ExistingSave) {
    Write-Host "A previous save file was detected." -ForegroundColor DarkCyan
    $LoadChoice = Read-Host "(C)ontinue or (N)ew Game?"
    if ($LoadChoice.ToLower().Trim() -eq 'c') {
        $Player = $ExistingSave.Player
        $WorldMap = ConvertTo-Hashtable $ExistingSave.WorldMap
        $LegacyBonuses = ConvertTo-Hashtable $ExistingSave.LegacyBonuses
        $LegacyBonuses.UnlockedTiers = ConvertTo-Hashtable $ExistingSave.LegacyBonuses.UnlockedTiers
        
        # --- HOTFIXES FOR OLD SAVES ---
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

# --- GEAR & SKILLS HOTFIX INJECTION ---
$NewSlots = @("EquippedArmor", "EquippedShoulders", "EquippedBoots", "EquippedTrinket", "EquippedNecklace")
foreach ($Slot in $NewSlots) {
    if (-not (Get-Member -InputObject $Player -Name $Slot -ErrorAction SilentlyContinue)) { $Player | Add-Member -MemberType NoteProperty -Name $Slot -Value "None" }
}

if (-not (Get-Member -InputObject $Player -Name "LearnedSkills" -ErrorAction SilentlyContinue)) {
    $BaseSkills = Get-ClassSkills -ClassName $Player.Class -PlayerLevel $Player.Level
    $Player | Add-Member -MemberType NoteProperty -Name "LearnedSkills" -Value @($BaseSkills)
}

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
    
    # --- SYNC ELEMENTAL CURRENCIES TO ACCOUNT LEGACY ---
    $LegacyBonuses.Bonechips = $Player.Bonechips
    $LegacyBonuses.Gunpowder = $Player.Gunpowder
    $LegacyBonuses.EnergyOrbs = $Player.EnergyOrbs
    $LegacyBonuses.ToxicGarnets = $Player.ToxicGarnets

    if ($Player.Level -gt $LegacyBonuses.MaxLevelReached) { $LegacyBonuses.MaxLevelReached = $Player.Level }

    # --- ELEMENTAL MILESTONE ENGINE ---
    $bBoneTiers = [math]::Floor($Player.Bonechips / 100)
    if ($bBoneTiers -gt $Player.AppliedBonechipTiers) {
        $Gain = $bBoneTiers - $Player.AppliedBonechipTiers
        $Player.MaxHP += (10 * $Gain); $Player.HP += (10 * $Gain)
        $Player.AppliedBonechipTiers = $bBoneTiers
        $LastActionMessage += "`n`n*** ELEMENTAL MILESTONE ***`n> Bonechips harden your body! (+$(10 * $Gain) HP)"
    }

    $bGunTiers = [math]::Floor($Player.Gunpowder / 100)
    if ($bGunTiers -gt $Player.AppliedGunpowderTiers) {
        $Gain = $bGunTiers - $Player.AppliedGunpowderTiers
        if ($Player.Class -eq "Immune Human") {
            $Player.MaxAmmo += (1 * $Gain); $Player.Ammo += (1 * $Gain)
            $Player.BaseWeaponDamage += (1 * $Gain); $Player.Damage += (1 * $Gain)
            $LastActionMessage += "`n`n*** ELEMENTAL MILESTONE ***`n> Gunpowder refines your arsenal! (+$(1 * $Gain) Ammo, +$(1 * $Gain) DMG)"
        } else {
            $TotalDmg = [math]::Floor(1.5 * $bGunTiers)
            $AppliedDmg = [math]::Floor(1.5 * $Player.AppliedGunpowderTiers)
            $DmgGain = $TotalDmg - $AppliedDmg
            $Player.BaseWeaponDamage += $DmgGain; $Player.Damage += $DmgGain
            $LastActionMessage += "`n`n*** ELEMENTAL MILESTONE ***`n> Gunpowder fuses with your attacks! (+$DmgGain DMG)"
        }
        $Player.AppliedGunpowderTiers = $bGunTiers
    }

    $bOrbTiers = [math]::Floor($Player.EnergyOrbs / 100)
    if ($bOrbTiers -gt $Player.AppliedOrbTiers) {
        $Gain = $bOrbTiers - $Player.AppliedOrbTiers
        $Player.MaxSP += (1 * $Gain); $Player.SP += (1 * $Gain)
        $Player.AppliedOrbTiers = $bOrbTiers
        $LastActionMessage += "`n`n*** ELEMENTAL MILESTONE ***`n> Energy Orbs expand your stamina! (+$(1 * $Gain) SP)"
    }

    $bGarnetTiers = [math]::Floor($Player.ToxicGarnets / 100)
    if ($bGarnetTiers -gt $Player.AppliedGarnetTiers) {
        $Gain = $bGarnetTiers - $Player.AppliedGarnetTiers
        if ($Player.Class -eq "Immune Human") {
            $Player.BaseInfectivity += (1 * $Gain); $Player.Infectivity = $Player.BaseInfectivity
            $LastActionMessage += "`n`n*** ELEMENTAL MILESTONE ***`n> Toxic Garnets mutate your DNA! (+$(1 * $Gain) Resistance)"
        } else {
            $Player.PetBonusHP += (10 * $Gain)
            if ($null -ne $Player.ActivePet) { $Player.ActivePet.MaxHP += (10 * $Gain); $Player.ActivePet.HP += (10 * $Gain) }
            $LastActionMessage += "`n`n*** ELEMENTAL MILESTONE ***`n> Toxic Garnets empower your pets! (+$(10 * $Gain) Pet HP)"
        }
        $Player.AppliedGarnetTiers = $bGarnetTiers
    }

    # --- LEGACY MILESTONE ENGINE (LEVEL 25 TIERS) ---
    $CurrentTier = [math]::Floor($Player.Level / 25)
    $AccountRecord = 0
    if ($LegacyBonuses.UnlockedTiers.ContainsKey($Player.Class)) { $AccountRecord = $LegacyBonuses.UnlockedTiers[$Player.Class] }

    if ($CurrentTier -gt $AccountRecord -and $Player.Level -ge 25) {
        $bStr = 0; $bDex = 0; $bCon = 0; $bCha = 0; $bTac = 0; $bInt = 0; $bLuck = 0; $bInf = 0; $bHp = 0; $bSp = 0; $bBp = 0; $bAmmo = 0
        switch ($Player.Class) {
            'Bruiser'       { $bStr += 1; $bHp += 5 }
            'Tank'          { $bCon += 1; $bHp += 16 }
            'Popular'       { $bCha += 1; $bSp += 2 }
            'Stealthy'      { $bDex += 1; $bHp += 2; $bSp += 2 }
            'Tactician'     { $bTac += 1; $bSp += 2 }
            'Technologist'  { $bInt += 1; $bSp += 2 }
            'Charmed'       { $bLuck += 1; $bHp += 6 }
            'Lobber'        { $bDex += 1; $bStr += 1 }
            'Plaguebringer' { $bInf += 2; $bHp += 2 }
            'Beserker'      { $bStr += 2; $bHp += 6 }
            'Vampire'       { $bStr += 1; $bDex += 1; $bCha += 1; $bHp += 1; $bSp += 1; $bBp += ([math]::Floor($CurrentTier * 0.25) - [math]::Floor($AccountRecord * 0.25)) }
            'Immune Human'  { $bStr += 1; $bDex += 1; $bCon += 1; $bCha += 1; $bTac += 1; $bInt += 1; $bLuck += 1; $bHp += 5; $bSp += 1; $bAmmo += ([math]::Floor($CurrentTier * 0.25) - [math]::Floor($AccountRecord * 0.25)) }
        }

        $LegacyBonuses.UnlockedTiers[$Player.Class] = $CurrentTier

        $BonusMessage = @()
        if ($bStr -gt 0) { $Player.BaseStrength += $bStr; $Player.Strength = $Player.BaseStrength; $BonusMessage += "+$bStr STR" }
        if ($bDex -gt 0) { $Player.BaseDexterity += $bDex; $Player.Dexterity = $Player.BaseDexterity; $BonusMessage += "+$bDex DEX" }
        if ($bCon -gt 0) { $Player.BaseCON += $bCon; $Player.CON = $Player.BaseCON; $BonusMessage += "+$bCon CON" }
        if ($bCha -gt 0) { $Player.BaseCHA += $bCha; $Player.CHA = $Player.BaseCHA; $BonusMessage += "+$bCha CHA" }
        if ($bTac -gt 0) { $Player.BaseTactics += $bTac; $Player.Tactics = $Player.BaseTactics; $BonusMessage += "+$bTac TAC" }
        if ($bInt -gt 0) { $Player.BaseInt += $bInt; $Player.Int = $Player.BaseInt; $BonusMessage += "+$bInt INT" }
        if ($bLuck -gt 0) { $Player.BaseLuck += $bLuck; $Player.Luck = $Player.BaseLuck; $BonusMessage += "+$bLuck LUCK" }
        if ($bInf -gt 0) { $Player.BaseInfectivity += $bInf; $Player.Infectivity = $Player.BaseInfectivity; $BonusMessage += "+$bInf INF" }
        if ($bHp -gt 0) { $Player.MaxHP += $bHp; $Player.HP += $bHp; $BonusMessage += "+$bHp HP" }
        if ($bSp -gt 0) { $Player.MaxSP += $bSp; $Player.SP += $bSp; $BonusMessage += "+$bSp SP" }
        if ($bBp -gt 0 -and $Player.Class -eq "Vampire") { $Player.MaxBP += $bBp; $Player.BP += $bBp; $BonusMessage += "+$bBp MAX BP" }
        if ($bAmmo -gt 0 -and $Player.Class -eq "Immune Human") { $Player.MaxAmmo += $bAmmo; $Player.Ammo += $bAmmo; $BonusMessage += "+$bAmmo MAX AMMO" }
        
        $MsgString = $BonusMessage -join ", "
        $LastActionMessage += "`n`n*** NEW ACCOUNT LEGACY UNLOCKED! (Tier $CurrentTier) ***`n> You gained an immediate $MsgString!`n> Future characters will permanently inherit this power."
    }

    # 1. Draw the screen
    Out-MudScreen -PlayerState $Player -RoomState $CurrentRoom -SystemMessage $LastActionMessage -MobState $CurrentMob

    # 2. Capture player input
    Write-Host "`n"
    $Command = Read-Host "What would you like to do?"
    $CleanCommand = $Command.ToLower().Trim()
    $TurnPassed = $false 

    # 3. COMBAT STATE PARSER
    if ($null -ne $CurrentMob -and $CurrentMob.HP -gt 0) {
        
        $TurnMessages = @()
        
        if ($TimePassed) {
            $BonusMobDmg = 0; $BonusMobArmor = 0
            $RemainingMobEffects = @()
            
            if ($null -ne $CurrentMob.ActiveEffects) {
                foreach ($Effect in $CurrentMob.ActiveEffects) {
                    if ($Effect.Duration -gt 0) {
                        if ($Effect.Modifiers.ContainsKey('Damage')) { $BonusMobDmg += $Effect.Modifiers.Damage }
                        if ($Effect.Modifiers.ContainsKey('Armor'))  { $BonusMobArmor += $Effect.Modifiers.Armor }
                        
                        if ($null -ne $Effect.DoT -and $Effect.DoT -gt 0) {
                            $CurrentMob.HP -= $Effect.DoT
                            $TurnMessages += "The $($CurrentMob.Name) takes $($Effect.DoT) damage from [$($Effect.Name)]!"
                            
                            # --- LOBBER 20: FLESH PARASITE ---
                            if ($Player.LearnedSkills -contains "Flesh Parasite" -and (Get-Random -Min 1 -Max 101) -le 10) {
                                $Heal = [math]::Floor($Effect.DoT / 2)
                                $Player.HP = [math]::Min($Player.MaxHP, $Player.HP + $Heal)
                                $TurnMessages += "🦠 FLESH PARASITE! You siphon $Heal HP from the affliction!"
                            }
                        }
                        $Effect.Duration -= 1
                        $RemainingMobEffects += $Effect
                    } else {
                        $TurnMessages += "The effect of [$($Effect.Name)] on the $($CurrentMob.Name) has faded."
                    }
                }
            }
            $CurrentMob.ActiveEffects = $RemainingMobEffects
            $CurrentMob.Damage = [math]::Max(0, ($CurrentMob.BaseDamage + $BonusMobDmg))
            $CurrentMob.Armor  = [math]::Max(0, ($CurrentMob.BaseArmor + $BonusMobArmor))
        }
        
        # --- DOT DEATH CHECK PATCH ---
        if ($CurrentMob.HP -le 0) {
            $Player.XP += $CurrentMob.XP; $Player.Currency += $CurrentMob.Scrap
            $TurnMessages += "The $($CurrentMob.Name) succumbed to its wounds and died! Gained $($CurrentMob.XP) XP."

            # --- STEALTHY 20: RE-ENTER STEALTH ---
            if ($Player.LearnedSkills -contains "Stealth" -and -not $Player.IsStealthed) {
                $Player.IsStealthed = $true
                $TurnMessages += "`n> 🌑 You naturally fade back into the shadows."
            }

            if ($null -eq $Player.ActivePet) {
                $HasCurse = @($CurrentMob.ActiveEffects) | Where-Object { $_.Name -eq "Blood Curse" }
                $HasRot = @($CurrentMob.ActiveEffects) | Where-Object { $_.Name -eq "Zombie Rot" }

                if ($null -ne $HasCurse) {
                    $Player.ActivePet = [PSCustomObject]@{ Name="Vampiric $($CurrentMob.Name)"; Level=$CurrentMob.Level; XP=0; MaxHP=($CurrentMob.MaxHP + $Player.PetBonusHP); HP=($CurrentMob.MaxHP + $Player.PetBonusHP); Damage=$CurrentMob.Damage; Armor=$CurrentMob.Armor; IsLegacyPet = $false }
                    $TurnMessages += "The Blood Curse takes hold... The $($CurrentMob.Name) resurrects as your Vampiric servant!"
                } elseif ($null -ne $HasRot) {
                    if (Invoke-InfectionCheck -Infectivity $Player.Infectivity) {
                        $Player.ActivePet = [PSCustomObject]@{ Name="Rotting $($CurrentMob.Name)"; Level=$CurrentMob.Level; XP=0; MaxHP=($CurrentMob.MaxHP + $Player.PetBonusHP); HP=($CurrentMob.MaxHP + $Player.PetBonusHP); Damage=$CurrentMob.Damage; Armor=$CurrentMob.Armor; IsLegacyPet = $false }
                        $TurnMessages += "COIN FLIP WON: The Zombie Rot consumes the corpse... The $($CurrentMob.Name) rises as your infected servant!"
                    } else {
                        $TurnMessages += "COIN FLIP FAILED: The $($CurrentMob.Name)'s corpse rots into useless sludge."
                    }
                }
            }
            
            if ($null -ne $Player.ActivePet -and $Player.ActivePet.Level -lt 100) {
                $Player.ActivePet.XP += $CurrentMob.XP
                $pLvl = $Player.ActivePet.Level; $NextXP = 10000
                if ($pLvl -ge 99) { $NextXP = 1000000 } elseif ($pLvl -ge 61) { $NextXP = 250000 } elseif ($pLvl -ge 51) { $NextXP = 100000 }
                elseif ($pLvl -ge 41) { $NextXP = 50000 } elseif ($pLvl -ge 36) { $NextXP = 25000 } elseif ($pLvl -ge 31) { $NextXP = 17500 }
                elseif ($pLvl -ge 21) { $NextXP = 15000 } elseif ($pLvl -ge 11) { $NextXP = 12500 }

                while ($Player.ActivePet.XP -ge $NextXP -and $Player.ActivePet.Level -lt 100) {
                    $Player.ActivePet.Level += 1; $Player.ActivePet.XP -= $NextXP
                    $Player.ActivePet.MaxHP += 15; $Player.ActivePet.HP = $Player.ActivePet.MaxHP
                    $Player.ActivePet.Damage += 3; $Player.ActivePet.Armor += 1
                    $TurnMessages += "YOUR PET LEVELED UP! The $($Player.ActivePet.Name) is now Level $($Player.ActivePet.Level)!"
                    $pLvl = $Player.ActivePet.Level; $NextXP = 10000
                    if ($pLvl -ge 99) { $NextXP = 1000000 } elseif ($pLvl -ge 61) { $NextXP = 250000 } elseif ($pLvl -ge 51) { $NextXP = 100000 }
                    elseif ($pLvl -ge 41) { $NextXP = 50000 } elseif ($pLvl -ge 36) { $NextXP = 25000 } elseif ($pLvl -ge 31) { $NextXP = 17500 }
                    elseif ($pLvl -ge 21) { $NextXP = 15000 } elseif ($pLvl -ge 11) { $NextXP = 12500 }
                }
            }

            if ($null -ne $CurrentMob.LootTable -and $CurrentMob.LootTable.Count -gt 0) {
                foreach ($Item in $CurrentMob.LootTable) {
                    $ItemData = Get-ItemStats -ItemName $Item
                    $IsUnique = ($null -ne $ItemData -and $ItemData.Type -eq "Trinket")
                    $AlreadyOwned = $false
                    
                    if ($IsUnique) {
                        $AllOwned = @($Player.Inventory) + @($Player.EquippedTrinket)
                        if ($null -ne $LegacyBonuses -and $null -ne $LegacyBonuses.Stash) { $AllOwned += @($LegacyBonuses.Stash) }
                        foreach ($Owned in $AllOwned) { if ($Owned -ieq $Item) { $AlreadyOwned = $true; break } }
                    }
                    
                    if (-not $AlreadyOwned) {
                        $Player.Inventory += $Item
                        $TurnMessages += "[LOOT] You picked up: $Item"
                    } else {
                        $TurnMessages += "[LOOT] You see a [$Item], but since it's a unique artifact you already possess, you leave it behind."
                    }
                }
            }

            while ($Player.XP -ge $Player.NextLevelXP) {
                $Player.Level += 1; $Player.MaxHP += 15; $Player.HP = $Player.MaxHP; $Player.MaxSP += 1; $Player.SP = $Player.MaxSP; 
                $Player.BaseStrength += 2; $Player.Strength = $Player.BaseStrength
                $Player.BaseDexterity += 2; $Player.Dexterity = $Player.BaseDexterity
                $Player.BaseCON += 1; $Player.CON = $Player.BaseCON
                $Player.BaseCHA += 1; $Player.CHA = $Player.BaseCHA
                $Player.BaseTactics += 1; $Player.Tactics = $Player.BaseTactics
                $Player.BaseInt += 1; $Player.Int = $Player.BaseInt
                $Player.BaseLuck += 1; $Player.Luck = $Player.BaseLuck
                
                if ($Player.Class -ne "Immune Human") { $Player.BaseInfectivity += 1; $Player.Infectivity = $Player.BaseInfectivity }
                $Player.NextLevelXP = [math]::Round($Player.NextLevelXP * 1.5)
                $TurnMessages += "LEVEL UP! You are now Level $($Player.Level)! Your stats have increased, and your HP and SP are fully restored."
                
                $NewClassSkills = Get-ClassSkills -ClassName $Player.Class -PlayerLevel $Player.Level
                foreach ($sk in $NewClassSkills) { if ($Player.LearnedSkills -notcontains $sk) { $Player.LearnedSkills += $sk } }
                
                if ($Player.Class -eq "Stealthy" -and $Player.Level -eq 20) { $Player.IsStealthed = $true; $TurnMessages += "🌑 STEALTH UNLOCKED: You naturally fade into the shadows." }
                if ($Player.Class -eq "Immune Human" -and $Player.Level -eq 20 -and $Player.Inventory -notcontains "Shotgun" -and $Player.EquippedWeapon -ne "Shotgun") { 
                    $Player.Inventory += "Shotgun"; $TurnMessages += "💥 LEVEL 20: You salvaged a heavy Shotgun for your arsenal!" 
                }
            }

            if ($null -ne $CurrentMob.IsPlayerCorpse -and $CurrentMob.IsPlayerCorpse) { $LegacyBonuses.PlayerCorpse = $null }
            $LastActionMessage = $TurnMessages -join "`n> "
            $CurrentMob = $null
        } else {
            # --- COMBAT SWITCH LOGIC ---
            switch -Regex ($CleanCommand) {
                '^a$|^attack$' { 
                    $TurnMessages += Invoke-CombatRound -Player $Player -Mob $CurrentMob -Action 'attack' -LegacyBonuses $LegacyBonuses
                    $TurnPassed = $true 
                }
                '^r$|^run$' { 
                    $TurnMessages += Invoke-CombatRound -Player $Player -Mob $CurrentMob -Action 'run' -LegacyBonuses $LegacyBonuses
                    if ($CurrentMob.HP -le 0 -and $null -ne $CurrentMob.IsPlayerCorpse -and $CurrentMob.IsPlayerCorpse) {
                        $LegacyBonuses.PlayerCorpse = $null
                        $TurnMessages += "`n> You fled! The zombified husk of your past self wanders off into the darkness, lost forever."
                    }
                    $TurnPassed = $true 
                }
                '^(give up|suicide)$' { 
                    $Player.HP = 0 
                    $TurnMessages += "You drop your weapon and surrender to the horde. The darkness takes you..." 
                    $TurnPassed = $true
                }
                '^skills$' {
                    $SkillDBPath = Join-Path $PSScriptRoot "Data\skills.json"
                    $SkillDB = ConvertFrom-Json (Get-Content $SkillDBPath -Raw)
                    $SkillDisplay = @("=== YOUR LEARNED SKILLS ===")
                    foreach ($LS in $Player.LearnedSkills) {
                        $SData = $SkillDB.$LS
                        if ($null -ne $SData) { $SkillDisplay += " - $($LS.PadRight(15)) | Cost: $($SData.Cost.PadRight(6)) | $($SData.Description)" } 
                        else { $SkillDisplay += " - $LS" }
                    }
                    $SkillDisplay += "--------------------------------------------------"
                    $SkillDisplay += " Type 'use [skillname]' in combat to activate."
                    $TurnMessages += $SkillDisplay -join "`n> "
                }
                '^use\s+(.+)' {
                    $TargetName = $Matches[1].Trim()
                    $RealItem = $Player.Inventory | Where-Object { $_ -ieq $TargetName } | Select-Object -First 1
                    if ($null -ne $RealItem) {
                        $ItemData = Get-ItemStats -ItemName $RealItem
                        if ($null -ne $ItemData -and $ItemData.Type -eq "Consumable") {
                            $ItemUsed = $false
                            if ($RealItem -eq "Bandage") {
                                $Player.HP = [math]::Min($Player.MaxHP, ($Player.HP + $ItemData.Value))
                                $TurnMessages += "You applied the [$RealItem] and recovered $($ItemData.Value) HP."
                                $Bleed = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Bleeding" }
                                if ($null -ne $Bleed) {
                                    $Player.ActiveEffects = @($Player.ActiveEffects | Where-Object { $_.Name -ne "Bleeding" })
                                    $TurnMessages += "The tight wrapping completely stopped your bleeding!"
                                }
                                $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList)
                                $ItemUsed = $true
                            } elseif ($RealItem -eq "Energy Drink") {
                                if ($Player.SP -ge $Player.MaxSP -and ($null -eq (@($Player.ActiveEffects) | Where-Object { $_.Name -eq "Zombie Rot" -or $_.Name -eq "Infected Wound" }))) { 
                                    $TurnMessages += "You feel jittery, but you are already at maximum stamina and have no infections to cure. You can't drink that right now." 
                                } else {
                                    $Player.SP = [math]::Min($Player.MaxSP, ($Player.SP + $ItemData.Value))
                                    $TurnMessages += "You chugged the [$RealItem] and recovered $($ItemData.Value) SP."
                                    $Rot = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Zombie Rot" -or $_.Name -eq "Infected Wound" }
                                    if ($null -ne $Rot) {
                                        $Player.ActiveEffects = @($Player.ActiveEffects | Where-Object { $_.Name -ne "Zombie Rot" -and $_.Name -ne "Infected Wound" })
                                        $TurnMessages += "The intense chemical rush purged the infection from your veins!"
                                    }
                                    $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList)
                                    $ItemUsed = $true
                                }
                            } elseif ($RealItem -eq "Pistol Ammo") {
                                if ($Player.Class -ne "Immune Human") { $TurnMessages += "You have no idea how to use this." }
                                elseif ($Player.Ammo -ge $Player.MaxAmmo) { $TurnMessages += "Your magazine is already full!" }
                                else {
                                    $Player.Ammo = [math]::Min($Player.MaxAmmo, ($Player.Ammo + $ItemData.Value))
                                    $TurnMessages += "You loaded $($ItemData.Value) rounds into your Glock. (Ammo: $($Player.Ammo)/$($Player.MaxAmmo))"
                                    $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList)
                                    $ItemUsed = $true
                                }
                            }
                            
                            if ($ItemUsed) {
                                $MobTurn = Invoke-MobTurn -Player $Player -Mob $CurrentMob
                                if (-not [string]::IsNullOrWhiteSpace($MobTurn)) { $TurnMessages += $MobTurn -replace "^`n>\s*", "" }
                                $TurnPassed = $true
                            }
                        } else { $TurnMessages += "You cannot use the [$RealItem] right now." }
                    } else {
                        $SkillRes = Invoke-SkillRound -Player $Player -Mob $CurrentMob -SkillName $TargetName -LegacyBonuses $LegacyBonuses
                        $TurnMessages += $SkillRes
                        if ($SkillRes -notmatch "You do not know|Needs|already transformed|out of ammo|cannot use|You are too Exhausted") {
                            $TurnPassed = $true
                            if ($null -ne $CurrentMob -and $CurrentMob.HP -gt 0) {
                                $MobTurn = Invoke-MobTurn -Player $Player -Mob $CurrentMob
                                if (-not [string]::IsNullOrWhiteSpace($MobTurn)) { $TurnMessages += $MobTurn -replace "^`n>\s*", "" }
                            }
                        }
                    }
                }
                '^release(\s+pet)?$' {
                    if ($null -ne $Player.ActivePet) {
                        $HealAmount = $Player.ActivePet.HP
                        $Player.HP = [math]::Min($Player.MaxHP, ($Player.HP + $HealAmount))
                        $TurnMessages += "You drain the energy from the $($Player.ActivePet.Name), adding it to your own. You were healed for $HealAmount HP."
                        $Player.ActivePet = $null
                        $MobTurn = Invoke-MobTurn -Player $Player -Mob $CurrentMob
                        if (-not [string]::IsNullOrWhiteSpace($MobTurn)) { $TurnMessages += $MobTurn -replace "^`n>\s*", "" }
                        $TurnPassed = $true
                    } else { $TurnMessages += "You do not have an active pet to release!" }
                }
                '^reload$' {
                    if ($Player.Class -ne "Immune Human") { $TurnMessages += "You don't have a gun to reload." }
                    elseif ($Player.Ammo -ge $Player.MaxAmmo) { $TurnMessages += "Your magazine is already full!" }
                    else {
                        $AmmoItem = $Player.Inventory | Where-Object { $_ -ieq "Pistol Ammo" } | Select-Object -First 1
                        if ($null -ne $AmmoItem) {
                            $ItemData = Get-ItemStats -ItemName $AmmoItem
                            $Player.Ammo = [math]::Min($Player.MaxAmmo, ($Player.Ammo + $ItemData.Value))
                            $TurnMessages += "You slammed a new magazine into your Glock. (Ammo: $($Player.Ammo)/$($Player.MaxAmmo))"
                            $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($AmmoItem); $Player.Inventory = @($InvList)
                            $MobTurn = Invoke-MobTurn -Player $Player -Mob $CurrentMob
                            if (-not [string]::IsNullOrWhiteSpace($MobTurn)) { $TurnMessages += $MobTurn -replace "^`n>\s*", "" }
                            $TurnPassed = $true
                        } else { $TurnMessages += "You reach into your pockets... but you are completely out of Pistol Ammo!" }
                    }
                }
                '^legacy$' {
                    $LegacyDisplay = @("=== ACCOUNT LEGACY MILESTONES ===")
                    $AllClasses = @("Bruiser", "Tank", "Popular", "Stealthy", "Tactician", "Technologist", "Charmed", "Lobber", "Plaguebringer", "Beserker", "Immune Human", "Vampire")
                    foreach ($c in $AllClasses) {
                        $Tier = if ($LegacyBonuses.UnlockedTiers.ContainsKey($c)) { $LegacyBonuses.UnlockedTiers[$c] } else { 0 }
                        $LevelReq = if ($Tier -eq 0) { "(Reach Lv 25)" } else { "(Lv $($Tier * 25))" }
                        $LegacyDisplay += " $($c.PadRight(15)): Tier $Tier $LevelReq"
                    }
                    $LegacyDisplay += "--------------------------------------------------"
                    $LegacyDisplay += " Highest Level Reached: $($LegacyBonuses.MaxLevelReached)"
                    if ($LegacyBonuses.HasOuroboros) { $LegacyDisplay += " 🐍 Ouroboros Unlocked: +5 to ALL base stats for all lives." }
                    $LegacyDisplay += " (Hit Levels 25, 50, 75, etc. on any character to permanently buff future lives!)"
                    $TurnMessages += $LegacyDisplay -join "`n> "
                }
                '^stats$' { $TurnMessages += "COMBAT STATS | STR: $($Player.Strength) | DEX: $($Player.Dexterity) | AC: $($Player.Armor) | WPN: $($Player.EquippedWeapon) ($($Player.Damage) DMG)" }
                '^(char|character|sheet)$' {
                    $ResourceLine = if ($Player.Class -eq "Vampire") { 
                        " HP: $("$($Player.HP)/$($Player.MaxHP)".PadRight(15)) BP: $($Player.BP)/$($Player.MaxBP)" 
                    } elseif ($Player.Class -eq "Immune Human") {
                        " HP: $("$($Player.HP)/$($Player.MaxHP)".PadRight(15)) SP: $("$($Player.SP)/$($Player.MaxSP)".PadRight(12)) AMMO: $($Player.Ammo)/$($Player.MaxAmmo)" 
                    } else { 
                        " HP: $("$($Player.HP)/$($Player.MaxHP)".PadRight(15)) SP: $($Player.SP)/$($Player.MaxSP)" 
                    }
                    
                    $InfLabel = if ($Player.Class -eq "Immune Human") { "Resistance:" } else { "Infectivity:" }
                    $InfLine = " $InfLabel $($Player.Infectivity)"

                    $Sheet = @(
                        "==================================================", 
                        " Name:  $("$($Player.Name)".PadRight(18)) Class: $($Player.Class)", 
                        " Level: $("$($Player.Level)".PadRight(18)) XP:    $($Player.XP)/$($Player.NextLevelXP)", 
                        "--------------------------------------------------", $ResourceLine, "--------------------------------------------------", 
                        " [ PRIMARY STATS ]              [ SECONDARY STATS ]", 
                        " Strength:  $("$($Player.Strength)".PadRight(14)) Charisma:    $($Player.CHA)", 
                        " Dexterity: $("$($Player.Dexterity)".PadRight(14)) Constit:     $($Player.CON)", 
                        " Armor(AC): $("$($Player.Armor)".PadRight(14)) Tactics:     $($Player.Tactics)",
                        " Base Dmg:  $("$($Player.Damage)".PadRight(14)) Int:         $($Player.Int)",
                        " Weapon:    $("$($Player.EquippedWeapon)".PadRight(14)) Luck:        $($Player.Luck)",
                        $InfLine,
                        "--------------------------------------------------",
                        " [ EQUIPPED GEAR ]"
                    )
                    if ($Player.LearnedSkills -contains "Two Fisting") {
                        $Sheet += " Main:      $("$($Player.EquippedWeapon)".PadRight(14)) Offhand:   $($Player.EquippedOffhand)"
                    } else {
                        $Sheet += " Weapon:    $($Player.EquippedWeapon)"
                    }
                    
                    $Sheet += " Chest:     $("$($Player.EquippedArmor)".PadRight(14)) Shoulders: $($Player.EquippedShoulders)"
                    $Sheet += " Boots:     $("$($Player.EquippedBoots)".PadRight(14)) Trinket:   $($Player.EquippedTrinket)"
                    $Sheet += " Necklace:  $($Player.EquippedNecklace)"
                    
                    if ($null -ne $Player.ActivePet) {
                        $pLvl = $Player.ActivePet.Level; $NextXP = 10000
                        if ($pLvl -ge 100) { $NextXP = "MAX" } elseif ($pLvl -ge 99) { $NextXP = 1000000 } elseif ($pLvl -ge 61) { $NextXP = 250000 } 
                        elseif ($pLvl -ge 51) { $NextXP = 100000 } elseif ($pLvl -ge 41) { $NextXP = 50000 } elseif ($pLvl -ge 36) { $NextXP = 25000 } 
                        elseif ($pLvl -ge 31) { $NextXP = 17500 } elseif ($pLvl -ge 21) { $NextXP = 15000 } elseif ($pLvl -ge 11) { $NextXP = 12500 }
                        $Sheet += "--------------------------------------------------"
                        $Sheet += " [ ACTIVE PET COMPANION ]"
                        $Sheet += " Name:   $($Player.ActivePet.Name)"
                        $Sheet += " Level:  $("$($Player.ActivePet.Level)".PadRight(14)) XP: $($Player.ActivePet.XP) / $NextXP"
                        $Sheet += " Damage: $("$($Player.ActivePet.Damage)".PadRight(14)) Armor: $($Player.ActivePet.Armor)"
                    }
                    $Sheet += "=================================================="
                    $TurnMessages += $Sheet -join "`n> "
                }
                default { $TurnMessages += "You are in combat! Valid commands: 'attack', 'run', 'skills', 'use [skill/item]', 'release pet', 'reload', 'stats', 'char'" }
            }
            
            # --- WIPE PLAYER CORPSE IF IT WAS KILLED BY COMBAT ACTION ---
            if ($null -ne $CurrentMob -and $CurrentMob.HP -le 0) {
                
                # --- STEALTHY 20: RE-ENTER STEALTH ---
                if ($Player.LearnedSkills -contains "Stealth" -and -not $Player.IsStealthed) {
                    $Player.IsStealthed = $true
                    $TurnMessages += "`n> 🌑 You naturally fade back into the shadows."
                }
                
                if ($null -ne $CurrentMob.IsPlayerCorpse -and $CurrentMob.IsPlayerCorpse) { 
                    if ($null -ne $Player.ActivePet -and $Player.ActivePet.Name -match [regex]::Escape($CurrentMob.Name)) {
                        $TurnMessages += "`n> 🏆 *** ACHIEVEMENT UNLOCKED: Ouroboros ***"
                        $TurnMessages += "> You have consumed your past life! Its soul now serves you."
                        
                        if (-not $LegacyBonuses.HasOuroboros) {
                            $LegacyBonuses.HasOuroboros = $true
                            $TurnMessages += "> 🐍 OUROBOROS LEGACY UNLOCKED: All future lives gain +5 to ALL base stats!"
                            $Player.BaseStrength += 5; $Player.Strength += 5; $Player.BaseDexterity += 5; $Player.Dexterity += 5
                            $Player.BaseCON += 5; $Player.CON += 5; $Player.BaseCHA += 5; $Player.CHA += 5
                            $Player.BaseTactics += 5; $Player.Tactics += 5; $Player.BaseInt += 5; $Player.Int += 5; $Player.BaseLuck += 5; $Player.Luck += 5
                        }
                    }
                    $LegacyBonuses.PlayerCorpse = $null 
                }
                $LastActionMessage = $TurnMessages -join "`n> "
                $CurrentMob = $null
            } else {
                $LastActionMessage = $TurnMessages -join "`n> "
            }
        }
    }
    # 3.5 NPC STATE PARSER
    elseif ($null -ne $CurrentNPC) {
        if ($CurrentNPC -eq "Wandering Merchant") {
            $ShopItems = Get-ShopInventory
            $BuildMenu = {
                param($ActionMsg)
                $Menu = @("", $ActionMsg, "", "=== WANDERING MERCHANT ===", " Wallet: $($Player.Currency) scrap coins", "--------------------------------------------------", " [ FOR SALE ]")
                foreach ($Item in $ShopItems.Keys) { $Menu += " $("[$($ShopItems[$Item]) scrap]".PadRight(15)) $Item" }
                $Menu += "--------------------------------------------------"
                $Menu += " [ YOUR SELLABLE ITEMS ]"
                
                $HasSellables = $false
                $GroupedInv = @{}
                foreach ($Item in $Player.Inventory) { if ($GroupedInv.ContainsKey($Item)) { $GroupedInv[$Item] += 1 } else { $GroupedInv[$Item] = 1 } }
                
                foreach ($InvItem in $GroupedInv.Keys) {
                    $Stats = Get-ItemStats -ItemName $InvItem
                    if ($null -ne $Stats -and $Stats.BasePrice -gt 0) {
                        $SellVal = [math]::Floor($Stats.BasePrice * $Stats.SellMultiplier)
                        $Qty = $GroupedInv[$InvItem]
                        $QtyStr = if ($Qty -gt 1) { " (x$Qty)" } else { "" }
                        $Menu += " $("[$SellVal scrap]".PadRight(15)) $InvItem$QtyStr"
                        $HasSellables = $true
                    }
                }
                if (-not $HasSellables) { $Menu += "  (You have nothing of value to sell)" }
                $Menu += "--------------------------------------------------"
                $Menu += " Type 'buy [item]', 'sell [item]', 'sell all [item]', or 'leave'."
                return ($Menu -join "`n> ")
            }

            switch -Regex ($CleanCommand) {
                '^buy\s+(.+)' {
                    $TargetItem = $Matches[1].Trim()
                    $RealItem = $ShopItems.Keys | Where-Object { $_ -ieq $TargetItem } | Select-Object -First 1
                    if ($null -ne $RealItem) {
                        $Cost = $ShopItems[$RealItem]
                        if ($Player.Currency -ge $Cost) {
                            $Player.Currency -= $Cost; $Player.Inventory += $RealItem
                            $ActionMsg = "Transaction complete! You bought the [$RealItem] for $Cost scrap."
                        } else { $ActionMsg = "The merchant sneers. You need $Cost scrap, but only have $($Player.Currency)." }
                    } else { $ActionMsg = "The merchant doesn't sell a '$TargetItem'." }
                    $LastActionMessage = &$BuildMenu $ActionMsg
                }
                '^sell\s+(all\s+)?(.+)' {
                    $SellAll = (-not [string]::IsNullOrWhiteSpace($Matches[1]))
                    $TargetItem = $Matches[2].Trim()
                    
                    $RealItem = $Player.Inventory | Where-Object { $_ -ieq $TargetItem } | Select-Object -First 1
                    if ($null -ne $RealItem) {
                        $ItemData = Get-ItemStats -ItemName $RealItem
                        if ($null -ne $ItemData -and $ItemData.BasePrice -gt 0) {
                            $SellVal = [math]::Floor($ItemData.BasePrice * $ItemData.SellMultiplier)
                            if ($SellAll) {
                                $Count = @($Player.Inventory | Where-Object { $_ -eq $RealItem }).Count
                                $TotalVal = $SellVal * $Count
                                $Player.Currency += $TotalVal
                                $Player.Inventory = @($Player.Inventory | Where-Object { $_ -ne $RealItem })
                                $ActionMsg = "Transaction complete! You sold ALL ($Count) [$RealItem] for $TotalVal scrap."
                            } else {
                                $Player.Currency += $SellVal
                                $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList)
                                $ActionMsg = "Transaction complete! You sold ONE [$RealItem] for $SellVal scrap."
                            }
                        } else { $ActionMsg = "The merchant refuses to buy the [$RealItem]." }
                    } else { $ActionMsg = "You don't have a '$TargetItem' to sell." }
                    $LastActionMessage = &$BuildMenu $ActionMsg
                }
                '^(leave|exit|quit|bye)$' { $CurrentNPC = $null; $LastActionMessage = "You nod and step away from the merchant." }
                default { $LastActionMessage = "You are busy talking to the $CurrentNPC. Valid commands: 'buy [item]', 'sell [item]', 'sell all [item]', 'leave'" }
            }
        }
        elseif ($CurrentNPC -eq "Old Master") {
            $SkillDBPath = Join-Path $PSScriptRoot "Data\skills.json"
            $SkillDB = ConvertFrom-Json (Get-Content $SkillDBPath -Raw)
            
            $BuildMenu = {
                param($ActionMsg)
                $Menu = @("", $ActionMsg, "", "=== THE OLD MASTER'S DOJO ===", " Wallet: $($Player.Currency) scrap coins", "--------------------------------------------------", " [ AVAILABLE SKILLS TO LEARN ]")
                
                $HasSkills = $false
                foreach ($S in $SkillDB.psobject.properties) {
                    $SkillName = $S.Name
                    $SData = $S.Value
                    if (($SData.Class -eq "Universal" -or $SData.Class -eq $Player.Class) -and $SData.Price -gt 0) {
                        if ($Player.Level -ge $SData.MinLevel) {
                            $AlreadyLearned = $false
                            foreach ($ls in $Player.LearnedSkills) { if ($ls -ieq $SkillName) { $AlreadyLearned = $true; break } }
                            if (-not $AlreadyLearned) {
                                $Menu += " $("[$($SData.Price) scrap]".PadRight(15)) $SkillName ($($SData.Cost)) - $($SData.Description)"
                                $HasSkills = $true
                            }
                        }
                    }
                }
                if (-not $HasSkills) { $Menu += "  (You have learned everything I can teach you for now)" }
                $Menu += "--------------------------------------------------"
                $Menu += " Type 'learn [skill]' or 'leave'."
                return ($Menu -join "`n> ")
            }

            switch -Regex ($CleanCommand) {
                '^learn\s+(.+)' {
                    $TargetSkill = $Matches[1].Trim()
                    $RealSkill = $null
                    foreach ($S in $SkillDB.psobject.properties) {
                        if ($S.Name -ieq $TargetSkill) { $RealSkill = $S.Name; break }
                    }
                    if ($null -ne $RealSkill) {
                        $SData = $SkillDB.$RealSkill
                        if ($SData.Class -ne "Universal" -and $SData.Class -ne $Player.Class) {
                            $ActionMsg = "The Old Master shakes his head. `"That technique is not suited for a $($Player.Class).`""
                        } elseif ($Player.Level -lt $SData.MinLevel) {
                            $ActionMsg = "The Old Master sighs. `"You lack the experience for this technique. Return at Level $($SData.MinLevel).`""
                        } elseif ($Player.LearnedSkills -contains $RealSkill) {
                            $ActionMsg = "You already know how to perform $RealSkill!"
                        } elseif ($Player.Currency -lt $SData.Price) {
                            $ActionMsg = "The Old Master sighs. `"Knowledge is not free. You need $($SData.Price) scrap.`""
                        } else {
                            $Player.Currency -= $SData.Price
                            $Player.LearnedSkills += $RealSkill
                            $ActionMsg = "The Old Master guides you through the forms... You have learned [$RealSkill]!"
                        }
                    } else { $ActionMsg = "The Old Master looks confused. `"I do not know of that technique.`"" }
                    $LastActionMessage = &$BuildMenu $ActionMsg
                }
                '^(leave|exit|quit|bye)$' { $CurrentNPC = $null; $LastActionMessage = "You bow to the Old Master and step away." }
                default { $LastActionMessage = "You are busy talking to the $CurrentNPC. Valid commands: 'learn [skill]', 'leave'" }
            }
        }
    }
    # 4. EXPLORATION STATE PARSER
    else {
        $CurrentMob = $null 

        switch -Regex ($CleanCommand) {
            '^quit$' { 
                Save-GameState -Player $Player -WorldMap $WorldMap -LegacyBonuses $LegacyBonuses
                $GameIsRunning = $false 
                Write-Host "`nGame saved. Exiting the nightmare..." -ForegroundColor DarkGray
            }
            '^save$' { 
                Save-GameState -Player $Player -WorldMap $WorldMap -LegacyBonuses $LegacyBonuses
                $LastActionMessage = "Progress saved. The nightmare continues..."
            }
            '^look$' {
                $Observations = @()
                if ($CurrentRoom.ID -eq "1") { $Observations += "A heavy iron storage box sits in the corner of the cell." }
                
                # --- SEE YOUR OWN CORPSE ---
                if ($null -ne $LegacyBonuses.PlayerCorpse -and $LegacyBonuses.PlayerCorpse.RoomID -eq $CurrentRoom.ID) {
                    $Observations += "`n> ⚠️ The undead husk of your past life, $($LegacyBonuses.PlayerCorpse.Mob.Name), is shambling around here!"
                }

                if ($null -ne $CurrentRoom.NPC) { $Observations += "A $($CurrentRoom.NPC) is sitting here." }
                if ($null -ne $CurrentRoom.Interactables -and $CurrentRoom.Interactables.Count -gt 0) {
                    foreach ($ObjName in $CurrentRoom.Interactables.Keys) {
                        if ($CurrentRoom.Interactables[$ObjName].State -eq "open") { $Observations += "The $ObjName is open, revealing a hidden path." } 
                        else { $Observations += "You notice a $ObjName that looks interactable." }
                    }
                }
                if ($Observations.Count -gt 0) { $LastActionMessage = $Observations -join " " } 
                else { $LastActionMessage = "You look around carefully, but nothing jumps out at you." }
            }
            '^say\s+(.+)' {
                $SpokenText = $Matches[1].Trim()
                if ($CurrentRoom.ID -eq "96" -and $SpokenText -match '(?i)i devote myself to the darkness') {
                    if ($LegacyBonuses.UnlockedClasses -notcontains "Vampire") {
                        $LegacyBonuses.UnlockedClasses += "Vampire"
                        Save-GameState -Player $Player -WorldMap $WorldMap -LegacyBonuses $LegacyBonuses
                        $LastActionMessage = "You speak the words. The darkness coils around you, sinking into your veins... `n> [ LEGACY UNLOCKED: The Vampire Class is now available on your next life! ]"
                    } else { $LastActionMessage = "The darkness whispers back: 'You are already mine...'" }
                } else { $LastActionMessage = "You say: `"$SpokenText`"" }
            }
            '^talk(\s+(.+))?$' {
                if ($null -ne $CurrentRoom.NPC) {
                    $CurrentNPC = $CurrentRoom.NPC 
                    if ($CurrentNPC -eq "Wandering Merchant") {
                        $ShopItems = Get-ShopInventory
                        $Menu = @("The $CurrentNPC gestures to their wares.", "=== WANDERING MERCHANT ===", " Wallet: $($Player.Currency) scrap coins", "--------------------------------------------------", " [ FOR SALE ]")
                        foreach ($Item in $ShopItems.Keys) { $Menu += " $("[$($ShopItems[$Item]) scrap]".PadRight(15)) $Item" }
                        $Menu += "--------------------------------------------------"
                        $Menu += " [ YOUR SELLABLE ITEMS ]"
                        
                        $HasSellables = $false
                        $GroupedInv = @{}
                        foreach ($Item in $Player.Inventory) { if ($GroupedInv.ContainsKey($Item)) { $GroupedInv[$Item] += 1 } else { $GroupedInv[$Item] = 1 } }
                        
                        foreach ($InvItem in $GroupedInv.Keys) {
                            $Stats = Get-ItemStats -ItemName $InvItem
                            if ($null -ne $Stats -and $Stats.BasePrice -gt 0) {
                                $SellVal = [math]::Floor($Stats.BasePrice * $Stats.SellMultiplier)
                                $Qty = $GroupedInv[$InvItem]
                                $QtyStr = if ($Qty -gt 1) { " (x$Qty)" } else { "" }
                                $Menu += " $("[$SellVal scrap]".PadRight(15)) $InvItem$QtyStr"
                                $HasSellables = $true
                            }
                        }
                        if (-not $HasSellables) { $Menu += "  (You have nothing of value to sell)" }
                        $Menu += "--------------------------------------------------"
                        $Menu += " Type 'buy [item]', 'sell [item]', 'sell all [item]', or 'leave'."
                        $LastActionMessage = $Menu -join "`n> "
                    } elseif ($CurrentNPC -eq "Old Master") {
                        $SkillDBPath = Join-Path $PSScriptRoot "Data\skills.json"
                        $SkillDB = ConvertFrom-Json (Get-Content $SkillDBPath -Raw)
                        $Menu = @("The $CurrentNPC nods slowly. `"You seek to master yourself.`"", "=== THE OLD MASTER'S DOJO ===", " Wallet: $($Player.Currency) scrap coins", "--------------------------------------------------", " [ AVAILABLE SKILLS TO LEARN ]")
                        
                        $HasSkills = $false
                        foreach ($S in $SkillDB.psobject.properties) {
                            $SkillName = $S.Name
                            $SData = $S.Value
                            if (($SData.Class -eq "Universal" -or $SData.Class -eq $Player.Class) -and $SData.Price -gt 0) {
                                if ($Player.Level -ge $SData.MinLevel) {
                                    $AlreadyLearned = $false
                                    foreach ($ls in $Player.LearnedSkills) { if ($ls -ieq $SkillName) { $AlreadyLearned = $true; break } }
                                    if (-not $AlreadyLearned) {
                                        $Menu += " $("[$($SData.Price) scrap]".PadRight(15)) $SkillName ($($SData.Cost)) - $($SData.Description)"
                                        $HasSkills = $true
                                    }
                                }
                            }
                        }
                        if (-not $HasSkills) { $Menu += "  (You have learned everything I can teach you for now)" }
                        $Menu += "--------------------------------------------------"
                        $Menu += " Type 'learn [skill]' or 'leave'."
                        $LastActionMessage = $Menu -join "`n> "
                    }
                } else { $LastActionMessage = "You mumble to yourself. Nobody answers." }
            }
            '^search$' {
                $TurnMessages = @()
                
                # --- FIGHT YOUR PAST LIFE ---
                if ($null -ne $LegacyBonuses.PlayerCorpse -and $LegacyBonuses.PlayerCorpse.RoomID -eq $CurrentRoom.ID) {
                    $CurrentMob = $LegacyBonuses.PlayerCorpse.Mob
                    $TurnMessages += "You lock eyes with your former self... The $($CurrentMob.Name) lunges at you!"
                } else {
                    $SpawnCap = $Player.Level + 2
                    $FloorMin = 1
                    if ($null -ne $CurrentRoom.MinLevel) {
                        $FloorMin = $CurrentRoom.MinLevel
                        if ($SpawnCap -lt $FloorMin) { $SpawnCap = $FloorMin + 2 }
                    }
                    $CurrentMob = Get-RandomMob -MaxLevel $SpawnCap -MinLevel $FloorMin
                    if ($FloorMin -ge 20) {
                        $TurnMessages += "You disturb the toxic debris... A devastating $($CurrentMob.Name) (Lv. $($CurrentMob.Level)) emerges!"
                    } else {
                        $TurnMessages += "You rummaged through the debris and found a $($CurrentMob.Name) (Lv. $($CurrentMob.Level))!"
                    }
                }
                
                # --- STEALTH CHECK ---
                if ($Player.LearnedSkills -contains "Stealth" -and -not $Player.IsStealthed) {
                    $Player.IsStealthed = $true
                    $TurnMessages += "`n> 🌑 You naturally fade back into the shadows."
                }

                $LastActionMessage = $TurnMessages -join "`n> "
                $TurnPassed = $true
            }
            '^use foresight$' {
                if ($Player.LearnedSkills -notcontains "Foresight") { $LastActionMessage = "You don't know the Foresight technique." }
                elseif ($Player.SP -lt 15) { $LastActionMessage = "Needs 15 SP to cast Foresight." }
                else {
                    $Player.SP -= 15
                    $SpawnCap = $Player.Level + 2
                    $FloorMin = 1
                    if ($null -ne $CurrentRoom.MinLevel) {
                        $FloorMin = $CurrentRoom.MinLevel
                        if ($SpawnCap -lt $FloorMin) { $SpawnCap = $FloorMin + 2 }
                    }
                    $ForesightMob = Get-RandomMob -MaxLevel $SpawnCap -MinLevel $FloorMin
                    $LegacyBonuses.ForesightMob = $ForesightMob
                    $LastActionMessage = "👁️ FORESIGHT: You peer into the future and see a $($ForesightMob.Name) (Lv. $($ForesightMob.Level)) waiting. Type 'engage' to ambush it, or 'ignore' to walk away."
                }
            }
            '^engage$' {
                if ($null -ne $LegacyBonuses.ForesightMob) {
                    $CurrentMob = $LegacyBonuses.ForesightMob
                    $LegacyBonuses.ForesightMob = $null
                    
                    $AmbushDmg = $Player.Damage
                    $CurrentMob.HP -= $AmbushDmg
                    
                    $TurnMessages = @()
                    $TurnMessages += "You execute your ambush perfectly!"
                    $TurnMessages += "👁️ FORESIGHT STRIKE! You deal $AmbushDmg damage before the fight even begins!"
                    $LastActionMessage = $TurnMessages -join "`n> "
                } else { $LastActionMessage = "There is nothing to engage." }
            }
            '^ignore$' {
                if ($null -ne $LegacyBonuses.ForesightMob) {
                    $LegacyBonuses.ForesightMob = $null
                    $LastActionMessage = "You carefully avoid the encounter and choose a different path."
                } else { $LastActionMessage = "There is nothing to ignore." }
            }
            '^combine\s+(.+)$' {
                if ($Player.LearnedSkills -notcontains "Mad Inventor") {
                    $LastActionMessage = "You lack the Mad Inventor skills required to combine items."
                } else {
                    $TargetName = $Matches[1].Trim()
                    $RealItem = $Player.Inventory | Where-Object { $_ -ieq $TargetName } | Select-Object -First 1
                    
                    if ($null -eq $RealItem) {
                        $LastActionMessage = "You don't have a '$TargetName' to combine."
                    } else {
                        $ItemData = Get-ItemStats -ItemName $RealItem
                        $LegendaryElements = @("Bonewerk", "Explosive", "Energetic", "Putrid")
                        $CommonElements = @("Radioactive", "Fire", "Cryogenis", "Bloodwerk")
                        $PossibleStats = @("Strength", "Dexterity", "Constitution", "Tactics", "Int", "Luck")
                        
                        if ($null -ne $ItemData -and $ItemData.Type -eq "Necklace") {
                            if ($ItemData.Element -in $LegendaryElements) {
                                $CurrencyNeeded = 1000
                                $CurrencyProp = ""
                                switch ($ItemData.Element) {
                                    "Bonewerk" { $CurrencyProp = "Bonechips" }
                                    "Explosive" { $CurrencyProp = "Gunpowder" }
                                    "Energetic" { $CurrencyProp = "EnergyOrbs" }
                                    "Putrid" { $CurrencyProp = "ToxicGarnets" }
                                }
                                
                                $CurrentLvl = 0; $BaseName = $RealItem
                                if ($RealItem -match '^(.*?)\s+\+(\d+)(?:\s+\[(.*?)\])?$') { $BaseName = $Matches[1]; $CurrentLvl = [int]$Matches[2] }
                                
                                if ($CurrentLvl -ge 20) { $LastActionMessage = "That legendary artifact is already at maximum power (+20)!" }
                                elseif ($Player.$CurrencyProp -lt $CurrencyNeeded) { $LastActionMessage = "You need $CurrencyNeeded $CurrencyProp to upgrade this!" }
                                else {
                                    $Player.$CurrencyProp -= $CurrencyNeeded
                                    if ((Get-Random -Min 1 -Max 101) -le 50) {
                                        $LastActionMessage = "💥 The experiment FAILED! The volatile reaction consumed your $CurrencyProp, but the artifact survived."
                                    } else {
                                        $NewLvl = $CurrentLvl + 1
                                        $NewName = "$BaseName +$NewLvl"
                                        $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList)
                                        $Player.Inventory += $NewName
                                        $LastActionMessage = "🧪 MAD INVENTOR SUCCESS! The artifact absorbs the energy and becomes [$NewName]!"
                                    }
                                }
                            } elseif ($ItemData.Element -in $CommonElements) {
                                $Count = @($Player.Inventory | Where-Object { $_ -eq $RealItem }).Count
                                if ($Count -lt 3) { $LastActionMessage = "You need 3x [$RealItem] to combine them!" }
                                else {
                                    for ($i=0; $i -lt 3; $i++) { $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList) }
                                    if ((Get-Random -Min 1 -Max 101) -le 50) {
                                        $LastActionMessage = "💥 The experiment FAILED! The necklaces shattered into useless dust."
                                    } else {
                                        $LegRewards = @("Bonewerk Amulet", "Explosive Collar", "Energetic Locket", "Putrid Charm")
                                        $Reward = $LegRewards | Get-Random
                                        $Player.Inventory += $Reward
                                        $LastActionMessage = "🧪 MAD INVENTOR SUCCESS! The common elements fused into a legendary [$Reward]!"
                                    }
                                }
                            }
                        } elseif ($ItemData.Type -in @("Weapon", "Armor", "Shoulders", "Boots", "Trinket")) {
                            $Count = @($Player.Inventory | Where-Object { $_ -eq $RealItem }).Count
                            if ($Count -lt 3) { $LastActionMessage = "You need 3x identical [$RealItem] to combine them!" }
                            else {
                                $CurrentLvl = 0; $BaseName = $RealItem
                                if ($RealItem -match '^(.*?)\s+\+(\d+)(?:\s+\[(.*?)\])?$') { $BaseName = $Matches[1]; $CurrentLvl = [int]$Matches[2] }
                                
                                if ($CurrentLvl -ge 10) { $LastActionMessage = "That equipment is already at maximum upgrade (+10)!" }
                                else {
                                    for ($i=0; $i -lt 3; $i++) { $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList) }
                                    if ((Get-Random -Min 1 -Max 101) -le 50) {
                                        $LastActionMessage = "💥 The experiment FAILED! The items were destroyed in the process."
                                    } else {
                                        $NewLvl = $CurrentLvl + 1
                                        $NewName = "$BaseName +$NewLvl"
                                        
                                        # Random stat chance
                                        if ((Get-Random -Min 1 -Max 101) -le 50) {
                                            $RStat = $PossibleStats | Get-Random
                                            $NewName = "$NewName [$RStat]"
                                        }
                                        
                                        $Player.Inventory += $NewName
                                        $LastActionMessage = "🧪 MAD INVENTOR SUCCESS! The items successfully fused into [$NewName]!"
                                    }
                                }
                            }
                        } else {
                            $LastActionMessage = "You can't combine that type of item."
                        }
                    }
                    $TurnPassed = $true
                }
            }
            '^cheat legacy$' { $Player.Level += 25; $Player.Currency += 1000; $LastActionMessage = "CHEAT ACTIVATED: You instantly surged forward 25 levels!" }
            '^cheat pet$' {
                if ($null -eq $Player.ActivePet) { $LastActionMessage = "You don't have a pet! Go infect something first." } 
                else {
                    $LevelsGained = 100 - $Player.ActivePet.Level
                    if ($LevelsGained -gt 0) {
                        $Player.ActivePet.Level = 100
                        $Player.ActivePet.MaxHP += ($LevelsGained * 15); $Player.ActivePet.HP = $Player.ActivePet.MaxHP
                        $Player.ActivePet.Damage += ($LevelsGained * 3)
                        $Player.ActivePet.Armor += ($LevelsGained * 1)
                        $LastActionMessage = "CHEAT ACTIVATED: Your $($Player.ActivePet.Name) violently mutated to Level 100!"
                    } else { $LastActionMessage = "Your pet is already at maximum level!" }
                }
            }
            '^cheat element$' { $Player.Bonechips += 1000; $Player.Gunpowder += 1000; $Player.EnergyOrbs += 1000; $Player.ToxicGarnets += 1000; $LastActionMessage = "CHEAT ACTIVATED: You injected 1000 of every element into your veins!" }
            '^(give up|suicide)$' { $Player.HP = 0; $LastActionMessage = "You can't take the nightmare anymore. You give up the will to live..."; $TurnPassed = $true }
            '^skills$' {
                $SkillDBPath = Join-Path $PSScriptRoot "Data\skills.json"
                $SkillDB = ConvertFrom-Json (Get-Content $SkillDBPath -Raw)
                $SkillDisplay = @("=== YOUR LEARNED SKILLS ===")
                foreach ($LS in $Player.LearnedSkills) {
                    $SData = $SkillDB.$LS
                    if ($null -ne $SData) { $SkillDisplay += " - $($LS.PadRight(15)) | Cost: $($SData.Cost.PadRight(6)) | $($SData.Description)" } 
                    else { $SkillDisplay += " - $LS" }
                }
                $SkillDisplay += "--------------------------------------------------"
                $SkillDisplay += " Type 'use [skillname]' in combat to activate."
                $LastActionMessage = $SkillDisplay -join "`n> "
            }
            '^stats$' { $LastActionMessage = "COMBAT STATS | STR: $($Player.Strength) | DEX: $($Player.Dexterity) | AC: $($Player.Armor) | WPN: $($Player.EquippedWeapon) ($($Player.Damage) DMG)" }
            '^(inv|inventory|i)$' {
                $InvDisplay = @("=== INVENTORY ===")
                $InvDisplay += " Elements: $($Player.Bonechips) Bonechips | $($Player.Gunpowder) Gunpowder | $($Player.EnergyOrbs) Orbs | $($Player.ToxicGarnets) Garnets"
                $InvDisplay += " Currency: $($Player.Currency) scrap coins"
                $InvDisplay += "--------------------------------------------------"
                if ($Player.Inventory.Count -gt 0) { 
                    $Grouped = @{}
                    foreach ($Item in $Player.Inventory) { if ($Grouped.ContainsKey($Item)) { $Grouped[$Item] += 1 } else { $Grouped[$Item] = 1 } }
                    foreach ($Key in $Grouped.Keys) {
                        if ($Grouped[$Key] -gt 1) { $InvDisplay += " - $Key (x$($Grouped[$Key]))" } else { $InvDisplay += " - $Key" }
                    }
                } else { $InvDisplay += " Your pockets are empty." }
                $LastActionMessage = $InvDisplay -join "`n> "
            }
            '^(char|character|sheet)$' {
                $ResourceLine = if ($Player.Class -eq "Vampire") { 
                    " HP: $("$($Player.HP)/$($Player.MaxHP)".PadRight(15)) BP: $($Player.BP)/$($Player.MaxBP)" 
                } elseif ($Player.Class -eq "Immune Human") {
                    " HP: $("$($Player.HP)/$($Player.MaxHP)".PadRight(15)) SP: $("$($Player.SP)/$($Player.MaxSP)".PadRight(12)) AMMO: $($Player.Ammo)/$($Player.MaxAmmo)" 
                } else { 
                    " HP: $("$($Player.HP)/$($Player.MaxHP)".PadRight(15)) SP: $($Player.SP)/$($Player.MaxSP)" 
                }
                
                $InfLabel = if ($Player.Class -eq "Immune Human") { "Resistance:" } else { "Infectivity:" }
                $InfLine = " $InfLabel $($Player.Infectivity)"

                $Sheet = @(
                    "==================================================", 
                    " Name:  $("$($Player.Name)".PadRight(18)) Class: $($Player.Class)", 
                    " Level: $("$($Player.Level)".PadRight(18)) XP:    $($Player.XP)/$($Player.NextLevelXP)", 
                    "--------------------------------------------------", $ResourceLine, "--------------------------------------------------", 
                    " [ PRIMARY STATS ]              [ SECONDARY STATS ]", 
                    " Strength:  $("$($Player.Strength)".PadRight(14)) Charisma:    $($Player.CHA)", 
                    " Dexterity: $("$($Player.Dexterity)".PadRight(14)) Constit:     $($Player.CON)", 
                    " Armor(AC): $("$($Player.Armor)".PadRight(14)) Tactics:     $($Player.Tactics)",
                    " Base Dmg:  $("$($Player.Damage)".PadRight(14)) Int:         $($Player.Int)",
                    " Weapon:    $("$($Player.EquippedWeapon)".PadRight(14)) Luck:        $($Player.Luck)",
                    $InfLine,
                    "--------------------------------------------------",
                    " [ EQUIPPED GEAR ]"
                )
                if ($Player.LearnedSkills -contains "Two Fisting") {
                    $Sheet += " Main:      $("$($Player.EquippedWeapon)".PadRight(14)) Offhand:   $($Player.EquippedOffhand)"
                } else {
                    $Sheet += " Weapon:    $($Player.EquippedWeapon)"
                }
                
                $Sheet += " Chest:     $("$($Player.EquippedArmor)".PadRight(14)) Shoulders: $($Player.EquippedShoulders)"
                $Sheet += " Boots:     $("$($Player.EquippedBoots)".PadRight(14)) Trinket:   $($Player.EquippedTrinket)"
                $Sheet += " Necklace:  $($Player.EquippedNecklace)"
                
                if ($null -ne $Player.ActivePet) {
                    $pLvl = $Player.ActivePet.Level; $NextXP = 10000
                    if ($pLvl -ge 100) { $NextXP = "MAX" } elseif ($pLvl -ge 99) { $NextXP = 1000000 } elseif ($pLvl -ge 61) { $NextXP = 250000 } 
                    elseif ($pLvl -ge 51) { $NextXP = 100000 } elseif ($pLvl -ge 41) { $NextXP = 50000 } elseif ($pLvl -ge 36) { $NextXP = 25000 } 
                    elseif ($pLvl -ge 31) { $NextXP = 17500 } elseif ($pLvl -ge 21) { $NextXP = 15000 } elseif ($pLvl -ge 11) { $NextXP = 12500 }
                    $Sheet += "--------------------------------------------------"
                    $Sheet += " [ ACTIVE PET COMPANION ]"
                    $Sheet += " Name:   $($Player.ActivePet.Name)"
                    $Sheet += " Level:  $("$($Player.ActivePet.Level)".PadRight(14)) XP: $($Player.ActivePet.XP) / $NextXP"
                    $Sheet += " Damage: $("$($Player.ActivePet.Damage)".PadRight(14)) Armor: $($Player.ActivePet.Armor)"
                }
                $Sheet += "=================================================="
                $LastActionMessage = $Sheet -join "`n> "
            }
            '^equip offhand\s+(.+)' {
                if ($Player.LearnedSkills -notcontains "Two Fisting") {
                    $LastActionMessage = "You do not know the Two Fisting technique to equip an offhand weapon!"
                } else {
                    $TargetItem = $Matches[1].Trim()
                    $RealItem = $Player.Inventory | Where-Object { $_ -ieq $TargetItem } | Select-Object -First 1
                    if ($null -ne $RealItem) {
                        $ItemData = Get-ItemStats -ItemName $RealItem
                        if ($null -ne $ItemData -and $ItemData.Type -eq "Weapon") {
                            if ($Player.EquippedOffhand -ne "None") { $Player.Inventory += $Player.EquippedOffhand }
                            $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList)
                            $Player.EquippedOffhand = $RealItem
                            $LastActionMessage = "You equipped the [$RealItem] in your offhand."
                            $TurnPassed = $true
                        } else { $LastActionMessage = "You can only equip weapons in your offhand." }
                    } else { $LastActionMessage = "You don't have a '$TargetItem' in your inventory." }
                }
            }
            '^equip\s+(?!offhand)(.+)' {
                $TargetItem = $Matches[1].Trim()
                $RealItem = $Player.Inventory | Where-Object { $_ -ieq $TargetItem } | Select-Object -First 1
                if ($null -ne $RealItem) {
                    $ItemData = Get-ItemStats -ItemName $RealItem
                    if ($null -ne $ItemData -and $ItemData.Type -eq "Weapon") {
                        if ($Player.EquippedWeapon -ne "Fists") { $Player.Inventory += $Player.EquippedWeapon }
                        $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList)
                        $Player.EquippedWeapon = $RealItem; $Player.Damage = $ItemData.Value + $Player.BaseWeaponDamage
                        $LastActionMessage = "You equipped the [$RealItem]. Your base damage is now $($Player.Damage)."
                        $TurnPassed = $true
                    } elseif ($null -ne $ItemData -and $ItemData.Type -in @("Armor", "Shoulders", "Boots", "Trinket", "Necklace")) {
                        $SlotName = "Equipped" + $ItemData.Type
                        if ($ItemData.Type -eq "Armor") { $SlotName = "EquippedArmor" }
                        
                        $CurrentEquipped = $Player.$SlotName
                        if ($CurrentEquipped -ne "None") { $Player.Inventory += $CurrentEquipped }
                        
                        $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList)
                        $Player.$SlotName = $RealItem
                        $LastActionMessage = "You equipped the [$RealItem]."
                        $TurnPassed = $true
                    } else { $LastActionMessage = "You cannot equip the [$RealItem]." }
                } else { $LastActionMessage = "You don't have a '$TargetItem' in your inventory." }
            }
            '^use\s+(.+)' {
                $TargetItem = $Matches[1].Trim()
                $RealItem = $Player.Inventory | Where-Object { $_ -ieq $TargetItem } | Select-Object -First 1
                if ($null -ne $RealItem) {
                    $ItemData = Get-ItemStats -ItemName $RealItem
                    if ($null -ne $ItemData -and $ItemData.Type -eq "Consumable") {
                        if ($RealItem -eq "Bandage") {
                            $Player.HP = [math]::Min($Player.MaxHP, ($Player.HP + $ItemData.Value))
                            $LastActionMessage = "You applied the [$RealItem] and recovered $($ItemData.Value) HP."
                            $Bleed = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Bleeding" }
                            if ($null -ne $Bleed) {
                                $Player.ActiveEffects = @($Player.ActiveEffects | Where-Object { $_.Name -ne "Bleeding" })
                                $LastActionMessage += "`n> The tight wrapping completely stopped your bleeding!"
                            }
                            $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList)
                            $TurnPassed = $true
                        } elseif ($RealItem -eq "Energy Drink") {
                            if ($Player.SP -ge $Player.MaxSP -and ($null -eq (@($Player.ActiveEffects) | Where-Object { $_.Name -eq "Zombie Rot" -or $_.Name -eq "Infected Wound" }))) { 
                                $LastActionMessage = "You feel jittery, but you are already at maximum stamina and have no infections to cure. You can't drink that right now." 
                            } else {
                                $Player.SP = [math]::Min($Player.MaxSP, ($Player.SP + $ItemData.Value))
                                $LastActionMessage = "You chugged the [$RealItem] and recovered $($ItemData.Value) SP."
                                $Rot = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Zombie Rot" -or $_.Name -eq "Infected Wound" }
                                if ($null -ne $Rot) {
                                    $Player.ActiveEffects = @($Player.ActiveEffects | Where-Object { $_.Name -ne "Zombie Rot" -and $_.Name -ne "Infected Wound" })
                                    $LastActionMessage += "`n> The intense chemical rush purged the infection from your veins!"
                                }
                                $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList)
                                $TurnPassed = $true
                            }
                        } elseif ($RealItem -eq "Pistol Ammo") {
                            if ($Player.Class -ne "Immune Human") { $LastActionMessage = "You have no idea how to use this." }
                            elseif ($Player.Ammo -ge $Player.MaxAmmo) { $LastActionMessage = "Your magazine is already full!" }
                            else {
                                $Player.Ammo = [math]::Min($Player.MaxAmmo, ($Player.Ammo + $ItemData.Value))
                                $LastActionMessage = "You loaded $($ItemData.Value) rounds into your Glock. (Ammo: $($Player.Ammo)/$($Player.MaxAmmo))"
                                $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList)
                                $TurnPassed = $true
                            }
                        }
                    } else { $LastActionMessage = "You cannot use the [$RealItem] right now." }
                } else { $LastActionMessage = "You don't have a '$TargetItem' in your inventory." }
            }
            '^reload$' {
                if ($Player.Class -ne "Immune Human") { $LastActionMessage = "You don't have a gun to reload." }
                elseif ($Player.Ammo -ge $Player.MaxAmmo) { $LastActionMessage = "Your magazine is already full!" }
                else {
                    $AmmoItem = $Player.Inventory | Where-Object { $_ -ieq "Pistol Ammo" } | Select-Object -First 1
                    if ($null -ne $AmmoItem) {
                        $ItemData = Get-ItemStats -ItemName $AmmoItem
                        $Player.Ammo = [math]::Min($Player.MaxAmmo, ($Player.Ammo + $ItemData.Value))
                        $LastActionMessage = "You slammed a new magazine into your Glock. (Ammo: $($Player.Ammo)/$($Player.MaxAmmo))"
                        $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($AmmoItem); $Player.Inventory = @($InvList)
                        $TurnPassed = $true
                    } else { $LastActionMessage = "You reach into your pockets... but you are completely out of Pistol Ammo!" }
                }
            }
            '^release(\s+pet)?$' {
                if ($null -ne $Player.ActivePet) {
                    $HealAmount = $Player.ActivePet.HP
                    $Player.HP = [math]::Min($Player.MaxHP, ($Player.HP + $HealAmount))
                    $LastActionMessage = "You drain the energy from the $($Player.ActivePet.Name), adding it to your own. You were healed for $HealAmount HP."
                    $Player.ActivePet = $null
                    $TurnPassed = $true
                } else { $LastActionMessage = "You do not have an active pet to release!" }
            }
            '^stash$' {
                if ($CurrentRoomID -ne "1") {
                    $LastActionMessage = "There is no storage box here. It is only accessible in the Awakening Cell."
                } else {
                    $MaxSlots = [math]::Floor($LegacyBonuses.MaxLevelReached / 10)
                    $StashDisplay = @("=== THE IRON STORAGE BOX ===", " Capacity: $($LegacyBonuses.Stash.Count) / $MaxSlots slots", "--------------------------------------------------")
                    if ($LegacyBonuses.Stash.Count -gt 0) {
                        $Grouped = @{}
                        foreach ($Item in $LegacyBonuses.Stash) { if ($Grouped.ContainsKey($Item)) { $Grouped[$Item] += 1 } else { $Grouped[$Item] = 1 } }
                        foreach ($Key in $Grouped.Keys) {
                            if ($Grouped[$Key] -gt 1) { $StashDisplay += " - $Key (x$($Grouped[$Key]))" } else { $StashDisplay += " - $Key" }
                        }
                    } else {
                        $StashDisplay += " The box is empty."
                    }
                    $StashDisplay += "--------------------------------------------------"
                    $StashDisplay += " Type 'stash put [item]' or 'stash take [item]'."
                    $LastActionMessage = $StashDisplay -join "`n> "
                }
            }
            '^stash put\s+(.+)' {
                if ($CurrentRoomID -ne "1") {
                    $LastActionMessage = "There is no storage box here."
                } else {
                    $TargetItem = $Matches[1].Trim()
                    $RealItem = $Player.Inventory | Where-Object { $_ -ieq $TargetItem } | Select-Object -First 1
                    
                    if ($null -ne $RealItem) {
                        $ItemData = Get-ItemStats -ItemName $RealItem
                        if ($null -ne $ItemData -and $ItemData.Type -in @("Weapon", "Armor", "Shoulders", "Boots", "Trinket", "Necklace")) {
                            $MaxSlots = [math]::Floor($LegacyBonuses.MaxLevelReached / 10)
                            if ($LegacyBonuses.Stash.Count -ge $MaxSlots) {
                                $LastActionMessage = "The storage box is full! (Capacity: $MaxSlots). You need to reach a higher historical level for more space."
                            } else {
                                $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList)
                                $LegacyBonuses.Stash += $RealItem
                                $LastActionMessage = "You safely locked the [$RealItem] in the storage box."
                            }
                        } else {
                            $LastActionMessage = "The storage box only accepts Weapons and Armor."
                        }
                    } else {
                        $LastActionMessage = "You don't have a '$TargetItem' in your inventory."
                    }
                }
            }
            '^stash take\s+(.+)' {
                if ($CurrentRoomID -ne "1") {
                    $LastActionMessage = "There is no storage box here."
                } else {
                    $TargetItem = $Matches[1].Trim()
                    $RealItem = $LegacyBonuses.Stash | Where-Object { $_ -ieq $TargetItem } | Select-Object -First 1
                    
                    if ($null -ne $RealItem) {
                        $StashList = [System.Collections.ArrayList]$LegacyBonuses.Stash; $StashList.Remove($RealItem); $LegacyBonuses.Stash = @($StashList)
                        $Player.Inventory += $RealItem
                        $LastActionMessage = "You retrieved the [$RealItem] from the storage box."
                    } else {
                        $LastActionMessage = "There is no '$TargetItem' in the storage box."
                    }
                }
            }
            '^legacy$' {
                $LegacyDisplay = @("=== ACCOUNT LEGACY MILESTONES ===")
                $AllClasses = @("Bruiser", "Tank", "Popular", "Stealthy", "Tactician", "Technologist", "Charmed", "Lobber", "Plaguebringer", "Beserker", "Immune Human", "Vampire")
                foreach ($c in $AllClasses) {
                    $Tier = if ($LegacyBonuses.UnlockedTiers.ContainsKey($c)) { $LegacyBonuses.UnlockedTiers[$c] } else { 0 }
                    $LevelReq = if ($Tier -eq 0) { "(Reach Lv 25)" } else { "(Lv $($Tier * 25))" }
                    $LegacyDisplay += " $($c.PadRight(15)): Tier $Tier $LevelReq"
                }
                $LegacyDisplay += "--------------------------------------------------"
                $LegacyDisplay += " Highest Level Reached: $($LegacyBonuses.MaxLevelReached)"
                if ($LegacyBonuses.HasOuroboros) { $LegacyDisplay += " 🐍 Ouroboros Unlocked: +5 to ALL base stats for all lives." }
                $LegacyDisplay += " (Hit Levels 25, 50, 75, etc. on any character to permanently buff future lives!)"
                $LastActionMessage = $LegacyDisplay -join "`n> "
            }
            '^unlock\s+(.+)' {
                $DirMap = @{'n'='North'; 'north'='North'; 'e'='East'; 'east'='East'; 's'='South'; 'south'='South'; 'w'='West'; 'west'='West'; 'u'='Up'; 'up'='Up'; 'd'='Down'; 'down'='Down'}
                $TargetDir = $Matches[1].Trim().ToLower()
                if ($DirMap.ContainsKey($TargetDir)) {
                    $IntendedDirection = $DirMap[$TargetDir]
                    if ($null -ne $CurrentRoom.Locked -and $CurrentRoom.Locked.ContainsKey($IntendedDirection)) {
                        $RequiredKey = $CurrentRoom.Locked[$IntendedDirection]
                        if ($Player.Inventory -contains $RequiredKey) {
                            $CurrentRoom.Locked.Remove($IntendedDirection); $WorldMap[$CurrentRoom.ID].Locked.$IntendedDirection = $null
                            $LastActionMessage = "You insert the $RequiredKey and turn it. The $IntendedDirection door is now permanently unlocked!"
                            $TurnPassed = $true
                        } else { $LastActionMessage = "You don't have the $RequiredKey required to unlock this." }
                    } else { $LastActionMessage = "The $IntendedDirection path is not locked." }
                } else { $LastActionMessage = "Unlock which direction? (e.g., 'unlock north')" }
            }
            '^open\s+(.+)' {
                $TargetObj = $Matches[1].Trim().ToLower()
                if ($CurrentRoom.Interactables.ContainsKey($TargetObj)) {
                    if ($CurrentRoom.Interactables[$TargetObj].State -ne "open") {
                        $CurrentRoom.Interactables[$TargetObj].State = "open"; $CurrentRoom.Exits += $TargetObj 
                        $LastActionMessage = "You pushed the $TargetObj aside. It is now open, revealing a path!"
                        $TurnPassed = $true
                    } else { $LastActionMessage = "The $TargetObj is already open." }
                } else { $LastActionMessage = "You cannot open the '$TargetObj' here." }
            }
            '^enter\s+(.+)' {
                $TargetObj = $Matches[1].Trim().ToLower()
                if ($CurrentRoom.Interactables.ContainsKey($TargetObj)) {
                    if ($CurrentRoom.Interactables[$TargetObj].State -eq "open") {
                        $CurrentRoomID = $CurrentRoom.Interactables[$TargetObj].TargetRoom
                        $CurrentRoom = Get-RoomState -WorldMap $WorldMap -RoomID $CurrentRoomID
                        $LastActionMessage = "You squeeze into the $TargetObj..."
                        $TurnPassed = $true
                    } else { $LastActionMessage = "The $TargetObj is closed." }
                } else { $LastActionMessage = "There is no '$TargetObj' to enter here." }
            }
            '^(n|north|e|east|s|south|w|west|ne|northeast|nw|northwest|se|southeast|sw|southwest|up|u|down|d|out|o)$' {
                $DirMap = @{'n'='North'; 'north'='North'; 'e'='East'; 'east'='East'; 's'='South'; 'south'='South'; 'w'='West'; 'west'='West'; 'ne'='Northeast'; 'northeast'='Northeast'; 'nw'='Northwest'; 'northwest'='Northwest'; 'se'='Southeast'; 'southeast'='Southeast'; 'sw'='Southwest'; 'southwest'='Southwest'; 'u'='Up'; 'up'='Up'; 'd'='Down'; 'down'='Down'; 'o'='Out'; 'out'='Out'}
                $IntendedDirection = $DirMap[$matches[1]]
                $IsLocked = $false
                if ($null -ne $CurrentRoom.Locked -and $CurrentRoom.Locked.ContainsKey($IntendedDirection)) {
                    $RequiredKey = $CurrentRoom.Locked[$IntendedDirection]
                    $LastActionMessage = "The $IntendedDirection door is locked! You need a $RequiredKey. Try typing 'unlock $IntendedDirection'."
                    $IsLocked = $true
                }
                if (-not $IsLocked) {
                    if ($CurrentRoom.ExitMap.ContainsKey($IntendedDirection)) {
                        $CurrentRoomID = $CurrentRoom.ExitMap[$IntendedDirection]
                        $CurrentRoom = Get-RoomState -WorldMap $WorldMap -RoomID $CurrentRoomID
                        $LastActionMessage = "You travel $IntendedDirection."
                        $TurnPassed = $true
                        
                        # --- STEALTHY RE-ENTER STEALTH ON ROOM MOVE ---
                        if ($Player.LearnedSkills -contains "Stealth" -and -not $Player.IsStealthed) {
                            $Player.IsStealthed = $true
                            $LastActionMessage += "`n> 🌑 You naturally fade back into the shadows."
                        }

                        if ($null -ne $CurrentRoom.NPC) { $LastActionMessage += "`n> A $($CurrentRoom.NPC) is here. Type 'talk' to interact." }
                    } else { $LastActionMessage = "You cannot go that way." }
                }
            }
            '^(help|commands|\?)$' { $LastActionMessage = "AVAILABLE COMMANDS:`n  look   - Examine surroundings`n  talk   - Speak to NPCs`n  search - Look for enemies`n  char   - View Character Sheet`n  inv    - View Inventory & Loot`n  stats  - View quick combat stats`n  skills - View abilities`n  legacy - View account milestones`n  equip [item] - Equip armor or weapons`n  stash  - View storage box (Room 1 only)`n  unlock [dir] - Open locked doors`n  open [obj] - Interact`n  enter [obj] - Use hidden path`n  combine [item] - Technologist Upgrade`n  use foresight - Scan room for enemies`n  n/s/e/w - Move directions`n  quit   - Exit" }
            default { $LastActionMessage = "Command not recognized: '$Command'" }
        }
    }

    # --- END OF TURN TICK ENGINE (PLAYER STATUS & RECALCULATION) ---
    if ($Player.HP -gt 0) {
        $BonusStr = 0; $BonusDex = 0; $BonusArmor = 0; $BonusCha = 0; $BonusCon = 0; $BonusTac = 0; $BonusInt = 0; $BonusLuck = 0; $BonusInf = 0

        $RemainingEffects = @()
        if ($null -ne $Player.ActiveEffects) {
            foreach ($Effect in $Player.ActiveEffects) {
                if ($Effect.Duration -gt 0) {
                    if ($Effect.Modifiers.ContainsKey('Strength'))     { $BonusStr   += $Effect.Modifiers.Strength }
                    if ($Effect.Modifiers.ContainsKey('Dexterity'))    { $BonusDex   += $Effect.Modifiers.Dexterity }
                    if ($Effect.Modifiers.ContainsKey('Armor'))        { $BonusArmor += $Effect.Modifiers.Armor }
                    if ($Effect.Modifiers.ContainsKey('Tactics'))      { $BonusTac   += $Effect.Modifiers.Tactics }
                    if ($Effect.Modifiers.ContainsKey('Luck'))         { $BonusLuck  += $Effect.Modifiers.Luck }
                    if ($Effect.Modifiers.ContainsKey('Int'))          { $BonusInt   += $Effect.Modifiers.Int }
                    if ($Effect.Modifiers.ContainsKey('Constitution')) { $BonusCon   += $Effect.Modifiers.Constitution }
                    if ($Effect.Modifiers.ContainsKey('Charisma'))     { $BonusCha   += $Effect.Modifiers.Charisma }
                    
                    if ($TurnPassed) {
                        if ($null -ne $Effect.DoT -and $Effect.DoT -gt 0) {
                            $Player.HP -= $Effect.DoT
                            if ($CurrentMob -ne $null -and $CurrentMob.HP -gt 0) { $TurnMessages += "You take $($Effect.DoT) damage from [$($Effect.Name)]!" } 
                            else { $LastActionMessage += "`n> You take $($Effect.DoT) damage from [$($Effect.Name)]!" }
                        }
                        $Effect.Duration -= 1
                    }
                    $RemainingEffects += $Effect
                } else {
                    if ($TurnPassed) {
                        if ($CurrentMob -ne $null -and $CurrentMob.HP -gt 0) { $TurnMessages += "The effect of [$($Effect.Name)] has faded." } 
                        else { $LastActionMessage += "`n> The effect of [$($Effect.Name)] has faded." }
                    } else {
                        # BUG FIX: If a non-turn command is used (like 'char'), preserve the 0-duration buff so it can fade out correctly on the next real turn!
                        $RemainingEffects += $Effect
                    }
                }
            }
        }
        $Player.ActiveEffects = $RemainingEffects

        if ($Player.Class -eq "Vampire") {
            if ($TurnPassed) { $Player.BP = [math]::Max(0, $Player.BP - 1) }
            
            $Tier = 0; $HPRegen = 0
            if ($Player.BP -ge 100) {
                $Tier = [math]::Floor(($Player.BP - 100) / 10)
                if ($TurnPassed) { $HPRegen = 2 + (0.2 * $Player.Level) }
            } elseif ($Player.BP -ge 30 -and $Player.BP -lt 100) {
                $Tier = 0
                if ($TurnPassed) { $HPRegen = 1 * $Player.Level }
            } elseif ($Player.BP -lt 10) {
                $Tier = -1
                if ($TurnPassed) { $HPRegen = -1 * $Player.Level }
            }

            if ($TurnPassed) { $Player.HP = [math]::Min($Player.MaxHP, ($Player.HP + $HPRegen)) }
            
            $BonusArmor += ($Tier * 5); $BonusStr   += ($Tier * 1); $BonusDex   += ($Tier * 2)
            $BonusCha   += ($Tier * 5); $BonusCon   += ($Tier * 1); $BonusTac   += ($Tier * 1)
            $BonusInt   += ($Tier * 1); $BonusLuck  += [math]::Floor($Tier * 0.5); $BonusInf += ($Tier * 2)
        }

        # --- DYNAMIC MULTI-SLOT GEAR CALCULATION ---
        $ArmorItemVal = 0
        $ItemStr = 0; $ItemDex = 0; $ItemTac = 0; $ItemInt = 0; $ItemCha = 0; $ItemCon = 0; $ItemLuck = 0; $ItemInf = 0

        $EquipSlots = @($Player.EquippedArmor, $Player.EquippedShoulders, $Player.EquippedBoots, $Player.EquippedTrinket, $Player.EquippedNecklace)
        foreach ($Eq in $EquipSlots) {
            if ($Eq -ne "None" -and $null -ne $Eq) {
                $ItemData = Get-ItemStats -ItemName $Eq
                if ($null -ne $ItemData) {
                    if ($ItemData.Type -in @("Armor", "Shoulders", "Boots", "Trinket")) { $ArmorItemVal += $ItemData.Value }
                    if ($null -ne $ItemData.Modifiers) {
                        if ($null -ne $ItemData.Modifiers.Strength)     { $ItemStr += $ItemData.Modifiers.Strength }
                        if ($null -ne $ItemData.Modifiers.Dexterity)    { $ItemDex += $ItemData.Modifiers.Dexterity }
                        if ($null -ne $ItemData.Modifiers.Constitution) { $ItemCon += $ItemData.Modifiers.Constitution }
                        if ($null -ne $ItemData.Modifiers.Armor)        { $BonusArmor += $ItemData.Modifiers.Armor }
                        if ($null -ne $ItemData.Modifiers.Tactics)      { $ItemTac += $ItemData.Modifiers.Tactics }
                        if ($null -ne $ItemData.Modifiers.Luck)         { $ItemLuck += $ItemData.Modifiers.Luck }
                        if ($null -ne $ItemData.Modifiers.Int)          { $ItemInt += $ItemData.Modifiers.Int }
                        if ($null -ne $ItemData.Modifiers.Charisma)     { $ItemCha += $ItemData.Modifiers.Charisma }
                    }
                }
            }
        }

        $Player.Strength    = $Player.BaseStrength + $BonusStr + $ItemStr
        $Player.Dexterity   = $Player.BaseDexterity + $BonusDex + $ItemDex
        $Player.Armor       = [math]::Max(0, ($Player.BaseArmor + $BonusArmor + $ArmorItemVal))
        $Player.CHA         = $Player.BaseCHA + $BonusCha + $ItemCha
        $Player.CON         = $Player.BaseCON + $BonusCon + $ItemCon
        $Player.Tactics     = $Player.BaseTactics + $BonusTac + $ItemTac
        $Player.Int         = $Player.BaseInt + $BonusInt + $ItemInt
        $Player.Luck        = $Player.BaseLuck + $BonusLuck + $ItemLuck
        $Player.Infectivity = $Player.BaseInfectivity + $BonusInf + $ItemInf
        
        # --- IMMUNE HUMAN 20: MAD SKILLS PASSIVE ---
        if ($Player.LearnedSkills -contains "Mad Skills") {
            $HighestStat = [math]::Max($Player.Strength, [math]::Max($Player.Dexterity, [math]::Max($Player.CON, [math]::Max($Player.CHA, [math]::Max($Player.Tactics, [math]::Max($Player.Int, $Player.Luck))))))
            $Player.Damage = $Player.BaseWeaponDamage + $HighestStat
        }
    }
    
    if ($CurrentMob -ne $null -and $CurrentMob.HP -gt 0 -and $TurnPassed) { $LastActionMessage = $TurnMessages -join "`n> " }
    $TimePassed = $TurnPassed

    # --- DEATH CHECK & LEGACY INHERITANCE ---
    if ($Player.HP -le 0) {
        Write-Host "`nYOU HAVE DIED." -ForegroundColor Red -BackgroundColor Black
        
        # --- CREATE PLAYER CORPSE MOB ---
        $CorpseInventory = @($Player.Inventory)
        $EquipSlots = @("EquippedWeapon", "EquippedOffhand", "EquippedArmor", "EquippedShoulders", "EquippedBoots", "EquippedTrinket", "EquippedNecklace")
        foreach ($Slot in $EquipSlots) {
            if ($Player.$Slot -ne "None" -and $Player.$Slot -ne "Fists" -and $null -ne $Player.$Slot) {
                $CorpseInventory += $Player.$Slot
            }
        }
        
        $CorpseScrap = [math]::Floor($Player.Currency / 2)
        
        $CorpseMob = [PSCustomObject]@{
            Name          = "Zombified $($Player.Name)"
            Level         = $Player.Level
            HP            = $Player.MaxHP
            MaxHP         = $Player.MaxHP
            Damage        = [math]::Max(5, $Player.Damage)
            Armor         = $Player.Armor
            BaseDamage    = [math]::Max(5, $Player.Damage)
            BaseArmor     = $Player.Armor
            XP            = ($Player.Level * 50)
            Scrap         = $CorpseScrap
            LootTable     = $CorpseInventory
            ActiveEffects = @()
            Type          = "Zombie"
            IsBoss        = $true
            IsImmune      = $true
            Skills        = @("Slam", "Eat Flesh", "Toxic Cloud")
            IsPlayerCorpse= $true
        }
        $LegacyBonuses.PlayerCorpse = [PSCustomObject]@{ RoomID = $CurrentRoomID; Mob = $CorpseMob }

        $InheritedScrap = [math]::Floor($Player.Currency * 0.10)
        $TrinketMessage = ""

        if ($null -ne $Player.ActivePet -and $Player.ActivePet.Level -ge 100) {
            $LegacyBonuses.HasLegendaryPet = $true
            $InheritedScrap += 5000
            $TrinketMessage += "Your Level 100 $($Player.ActivePet.Name) returns to the shadows, leaving 5000 scrap behind! "
        }

        $LegacyBonuses.Scrap += $InheritedScrap
        
        $LevelTiers = [math]::Floor($Player.Level / 25)
        $CurrentRecord = 0
        if ($LegacyBonuses.UnlockedTiers.ContainsKey($Player.Class)) { $CurrentRecord = $LegacyBonuses.UnlockedTiers[$Player.Class] }

        if ($LevelTiers -gt $CurrentRecord) {
            $LegacyBonuses.UnlockedTiers[$Player.Class] = $LevelTiers
            $TrinketMessage += "NEW LEGACY LANDMARK! Your achievements as a $($Player.Class) permanently empower future lives."
        }

        Write-Host "Death claims you, but your legacy survives." -ForegroundColor DarkGray
        Write-Host "> Your zombified corpse now wanders the very room you died in..." -ForegroundColor DarkRed
        Write-Host "> $InheritedScrap scrap coins were left behind for the next survivor." -ForegroundColor Yellow
        if (-not [string]::IsNullOrWhiteSpace($TrinketMessage)) { Write-Host "> $TrinketMessage" -ForegroundColor Magenta }
        Read-Host "`nPress [Enter] to awaken in a new body..."
        
        $Player = New-PlayerCharacter -UnlockedClasses $LegacyBonuses.UnlockedClasses -HasLegendaryPet ($LegacyBonuses.HasLegendaryPet -eq $true)
        $Player.Currency += $LegacyBonuses.Scrap
        
        # --- BULLETPROOF ELEMENTAL TRACKER INJECTION ---
        if (-not (Get-Member -InputObject $Player -Name "Bonechips" -ErrorAction SilentlyContinue)) {
            $Player | Add-Member -MemberType NoteProperty -Name "Bonechips" -Value 0
            $Player | Add-Member -MemberType NoteProperty -Name "AppliedBonechipTiers" -Value 0
            $Player | Add-Member -MemberType NoteProperty -Name "Gunpowder" -Value 0
            $Player | Add-Member -MemberType NoteProperty -Name "AppliedGunpowderTiers" -Value 0
            $Player | Add-Member -MemberType NoteProperty -Name "EnergyOrbs" -Value 0
            $Player | Add-Member -MemberType NoteProperty -Name "AppliedOrbTiers" -Value 0
            $Player | Add-Member -MemberType NoteProperty -Name "ToxicGarnets" -Value 0
            $Player | Add-Member -MemberType NoteProperty -Name "AppliedGarnetTiers" -Value 0
            $Player | Add-Member -MemberType NoteProperty -Name "PetBonusHP" -Value 0
            $Player | Add-Member -MemberType NoteProperty -Name "BaseWeaponDamage" -Value 0
            $Player | Add-Member -MemberType NoteProperty -Name "IsStealthed" -Value $false
            $Player | Add-Member -MemberType NoteProperty -Name "EquippedOffhand" -Value "None"
            $Player | Add-Member -MemberType NoteProperty -Name "ShockAuraHits" -Value 0
        }

        # --- INJECT ELEMENTAL LEGACY DIRECTLY INTO NEW BODY ---
        $Player.Bonechips = $LegacyBonuses.Bonechips
        $Player.AppliedBonechipTiers = [math]::Floor($Player.Bonechips / 100)
        
        $Player.Gunpowder = $LegacyBonuses.Gunpowder
        $Player.AppliedGunpowderTiers = [math]::Floor($Player.Gunpowder / 100)
        
        $Player.EnergyOrbs = $LegacyBonuses.EnergyOrbs
        $Player.AppliedOrbTiers = [math]::Floor($Player.EnergyOrbs / 100)
        
        $Player.ToxicGarnets = $LegacyBonuses.ToxicGarnets
        $Player.AppliedGarnetTiers = [math]::Floor($Player.ToxicGarnets / 100)
        
        $TotalStr = 0; $TotalDex = 0; $TotalCon = 0; $TotalCha = 0; $TotalTac = 0; 
        $TotalInt = 0; $TotalLuck = 0; $TotalInf = 0; $TotalHp = 0; $TotalSp = 0; 
        $RawBp = 0; $RawAmmo = 0;

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

        $TotalBp = [math]::Floor($RawBp)
        $TotalAmmo = [math]::Floor($RawAmmo)

        # --- APPLY ELEMENTAL LEGACY ---
        $TotalHp += (10 * $Player.AppliedBonechipTiers)
        $TotalSp += (1 * $Player.AppliedOrbTiers)
        if ($Player.Class -eq "Immune Human") {
            $TotalAmmo += (1 * $Player.AppliedGunpowderTiers)
            $Player.BaseWeaponDamage += (1 * $Player.AppliedGunpowderTiers)
            $Player.Damage += (1 * $Player.AppliedGunpowderTiers)
            $TotalInf += (1 * $Player.AppliedGarnetTiers)
        } else {
            $DmgBoost = [math]::Floor(1.5 * $Player.AppliedGunpowderTiers)
            $Player.BaseWeaponDamage += $DmgBoost
            $Player.Damage += $DmgBoost
            $Player.PetBonusHP += (10 * $Player.AppliedGarnetTiers)
        }

        if ($LegacyBonuses.HasOuroboros) {
            $TotalStr += 5; $TotalDex += 5; $TotalCon += 5; $TotalCha += 5; $TotalTac += 5; $TotalInt += 5; $TotalLuck += 5
        }

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
        foreach ($Slot in $NewSlots) {
            if (-not (Get-Member -InputObject $Player -Name $Slot -ErrorAction SilentlyContinue)) { $Player | Add-Member -MemberType NoteProperty -Name $Slot -Value "None" }
        }
        if (-not (Get-Member -InputObject $Player -Name "LearnedSkills" -ErrorAction SilentlyContinue)) { $Player | Add-Member -MemberType NoteProperty -Name "LearnedSkills" -Value @(Get-ClassSkills -ClassName $Player.Class -PlayerLevel $Player.Level) }
        $Player.Armor = $Player.BaseArmor

        if ($BonusMessage.Count -gt 0) {
            $MsgString = $BonusMessage -join ", "
            Write-Host "`n> The ancestral trinkets glow... You inherited: $MsgString!" -ForegroundColor Magenta
        }

        $CurrentRoomID = "1"
        $CurrentRoom = Get-RoomState -WorldMap $WorldMap -RoomID $CurrentRoomID
        $CurrentMob = $null
        $CurrentNPC = $null
        $LastActionMessage = "Death was only a temporary setback. You feel the strength of your past lives."
        $TimePassed = $false
        continue 
    }
}