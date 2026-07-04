# --- Modules\StateManager.psm1 ---

function Invoke-GameTick {
    param(
        $Player, 
        $Mob, 
        [bool]$TurnPassed, 
        $LegacyBonuses
    )

    $TickMsgs = @()
    $MobDied = $false

    # --- 1. END OF TURN DOTS & BUFFS (PLAYER) ---
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
                            $TickMsgs += "You take $($Effect.DoT) damage from [$($Effect.Name)]!"
                        }
                        $Effect.Duration -= 1
                    }
                    $RemainingEffects += $Effect
                } else {
                    if ($TurnPassed) {
                        $TickMsgs += "The effect of [$($Effect.Name)] has faded."
                    } else {
                        $RemainingEffects += $Effect
                    }
                }
            }
        }
        $Player.ActiveEffects = $RemainingEffects

        if ($Player.Class -eq "Vampire") {
            if ($TurnPassed) { $Player.BP = [math]::Max(0, $Player.BP - 1) }
            $Tier = 0; $HPRegen = 0
            if ($Player.BP -ge 100) { $Tier = [math]::Floor(($Player.BP - 100) / 10); if ($TurnPassed) { $HPRegen = 2 + (0.2 * $Player.Level) } } 
            elseif ($Player.BP -ge 30 -and $Player.BP -lt 100) { $Tier = 0; if ($TurnPassed) { $HPRegen = 1 * $Player.Level } } 
            elseif ($Player.BP -lt 10) { $Tier = -1; if ($TurnPassed) { $HPRegen = -1 * $Player.Level } }

            if ($TurnPassed) { $Player.HP = [math]::Min($Player.MaxHP, ($Player.HP + $HPRegen)) }
            $BonusArmor += ($Tier * 5); $BonusStr += ($Tier * 1); $BonusDex += ($Tier * 2); $BonusCha += ($Tier * 5)
            $BonusCon += ($Tier * 1); $BonusTac += ($Tier * 1); $BonusInt += ($Tier * 1); $BonusLuck += [math]::Floor($Tier * 0.5); $BonusInf += ($Tier * 2)
        }

        $ArmorItemVal = 0; $ItemStr = 0; $ItemDex = 0; $ItemTac = 0; $ItemInt = 0; $ItemCha = 0; $ItemCon = 0; $ItemLuck = 0; $ItemInf = 0
        $EquipSlots = @($Player.EquippedArmor, $Player.EquippedShoulders, $Player.EquippedBoots, $Player.EquippedTrinket, $Player.EquippedNecklace, $Player.EquippedOffhand)
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
        
        if ($Player.LearnedSkills -contains "Mad Skills") {
            $HighestStat = [math]::Max($Player.Strength, [math]::Max($Player.Dexterity, [math]::Max($Player.CON, [math]::Max($Player.CHA, [math]::Max($Player.Tactics, [math]::Max($Player.Int, $Player.Luck))))))
            $Player.Damage = $Player.BaseWeaponDamage + $HighestStat
        }
    }

    # --- 2. END OF TURN DOTS (MOB) ---
    if ($null -ne $Mob -and $Mob.HP -gt 0 -and $TurnPassed) {
        $BonusMobDmg = 0; $BonusMobArmor = 0
        $RemainingMobEffects = @()
        
        if ($null -ne $Mob.ActiveEffects) {
            foreach ($Effect in $Mob.ActiveEffects) {
                if ($Effect.Duration -gt 0) {
                    if ($Effect.Modifiers.ContainsKey('Damage')) { $BonusMobDmg += $Effect.Modifiers.Damage }
                    if ($Effect.Modifiers.ContainsKey('Armor'))  { $BonusMobArmor += $Effect.Modifiers.Armor }
                    
                    if ($null -ne $Effect.DoT -and $Effect.DoT -gt 0) {
                        $Mob.HP -= $Effect.DoT
                        $TickMsgs += "The $($Mob.Name) takes $($Effect.DoT) damage from [$($Effect.Name)]!"
                        
                        if ($Player.LearnedSkills -contains "Flesh Parasite" -and (Get-Random -Min 1 -Max 101) -le 10) {
                            $Heal = [math]::Floor($Effect.DoT / 2)
                            $Player.HP = [math]::Min($Player.MaxHP, $Player.HP + $Heal)
                            $TickMsgs += "🦠 FLESH PARASITE! You siphon $Heal HP from the affliction!"
                        }
                    }
                    $Effect.Duration -= 1
                    $RemainingMobEffects += $Effect
                } else {
                    $TickMsgs += "The effect of [$($Effect.Name)] on the $($Mob.Name) has faded."
                }
            }
        }
        $Mob.ActiveEffects = $RemainingMobEffects
        $Mob.Damage = [math]::Max(0, ($Mob.BaseDamage + $BonusMobDmg))
        $Mob.Armor  = [math]::Max(0, ($Mob.BaseArmor + $BonusMobArmor))
    }

    # --- 3. MOB DEATH LOGIC ---
    if ($null -ne $Mob -and $Mob.HP -le 0) {
        $MobDied = $true
        $Player.XP += $Mob.XP; $Player.Currency += $Mob.Scrap
        $TickMsgs += "The $($Mob.Name) has been defeated! Gained $($Mob.XP) XP and found $($Mob.Scrap) scrap."

        # --- BESERKER 10: BLOODTHIRST ---
        if ($Player.LearnedSkills -contains "Bloodthirst") {
            $Heal = [math]::Floor($Player.MaxHP * 0.10)
            $Player.HP = [math]::Min($Player.MaxHP, $Player.HP + $Heal)
            $TickMsgs += "🩸 BLOODTHIRST! The kill fuels you, recovering $Heal HP!"
        }

        if ($null -eq $Player.ActivePet) {
            $HasCurse = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Blood Curse" }
            $HasRot = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Zombie Rot" }

            if ($null -ne $HasCurse) {
                $Player.ActivePet = [PSCustomObject]@{ Name="Vampiric $($Mob.Name)"; Level=$Mob.Level; XP=0; MaxHP=($Mob.MaxHP + $Player.PetBonusHP); HP=($Mob.MaxHP + $Player.PetBonusHP); Damage=$Mob.Damage; Armor=$Mob.Armor; IsLegacyPet = $false }
                $TickMsgs += "The Blood Curse takes hold... The $($Mob.Name) resurrects as your Vampiric servant!"
            } elseif ($null -ne $HasRot) {
                if (Invoke-InfectionCheck -Infectivity $Player.Infectivity) {
                    $Player.ActivePet = [PSCustomObject]@{ Name="Rotting $($Mob.Name)"; Level=$Mob.Level; XP=0; MaxHP=($Mob.MaxHP + $Player.PetBonusHP); HP=($Mob.MaxHP + $Player.PetBonusHP); Damage=$Mob.Damage; Armor=$Mob.Armor; IsLegacyPet = $false }
                    $TickMsgs += "COIN FLIP WON: The Zombie Rot consumes the corpse... The $($Mob.Name) rises as your infected servant!"
                } else {
                    $TickMsgs += "COIN FLIP FAILED: The $($Mob.Name)'s corpse rots into useless sludge."
                }
            }
        }
        
        if ($null -ne $Player.ActivePet -and $Player.ActivePet.Level -lt 100) {
            $Player.ActivePet.XP += $Mob.XP
            $pLvl = $Player.ActivePet.Level; $NextXP = 10000
            if ($pLvl -ge 99) { $NextXP = 1000000 } elseif ($pLvl -ge 61) { $NextXP = 250000 } elseif ($pLvl -ge 51) { $NextXP = 100000 } elseif ($pLvl -ge 41) { $NextXP = 50000 } elseif ($pLvl -ge 36) { $NextXP = 25000 } elseif ($pLvl -ge 31) { $NextXP = 17500 } elseif ($pLvl -ge 21) { $NextXP = 15000 } elseif ($pLvl -ge 11) { $NextXP = 12500 }

            while ($Player.ActivePet.XP -ge $NextXP -and $Player.ActivePet.Level -lt 100) {
                $Player.ActivePet.Level += 1; $Player.ActivePet.XP -= $NextXP
                $Player.ActivePet.MaxHP += 15; $Player.ActivePet.HP = $Player.ActivePet.MaxHP
                $Player.ActivePet.Damage += 3; $Player.ActivePet.Armor += 1
                $TickMsgs += "YOUR PET LEVELED UP! The $($Player.ActivePet.Name) is now Level $($Player.ActivePet.Level)!"
                $pLvl = $Player.ActivePet.Level; $NextXP = 10000
                if ($pLvl -ge 99) { $NextXP = 1000000 } elseif ($pLvl -ge 61) { $NextXP = 250000 } elseif ($pLvl -ge 51) { $NextXP = 100000 } elseif ($pLvl -ge 41) { $NextXP = 50000 } elseif ($pLvl -ge 36) { $NextXP = 25000 } elseif ($pLvl -ge 31) { $NextXP = 17500 } elseif ($pLvl -ge 21) { $NextXP = 15000 } elseif ($pLvl -ge 11) { $NextXP = 12500 }
            }
        }

        if ($null -ne $Mob.LootTable -and $Mob.LootTable.Count -gt 0) {
            foreach ($Item in $Mob.LootTable) {
                $ItemData = Get-ItemStats -ItemName $Item
                $IsUnique = ($null -ne $ItemData -and $ItemData.Type -eq "Trinket")
                $AlreadyOwned = $false
                if ($IsUnique) {
                    $AllOwned = @($Player.Inventory) + @($Player.EquippedTrinket)
                    if ($null -ne $LegacyBonuses -and $null -ne $LegacyBonuses.Stash) { $AllOwned += @($LegacyBonuses.Stash) }
                    foreach ($Owned in $AllOwned) { if ($Owned -ieq $Item) { $AlreadyOwned = $true; break } }
                }
                if (-not $AlreadyOwned) {
                    $Player.Inventory += $Item; $TickMsgs += "[LOOT] You picked up: $Item"
                } else {
                    $TickMsgs += "[LOOT] You see a [$Item], but since it's a unique artifact you already possess, you leave it behind."
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
            $TickMsgs += "LEVEL UP! You are now Level $($Player.Level)! Your stats have increased, and your HP and SP are fully restored."
            
            $NewClassSkills = Get-ClassSkills -ClassName $Player.Class -PlayerLevel $Player.Level
            foreach ($sk in $NewClassSkills) { if ($Player.LearnedSkills -notcontains $sk) { $Player.LearnedSkills += $sk } }
            
            if ($Player.LearnedSkills -contains "Stealth" -and -not $Player.IsStealthed) { $Player.IsStealthed = $true; $TickMsgs += "🌑 STEALTH UNLOCKED: You naturally fade into the shadows." }
            if ($Player.Class -eq "Immune Human" -and $Player.Level -eq 20 -and $Player.Inventory -notcontains "Shotgun" -and $Player.EquippedWeapon -ne "Shotgun") { 
                $Player.Inventory += "Shotgun"; $TickMsgs += "💥 LEVEL 20: You salvaged a heavy Shotgun for your arsenal!" 
            }
        }

        if ($null -ne $Mob.IsPlayerCorpse -and $Mob.IsPlayerCorpse) { 
            if ($null -ne $Player.ActivePet -and $Player.ActivePet.Name -match [regex]::Escape($Mob.Name)) {
                $TickMsgs += "🏆 *** ACHIEVEMENT UNLOCKED: Ouroboros ***`n> You have consumed your past life! Its soul now serves you."
                if (-not $LegacyBonuses.HasOuroboros) {
                    $LegacyBonuses.HasOuroboros = $true; $TickMsgs += "🐍 OUROBOROS LEGACY UNLOCKED: All future lives gain +5 to ALL base stats!"
                    $Player.BaseStrength += 5; $Player.Strength += 5; $Player.BaseDexterity += 5; $Player.Dexterity += 5
                    $Player.BaseCON += 5; $Player.CON += 5; $Player.BaseCHA += 5; $Player.CHA += 5
                    $Player.BaseTactics += 5; $Player.Tactics += 5; $Player.BaseInt += 5; $Player.Int += 5; $Player.BaseLuck += 5; $Player.Luck += 5
                }
            }
            $LegacyBonuses.PlayerCorpse = $null 
        }
    }

    # --- 4. LEGACY MILESTONES ---
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
        $TickMsgs += "*** NEW ACCOUNT LEGACY UNLOCKED! (Tier $CurrentTier) ***`n> You gained an immediate $MsgString!`n> Future characters will permanently inherit this power."
    }

    return [PSCustomObject]@{
        Message = ($TickMsgs -join "`n> ")
        MobDied = $MobDied
    }
}