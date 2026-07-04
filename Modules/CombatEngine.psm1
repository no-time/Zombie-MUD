# --- Modules\CombatEngine.psm1 ---

function Get-CalculatedDamage {
    param([int]$Str, [int]$Dex, [int]$WeaponDmg, [bool]$IsCrit)
    $StrDmg = 0
    if ($Str -ge 5000) { $StrDmg = [math]::Ceiling($Str * 4) } elseif ($Str -ge 1000) { $StrDmg = [math]::Ceiling($Str * 2.5) } elseif ($Str -ge 200) { $StrDmg = [math]::Ceiling($Str * 2) } elseif ($Str -ge 50) { $StrDmg = [math]::Ceiling($Str * 1.75) } elseif ($Str -ge 10) { $StrDmg = [math]::Ceiling($Str * 1.5) } else { $StrDmg = [math]::Ceiling($Str * 1) }
    $DexBase = [math]::Floor($Dex / 5); $DexDmg = 0
    if ($Dex -ge 1000) { $DexDmg = [math]::Ceiling($DexBase * 1.75) } elseif ($Dex -ge 500) { $DexDmg = [math]::Ceiling($DexBase * 1.5) } elseif ($Dex -ge 100) { $DexDmg = [math]::Ceiling($DexBase * 1.25) } else { $DexDmg = $DexBase }
    $Total = $StrDmg + $DexDmg + $WeaponDmg
    if ($IsCrit) { $Total = [math]::Ceiling($Total * 1.5) }
    return $Total
}

function Invoke-TacticsProc {
    param($Player, $Mob)
    $TacMsgs = @()
    $Tac = $Player.Tactics
    $BaseChance = 0
    if ($Tac -ge 150) { $BaseChance = 25 + [math]::Floor(($Tac - 150) * 0.5) } elseif ($Tac -ge 100) { $BaseChance = 20 + [math]::Floor(($Tac - 100) / 10) } elseif ($Tac -ge 50) { $BaseChance = 10 + [math]::Floor(($Tac - 50) / 5) } else { $BaseChance = [math]::Floor($Tac / 5) }
    
    $StatContrib = [math]::Min(30, $BaseChance)
    $BonusChance = 0
    if ($null -ne $Player.ActiveEffects) { foreach ($Eff in $Player.ActiveEffects) { if ($null -ne $Eff.Modifiers -and $Eff.Modifiers.ContainsKey('TacticsChance')) { $BonusChance += $Eff.Modifiers.TacticsChance } } }
    $EquipSlots = @($Player.EquippedArmor, $Player.EquippedShoulders, $Player.EquippedBoots, $Player.EquippedTrinket, $Player.EquippedNecklace)
    foreach ($Eq in $EquipSlots) {
        if ($Eq -ne "None" -and $null -ne $Eq) {
            $ItemData = Get-ItemStats -ItemName $Eq
            if ($null -ne $ItemData -and $null -ne $ItemData.Modifiers -and $ItemData.Modifiers.ContainsKey('TacticsChance')) { $BonusChance += $ItemData.Modifiers.TacticsChance }
        }
    }
    
    $TotalChance = $StatContrib + $BonusChance
    $MobResist = 0
    if ($null -ne $Mob.CCResist) { $MobResist = $Mob.CCResist } elseif ($Mob.IsBoss -or $Mob.IsImmune) { $MobResist = 100 }
    $FinalChance = $TotalChance - $MobResist
    
    if ($FinalChance -gt 0 -and (Get-Random -Min 1 -Max 101) -le $FinalChance) {
        $Roll = Get-Random -Min 1 -Max 4
        if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
        
        if ($Roll -eq 1) {
            $Existing = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Tactical Stun" } | Select-Object -First 1
            if ($null -ne $Existing) { $Existing.Duration = 2 } else { $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Tactical Stun"; Duration=2; DoT=0; Modifiers=@{} } }
            $TacMsgs += "🧠 TACTICS PROC! You cleverly Stun the $($Mob.Name)! They cannot use basic attacks for 2 turns."
        } elseif ($Roll -eq 2) {
            $Existing = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Tactical Flinch" } | Select-Object -First 1
            if ($null -ne $Existing) { $Existing.Duration = 3 } else { $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Tactical Flinch"; Duration=3; DoT=0; Modifiers=@{} } }
            $TacMsgs += "🧠 TACTICS PROC! You force the $($Mob.Name) to Flinch! Their special skills fail for 3 turns."
        } else {
            $Existing = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Tactical Tumble" } | Select-Object -First 1
            if ($null -ne $Existing) { $Existing.Duration = 1 } else { $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Tactical Tumble"; Duration=1; DoT=0; Modifiers=@{} } }
            $TacMsgs += "🧠 TACTICS PROC! You trip the $($Mob.Name), causing them to Tumble! They lose their next turn!"
            $RawDmg = Get-CalculatedDamage -Str $Player.Strength -Dex $Player.Dexterity -WeaponDmg $Player.Damage -IsCrit $false
            $OppDmg = [math]::Max(0, ($RawDmg - $Mob.Armor))
            $Mob.HP -= $OppDmg
            $TacMsgs += "> Attack of Opportunity strikes for $OppDmg damage!"
        }
    }
    return ($TacMsgs -join "`n> ")
}

function Invoke-ElementProc {
    param($Player, $Mob, $FinalDmg, $IsCrit)
    $ProcMsgs = @()
    if ($Player.EquippedNecklace -eq "None" -or $null -eq $Player.EquippedNecklace) { return "" }
    
    $NecklaceData = Get-ItemStats -ItemName $Player.EquippedNecklace
    if ($null -eq $NecklaceData -or $null -eq $NecklaceData.Element) { return "" }
    
    $Element = $NecklaceData.Element
    $IsRad = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Radioactive" } | Select-Object -First 1
    if ($null -ne $IsRad -and $FinalDmg -gt 0) {
        $Mob.MaxHP = [math]::Max(1, ($Mob.MaxHP - $FinalDmg))
        $Mob.HP = [math]::Min($Mob.HP, $Mob.MaxHP)
        $ProcMsgs += "☢️ The radiation severely decays the $($Mob.Name)'s cells! Max HP permanently reduced by $FinalDmg."
    }

    $LuckProcBonus = [math]::Min(70, [math]::Floor($Player.Luck / 10))
    $ProcChance = 20 + $LuckProcBonus
    $IsBurning = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Burning" } | Select-Object -First 1
    if ($null -ne $IsBurning) { $ProcChance += 15 }

    if ((Get-Random -Min 1 -Max 101) -gt $ProcChance) { return "" }
    if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
    if ($null -eq $Player.ActiveEffects) { $Player.ActiveEffects = @() }

    $ProcMult = 1
    if ($null -ne $NecklaceData.UpgradeLevel -and $NecklaceData.UpgradeLevel -gt 0) { $ProcMult += $NecklaceData.UpgradeLevel }

    switch ($Element) {
        "Radioactive" {
            if ($null -eq $IsRad) { $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Radioactive"; Duration=10; DoT=0; Modifiers=@{} }; $ProcMsgs += "☢️ RADIOACTIVE PROC! The $($Mob.Name) is glowing violently! Future attacks will shred their Max HP!" }
        }
        "Fire" {
            if ($null -ne $IsBurning) { $IsBurning.Duration = 5 } else { $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Burning"; Duration=5; DoT=8; Modifiers=@{} }; $ProcMsgs += "🔥 FIRE PROC! The $($Mob.Name) bursts into searing flames!" }
        }
        "Cryogenis" {
            $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Frozen"; Duration=2; DoT=0; Modifiers=@{} }
            $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Slowed"; Duration=3; DoT=0; Modifiers=@{Damage=-[math]::Floor($Mob.BaseDamage / 2)} }
            $ProcMsgs += "❄️ CRYOGENIS PROC! The $($Mob.Name) is flash-frozen!"
        }
        "Bloodwerk" {
            $IsExhausted = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Exhausted" } | Select-Object -First 1
            if ($null -eq $IsExhausted) {
                $BloodDoT = [math]::Max(1, [math]::Floor($FinalDmg / 10))
                $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Blood Drain"; Duration=3; DoT=$BloodDoT; Modifiers=@{} }
                $ExistingLust = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Bloodlust" } | Select-Object -First 1
                if ($null -eq $ExistingLust) {
                    $Player.ActiveEffects = @($Player.ActiveEffects) + [PSCustomObject]@{ Name="Bloodlust"; Duration=3; DoT=0; Modifiers=@{} }
                    $Player.ActiveEffects = @($Player.ActiveEffects) + [PSCustomObject]@{ Name="Exhausted"; Duration=10; DoT=0; Modifiers=@{} }
                    $ProcMsgs += "🩸 BLOODWERK PROC! You enter a furious Bloodlust! You will attack twice per turn!"
                }
            }
        }
        "Bonewerk" {
            $ExistingBone = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Bone Armor" } | Select-Object -First 1
            if ($null -ne $ExistingBone) { $ExistingBone.Duration = 3 } else { $Player.ActiveEffects = @($Player.ActiveEffects) + [PSCustomObject]@{ Name="Bone Armor"; Duration=3; DoT=0; Modifiers=@{Armor=5} } }
            $Player.MaxHP += 1; $Player.HP += 1; $Player.Bonechips += $ProcMult
            $ProcMsgs += "💀 BONEWERK PROC! Bones harden (+5 AC). Gained +1 Max HP! (+$ProcMult Bonechips)"
        }
        "Explosive" {
            $ExistingExp = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Explosive Ammo" } | Select-Object -First 1
            if ($null -ne $ExistingExp) { $ExistingExp.Duration = 2 } else { $Player.ActiveEffects = @($Player.ActiveEffects) + [PSCustomObject]@{ Name="Explosive Ammo"; Duration=2; DoT=0; Modifiers=@{} } }
            $Player.Gunpowder += $ProcMult
            $ProcMsgs += "💥 EXPLOSIVE PROC! Next criticals deal double damage! (+$ProcMult Gunpowder)"
            if ($Player.Class -eq "Immune Human") { $Player.Ammo = $Player.MaxAmmo; $ProcMsgs += "💥 Your Ammo is completely refilled!" }
        }
        "Energetic" {
            $ProcMsgs += "⚡ ENERGETIC PROC! Time slows as you unleash a blinding 4-hit combo!"
            for ($i = 0; $i -lt 4; $i++) {
                $ExDmg = Get-CalculatedDamage -Str $Player.Strength -Dex $Player.Dexterity -WeaponDmg $Player.Damage -IsCrit $false
                $ExFin = [math]::Max(0, ($ExDmg - $Mob.Armor))
                $Mob.HP -= $ExFin; $ProcMsgs += "> Energetic Strike deals $ExFin damage!"
            }
            $Player.MaxSP += 1; $Player.SP += 1; $Player.EnergyOrbs += $ProcMult
            if ($Player.Class -eq "Vampire") { $Player.BP = $Player.MaxBP; $ProcMsgs += "⚡ Your Vampire blood boils... BP fully restored!" }
            $ProcMsgs += "> Gained +1 Max SP permanently! (+$ProcMult Energy Orbs)"
        }
        "Putrid" {
            $TCloudDmg = $Player.Damage + 15 + $Player.Infectivity 
            $Mob.HP -= $TCloudDmg
            $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Zombie Rot"; Duration=4; DoT=($Player.Infectivity + 10); Modifiers=@{} }
            $Player.ToxicGarnets += $ProcMult
            $ProcMsgs += "🤢 PUTRID PROC! You exhale a Toxic Cloud for $TCloudDmg damage! (+$ProcMult Toxic Garnets)"
            if ($null -ne $Player.ActivePet) { $Player.ActivePet.HP = $Player.ActivePet.MaxHP; $ProcMsgs += "🤢 Fumes fully heal your $($Player.ActivePet.Name)!" }
        }
    }
    return ($ProcMsgs -join "`n> ")
}

function Invoke-MobTurn {
    param([Parameter(Mandatory=$true)]$Player, [Parameter(Mandatory=$true)]$Mob)
    $Message = ""

    # --- TANK 20: REFLECTIVE ARMOR ---
    if ($Player.LearnedSkills -contains "Reflective Armor") {
        if ((Get-Random -Min 1 -Max 101) -le 10) {
            $ReflectDmg = [math]::Max(0, ($Mob.Damage - $Player.Armor))
            $Heal = [math]::Floor($ReflectDmg / 2)
            $Player.HP = [math]::Min($Player.MaxHP, $Player.HP + $Heal)
            $Mob.HP -= $ReflectDmg
            return "`n> 🛡️ REFLECTIVE ARMOR! The $($Mob.Name)'s attack violently bounces back for $ReflectDmg damage, healing you for $Heal!"
        }
    }

    # --- POPULAR 20: RUMOR MILL ---
    if ($Player.LearnedSkills -contains "Rumor Mill") {
        if ((Get-Random -Min 1 -Max 101) -le 5) {
            $SelfDmg = Get-Random -Min [math]::Floor($Mob.Damage / 2) -Max ($Mob.Damage + 1)
            $Mob.HP -= $SelfDmg
            return "`n> 🗣️ RUMOR MILL! The $($Mob.Name) gets confused by conflicting gossip and furiously hits ITSELF for $SelfDmg damage!"
        }
    }

    # --- HARD STUN ENGINE ---
    $IsFrozen = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Frozen" } | Select-Object -First 1
    if ($null -ne $IsFrozen) { return "`n> ❄️ The $($Mob.Name) is completely frozen solid and cannot move!" }
    
    $IsDistracted = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Distracted" } | Select-Object -First 1
    if ($null -ne $IsDistracted) { return "`n> The $($Mob.Name) is utterly mesmerized and skips its turn!" }

    $IsTumbled = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Tactical Tumble" } | Select-Object -First 1
    if ($null -ne $IsTumbled) { return "`n> 🧠 TACTICS: The $($Mob.Name) is tumbling and completely loses its turn!" }

    $IsStunned = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Tactical Stun" } | Select-Object -First 1
    $IsFlinching = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Tactical Flinch" } | Select-Object -First 1

    $IsTargetingPet = ($null -ne $Player.ActivePet -and (Get-Random -Min 1 -Max 101) -gt 50)
    
    # --- MIRACLE DODGE ENGINE ---
    if (-not $IsTargetingPet) {
        $LuckDodgeBonus = [math]::Min(70, [math]::Floor($Player.Luck / 4))
        if ((Get-Random -Minimum 1 -Maximum 101) -le $LuckDodgeBonus) {
            return "`n> 🍀 MIRACLE DODGE! Your extreme luck allows you to effortlessly evade the $($Mob.Name)'s attack!"
        }
    }

    $TargetName = if ($IsTargetingPet) { "your $($Player.ActivePet.Name)" } else { "you" }
    $TargetArmor = if ($IsTargetingPet) { $Player.ActivePet.Armor } else { $Player.Armor }

    $MobDelta = $Mob.Level - $Player.Level
    $MobHitChance = [math]::Max(10, [math]::Min(95, (70 + ($MobDelta * 5))))
    
    # --- STEALTHY 20: EVASION DROP ---
    if ($Player.LearnedSkills -contains "Stealth" -and $Player.IsStealthed -and -not $IsTargetingPet) {
        $MobHitChance = [math]::Max(1, [math]::Floor($MobHitChance * 0.1))
    }

    $MobCritChance = [math]::Max(1, [math]::Min(50, (10 + ($MobDelta * 2))))

    if ((Get-Random -Minimum 1 -Maximum 101) -gt $MobHitChance) {
        $Message += "`n> The $($Mob.Name) lunges at $TargetName and misses!"
    } else {
        # --- TANK 10: BONEGUARD REFLECT ---
        if ($Player.LearnedSkills -contains "Boneguard" -and -not $IsTargetingPet) {
            $BoneReflect = 10 * [math]::Floor($Player.Level / 5)
            if ($BoneReflect -gt 0) {
                $Mob.HP -= $BoneReflect
                $Message += "`n> 🛡️ BONEGUARD! Spikes of bone impale the attacker for $BoneReflect damage!"
            }
        }
        
        # --- PLAGUEBRINGER 10: ROTTING TOUCH ---
        if ($Player.LearnedSkills -contains "Rotting Touch" -and -not $IsTargetingPet -and (-not $Mob.IsImmune -and -not $Mob.IsBoss)) {
            if ((Get-Random -Min 1 -Max 101) -le 10) {
                if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
                $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Zombie Rot"; Duration=3; DoT=($Player.Infectivity + 10); Modifiers=@{} }
                $Message += "`n> ☣️ ROTTING TOUCH! Your infected blood splatters, causing Zombie Rot!"
            }
        }

        # --- STEALTH BREAK ---
        if ($Player.LearnedSkills -contains "Stealth" -and $Player.IsStealthed -and -not $IsTargetingPet) {
            $Player.IsStealthed = $false; $Message += "`n> 🌑 You were pulled out of the shadows!"
        }

        $UseSkill = ($null -ne $Mob.Skills -and $Mob.Skills.Count -gt 0 -and (Get-Random -Min 1 -Max 101) -gt 50)
        
        if ($UseSkill) {
            if ($null -ne $IsFlinching) { return "`n> 🧠 TACTICS: The $($Mob.Name) tries to use a skill, but flinches and fails!" }
            
            $ChosenSkill = $Mob.Skills | Get-Random
            $SkillDmg = 0
            
            switch ($ChosenSkill) {
                { $_ -in "Bite", "Eat Flesh" } { $SkillDmg = [math]::Max(0, (($Mob.Damage + 10) - $TargetArmor)); $Heal = 15; $Mob.HP = [math]::Min($Mob.MaxHP, ($Mob.HP + $Heal)); $Message += "`n> The $($Mob.Name) uses $ChosenSkill on $TargetName for $SkillDmg damage and heals 15 HP!" }
                { $_ -eq "Brace" } {
                    $Heal = 25; $Mob.HP = [math]::Min($Mob.MaxHP, ($Mob.HP + $Heal))
                    if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
                    $ExistingBuff = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Mob Buff" } | Select-Object -First 1
                    if ($null -ne $ExistingBuff) { $ExistingBuff.Duration = 3; $Message += "`n> The $($Mob.Name) uses Brace! It heals 25 HP and refreshes its Armor buff." } 
                    else { $Buff = [PSCustomObject]@{ Name="Mob Buff"; Duration=3; DoT=0; Modifiers=@{Armor=5} }; $Mob.ActiveEffects = @($Mob.ActiveEffects) + $Buff; $Message += "`n> The $($Mob.Name) uses Brace! It heals 25 HP and gains +5 Armor." }
                }
                { $_ -eq "Focus" } {
                    $Heal = 15; $Mob.HP = [math]::Min($Mob.MaxHP, ($Mob.HP + $Heal))
                    $Message += "`n> The $($Mob.Name) uses Focus and recovers 15 HP!"
                }
                { $_ -in "Toxic Cloud", "Lob Tissue" } { $SkillDmg = [math]::Max(0, ($Mob.Damage - $TargetArmor)); if ($IsTargetingPet) { $SkillDmg += 15; $Message += "`n> The $($Mob.Name) uses $ChosenSkill on $TargetName for $SkillDmg damage!" } else { if ($null -eq $Player.ActiveEffects) { $Player.ActiveEffects = @() }; $ExistingInf = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Infected Wound" } | Select-Object -First 1; if ($null -ne $ExistingInf) { $ExistingInf.Duration = 3; $Message += "`n> The $($Mob.Name) uses $ChosenSkill on $TargetName for $SkillDmg damage! Your Infected Wound is renewed." } else { $DoT = [PSCustomObject]@{ Name="Infected Wound"; Duration=3; DoT=5; Modifiers=@{} }; $Player.ActiveEffects = @($Player.ActiveEffects) + $DoT; $Message += "`n> The $($Mob.Name) uses $ChosenSkill on $TargetName for $SkillDmg damage! You are poisoned (5 DoT)." } } }
                { $_ -eq "Slam" } { $SkillDmg = [math]::Max(0, ([math]::Floor($Mob.Damage * 1.5) - $TargetArmor)); $Message += "`n> The $($Mob.Name) unleashes Slam on $TargetName for a massive $SkillDmg damage!" }
                { $_ -eq "Cleave" } { $SkillDmg = [math]::Max(0, ([math]::Floor($Mob.Damage * 1.5) - $TargetArmor)); if ($IsTargetingPet) { $Message += "`n> The $($Mob.Name) unleashes Cleave on $TargetName for $SkillDmg damage!" } else { if ($null -eq $Player.ActiveEffects) { $Player.ActiveEffects = @() }; $ExistingSunder = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Sundered Armor" } | Select-Object -First 1; if ($null -ne $ExistingSunder) { $ExistingSunder.Duration = 3; $Message += "`n> The $($Mob.Name) unleashes Cleave on $TargetName for $SkillDmg damage! Your defenses remain sundered." } else { $Sunder = [PSCustomObject]@{ Name="Sundered Armor"; Duration=3; DoT=0; Modifiers=@{Armor=-3} }; $Player.ActiveEffects = @($Player.ActiveEffects) + $Sunder; $Message += "`n> The $($Mob.Name) unleashes Cleave on $TargetName for $SkillDmg damage, shattering your defenses (-3 AC)!" } } }
                { $_ -eq "Backstab" } { $SkillDmg = [math]::Max(0, ([math]::Floor($Mob.Damage * 1.5) - $TargetArmor)); if ($IsTargetingPet) { $Message += "`n> The $($Mob.Name) backstabs $TargetName for $SkillDmg damage!" } else { if ($null -eq $Player.ActiveEffects) { $Player.ActiveEffects = @() }; $ExistingBleed = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Bleeding" } | Select-Object -First 1; if ($null -ne $ExistingBleed) { $ExistingBleed.Duration = 4; $Message += "`n> The $($Mob.Name) backstabs $TargetName for $SkillDmg damage! Your bleeding wound is torn open again!" } else { $Bleed = [PSCustomObject]@{ Name="Bleeding"; Duration=4; DoT=12; Modifiers=@{} }; $Player.ActiveEffects = @($Player.ActiveEffects) + $Bleed; $Message += "`n> The $($Mob.Name) backstabs $TargetName for $SkillDmg damage, leaving a gaping bleeding wound (12 DoT)!" } } }
                { $_ -eq "Transform" } { $Mob.HP = $Mob.MaxHP; if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }; $ExistingHulk = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Hulk Form" } | Select-Object -First 1; if ($null -ne $ExistingHulk) { $ExistingHulk.Duration = 10; $Message += "`n> The $($Mob.Name) roars, refreshing its Hulk Form! HP fully restored." } else { $Buff = [PSCustomObject]@{ Name="Hulk Form"; Duration=10; DoT=0; Modifiers=@{Damage=20} }; $Mob.ActiveEffects = @($Mob.ActiveEffects) + $Buff; $Message += "`n> The $($Mob.Name) mutates into a raging HULK! HP fully restored and gains +20 Damage for 10 turns." } }
                { $_ -eq "Overload" } { $SkillDmg = [math]::Max(0, (($Mob.Damage + 15) - $TargetArmor)); if ($IsTargetingPet) { $Message += "`n> The $($Mob.Name) blasts $TargetName with Overload for $SkillDmg damage!" } else { if ($null -eq $Player.ActiveEffects) { $Player.ActiveEffects = @() }; $ExistingShock = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Shocked" } | Select-Object -First 1; if ($null -ne $ExistingShock) { $ExistingShock.Duration = 3; $Message += "`n> The $($Mob.Name) blasts $TargetName with Overload for $SkillDmg damage! You remain Shocked." } else { $Shock = [PSCustomObject]@{ Name="Shocked"; Duration=3; DoT=5; Modifiers=@{Damage=-3} }; $Player.ActiveEffects = @($Player.ActiveEffects) + $Shock; $Message += "`n> The $($Mob.Name) blasts $TargetName with Overload for $SkillDmg damage! You are Shocked (5 DoT, -3 DMG)." } } }
                { $_ -eq "Exploit" } { $SkillDmg = [math]::Max(0, (($Mob.Damage + 10) - $TargetArmor)); if ($IsTargetingPet) { $Message += "`n> The $($Mob.Name) exploits a weakness on $TargetName for $SkillDmg damage!" } else { if ($null -eq $Player.ActiveEffects) { $Player.ActiveEffects = @() }; $ExistingExposed = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Exposed" } | Select-Object -First 1; if ($null -ne $ExistingExposed) { $ExistingExposed.Duration = 3; $Message += "`n> The $($Mob.Name) exploits a weakness on $TargetName for $SkillDmg damage! You remain Exposed." } else { $Exposed = [PSCustomObject]@{ Name="Exposed"; Duration=3; DoT=0; Modifiers=@{Armor=-5; Damage=-2} }; $Player.ActiveEffects = @($Player.ActiveEffects) + $Exposed; $Message += "`n> The $($Mob.Name) exploits a weakness on $TargetName for $SkillDmg damage! You are Exposed (-5 AC, -2 DMG)." } } }
                { $_ -eq "Lucky Strike" } { $SkillDmg = [math]::Max(0, (($Mob.Damage + 25) - $TargetArmor)); $Message += "`n> The $($Mob.Name) swings blindly with a Lucky Strike on $TargetName for $SkillDmg damage!"; if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }; $ExistingLuck = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Charmed Aura" } | Select-Object -First 1; if ($null -ne $ExistingLuck) { $ExistingLuck.Duration = 3 } else { $LuckAura = [PSCustomObject]@{ Name="Charmed Aura"; Duration=3; DoT=0; Modifiers=@{Damage=5} }; $Mob.ActiveEffects = @($Mob.ActiveEffects) + $LuckAura } }
                default { $SkillDmg = [math]::Max(0, ($Mob.Damage - $TargetArmor)); $Message += "`n> The $($Mob.Name) uses $ChosenSkill on $TargetName for $SkillDmg damage!" }
            }
            
            if ($IsTargetingPet) { $Player.ActivePet.HP -= $SkillDmg } else { $Player.HP -= $SkillDmg }
            
        } else {
            if ($null -ne $IsStunned) { return "`n> 🧠 TACTICS: The $($Mob.Name) is stunned and cannot make a basic attack this turn!" }

            if ((Get-Random -Minimum 1 -Maximum 101) -le $MobCritChance) {
                $MobDmg = [math]::Max(0, (($Mob.Damage * 2) - $TargetArmor))
                if ($IsTargetingPet) { $Player.ActivePet.HP -= $MobDmg } else { $Player.HP -= $MobDmg }
                $Message += "`n> CRITICAL HIT! The $($Mob.Name) viciously attacks $TargetName for $MobDmg damage!"
            } else {
                $MobDmg = [math]::Max(0, ($Mob.Damage - $TargetArmor))
                if ($IsTargetingPet) { $Player.ActivePet.HP -= $MobDmg } else { $Player.HP -= $MobDmg }
                $Message += "`n> The $($Mob.Name) hits $TargetName for $MobDmg damage."
            }
        }
    }

    if ($null -ne $Player.ActivePet -and $Player.ActivePet.HP -le 0) {
        $Message += "`n> YOUR PET HAS FALLEN! The $($Player.ActivePet.Name) collapses lifelessly to the ground."
        $Player.ActivePet = $null
    }
    return $Message
}

function Invoke-CombatRound {
    param(
        [Parameter(Mandatory=$true)]$Player, 
        [Parameter(Mandatory=$true)]$Mob, 
        [Parameter(Mandatory=$true)]$Action,
        [hashtable]$LegacyBonuses = $null
    )
    $RoundMessages = @()

    # --- TECHNOLOGIST 10: QUITE SHOCKING AURA ---
    if ($Player.LearnedSkills -contains "Quite Shocking" -and $Mob.HP -gt 0) {
        $Player.ShockAuraHits += 1
        $Mob.HP -= $Player.Level
        $RoundMessages += "⚡ Your Quite Shocking aura deals $($Player.Level) static damage!"
        
        if ($Player.ShockAuraHits -ge 10) {
            $Player.ShockAuraHits = 0
            $RawDmg = Get-CalculatedDamage -Str $Player.Strength -Dex $Player.Dexterity -WeaponDmg $Player.Damage -IsCrit $false
            $ODmg = [math]::Max(0, ($RawDmg + ($Player.Int * 4) - $Mob.Armor))
            $Mob.HP -= $ODmg
            if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
            $ExistingShock = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Shocked" } | Select-Object -First 1
            if ($null -ne $ExistingShock) { $ExistingShock.Duration = 3 }
            else { $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Shocked"; Duration=3; DoT=5; Modifiers=@{Damage=-3} } }
            $RoundMessages += "⚡ QUITE SHOCKING OVERLOAD! Stored static blasts the target for $ODmg damage and Shock!"
        }
    }

    if ($Action -in 'a', 'attack') {
        
        # --- STEALTH BREAK ---
        if ($Player.LearnedSkills -contains "Stealth" -and $Player.IsStealthed) {
            $Player.IsStealthed = $false; $RoundMessages += "🌑 You leap from the shadows!"
        }

        # --- LOBBER 10: GOO SHOES PROC ---
        if ($Player.LearnedSkills -contains "Goo Shoes" -and (Get-Random -Min 1 -Max 101) -le 10) {
            if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
            $Existing = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Tactical Flinch" } | Select-Object -First 1
            if ($null -ne $Existing) { $Existing.Duration = 3 } else { $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Tactical Flinch"; Duration=3; DoT=0; Modifiers=@{} } }
            $RoundMessages += "🦠 GOO SHOES! Your attack splashes sticky mass, causing the enemy to Flinch!"
        }

        # --- BESERKER 20: HULK FRENZY SYNERGY ---
        $IsBeserkerHulkFrenzy = $false
        if ($Player.LearnedSkills -contains "Feeding Frenzy") {
            $IsFrenzy = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Feeding Frenzy" }
            $IsHulk = @($Player.ActiveEffects) | Where-Object { $_.Name -match "Hulk Form" -or $_.Name -match "Apex Alpha" }
            if ($IsFrenzy -and $IsHulk) { $IsBeserkerHulkFrenzy = $true }
        }

        if ($IsBeserkerHulkFrenzy) {
            $RoundMessages += "🧟 HULK FRENZY! You violently lash out with a free Brains! attack instead of swinging your weapon!"
            $SuccessChance = 1 + [math]::Floor($Player.Infectivity / 2)
            
            if ($Mob.IsBoss -or $Mob.IsImmune) {
                $B_Dmg = $Player.Damage + 10 + [math]::Floor($Player.Strength / 2); $Mob.HP -= $B_Dmg
                $RoundMessages += "You tear into the $($Mob.Name) for $B_Dmg DMG!"
            } elseif ((Get-Random -Min 1 -Max 101) -le $SuccessChance) {
                $HealAmount = $Mob.HP; $Player.HP = [math]::Min($Player.MaxHP, ($Player.HP + $HealAmount)); $Mob.HP = 0
                if ($null -eq $Player.ActivePet) {
                    $Player.ActivePet = [PSCustomObject]@{ Name="Infected $($Mob.Name)"; Level=$Mob.Level; XP=0; MaxHP=($Mob.MaxHP + $Player.PetBonusHP); HP=($Mob.MaxHP + $Player.PetBonusHP); Damage=$Mob.Damage; Armor=$Mob.Armor; IsLegacyPet = $false }
                    $RoundMessages += "INSTANT KILL! You healed for $HealAmount HP and the corpse rises as your pet!"
                } else { $RoundMessages += "INSTANT KILL! You healed for $HealAmount HP!" }
            } else {
                $B_Dmg = $Player.Damage + 10 + [math]::Floor($Player.Strength / 2); $Mob.HP -= $B_Dmg
                $RoundMessages += "You chew on the $($Mob.Name) for $B_Dmg DMG!"
            }
        } 
        else {
            $PlayerDelta = $Player.Level - $Mob.Level
            $BaseCritChance = [math]::Max(1, [math]::Min(50, (10 + ($PlayerDelta * 2))))
            $LuckCritBonus = [math]::Min(70, [math]::Floor($Player.Luck / 5))
            $CritChance = [math]::Min(100, ($BaseCritChance + $LuckCritBonus))
            
            $HitChance = [math]::Max(10, [math]::Min(95, (85 + ($PlayerDelta * 5))))
            $HitRoll = Get-Random -Minimum 1 -Maximum 101

            if ($HitRoll -gt $HitChance) {
                $RoundMessages += "You swing at the $($Mob.Name) but they easily evade your attack!"
            } else {
                $CritRoll = Get-Random -Minimum 1 -Maximum 101
                $IsCrit = ($CritRoll -le $CritChance)
                
                $IsBurning = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Burning" } | Select-Object -First 1
                if ($null -ne $IsBurning -and -not $IsCrit) { if ((Get-Random -Min 1 -Max 101) -le 20) { $IsCrit = $true } }

                $RawDmg = Get-CalculatedDamage -Str $Player.Strength -Dex $Player.Dexterity -WeaponDmg $Player.Damage -IsCrit $IsCrit
                
                $ZombieClasses = @("Bruiser", "Tank", "Popular", "Stealthy", "Tactician", "Technologist", "Charmed", "Lobber", "Plaguebringer", "Beserker")
                if ($Player.Class -in $ZombieClasses) {
                    $CanInfect = (-not $Mob.IsBoss) -and (-not $Mob.IsImmune) -and ($Mob.Type -eq "Human" -or $Player.Class -in @("Lobber", "Plaguebringer"))
                    if ($CanInfect) {
                        $InfChance = [math]::Min(50, (5 + [math]::Floor($Player.Infectivity / 3)))
                        if ((Get-Random -Min 1 -Max 101) -le $InfChance) {
                            if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
                            $HasRot = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Zombie Rot" } | Select-Object -First 1
                            if ($null -ne $HasRot) {
                                $HasRot.Duration = 3; $RoundMessages += "Your infectious touch renews the Zombie Rot on the $($Mob.Name)!"
                            } else {
                                $RotDmg = [math]::Max(2, [math]::Floor($Player.Infectivity / 2))
                                $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Zombie Rot"; Duration=3; DoT=$RotDmg; Modifiers=@{} }
                                $RoundMessages += "Your infectious touch takes hold! The $($Mob.Name) is inflicted with Zombie Rot ($RotDmg DoT)."
                            }
                        }
                    }
                }

                # --- BRUISER 20: SKULLCRACKER ---
                if ($Player.LearnedSkills -contains "Skullcracker" -and (Get-Random -Min 1 -Max 101) -le 5) {
                    $RawDmg += $Player.Strength
                    $RoundMessages += "💀 SKULLCRACKER! You crush bone, dealing massive bonus STR damage!"
                    
                    if ($null -eq $Player.ActiveEffects) { $Player.ActiveEffects = @() }
                    $ExistingBrace = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Braced" } | Select-Object -First 1
                    $Heal = 25; $Player.HP = [math]::Min($Player.MaxHP, ($Player.HP + $Heal))
                    if ($null -ne $ExistingBrace) {
                        $ExistingBrace.Duration = 3; $RoundMessages += "> Momentum triggers Brace! Healed $Heal HP and refreshed Armor buff."
                    } else {
                        $Player.ActiveEffects = @($Player.ActiveEffects) + [PSCustomObject]@{ Name="Braced"; Duration=3; DoT=0; Modifiers=@{Armor=5} }
                        $RoundMessages += "> Momentum triggers Brace! Healed $Heal HP and gained +5 Armor for 3 turns."
                    }
                }

                $FinalDmg = [math]::Max(0, ($RawDmg - $Mob.Armor))
                
                if ($IsCrit) {
                    $HasExp = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Explosive Ammo" } | Select-Object -First 1
                    if ($null -ne $HasExp) { $FinalDmg = [math]::Floor($FinalDmg * 2); $RoundMessages += "💥 EXPLOSIVE DETONATION! Critical damage is DOUBLED!" }
                    if ($null -ne $IsBurning) { $FinalDmg = [math]::Floor($FinalDmg * 1.5); $RoundMessages += "🔥 FLAME STRIKE! Searing heat drastically increases critical damage!" }
                }

                $Mob.HP -= $FinalDmg
                if ($IsCrit) { $RoundMessages += "CRITICAL HIT! You strike the $($Mob.Name) for $FinalDmg damage!" } else { $RoundMessages += "You strike the $($Mob.Name) for $FinalDmg damage." }
                
                $ElementProcs = Invoke-ElementProc -Player $Player -Mob $Mob -FinalDmg $FinalDmg -IsCrit $IsCrit
                if (-not [string]::IsNullOrWhiteSpace($ElementProcs)) { $RoundMessages += $ElementProcs }

                if ($Mob.HP -gt 0) {
                    $TacProcs = Invoke-TacticsProc -Player $Player -Mob $Mob
                    if (-not [string]::IsNullOrWhiteSpace($TacProcs)) { $RoundMessages += $TacProcs }
                }

                # --- STEALTHY 10: TWO FISTING (OFFHAND STRIKE) ---
                if ($Player.LearnedSkills -contains "Two Fisting" -and $Player.EquippedOffhand -ne "None" -and $Mob.HP -gt 0) {
                    $OHData = Get-ItemStats $Player.EquippedOffhand
                    $OHRaw = Get-CalculatedDamage -Str $Player.Strength -Dex $Player.Dexterity -WeaponDmg $OHData.Value -IsCrit $false
                    $OHFin = [math]::Max(0, ($OHRaw - $Mob.Armor))
                    $Mob.HP -= $OHFin
                    $RoundMessages += "🗡️ TWO FISTING! Your offhand weapon slices in for $OHFin damage!"
                }

                $HasLust = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Bloodlust" } | Select-Object -First 1
                if ($null -ne $HasLust -and $Mob.HP -gt 0) {
                    $RawDmg2 = Get-CalculatedDamage -Str $Player.Strength -Dex $Player.Dexterity -WeaponDmg $Player.Damage -IsCrit $false
                    $FinalDmg2 = [math]::Max(0, ($RawDmg2 - $Mob.Armor))
                    $Mob.HP -= $FinalDmg2
                    $RoundMessages += "🩸 BLOODLUST! Your frenzy grants a free physical follow-up strike for $FinalDmg2 damage!"
                    
                    $ElementProcs2 = Invoke-ElementProc -Player $Player -Mob $Mob -FinalDmg $FinalDmg2 -IsCrit $false
                    if (-not [string]::IsNullOrWhiteSpace($ElementProcs2)) { $RoundMessages += $ElementProcs2 }

                    if ($Mob.HP -gt 0) {
                        $TacProcs2 = Invoke-TacticsProc -Player $Player -Mob $Mob
                        if (-not [string]::IsNullOrWhiteSpace($TacProcs2)) { $RoundMessages += $TacProcs2 }
                    }
                }
            }
        }
        
        # --- TACTICIAN 20: TACTICAL ADVANTAGE ---
        if ($Player.LearnedSkills -contains "Tactical Advantage" -and $Mob.HP -gt 0) {
            $TacDmg = $Player.Level * 1
            $Mob.HP -= $TacDmg
            $RoundMessages += "♟️ TACTICAL ADVANTAGE! You seamlessly weave in a free attack for $TacDmg damage!"
            $TacElProc = Invoke-ElementProc -Player $Player -Mob $Mob -FinalDmg $TacDmg -IsCrit $false
            if ($TacElProc) { $RoundMessages += $TacElProc }
            if ($Mob.HP -gt 0) {
                $TacCCProc = Invoke-TacticsProc -Player $Player -Mob $Mob
                if ($TacCCProc) { $RoundMessages += $TacCCProc }
            }
        }

        # --- PET SKILL ENGINE ---
        if ($null -ne $Player.ActivePet) {
            if ($Player.ActivePet.IsLegacyPet -eq $true) {
                $UseSkill = ((Get-Random -Min 1 -Max 101) -gt 50)
                if ($UseSkill) {
                    switch ($Player.ActivePet.Role) {
                        "Heal" {
                            $Heal = [math]::Floor($Player.ActivePet.Damage / 2)
                            $MissingHP = $Player.MaxHP - $Player.HP
                            $ActualHeal = [math]::Max(0, [math]::Min($Heal, $MissingHP))
                            $Player.HP += $ActualHeal
                            if ($ActualHeal -gt 0) { $RoundMessages += "Your Legacy $($Player.ActivePet.Name) uses Mend! You recover $ActualHeal HP." } 
                            else { $RoundMessages += "Your Legacy $($Player.ActivePet.Name) readies a Mend, but you are already at full health!" }
                        }
                        "Buff" {
                            $Scale = $Player.ActivePet.Level * 1.25
                            $BuffStr = [math]::Round(5 * $Scale); $BuffAC = [math]::Round(2 * $Scale)
                            if ($null -eq $Player.ActiveEffects) { $Player.ActiveEffects = @() }
                            $ExistingAura = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Pet Aura" } | Select-Object -First 1
                            if ($null -ne $ExistingAura) {
                                $ExistingAura.Duration = 2; $ExistingAura.Modifiers.Strength = $BuffStr; $ExistingAura.Modifiers.Armor = $BuffAC
                                $RoundMessages += "Your Legacy $($Player.ActivePet.Name) refreshes its battle aura!"
                            } else {
                                $Buff = [PSCustomObject]@{ Name="Pet Aura"; Duration=2; DoT=0; Modifiers=@{Strength=$BuffStr; Armor=$BuffAC} }
                                $Player.ActiveEffects = @($Player.ActiveEffects) + $Buff; $RoundMessages += "Your Legacy $($Player.ActivePet.Name) grants a battle aura! +$BuffStr STR, +$BuffAC AC."
                            }
                        }
                        "Damage" {
                            if ($Mob.HP -gt 0) {
                                $ScaleBonus = [math]::Round($Player.ActivePet.Level * 2.5)
                                $Dmg = $Player.ActivePet.Damage + $ScaleBonus + (Get-Random -Min 10 -Max 30)
                                $Mob.HP -= $Dmg; $RoundMessages += "Your Legacy $($Player.ActivePet.Name) unleashes Smash for $Dmg damage!"
                            }
                        }
                    }
                } else {
                    if ($Mob.HP -gt 0) {
                        $PetDmg = $Player.ActivePet.Damage + (Get-Random -Minimum 0 -Maximum 11)
                        $Mob.HP -= $PetDmg; $RoundMessages += "Your Legacy $($Player.ActivePet.Name) strikes normally for $PetDmg damage!"
                    }
                }
            } else {
                if ($Mob.HP -gt 0) {
                    $PetDmg = $Player.ActivePet.Damage + (Get-Random -Minimum 0 -Maximum 11)
                    $Mob.HP -= $PetDmg; $RoundMessages += "Your $($Player.ActivePet.Name) attacks for $PetDmg damage!"
                }
            }
        }
    }
    elseif ($Action -in 'r', 'run') {
        $RoundMessages += "You attempt to flee..."
        if ((Get-Random -Minimum 1 -Maximum 10) -gt 4) {
            $RoundMessages += "You successfully broke away and escaped!"
            $Mob.HP = 0
        } else {
            $RoundMessages += "You tripped! The $($Mob.Name) bites you for $($Mob.Damage) damage."
            $Player.HP -= $Mob.Damage
        }
    }
    return ($RoundMessages -join "`n> ")
}