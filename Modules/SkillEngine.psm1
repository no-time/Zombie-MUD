# --- Modules\SkillEngine.psm1 ---

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

function Get-ClassSkills {
    param([string]$ClassName, [int]$PlayerLevel = 1)
    $Skills = @('Focus') 
    $ZombieClasses = @("Bruiser", "Tank", "Popular", "Stealthy", "Tactician", "Technologist", "Charmed", "Lobber", "Plaguebringer", "Beserker")
    if ($ClassName -in $ZombieClasses) { $Skills += 'Brains!' }

    switch ($ClassName) {
        'Bruiser'       { $Skills += 'Slam', 'Cleave'; if ($PlayerLevel -ge 10) { $Skills += 'Vicious Kick' } }
        'Tank'          { $Skills += 'Brace' }
        'Popular'       { $Skills += 'Distract', 'Cancel' }
        'Stealthy'      { $Skills += 'Backstab' }
        'Tactician'     { $Skills += 'Exploit'; if ($PlayerLevel -ge 10) { $Skills += 'Foresight' } }
        'Technologist'  { $Skills += 'Overload' }
        'Charmed'       { $Skills += 'Lucky Strike'; if ($PlayerLevel -ge 10) { $Skills += 'Heads or Tails' } }
        'Lobber'        { $Skills += 'Lob Tissue' }
        'Plaguebringer' { $Skills += 'Toxic Cloud' }
        'Beserker'      { $Skills += 'Transform', 'Eat Flesh' }
        'Vampire'       { $Skills += 'Bite', 'Blood Curse'; if ($PlayerLevel -ge 20) { $Skills += 'Exsanguinate'; $Skills += 'Blood Mist' } } 
        'Immune Human'  { $Skills += 'Firearm' }
    }
    return $Skills
}

function Invoke-InfectionCheck {
    param([int]$Infectivity)
    if ($Infectivity -le 0) { return $false }
    $TriggerChance = [math]::Min(100, [math]::Round(($Infectivity / 112) * 100))
    if ((Get-Random -Minimum 1 -Maximum 101) -le $TriggerChance) { return ((Get-Random -Minimum 0 -Maximum 2) -eq 1) }
    return $false
}

function Invoke-SkillRound {
    param(
        $Player, 
        $Mob, 
        $SkillName,
        $LegacyBonuses = $null
    )

    $HasSkill = $false; $RealSkillName = ""
    foreach ($S in $Player.LearnedSkills) { 
        if ($S -ieq $SkillName) { $HasSkill = $true; $RealSkillName = $S; break } 
    }
    if (-not $HasSkill) { return "You do not know the skill '$SkillName'." }
    $SkillName = $RealSkillName

    $Message = ""; $DamageDealt = 0; $IsAttack = $true

    # --- TECHNOLOGIST 10: QUITE SHOCKING AURA ---
    if ($Player.LearnedSkills -contains "Quite Shocking" -and $Mob.HP -gt 0) {
        $Player.ShockAuraHits += 1
        $Mob.HP -= $Player.Level
        $Message += "⚡ Your Quite Shocking aura deals $($Player.Level) static damage!`n> "
        
        if ($Player.ShockAuraHits -ge 10) {
            $Player.ShockAuraHits = 0
            $RawDmg = Get-CalculatedDamage -Str $Player.Strength -Dex $Player.Dexterity -WeaponDmg $Player.Damage -IsCrit $false
            $ODmg = [math]::Max(0, ($RawDmg + ($Player.Int * 4) - $Mob.Armor))
            $Mob.HP -= $ODmg
            if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
            $ExistingShock = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Shocked" } | Select-Object -First 1
            if ($null -ne $ExistingShock) { $ExistingShock.Duration = 3 }
            else { $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Shocked"; Duration=3; DoT=5; Modifiers=@{Damage=-3} } }
            $Message += "⚡ QUITE SHOCKING OVERLOAD! Stored static blasts the target for $ODmg damage and Shock!`n> "
        }
    }

    # --- STEALTH BREAK ---
    if ($Player.LearnedSkills -contains "Stealth" -and $Player.IsStealthed -and $SkillName -notmatch "Stealth|Focus|First Aid|Brace|Transform|Blood Mist") {
        $Player.IsStealthed = $false; $Message += "🌑 You leap from the shadows!`n> "
    }

    # --- CHARMED 20: NOTHING UP MY SLEEVES ---
    $IsFreeCast = $false
    if ($Player.LearnedSkills -contains "Nothing Up My Sleeves") {
        if ((Get-Random -Min 1 -Max 101) -le 10) { 
            $Player.SP = [math]::Min($Player.MaxSP, $Player.SP + 1)
            $Message += "🎩 NOTHING UP MY SLEEVES! You miraculously find +1 SP in your pocket!`n> "
        }
        if ((Get-Random -Min 1 -Max 101) -le 5) {
            $IsFreeCast = $true
            $Message += "🎩 NOTHING UP MY SLEEVES! The magical energy completely refunds this skill's SP cost!`n> "
        }
    }

    if ($SkillName -ieq 'Stealth') {
        if ($Player.IsStealthed) { return "You are already hiding in the shadows!" }
        $Player.IsStealthed = $true
        $Message += "🌑 You slip quietly into the shadows. Your evasion is drastically increased!"; $IsAttack = $false
    }
    elseif ($SkillName -ieq 'Brains!') {
        $SPCost = 12
        if ($Player.LearnedSkills -contains "Feeding Frenzy" -and (@($Player.ActiveEffects) | Where-Object { $_.Name -eq "Feeding Frenzy" })) { $SPCost = 0 }
        if ($IsFreeCast) { $SPCost = 0 }
        if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP." }
        $Player.SP -= $SPCost
        
        $Message += "You run towards the $($Mob.Name) screaming BRAAIINS!"
        $BaseChance = 2
        switch ($Player.Class) { "Plaguebringer" { $BaseChance = 30 }; "Lobber" { $BaseChance = 15 }; "Popular" { $BaseChance = 10 }; "Beserker" { $BaseChance = 1 } }
        $SuccessChance = $BaseChance + [math]::Floor($Player.Infectivity / 2)
        
        if ($Mob.IsBoss -or $Mob.IsImmune) {
            $DamageDealt = $Player.Damage + 10 + [math]::Floor($Player.Strength / 2)
            $Message += "`n> The $($Mob.Name) pushes you off. You try to gnaw on them, but spit out a wad of hair... (Dealt $DamageDealt DMG)"
        } elseif ((Get-Random -Min 1 -Max 101) -le $SuccessChance) {
            $HealAmount = $Mob.HP; $Player.HP = [math]::Min($Player.MaxHP, ($Player.HP + $HealAmount)); $DamageDealt = 9999
            if ($null -eq $Player.ActivePet) {
                $Player.ActivePet = [PSCustomObject]@{ Name="Infected $($Mob.Name)"; Level=$Mob.Level; XP=0; MaxHP=($Mob.MaxHP + $Player.PetBonusHP); HP=($Mob.MaxHP + $Player.PetBonusHP); Damage=$Mob.Damage; Armor=$Mob.Armor; IsLegacyPet = $false }
                $Message += "`n> You tear in to a nice $($Mob.Name) sweetbread...`n> You heal for $HealAmount HP and the corpse rises as your pet!"
            } else {
                $Message += "`n> You tear in to a nice $($Mob.Name) sweetbread...`n> You heal for $HealAmount HP! (You already have a pet, so the corpse is left to rot)."
            }
        } else {
            $DamageDealt = $Player.Damage + 10 + [math]::Floor($Player.Strength / 2)
            $Message += "`n> You try to gnaw on the $($Mob.Name), but spit out a wad of hair... (Dealt $DamageDealt DMG)"
        }
        
        if ($Player.LearnedSkills -contains "Feeding Frenzy" -and (Get-Random -Min 1 -Max 101) -le 15) {
            if ($null -eq $Player.ActiveEffects) { $Player.ActiveEffects = @() }
            $ExistingFrenzy = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Feeding Frenzy" } | Select-Object -First 1
            if ($null -ne $ExistingFrenzy) { $ExistingFrenzy.Duration = 5 } else { $Player.ActiveEffects = @($Player.ActiveEffects) + [PSCustomObject]@{ Name="Feeding Frenzy"; Duration=5; DoT=0; Modifiers=@{} } }
            $Message += "`n> 🩸 FEEDING FRENZY! The taste of flesh drives you wild! Flesh skills cost 0 SP for 5 turns!"
        }
    }
    elseif ($SkillName -ieq 'Focus') {
        $SPCost = 3; $BPCost = 10
        if ($IsFreeCast) { $SPCost = 0; $BPCost = 0 }
        
        if ($Player.Class -eq "Vampire") {
            if ($Player.BP -lt $BPCost) { return "Needs $BPCost BP to Focus." }
            $Player.BP -= $BPCost
        } else {
            if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP to Focus." }
            $Player.SP -= $SPCost
        }
        
        $Heal = 15; $Player.HP = [math]::Min($Player.MaxHP, ($Player.HP + $Heal))
        $Message += "You bandage your wounds, restoring $Heal HP."; $IsAttack = $false
    }
    elseif ($SkillName -ieq 'First Aid') {
        $SPCost = 8; $BPCost = 20
        if ($IsFreeCast) { $SPCost = 0; $BPCost = 0 }
        
        if ($Player.Class -eq "Vampire") {
            if ($Player.BP -lt $BPCost) { return "Needs $BPCost BP for First Aid." }
            $Player.BP -= $BPCost
        } else {
            if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP for First Aid." }
            $Player.SP -= $SPCost
        }
        
        $IntBonus = [math]::Floor($Player.Int / 10); $ChaBonus = [math]::Floor($Player.CHA / 50) * 2; $LvlBonus = $Player.Level
        $Heal = 40 + $IntBonus + $ChaBonus + $LvlBonus
        $Player.HP = [math]::Min($Player.MaxHP, ($Player.HP + $Heal))
        $Message += "You apply advanced first aid techniques, restoring $Heal HP! (Base 40 + $IntBonus INT + $ChaBonus CHA + $LvlBonus LVL)"
        if ($null -ne $Player.ActivePet) {
            $Player.ActivePet.HP = [math]::Min($Player.ActivePet.MaxHP, ($Player.ActivePet.HP + $Heal))
            $Message += "`n> You quickly bandage your $($Player.ActivePet.Name) as well, restoring $Heal HP to it!"
        }
        $IsAttack = $false
    }
    elseif ($SkillName -ieq 'Slam') {
        $SPCost = 10; if ($IsFreeCast) { $SPCost = 0 }; if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP." }; $Player.SP -= $SPCost
        $DamageDealt = $Player.Damage + ($Player.Strength * 3)
        $Message += "You SLAM the $($Mob.Name) for $DamageDealt damage!"
    }
    elseif ($SkillName -ieq 'Cleave') {
        $SPCost = 8; if ($IsFreeCast) { $SPCost = 0 }; if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP." }; $Player.SP -= $SPCost
        $DamageDealt = $Player.Damage + [math]::Floor($Player.Strength * 2.5) + 10 
        if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
        $ExistingSunder = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Sundered Armor" } | Select-Object -First 1
        if ($null -ne $ExistingSunder) {
            $ExistingSunder.Duration = 3
            $Message += "You cleave the $($Mob.Name) for $DamageDealt damage, keeping their defenses shattered!"
        } else {
            $Sunder = [PSCustomObject]@{ Name="Sundered Armor"; Duration=3; DoT=0; Modifiers=@{Armor=-3} }
            $Mob.ActiveEffects = @($Mob.ActiveEffects) + $Sunder; $Message += "You cleave the $($Mob.Name) for $DamageDealt damage, shattering their defenses!"
        }
    }
    elseif ($SkillName -ieq 'Vicious Kick') {
        $SPCost = 12; if ($IsFreeCast) { $SPCost = 0 }; if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP." }; $Player.SP -= $SPCost
        $DamageDealt = $Player.Damage + ($Player.Strength * 2)
        if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
        
        if ((Get-Random -Min 1 -Max 101) -le 50) {
            $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Tactical Stun"; Duration=2; DoT=0; Modifiers=@{} }
            $Message += "🦵 VICIOUS KICK! You shatter the enemy's stance for $DamageDealt damage, Stunning them for 2 turns!"
        } else {
            $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Slowed"; Duration=3; DoT=0; Modifiers=@{Damage=-[math]::Floor($Mob.BaseDamage / 2)} }
            $Message += "🦵 VICIOUS KICK! You strike for $DamageDealt damage, Slowing and weakening the target for 3 turns!"
        }
    }
    elseif ($SkillName -ieq 'Heads or Tails') {
        $SPCost = 15; if ($IsFreeCast) { $SPCost = 0 }; if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP." }; $Player.SP -= $SPCost
        
        if ((Get-Random -Min 1 -Max 101) -le 51) {
            $DamageDealt = $Player.Damage * 2
            $Message += "🪙 HEADS! Luck favors you! You deal a massive $DamageDealt damage!"
        } else {
            if ($null -eq $Player.ActiveEffects) { $Player.ActiveEffects = @() }
            $Player.ActiveEffects = @($Player.ActiveEffects) + [PSCustomObject]@{ Name="Tactical Stun"; Duration=1; DoT=0; Modifiers=@{} }
            $Message += "🪙 TAILS! You fumble the trick and lose your next turn!"
            $IsAttack = $false
        }
    }
    elseif ($SkillName -ieq 'Brace') {
        $SPCost = 5; if ($IsFreeCast) { $SPCost = 0 }; if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP." }; $Player.SP -= $SPCost
        $Heal = 25; $Player.HP = [math]::Min($Player.MaxHP, ($Player.HP + $Heal))
        if ($null -eq $Player.ActiveEffects) { $Player.ActiveEffects = @() }
        $ExistingBrace = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Braced" } | Select-Object -First 1
        if ($null -ne $ExistingBrace) {
            $ExistingBrace.Duration = 3; $Message += "You brace yourself! Healed $Heal HP and refreshed your Armor buff."; $IsAttack = $false
        } else {
            $Buff = [PSCustomObject]@{ Name="Braced"; Duration=3; DoT=0; Modifiers=@{Armor=5} }
            $Player.ActiveEffects = @($Player.ActiveEffects) + $Buff; $Message += "You brace yourself! Healed $Heal HP and gained +5 Armor for 3 turns."; $IsAttack = $false
        }
    }
    elseif ($SkillName -ieq 'Distract') {
        $SPCost = 8; if ($IsFreeCast) { $SPCost = 0 }; if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP." }; $Player.SP -= $SPCost
        $DistractTurns = 1 + [math]::Floor($Player.CHA / 10)
        
        if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
        $ExistingDistract = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Distracted" } | Select-Object -First 1
        if ($null -ne $ExistingDistract) {
            $ExistingDistract.Duration = $DistractTurns; $Message += "Your charisma distracts the $($Mob.Name) again! They are mesmerized for $DistractTurns turn(s)."; $IsAttack = $false
        } else {
            $DistractDebuff = [PSCustomObject]@{ Name="Distracted"; Duration=$DistractTurns; DoT=0; Modifiers=@{} }
            $Mob.ActiveEffects = @($Mob.ActiveEffects) + $DistractDebuff; $Message += "Your charisma distracts the $($Mob.Name)! They are mesmerized for $DistractTurns turn(s)."; $IsAttack = $false
        }
    }
    elseif ($SkillName -ieq 'Cancel') {
        $SPCost = 10; if ($IsFreeCast) { $SPCost = 0 }; if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP." }; $Player.SP -= $SPCost
        $DamageDealt = $Player.Damage + ($Player.CHA * 3)
        if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
        $ExistingShame = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Shamed" } | Select-Object -First 1
        if ($null -ne $ExistingShame) {
            $ExistingShame.Duration = 3; $Message += "You relentlessly cancel the $($Mob.Name) for $DamageDealt damage! Their attack remains crippled."
        } else {
            $Shame = [PSCustomObject]@{ Name="Shamed"; Duration=3; DoT=0; Modifiers=@{Damage=-5} }
            $Mob.ActiveEffects = @($Mob.ActiveEffects) + $Shame; $Message += "You absolutely cancel the $($Mob.Name) for $DamageDealt damage! They are Shamed (-5 DMG) for 3 turns."
        }
    }
    elseif ($SkillName -ieq 'Backstab') {
        $SPCost = 10; if ($IsFreeCast) { $SPCost = 0 }; if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP." }; $Player.SP -= $SPCost
        $DamageDealt = $Player.Damage + [math]::Floor($Player.Dexterity * 3)
        $BleedTurns = 4
        
        if ($Player.LearnedSkills -contains "Stealth" -and $Message -match "You leap from the shadows") {
            $DamageDealt = $DamageDealt * 2
            $BleedTurns += [math]::Max(1, [math]::Floor($Player.Level * 0.1))
        }

        if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
        $ExistingBleed = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Bleeding" } | Select-Object -First 1
        if ($null -ne $ExistingBleed) {
            $ExistingBleed.Duration = $BleedTurns; $Message += "You backstab the $($Mob.Name) for $DamageDealt damage! The bleeding worsens!"
        } else {
            $Bleed = [PSCustomObject]@{ Name="Bleeding"; Duration=$BleedTurns; DoT=12; Modifiers=@{} }
            $Mob.ActiveEffects = @($Mob.ActiveEffects) + $Bleed; $Message += "You backstab the $($Mob.Name) for $DamageDealt damage, leaving a gaping, bleeding wound!"
        }
    }
    elseif ($SkillName -ieq 'Exploit') {
        $SPCost = 10; if ($IsFreeCast) { $SPCost = 0 }; if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP." }; $Player.SP -= $SPCost
        $DamageDealt = $Player.Damage + ($Player.Tactics * 3)
        
        if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
        $ExistingExposed = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Exposed" } | Select-Object -First 1
        if ($null -ne $ExistingExposed) { $ExistingExposed.Duration = 3 } 
        else { $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Exposed"; Duration=3; DoT=0; Modifiers=@{Armor=-5; Damage=-2} } }
        
        if ($null -eq $Player.ActiveEffects) { $Player.ActiveEffects = @() }
        $ExistingAdv = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Tactical Advantage" } | Select-Object -First 1
        if ($null -ne $ExistingAdv) { $ExistingAdv.Duration = 3 }
        else { $Player.ActiveEffects = @($Player.ActiveEffects) + [PSCustomObject]@{ Name="Tactical Advantage"; Duration=3; DoT=0; Modifiers=@{TacticsChance=50} } }
        
        $Message += "You exploit a tactical weakness for $DamageDealt damage! The target is Exposed (-5 AC, -2 DMG), and you gain Tactical Advantage (+50% CC Chance) for 3 turns."
    }
    elseif ($SkillName -ieq 'Overload') {
        $SPCost = 12; if ($IsFreeCast) { $SPCost = 0 }; if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP." }; $Player.SP -= $SPCost
        $DamageDealt = $Player.Damage + ($Player.Int * 4)
        if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
        $ExistingShock = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Shocked" } | Select-Object -First 1
        if ($null -ne $ExistingShock) {
            $ExistingShock.Duration = 3; $Message += "You blast the $($Mob.Name) with overloaded tech for $DamageDealt damage! They remain Shocked."
        } else {
            $Shock = [PSCustomObject]@{ Name="Shocked"; Duration=3; DoT=5; Modifiers=@{Damage=-3} }
            $Mob.ActiveEffects = @($Mob.ActiveEffects) + $Shock; $Message += "You blast the $($Mob.Name) with overloaded tech for $DamageDealt damage! They are Shocked, taking 5 DoT and dealing less damage."
        }
    }
    elseif ($SkillName -ieq 'Lucky Strike') {
        $SPCost = 8; if ($IsFreeCast) { $SPCost = 0 }; if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP." }; $Player.SP -= $SPCost
        $DamageDealt = $Player.Damage + ($Player.Luck * 5) + (Get-Random -Min 10 -Max 30)
        if ($null -eq $Player.ActiveEffects) { $Player.ActiveEffects = @() }
        $ExistingLuck = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Charmed Aura" } | Select-Object -First 1
        if ($null -ne $ExistingLuck) {
            $ExistingLuck.Duration = 3; $Message += "You swing blindly for $DamageDealt damage! Your aura of extreme luck is refreshed."
        } else {
            $LuckAura = [PSCustomObject]@{ Name="Charmed Aura"; Duration=3; DoT=0; Modifiers=@{Luck=500} }
            $Player.ActiveEffects = @($Player.ActiveEffects) + $LuckAura; $Message += "You swing blindly for $DamageDealt damage! An aura of extreme luck surrounds you."
        }
    }
    elseif ($SkillName -ieq 'Lob Tissue') {
        $SPCost = 10; if ($IsFreeCast) { $SPCost = 0 }; if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP." }; $Player.SP -= $SPCost
        $DamageDealt = $Player.Damage + 15 + $Player.Infectivity 
        $Message += "You lob heavy infected mass for $DamageDealt damage!"
        
        if ($Player.LearnedSkills -contains "Flesh Parasite" -and (Get-Random -Min 1 -Max 101) -le 10) {
            $Heal = [math]::Floor($DamageDealt / 2)
            $Player.HP = [math]::Min($Player.MaxHP, $Player.HP + $Heal)
            $Message += "`n> 🦠 FLESH PARASITE! You siphon $Heal HP from the impact!"
        }

        if ($Mob.IsBoss -or $Mob.IsImmune) {
            $Message += "`n> The $($Mob.Name) is IMMUNE to your infection!"
        } elseif (Invoke-InfectionCheck -Infectivity $Player.Infectivity) {
            $DamageDealt = 9999
            if ($null -eq $Player.ActivePet) {
                $Player.ActivePet = [PSCustomObject]@{ Name="Infected $($Mob.Name)"; Level=$Mob.Level; XP=0; MaxHP=($Mob.MaxHP + $Player.PetBonusHP); HP=($Mob.MaxHP + $Player.PetBonusHP); Damage=$Mob.Damage; Armor=$Mob.Armor; IsLegacyPet = $false }
                $Message += "`n> COIN FLIP WON: The target is overwhelmed and becomes your Pet!"
            } else {
                $Message += "`n> COIN FLIP WON: The target is overwhelmed and dies instantly!"
            }
        } else {
            if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
            $ExistingCripple = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Crippled" } | Select-Object -First 1
            if ($null -ne $ExistingCripple) {
                $ExistingCripple.Duration = 3; $Message += "`n> COIN FLIP FAILED: The target remains Crippled (-4 DMG, -2 AC)!"
            } else {
                $Cripple = [PSCustomObject]@{ Name="Crippled"; Duration=3; DoT=0; Modifiers=@{Damage=-4; Armor=-2} }
                $Mob.ActiveEffects = @($Mob.ActiveEffects) + $Cripple; $Message += "`n> COIN FLIP FAILED: The target is Crippled (-4 DMG, -2 AC)!"
            }
        }
    }
    elseif ($SkillName -ieq 'Toxic Cloud') {
        $SPCost = 10; if ($IsFreeCast) { $SPCost = 0 }; if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP." }; $Player.SP -= $SPCost
        $DamageDealt = $Player.Damage + 15 + $Player.Infectivity 
        $Message += "You release a dense toxic cloud for $DamageDealt damage!"
        
        $IsImmune = ($Mob.IsBoss -or $Mob.IsImmune)
        
        if ($IsImmune -and $Player.LearnedSkills -contains "Legendary Toxin" -and (Get-Random -Min 1 -Max 101) -le 5) {
            $IsImmune = $false
            $Message += "`n> ☣️ LEGENDARY TOXIN! Your intense plague completely bypasses the $($Mob.Name)'s immunity!"
            $DamageDealt = 9999
            if ($null -eq $Player.ActivePet) {
                $Player.ActivePet = [PSCustomObject]@{ Name="Infected $($Mob.Name)"; Level=$Mob.Level; XP=0; MaxHP=($Mob.MaxHP + $Player.PetBonusHP); HP=($Mob.MaxHP + $Player.PetBonusHP); Damage=$Mob.Damage; Armor=$Mob.Armor; IsLegacyPet = $false }
                $Message += "`n> The target is overwhelmed and becomes your Pet!"
            } else {
                $Message += "`n> The target is overwhelmed and dies instantly!"
            }
        }
        
        if ($IsImmune) {
            $Message += "`n> The $($Mob.Name) is IMMUNE to your infection!"
        } elseif ($DamageDealt -eq 9999) {
            # Bypassed
        } elseif (Invoke-InfectionCheck -Infectivity $Player.Infectivity) {
            $DamageDealt = 9999
            if ($null -eq $Player.ActivePet) {
                $Player.ActivePet = [PSCustomObject]@{ Name="Infected $($Mob.Name)"; Level=$Mob.Level; XP=0; MaxHP=($Mob.MaxHP + $Player.PetBonusHP); HP=($Mob.MaxHP + $Player.PetBonusHP); Damage=$Mob.Damage; Armor=$Mob.Armor; IsLegacyPet = $false }
                $Message += "`n> COIN FLIP WON: The target breathes deep and becomes your Pet!"
            } else {
                $Message += "`n> COIN FLIP WON: The target breathes deep and perishes instantly!"
            }
        } else {
            if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
            $ExistingRot = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Zombie Rot" } | Select-Object -First 1
            if ($null -ne $ExistingRot) {
                $ExistingRot.Duration = 4; $Message += "`n> COIN FLIP FAILED: The target's Zombie Rot is renewed!"
            } else {
                $Rot = [PSCustomObject]@{ Name="Zombie Rot"; Duration=4; DoT=($Player.Infectivity + 10); Modifiers=@{} }
                $Mob.ActiveEffects = @($Mob.ActiveEffects) + $Rot; $Message += "`n> COIN FLIP FAILED: The target suffers heavy Zombie Rot!"
            }
        }
    }
    elseif ($SkillName -ieq 'Transform') {
        if ($null -eq $Player.ActiveEffects) { $Player.ActiveEffects = @() }
        $AlreadyTransformed = @($Player.ActiveEffects) | Where-Object { $_.Name -match "Hulk Form" } | Select-Object -First 1
        if ($null -ne $AlreadyTransformed) { return "You are already transformed!" }
        
        $IsExhausted = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Exhausted" } | Select-Object -First 1
        if ($null -ne $IsExhausted) { return "Your body is too Exhausted to Transform!" }
        
        $SPCost = 15; if ($IsFreeCast) { $SPCost = 0 }; if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP." }; $Player.SP -= $SPCost
        $Player.HP = $Player.MaxHP
        
        $Buff = [PSCustomObject]@{ Name="Hulk Form"; Duration=10; DoT=0; Modifiers=@{Strength=20} }
        $Exhaustion = [PSCustomObject]@{ Name="Exhausted"; Duration=13; DoT=0; Modifiers=@{} }
        $Player.ActiveEffects = @($Player.ActiveEffects) + $Buff + $Exhaustion
        $Message += "You roar as the virus mutates you into a raging HULK! HP fully restored and Strength surged. (Causes 13 turns of Exhaustion)"; $IsAttack = $false
    }
    elseif ($SkillName -ieq 'Eat Flesh') {
        $SPCost = 8
        if ($Player.LearnedSkills -contains "Feeding Frenzy" -and (@($Player.ActiveEffects) | Where-Object { $_.Name -eq "Feeding Frenzy" })) { $SPCost = 0 }
        if ($IsFreeCast) { $SPCost = 0 }
        if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP." }
        $Player.SP -= $SPCost
        
        $DamageDealt = $Player.Damage + 20 + $Player.Strength
        $Player.HP = [math]::Min($Player.MaxHP, ($Player.HP + 15)) 
        $Message += "You tear into flesh, dealing $DamageDealt damage and recovering 15 HP!"
        
        if ($Player.LearnedSkills -contains "Feeding Frenzy" -and (Get-Random -Min 1 -Max 101) -le 15) {
            if ($null -eq $Player.ActiveEffects) { $Player.ActiveEffects = @() }
            $ExistingFrenzy = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Feeding Frenzy" } | Select-Object -First 1
            if ($null -ne $ExistingFrenzy) { $ExistingFrenzy.Duration = 5 } else { $Player.ActiveEffects = @($Player.ActiveEffects) + [PSCustomObject]@{ Name="Feeding Frenzy"; Duration=5; DoT=0; Modifiers=@{} } }
            $Message += "`n> 🩸 FEEDING FRENZY! The taste of flesh drives you wild! Flesh skills cost 0 SP for 5 turns!"
        }
    }
    elseif ($SkillName -ieq 'Bite') {
        $DamageDealt = $Player.Damage + [math]::Floor($Player.Strength * 1.5)
        $BPLeech = 20 + ($Player.Infectivity * 2)
        $Player.BP = [math]::Min($Player.MaxBP, ($Player.BP + $BPLeech))
        $Message += "You bare your fangs and strike the $($Mob.Name) for $DamageDealt damage, recovering $BPLeech BP!"
    }
    elseif ($SkillName -ieq 'Blood Curse') {
        $BPCost = 35; if ($Player.BP -lt $BPCost) { return "Needs $BPCost BP to cast Blood Curse." }; $Player.BP -= $BPCost
        if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
        $ExistingCurse = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Blood Curse" } | Select-Object -First 1
        if ($null -ne $ExistingCurse) {
            $ExistingCurse.Duration = 4; $Message += "You expend $BPCost BP to renew the Blood Curse! The target takes heavy DoT and is weakened."; $IsAttack = $false
        } else {
            $Curse = [PSCustomObject]@{ Name="Blood Curse"; Duration=4; DoT=15; Modifiers=@{Armor=-2; Damage=-2} }
            $Mob.ActiveEffects = @($Mob.ActiveEffects) + $Curse; $Message += "You expend $BPCost BP to inflict a Blood Curse! The target takes heavy DoT and is weakened. If it dies, it will rise as your servant!"; $IsAttack = $false
        }
    }
    elseif ($SkillName -ieq 'Blood Mist') {
        $SPCost = 10; if ($IsFreeCast) { $SPCost = 0 }; if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP." }
        if ($Player.BP -lt 5) { return "Needs 5 BP to cast Blood Mist." }
        $ExistingExh = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Exhausted" } | Select-Object -First 1
        if ($null -ne $ExistingExh) { return "You are too Exhausted to cast Blood Mist!" }
        
        $Player.SP -= $SPCost; $Player.BP -= 5
        $BonusDmg = $Player.BP
        
        if ($null -eq $Player.ActiveEffects) { $Player.ActiveEffects = @() }
        $Player.ActiveEffects = @($Player.ActiveEffects) + [PSCustomObject]@{ Name="Blood Mist"; Duration=5; DoT=0; Modifiers=@{Armor=10; Damage=$BonusDmg} }
        $Player.ActiveEffects = @($Player.ActiveEffects) + [PSCustomObject]@{ Name="Exhausted"; Duration=10; DoT=0; Modifiers=@{} }
        $Message += "🦇 BLOOD MIST! You vaporize your blood into a protective mist! Gained +$BonusDmg DMG and +10 AC for 5 rounds, but you are now Exhausted!"; $IsAttack = $false
    }
    elseif ($SkillName -ieq 'Exsanguinate') {
        if ($Player.BP -lt 70) { return "You need at least 70 BP to unleash Exsanguinate!" }
        $SPCost = 15; if ($IsFreeCast) { $SPCost = 0 }; if ($Player.SP -lt $SPCost) { return "Needs $SPCost SP." }; $Player.SP -= $SPCost
        
        $Player.BP = [math]::Min($Player.MaxBP, ($Player.BP + 5))
        if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
        
        $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Bleeding"; Duration=4; DoT=12; Modifiers=@{} }
        $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Exposed"; Duration=3; DoT=0; Modifiers=@{Armor=-5; Damage=-2} }
        $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Crippled"; Duration=3; DoT=0; Modifiers=@{Damage=-4; Armor=-2} }
        
        if ($null -eq $Player.ActiveEffects) { $Player.ActiveEffects = @() }
        $Player.ActiveEffects = @($Player.ActiveEffects) + [PSCustomObject]@{ Name="Exhausted"; Duration=10; DoT=0; Modifiers=@{} }
        
        $Message += "🦇 EXSANGUINATE! You violently drain the target, recovering 5 BP! The target is Bleeding, Exposed, and Crippled, but you are left Exhausted!"; $IsAttack = $false
    }
    elseif ($SkillName -ieq 'Firearm') {
        $HasShotgun = ($Player.LearnedSkills -contains "Double-Pump" -and ($Player.Inventory -contains "Shotgun" -or $Player.EquippedWeapon -eq "Shotgun"))
        if (-not ($Player.Inventory -contains "Glock .45" -or $Player.EquippedWeapon -eq "Glock .45" -or $HasShotgun)) { return "You need a firearm to use this skill!" }
        
        $AmmoCost = if ($HasShotgun) { 2 } else { 1 }
        if ($Player.Ammo -lt $AmmoCost) { return "*Click*... You are out of ammo! You'll have to rely on your melee weapon." }
        $Player.Ammo -= $AmmoCost
        
        $TacticsMultiplier = 1 + ($Player.Tactics / 100)
        $DamageDealt = [math]::Floor(45 * $TacticsMultiplier)
        
        if ($HasShotgun) {
            $DamageDealt = $DamageDealt * 2
            if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
            $ExistingBleed = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Bleeding" } | Select-Object -First 1
            if ($null -ne $ExistingBleed) { $ExistingBleed.Duration = 4 } else { $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Bleeding"; Duration=4; DoT=12; Modifiers=@{} } }
            $Message += "💥 DOUBLE-PUMP! You blast the target with your Shotgun for an obliterating $DamageDealt damage and heavy Bleeding!"
        } else {
            $Message += "You fire your Glock .45 ($($Player.Ammo) rounds left) for $DamageDealt damage!"
        }

        if ($null -eq $Player.ActiveEffects) { $Player.ActiveEffects = @() }
        $ExistingAdrenaline = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Adrenaline" } | Select-Object -First 1
        if ($null -ne $ExistingAdrenaline) {
            $ExistingAdrenaline.Duration = 2; $Message += "`n> Your Adrenaline rush is refreshed."
        } else {
            $Adrenaline = [PSCustomObject]@{ Name="Adrenaline"; Duration=2; DoT=0; Modifiers=@{Tactics=5; Dexterity=5; Armor=3} }
            $Player.ActiveEffects = @($Player.ActiveEffects) + $Adrenaline; $Message += "`n> The panic gives you an Adrenaline rush (+DEX, +TAC, +AC)."
        }
    }

    # --- DAMAGE & PROC ENGINE INTEGRATION ---
    if ($IsAttack -and $DamageDealt -gt 0 -and $DamageDealt -ne 9999) { 
        $IsCrit = $false
        $LuckCritBonus = [math]::Min(70, [math]::Floor($Player.Luck / 5))
        if ((Get-Random -Min 1 -Max 101) -le $LuckCritBonus) { $IsCrit = $true }

        $IsBurning = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Burning" } | Select-Object -First 1
        if ($null -ne $IsBurning -and -not $IsCrit) { 
            if ((Get-Random -Min 1 -Max 101) -le 20) { $IsCrit = $true }
        }

        if ($IsCrit) {
            $HasExp = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Explosive Ammo" } | Select-Object -First 1
            if ($null -ne $HasExp) {
                $DamageDealt = [math]::Floor($DamageDealt * 2)
                $Message += "`n> 💥 EXPLOSIVE DETONATION! Critical damage is DOUBLED!"
            }
            if ($null -ne $IsBurning) {
                $DamageDealt = [math]::Floor($DamageDealt * 1.5)
                $Message += "`n> 🔥 FLAME STRIKE! Searing heat drastically increases critical damage!"
            }
        }
    
        $Mob.HP -= $DamageDealt 
        
        $ElementProcs = Invoke-ElementProc -Player $Player -Mob $Mob -FinalDmg $DamageDealt -IsCrit $IsCrit
        if (-not [string]::IsNullOrWhiteSpace($ElementProcs)) { $Message += "`n> $ElementProcs" }

        # --- LOBBER 10: GOO SHOES PROC ---
        if ($Player.LearnedSkills -contains "Goo Shoes" -and (Get-Random -Min 1 -Max 101) -le 10) {
            if ($null -eq $Mob.ActiveEffects) { $Mob.ActiveEffects = @() }
            $Existing = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Tactical Flinch" } | Select-Object -First 1
            if ($null -ne $Existing) { $Existing.Duration = 3 } else { $Mob.ActiveEffects = @($Mob.ActiveEffects) + [PSCustomObject]@{ Name="Tactical Flinch"; Duration=3; DoT=0; Modifiers=@{} } }
            $Message += "`n> 🦠 GOO SHOES! Your attack splashes sticky mass, causing the enemy to Flinch!"
        }

        if ($Mob.HP -gt 0) {
            $TacProcs = Invoke-TacticsProc -Player $Player -Mob $Mob
            if (-not [string]::IsNullOrWhiteSpace($TacProcs)) { $Message += "`n> $TacProcs" }
        }
        
        # --- STEALTHY 10: TWO FISTING (OFFHAND STRIKE) ---
        if ($Player.LearnedSkills -contains "Two Fisting" -and $Player.EquippedOffhand -ne "None" -and $Mob.HP -gt 0) {
            $OHData = Get-ItemStats $Player.EquippedOffhand
            $OHRaw = Get-CalculatedDamage -Str $Player.Strength -Dex $Player.Dexterity -WeaponDmg $OHData.Value -IsCrit $false
            $OHFin = [math]::Max(0, ($OHRaw - $Mob.Armor))
            $Mob.HP -= $OHFin
            $Message += "`n> 🗡️ TWO FISTING! Your offhand weapon slices in for $OHFin damage!"
        }

        # Bloodlust Follow-Up Attack
        $HasLust = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Bloodlust" } | Select-Object -First 1
        if ($null -ne $HasLust -and $Mob.HP -gt 0) {
            $RawDmg2 = [math]::Floor($Player.Damage + ($Player.Strength * 1.5)) 
            $FinalDmg2 = [math]::Max(0, ($RawDmg2 - $Mob.Armor))
            $Mob.HP -= $FinalDmg2
            $Message += "`n> 🩸 BLOODLUST! Your frenzy grants a free physical follow-up strike for $FinalDmg2 damage!"
            
            $ElementProcs2 = Invoke-ElementProc -Player $Player -Mob $Mob -FinalDmg $FinalDmg2 -IsCrit $false
            if (-not [string]::IsNullOrWhiteSpace($ElementProcs2)) { $Message += "`n> $ElementProcs2" }
            
            if ($Mob.HP -gt 0) {
                $TacProcs2 = Invoke-TacticsProc -Player $Player -Mob $Mob
                if (-not [string]::IsNullOrWhiteSpace($TacProcs2)) { $Message += "`n> $TacProcs2" }
            }
        }
    }

    # --- TACTICIAN 20: TACTICAL ADVANTAGE ---
    if ($Player.LearnedSkills -contains "Tactical Advantage" -and $Mob.HP -gt 0) {
        $TacDmg = $Player.Level * 1
        $Mob.HP -= $TacDmg
        $Message += "`n> ♟️ TACTICAL ADVANTAGE! You seamlessly weave in a free attack for $TacDmg damage!"
        $TacElProc = Invoke-ElementProc -Player $Player -Mob $Mob -FinalDmg $TacDmg -IsCrit $false
        if ($TacElProc) { $Message += "`n> $TacElProc" }
        if ($Mob.HP -gt 0) {
            $TacCCProc = Invoke-TacticsProc -Player $Player -Mob $Mob
            if ($TacCCProc) { $Message += "`n> $TacCCProc" }
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
                        if ($ActualHeal -gt 0) { $Message += "`n> Your Legacy $($Player.ActivePet.Name) uses Mend! You recover $ActualHeal HP (Now at $($Player.HP)/$($Player.MaxHP))." } 
                        else { $Message += "`n> Your Legacy $($Player.ActivePet.Name) readies a Mend, but you are already at full health!" }
                    }
                    "Buff" {
                        $Scale = $Player.ActivePet.Level * 1.25
                        $BuffStr = [math]::Round(5 * $Scale); $BuffAC = [math]::Round(2 * $Scale)
                        if ($null -eq $Player.ActiveEffects) { $Player.ActiveEffects = @() }
                        $ExistingAura = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Pet Aura" } | Select-Object -First 1
                        if ($null -ne $ExistingAura) {
                            $ExistingAura.Duration = 2; $ExistingAura.Modifiers.Strength = $BuffStr; $ExistingAura.Modifiers.Armor = $BuffAC
                            $Message += "`n> Your Legacy $($Player.ActivePet.Name) refreshes its battle aura!"
                        } else {
                            $Buff = [PSCustomObject]@{ Name="Pet Aura"; Duration=2; DoT=0; Modifiers=@{Strength=$BuffStr; Armor=$BuffAC} }
                            $Player.ActiveEffects = @($Player.ActiveEffects) + $Buff; $Message += "`n> Your Legacy $($Player.ActivePet.Name) grants a battle aura! +$BuffStr STR, +$BuffAC AC."
                        }
                    }
                    "Damage" {
                        if ($Mob.HP -gt 0) {
                            $ScaleBonus = [math]::Round($Player.ActivePet.Level * 2.5)
                            $Dmg = $Player.ActivePet.Damage + $ScaleBonus + (Get-Random -Min 10 -Max 30)
                            $Mob.HP -= $Dmg; $Message += "`n> Your Legacy $($Player.ActivePet.Name) unleashes Smash for $Dmg damage!"
                        }
                    }
                }
            } else {
                if ($Mob.HP -gt 0) {
                    $PetDmg = $Player.ActivePet.Damage + (Get-Random -Minimum 0 -Maximum 11)
                    $Mob.HP -= $PetDmg; $Message += "`n> Your Legacy $($Player.ActivePet.Name) strikes normally for $PetDmg damage!"
                }
            }
        } else {
            if ($Mob.HP -gt 0) {
                $PetDmg = $Player.ActivePet.Damage + (Get-Random -Minimum 0 -Maximum 11)
                $Mob.HP -= $PetDmg; $Message += "`n> Your $($Player.ActivePet.Name) attacks for $PetDmg damage!"
            }
        }
    }

    # --- UNIFIED DEATH CHECK ---
    if ($Mob.HP -le 0) {
        $Message += "`n> The $($Mob.Name) has been defeated! Gained $($Mob.XP) XP and found $($Mob.Scrap) scrap."
        $Player.XP += $Mob.XP; $Player.Currency += $Mob.Scrap

        # --- BESERKER 10: BLOODTHIRST ---
        if ($Player.LearnedSkills -contains "Bloodthirst") {
            $Heal = [math]::Floor($Player.MaxHP * 0.10)
            $Player.HP = [math]::Min($Player.MaxHP, $Player.HP + $Heal)
            $Message += "`n> 🩸 BLOODTHIRST! The kill fuels you, recovering $Heal HP!"
        }

        if ($null -eq $Player.ActivePet) {
            $HasCurse = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Blood Curse" }
            $HasRot = @($Mob.ActiveEffects) | Where-Object { $_.Name -eq "Zombie Rot" }

            if ($null -ne $HasCurse) {
                $Player.ActivePet = [PSCustomObject]@{ Name="Vampiric $($Mob.Name)"; Level=$Mob.Level; XP=0; MaxHP=($Mob.MaxHP + $Player.PetBonusHP); HP=($Mob.MaxHP + $Player.PetBonusHP); Damage=$Mob.Damage; Armor=$Mob.Armor; IsLegacyPet = $false }
                $Message += "`n> The Blood Curse takes hold... The $($Mob.Name) resurrects as your Vampiric servant!"
            } elseif ($null -ne $HasRot) {
                if (Invoke-InfectionCheck -Infectivity $Player.Infectivity) {
                    $Player.ActivePet = [PSCustomObject]@{ Name="Rotting $($Mob.Name)"; Level=$Mob.Level; XP=0; MaxHP=($Mob.MaxHP + $Player.PetBonusHP); HP=($Mob.MaxHP + $Player.PetBonusHP); Damage=$Mob.Damage; Armor=$Mob.Armor; IsLegacyPet = $false }
                    $Message += "`n> COIN FLIP WON: The Zombie Rot consumes the corpse... The $($Mob.Name) rises as your infected servant!"
                } else {
                    $Message += "`n> COIN FLIP FAILED: The $($Mob.Name)'s corpse rots into useless sludge."
                }
            }
        }

        if ($null -ne $Player.ActivePet -and $Player.ActivePet.Level -lt 100) {
            $Player.ActivePet.XP += $Mob.XP
            $pLvl = $Player.ActivePet.Level; $NextXP = 10000
            if ($pLvl -ge 99) { $NextXP = 1000000 } elseif ($pLvl -ge 61) { $NextXP = 250000 } elseif ($pLvl -ge 51) { $NextXP = 100000 }
            elseif ($pLvl -ge 41) { $NextXP = 50000 } elseif ($pLvl -ge 36) { $NextXP = 25000 } elseif ($pLvl -ge 31) { $NextXP = 17500 }
            elseif ($pLvl -ge 21) { $NextXP = 15000 } elseif ($pLvl -ge 11) { $NextXP = 12500 }

            if ($Player.ActivePet.XP -ge $NextXP) {
                $Player.ActivePet.Level += 1; $Player.ActivePet.XP -= $NextXP
                $Player.ActivePet.MaxHP += 15; $Player.ActivePet.HP = $Player.ActivePet.MaxHP
                $Player.ActivePet.Damage += 3; $Player.ActivePet.Armor += 1
                $Message += "`n> YOUR PET LEVELED UP! The $($Player.ActivePet.Name) is now Level $($Player.ActivePet.Level)!"
            }
        }

        if ($null -ne $Mob.LootTable -and $Mob.LootTable.Count -gt 0) {
            foreach ($Item in $Mob.LootTable) { $Player.Inventory += $Item; $Message += "`n> [LOOT] You picked up: $Item" }
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
            $Message += "`n> LEVEL UP! You are now Level $($Player.Level)! Stats increased, HP/SP restored."
            
            $NewClassSkills = Get-ClassSkills -ClassName $Player.Class -PlayerLevel $Player.Level
            foreach ($sk in $NewClassSkills) { if ($Player.LearnedSkills -notcontains $sk) { $Player.LearnedSkills += $sk } }
        }
    }
    
    return $Message
}