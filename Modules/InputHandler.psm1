# --- Modules\InputHandler.psm1 ---

function Invoke-PlayerCommand {
    param(
        [string]$Command,
        $Player,
        $Mob,
        $NPC,
        $Room,
        $RoomID,
        $WorldMap,
        $LegacyBonuses
    )

    $OutMsg = @()
    $PassTurn = $false
    $IsRunning = $true
    $CleanCommand = $Command.ToLower().Trim()

    if ($null -ne $Mob -and $Mob.HP -gt 0) {
        switch -Regex ($CleanCommand) {
            '^a$|^attack$' { 
                $OutMsg += Invoke-CombatRound -Player $Player -Mob $Mob -Action 'attack' -LegacyBonuses $LegacyBonuses
                $PassTurn = $true 
            }
            '^r$|^run$' { 
                $OutMsg += Invoke-CombatRound -Player $Player -Mob $Mob -Action 'run' -LegacyBonuses $LegacyBonuses
                if ($Mob.HP -le 0 -and $null -ne $Mob.IsPlayerCorpse -and $Mob.IsPlayerCorpse) {
                    $LegacyBonuses.PlayerCorpse = $null
                    $OutMsg += "`n> You fled! The zombified husk of your past self wanders off into the darkness, lost forever."
                }
                $PassTurn = $true 
            }
            '^(give up|suicide)$' { 
                $Player.HP = 0; $OutMsg += "You drop your weapon and surrender to the horde. The darkness takes you..."; $PassTurn = $true
            }
            '^skills$' {
                $SkillDBPath = Join-Path $PSScriptRoot "..\Data\skills.json"
                $SkillDB = ConvertFrom-Json (Get-Content $SkillDBPath -Raw)
                $SkillDisplay = @("=== YOUR LEARNED SKILLS ===")
                foreach ($LS in $Player.LearnedSkills) {
                    $SData = $SkillDB.$LS
                    if ($null -ne $SData) { $SkillDisplay += " - $($LS.PadRight(15)) | Cost: $($SData.Cost.PadRight(6)) | $($SData.Description)" } 
                    else { $SkillDisplay += " - $LS" }
                }
                $SkillDisplay += "--------------------------------------------------`n Type 'use [skillname]' in combat to activate."
                $OutMsg += $SkillDisplay -join "`n> "
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
                            $OutMsg += "You applied the [$RealItem] and recovered $($ItemData.Value) HP."
                            $Bleed = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Bleeding" }
                            if ($null -ne $Bleed) {
                                $Player.ActiveEffects = @($Player.ActiveEffects | Where-Object { $_.Name -ne "Bleeding" })
                                $OutMsg += "The tight wrapping completely stopped your bleeding!"
                            }
                            $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList)
                            $ItemUsed = $true
                        } elseif ($RealItem -eq "Energy Drink") {
                            if ($Player.SP -ge $Player.MaxSP -and ($null -eq (@($Player.ActiveEffects) | Where-Object { $_.Name -eq "Zombie Rot" -or $_.Name -eq "Infected Wound" }))) { 
                                $OutMsg += "You feel jittery, but you are already at maximum stamina and have no infections to cure." 
                            } else {
                                $Player.SP = [math]::Min($Player.MaxSP, ($Player.SP + $ItemData.Value))
                                $OutMsg += "You chugged the [$RealItem] and recovered $($ItemData.Value) SP."
                                $Rot = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Zombie Rot" -or $_.Name -eq "Infected Wound" }
                                if ($null -ne $Rot) {
                                    $Player.ActiveEffects = @($Player.ActiveEffects | Where-Object { $_.Name -ne "Zombie Rot" -and $_.Name -ne "Infected Wound" })
                                    $OutMsg += "The intense chemical rush purged the infection from your veins!"
                                }
                                $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList)
                                $ItemUsed = $true
                            }
                        } elseif ($RealItem -eq "Pistol Ammo") {
                            if ($Player.Class -ne "Immune Human") { $OutMsg += "You have no idea how to use this." }
                            elseif ($Player.Ammo -ge $Player.MaxAmmo) { $OutMsg += "Your magazine is already full!" }
                            else {
                                $Player.Ammo = [math]::Min($Player.MaxAmmo, ($Player.Ammo + $ItemData.Value))
                                $OutMsg += "You loaded $($ItemData.Value) rounds into your Glock. (Ammo: $($Player.Ammo)/$($Player.MaxAmmo))"
                                $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList)
                                $ItemUsed = $true
                            }
                        }
                        
                        if ($ItemUsed) {
                            $MobTurn = Invoke-MobTurn -Player $Player -Mob $Mob
                            if (-not [string]::IsNullOrWhiteSpace($MobTurn)) { $OutMsg += $MobTurn -replace "^`n>\s*", "" }
                            $PassTurn = $true
                        }
                    } else { $OutMsg += "You cannot use the [$RealItem] right now." }
                } else {
                    $SkillRes = Invoke-SkillRound -Player $Player -Mob $Mob -SkillName $TargetName -LegacyBonuses $LegacyBonuses
                    $OutMsg += $SkillRes
                    if ($SkillRes -notmatch "You do not know|Needs|already transformed|out of ammo|cannot use|You are too Exhausted") {
                        $PassTurn = $true
                        if ($null -ne $Mob -and $Mob.HP -gt 0) {
                            $MobTurn = Invoke-MobTurn -Player $Player -Mob $Mob
                            if (-not [string]::IsNullOrWhiteSpace($MobTurn)) { $OutMsg += $MobTurn -replace "^`n>\s*", "" }
                        }
                    }
                }
            }
            '^release(\s+pet)?$' {
                if ($null -ne $Player.ActivePet) {
                    $HealAmount = $Player.ActivePet.HP
                    $Player.HP = [math]::Min($Player.MaxHP, ($Player.HP + $HealAmount))
                    $OutMsg += "You drain the energy from the $($Player.ActivePet.Name), adding it to your own. You were healed for $HealAmount HP."
                    $Player.ActivePet = $null
                    $MobTurn = Invoke-MobTurn -Player $Player -Mob $Mob
                    if (-not [string]::IsNullOrWhiteSpace($MobTurn)) { $OutMsg += $MobTurn -replace "^`n>\s*", "" }
                    $PassTurn = $true
                } else { $OutMsg += "You do not have an active pet to release!" }
            }
            '^reload$' {
                if ($Player.Class -ne "Immune Human") { $OutMsg += "You don't have a gun to reload." }
                elseif ($Player.Ammo -ge $Player.MaxAmmo) { $OutMsg += "Your magazine is already full!" }
                else {
                    $AmmoItem = $Player.Inventory | Where-Object { $_ -ieq "Pistol Ammo" } | Select-Object -First 1
                    if ($null -ne $AmmoItem) {
                        $ItemData = Get-ItemStats -ItemName $AmmoItem
                        $Player.Ammo = [math]::Min($Player.MaxAmmo, ($Player.Ammo + $ItemData.Value))
                        $OutMsg += "You slammed a new magazine into your Glock. (Ammo: $($Player.Ammo)/$($Player.MaxAmmo))"
                        $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($AmmoItem); $Player.Inventory = @($InvList)
                        $MobTurn = Invoke-MobTurn -Player $Player -Mob $Mob
                        if (-not [string]::IsNullOrWhiteSpace($MobTurn)) { $OutMsg += $MobTurn -replace "^`n>\s*", "" }
                        $PassTurn = $true
                    } else { $OutMsg += "You reach into your pockets... but you are completely out of Pistol Ammo!" }
                }
            }
            '^stats$' { $OutMsg += "COMBAT STATS | STR: $($Player.Strength) | DEX: $($Player.Dexterity) | AC: $($Player.Armor) | WPN: $($Player.EquippedWeapon) ($($Player.Damage) DMG)" }
            '^(char|character|sheet)$' {
                $ResourceLine = if ($Player.Class -eq "Vampire") { " HP: $("$($Player.HP)/$($Player.MaxHP)".PadRight(15)) BP: $($Player.BP)/$($Player.MaxBP)" } elseif ($Player.Class -eq "Immune Human") { " HP: $("$($Player.HP)/$($Player.MaxHP)".PadRight(15)) SP: $("$($Player.SP)/$($Player.MaxSP)".PadRight(12)) AMMO: $($Player.Ammo)/$($Player.MaxAmmo)" } else { " HP: $("$($Player.HP)/$($Player.MaxHP)".PadRight(15)) SP: $($Player.SP)/$($Player.MaxSP)" }
                $InfLine = " $("Resistance:".PadRight(14)) $($Player.Infectivity)"
                if ($Player.Class -ne "Immune Human") { $InfLine = " $("Infectivity:".PadRight(14)) $($Player.Infectivity)" }

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
                    $InfLine, "--------------------------------------------------", " [ EQUIPPED GEAR ]"
                )
                if ($Player.LearnedSkills -contains "Two Fisting") { $Sheet += " Main:      $("$($Player.EquippedWeapon)".PadRight(14)) Offhand:   $($Player.EquippedOffhand)" } 
                else { $Sheet += " Weapon:    $($Player.EquippedWeapon)" }
                
                $Sheet += " Chest:     $("$($Player.EquippedArmor)".PadRight(14)) Shoulders: $($Player.EquippedShoulders)"
                $Sheet += " Boots:     $("$($Player.EquippedBoots)".PadRight(14)) Trinket:   $($Player.EquippedTrinket)"
                $Sheet += " Necklace:  $($Player.EquippedNecklace)"
                
                if ($null -ne $Player.ActivePet) {
                    $pLvl = $Player.ActivePet.Level; $NextXP = 10000
                    if ($pLvl -ge 100) { $NextXP = "MAX" } elseif ($pLvl -ge 99) { $NextXP = 1000000 } elseif ($pLvl -ge 61) { $NextXP = 250000 } 
                    elseif ($pLvl -ge 51) { $NextXP = 100000 } elseif ($pLvl -ge 41) { $NextXP = 50000 } elseif ($pLvl -ge 36) { $NextXP = 25000 } 
                    elseif ($pLvl -ge 31) { $NextXP = 17500 } elseif ($pLvl -ge 21) { $NextXP = 15000 } elseif ($pLvl -ge 11) { $NextXP = 12500 }
                    $Sheet += "--------------------------------------------------"; $Sheet += " [ ACTIVE PET COMPANION ]"
                    $Sheet += " Name:   $($Player.ActivePet.Name)"; $Sheet += " Level:  $("$($Player.ActivePet.Level)".PadRight(14)) XP: $($Player.ActivePet.XP) / $NextXP"
                    $Sheet += " Damage: $("$($Player.ActivePet.Damage)".PadRight(14)) Armor: $($Player.ActivePet.Armor)"
                }
                $Sheet += "=================================================="
                $OutMsg += $Sheet -join "`n> "
            }
            default { $OutMsg += "You are in combat! Valid commands: 'attack', 'run', 'skills', 'use [skill/item]', 'release pet', 'reload', 'stats', 'char'" }
        }
    }
    elseif ($null -ne $NPC) {
        if ($NPC -eq "Wandering Merchant") {
            $ShopItems = Get-ShopInventory
            $BuildMenu = {
                param($ActionMsg)
                $Menu = @("", $ActionMsg, "", "=== WANDERING MERCHANT ===", " Wallet: $($Player.Currency) scrap coins", "--------------------------------------------------", " [ FOR SALE ]")
                foreach ($Item in $ShopItems.Keys) { $Menu += " $("[$($ShopItems[$Item]) scrap]".PadRight(15)) $Item" }
                $Menu += "--------------------------------------------------"; $Menu += " [ YOUR SELLABLE ITEMS ]"
                $HasSellables = $false; $GroupedInv = @{}
                foreach ($Item in $Player.Inventory) { if ($GroupedInv.ContainsKey($Item)) { $GroupedInv[$Item] += 1 } else { $GroupedInv[$Item] = 1 } }
                foreach ($InvItem in $GroupedInv.Keys) {
                    $Stats = Get-ItemStats -ItemName $InvItem
                    if ($null -ne $Stats -and $Stats.BasePrice -gt 0) {
                        $SellVal = [math]::Floor($Stats.BasePrice * $Stats.SellMultiplier)
                        $Qty = $GroupedInv[$InvItem]; $QtyStr = if ($Qty -gt 1) { " (x$Qty)" } else { "" }
                        $Menu += " $("[$SellVal scrap]".PadRight(15)) $InvItem$QtyStr"; $HasSellables = $true
                    }
                }
                if (-not $HasSellables) { $Menu += "  (You have nothing of value to sell)" }
                $Menu += "--------------------------------------------------"; $Menu += " Type 'buy [item]', 'sell [item]', 'sell all [item]', or 'leave'."
                return ($Menu -join "`n> ")
            }

            switch -Regex ($CleanCommand) {
                '^buy\s+(.+)' {
                    $TargetItem = $Matches[1].Trim()
                    $RealItem = $ShopItems.Keys | Where-Object { $_ -ieq $TargetItem } | Select-Object -First 1
                    if ($null -ne $RealItem) {
                        $Cost = $ShopItems[$RealItem]
                        if ($Player.Currency -ge $Cost) { $Player.Currency -= $Cost; $Player.Inventory += $RealItem; $OutMsg += &$BuildMenu "Transaction complete! You bought the [$RealItem] for $Cost scrap." } 
                        else { $OutMsg += &$BuildMenu "The merchant sneers. You need $Cost scrap, but only have $($Player.Currency)." }
                    } else { $OutMsg += &$BuildMenu "The merchant doesn't sell a '$TargetItem'." }
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
                                $Count = @($Player.Inventory | Where-Object { $_ -eq $RealItem }).Count; $TotalVal = $SellVal * $Count
                                $Player.Currency += $TotalVal; $Player.Inventory = @($Player.Inventory | Where-Object { $_ -ne $RealItem })
                                $OutMsg += &$BuildMenu "Transaction complete! You sold ALL ($Count) [$RealItem] for $TotalVal scrap."
                            } else {
                                $Player.Currency += $SellVal
                                $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList)
                                $OutMsg += &$BuildMenu "Transaction complete! You sold ONE [$RealItem] for $SellVal scrap."
                            }
                        } else { $OutMsg += &$BuildMenu "The merchant refuses to buy the [$RealItem]." }
                    } else { $OutMsg += &$BuildMenu "You don't have a '$TargetItem' to sell." }
                }
                '^(leave|exit|quit|bye)$' { $NPC = $null; $OutMsg += "You nod and step away from the merchant." }
                default { $OutMsg += "You are busy talking to the $NPC. Valid commands: 'buy [item]', 'sell [item]', 'sell all [item]', 'leave'" }
            }
        }
        elseif ($NPC -eq "Old Master") {
            $SkillDBPath = Join-Path $PSScriptRoot "..\Data\skills.json"
            $SkillDB = ConvertFrom-Json (Get-Content $SkillDBPath -Raw)
            
            $BuildMenu = {
                param($ActionMsg)
                $Menu = @("", $ActionMsg, "", "=== THE OLD MASTER'S DOJO ===", " Wallet: $($Player.Currency) scrap coins", "--------------------------------------------------", " [ AVAILABLE SKILLS TO LEARN ]")
                $HasSkills = $false
                foreach ($S in $SkillDB.psobject.properties) {
                    $SkillName = $S.Name; $SData = $S.Value
                    if (($SData.Class -eq "Universal" -or $SData.Class -eq $Player.Class) -and $SData.Price -gt 0) {
                        if ($Player.Level -ge $SData.MinLevel) {
                            $AlreadyLearned = $false
                            foreach ($ls in $Player.LearnedSkills) { if ($ls -ieq $SkillName) { $AlreadyLearned = $true; break } }
                            if (-not $AlreadyLearned) { $Menu += " $("[$($SData.Price) scrap]".PadRight(15)) $SkillName ($($SData.Cost)) - $($SData.Description)"; $HasSkills = $true }
                        }
                    }
                }
                if (-not $HasSkills) { $Menu += "  (You have learned everything I can teach you for now)" }
                $Menu += "--------------------------------------------------"; $Menu += " Type 'learn [skill]' or 'leave'."
                return ($Menu -join "`n> ")
            }

            switch -Regex ($CleanCommand) {
                '^learn\s+(.+)' {
                    $TargetSkill = $Matches[1].Trim(); $RealSkill = $null
                    foreach ($S in $SkillDB.psobject.properties) { if ($S.Name -ieq $TargetSkill) { $RealSkill = $S.Name; break } }
                    if ($null -ne $RealSkill) {
                        $SData = $SkillDB.$RealSkill
                        if ($SData.Class -ne "Universal" -and $SData.Class -ne $Player.Class) { $OutMsg += &$BuildMenu "The Old Master shakes his head. `"That technique is not suited for a $($Player.Class).`"" } 
                        elseif ($Player.Level -lt $SData.MinLevel) { $OutMsg += &$BuildMenu "The Old Master sighs. `"You lack the experience for this technique. Return at Level $($SData.MinLevel).`"" } 
                        elseif ($Player.LearnedSkills -contains $RealSkill) { $OutMsg += &$BuildMenu "You already know how to perform $RealSkill!" } 
                        elseif ($Player.Currency -lt $SData.Price) { $OutMsg += &$BuildMenu "The Old Master sighs. `"Knowledge is not free. You need $($SData.Price) scrap.`"" } 
                        else { $Player.Currency -= $SData.Price; $Player.LearnedSkills += $RealSkill; $OutMsg += &$BuildMenu "The Old Master guides you through the forms... You have learned [$RealSkill]!" }
                    } else { $OutMsg += &$BuildMenu "The Old Master looks confused. `"I do not know of that technique.`"" }
                }
                '^(leave|exit|quit|bye)$' { $NPC = $null; $OutMsg += "You bow to the Old Master and step away." }
                default { $OutMsg += "You are busy talking to the $NPC. Valid commands: 'learn [skill]', 'leave'" }
            }
        }
    }
    else {
        switch -Regex ($CleanCommand) {
            '^quit$' { Save-GameState -Player $Player -WorldMap $WorldMap -LegacyBonuses $LegacyBonuses; $IsRunning = $false; Write-Host "`nGame saved. Exiting the nightmare..." -ForegroundColor DarkGray }
            '^save$' { Save-GameState -Player $Player -WorldMap $WorldMap -LegacyBonuses $LegacyBonuses; $OutMsg += "Progress saved. The nightmare continues..." }
            '^look$' {
                $Observations = @()
                if ($RoomID -eq "1") { $Observations += "A heavy iron storage box sits in the corner of the cell." }
                if ($null -ne $LegacyBonuses.PlayerCorpse -and $LegacyBonuses.PlayerCorpse.RoomID -eq $RoomID) { $Observations += "`n> ⚠️ The undead husk of your past life, $($LegacyBonuses.PlayerCorpse.Mob.Name), is shambling around here!" }
                if ($null -ne $Room.NPC) { $Observations += "A $($Room.NPC) is sitting here." }
                if ($null -ne $Room.Interactables -and $Room.Interactables.Count -gt 0) {
                    foreach ($ObjName in $Room.Interactables.Keys) {
                        if ($Room.Interactables[$ObjName].State -eq "open") { $Observations += "The $ObjName is open, revealing a hidden path." } else { $Observations += "You notice a $ObjName that looks interactable." }
                    }
                }
                if ($Observations.Count -gt 0) { $OutMsg += $Observations -join " " } else { $OutMsg += "You look around carefully, but nothing jumps out at you." }
            }
            '^say\s+(.+)' {
                $SpokenText = $Matches[1].Trim()
                if ($RoomID -eq "96" -and $SpokenText -match '(?i)i devote myself to the darkness') {
                    if ($LegacyBonuses.UnlockedClasses -notcontains "Vampire") {
                        $LegacyBonuses.UnlockedClasses += "Vampire"; Save-GameState -Player $Player -WorldMap $WorldMap -LegacyBonuses $LegacyBonuses
                        $OutMsg += "You speak the words. The darkness coils around you, sinking into your veins... `n> [ LEGACY UNLOCKED: The Vampire Class is now available on your next life! ]"
                    } else { $OutMsg += "The darkness whispers back: 'You are already mine...'" }
                } else { $OutMsg += "You say: `"$SpokenText`"" }
            }
            '^talk(\s+(.+))?$' {
                if ($null -ne $Room.NPC) {
                    $NPC = $Room.NPC 
                    if ($NPC -eq "Wandering Merchant") {
                        $ShopItems = Get-ShopInventory; $Menu = @("The $NPC gestures to their wares.", "=== WANDERING MERCHANT ===", " Wallet: $($Player.Currency) scrap coins", "--------------------------------------------------", " [ FOR SALE ]")
                        foreach ($Item in $ShopItems.Keys) { $Menu += " $("[$($ShopItems[$Item]) scrap]".PadRight(15)) $Item" }
                        $Menu += "--------------------------------------------------"; $Menu += " [ YOUR SELLABLE ITEMS ]"
                        $HasSellables = $false; $GroupedInv = @{}
                        foreach ($Item in $Player.Inventory) { if ($GroupedInv.ContainsKey($Item)) { $GroupedInv[$Item] += 1 } else { $GroupedInv[$Item] = 1 } }
                        foreach ($InvItem in $GroupedInv.Keys) {
                            $Stats = Get-ItemStats -ItemName $InvItem
                            if ($null -ne $Stats -and $Stats.BasePrice -gt 0) {
                                $SellVal = [math]::Floor($Stats.BasePrice * $Stats.SellMultiplier)
                                $Qty = $GroupedInv[$InvItem]; $QtyStr = if ($Qty -gt 1) { " (x$Qty)" } else { "" }
                                $Menu += " $("[$SellVal scrap]".PadRight(15)) $InvItem$QtyStr"; $HasSellables = $true
                            }
                        }
                        if (-not $HasSellables) { $Menu += "  (You have nothing of value to sell)" }
                        $Menu += "--------------------------------------------------"; $Menu += " Type 'buy [item]', 'sell [item]', 'sell all [item]', or 'leave'."
                        $OutMsg += $Menu -join "`n> "
                    } elseif ($NPC -eq "Old Master") {
                        $SkillDBPath = Join-Path $PSScriptRoot "..\Data\skills.json"
                        $SkillDB = ConvertFrom-Json (Get-Content $SkillDBPath -Raw)
                        $Menu = @("The $NPC nods slowly. `"You seek to master yourself.`"", "=== THE OLD MASTER'S DOJO ===", " Wallet: $($Player.Currency) scrap coins", "--------------------------------------------------", " [ AVAILABLE SKILLS TO LEARN ]")
                        $HasSkills = $false
                        foreach ($S in $SkillDB.psobject.properties) {
                            $SkillName = $S.Name; $SData = $S.Value
                            if (($SData.Class -eq "Universal" -or $SData.Class -eq $Player.Class) -and $SData.Price -gt 0) {
                                if ($Player.Level -ge $SData.MinLevel) {
                                    $AlreadyLearned = $false
                                    foreach ($ls in $Player.LearnedSkills) { if ($ls -ieq $SkillName) { $AlreadyLearned = $true; break } }
                                    if (-not $AlreadyLearned) { $Menu += " $("[$($SData.Price) scrap]".PadRight(15)) $SkillName ($($SData.Cost)) - $($SData.Description)"; $HasSkills = $true }
                                }
                            }
                        }
                        if (-not $HasSkills) { $Menu += "  (You have learned everything I can teach you for now)" }
                        $Menu += "--------------------------------------------------"; $Menu += " Type 'learn [skill]' or 'leave'."
                        $OutMsg += $Menu -join "`n> "
                    }
                } else { $OutMsg += "You mumble to yourself. Nobody answers." }
            }
            '^search$' {
                if ($null -ne $LegacyBonuses.PlayerCorpse -and $LegacyBonuses.PlayerCorpse.RoomID -eq $RoomID) {
                    $Mob = $LegacyBonuses.PlayerCorpse.Mob
                    $OutMsg += "You lock eyes with your former self... The $($Mob.Name) lunges at you!"
                } else {
                    $SpawnCap = $Player.Level + 2; $FloorMin = 1
                    if ($null -ne $Room.MinLevel) { $FloorMin = $Room.MinLevel; if ($SpawnCap -lt $FloorMin) { $SpawnCap = $FloorMin + 2 } }
                    $Mob = Get-RandomMob -MaxLevel $SpawnCap -MinLevel $FloorMin
                    if ($FloorMin -ge 20) { $OutMsg += "You disturb the toxic debris... A devastating $($Mob.Name) (Lv. $($Mob.Level)) emerges!" } 
                    else { $OutMsg += "You rummaged through the debris and found a $($Mob.Name) (Lv. $($Mob.Level))!" }
                }
                
                if ($Player.LearnedSkills -contains "Stealth" -and -not $Player.IsStealthed) {
                    $Player.IsStealthed = $true; $OutMsg += "`n> 🌑 You naturally fade back into the shadows."
                }
                $PassTurn = $true
            }
            '^use foresight$' {
                if ($Player.LearnedSkills -notcontains "Foresight") { $OutMsg += "You don't know the Foresight technique." }
                elseif ($Player.SP -lt 15) { $OutMsg += "Needs 15 SP to cast Foresight." }
                else {
                    $Player.SP -= 15
                    $SpawnCap = $Player.Level + 2; $FloorMin = 1
                    if ($null -ne $Room.MinLevel) { $FloorMin = $Room.MinLevel; if ($SpawnCap -lt $FloorMin) { $SpawnCap = $FloorMin + 2 } }
                    $ForesightMob = Get-RandomMob -MaxLevel $SpawnCap -MinLevel $FloorMin
                    $LegacyBonuses.ForesightMob = $ForesightMob
                    $OutMsg += "👁️ FORESIGHT: You peer into the future and see a $($ForesightMob.Name) (Lv. $($ForesightMob.Level)) waiting. Type 'engage' to ambush it, or 'ignore' to walk away."
                }
            }
            '^engage$' {
                if ($null -ne $LegacyBonuses.ForesightMob) {
                    $Mob = $LegacyBonuses.ForesightMob; $LegacyBonuses.ForesightMob = $null
                    $AmbushDmg = $Player.Damage; $Mob.HP -= $AmbushDmg
                    $OutMsg += "You execute your ambush perfectly!`n> 👁️ FORESIGHT STRIKE! You deal $AmbushDmg damage before the fight even begins!"
                } else { $OutMsg += "There is nothing to engage." }
            }
            '^ignore$' {
                if ($null -ne $LegacyBonuses.ForesightMob) {
                    $LegacyBonuses.ForesightMob = $null; $OutMsg += "You carefully avoid the encounter and choose a different path."
                } else { $OutMsg += "There is nothing to ignore." }
            }
            '^combine\s+(.+)$' {
                if ($Player.LearnedSkills -notcontains "Mad Inventor") { $OutMsg += "You lack the Mad Inventor skills required to combine items." } else {
                    $TargetName = $Matches[1].Trim()
                    $RealItem = $Player.Inventory | Where-Object { $_ -ieq $TargetName } | Select-Object -First 1
                    if ($null -eq $RealItem) { $OutMsg += "You don't have a '$TargetName' to combine." } else {
                        $ItemData = Get-ItemStats -ItemName $RealItem
                        $LegendaryElements = @("Bonewerk", "Explosive", "Energetic", "Putrid")
                        $CommonElements = @("Radioactive", "Fire", "Cryogenis", "Bloodwerk")
                        $PossibleStats = @("Strength", "Dexterity", "Constitution", "Tactics", "Int", "Luck")
                        
                        if ($null -ne $ItemData -and $ItemData.Type -eq "Necklace") {
                            if ($ItemData.Element -in $LegendaryElements) {
                                $CurrencyNeeded = 1000; $CurrencyProp = ""
                                switch ($ItemData.Element) { "Bonewerk" { $CurrencyProp = "Bonechips" } "Explosive" { $CurrencyProp = "Gunpowder" } "Energetic" { $CurrencyProp = "EnergyOrbs" } "Putrid" { $CurrencyProp = "ToxicGarnets" } }
                                $CurrentLvl = 0; $BaseName = $RealItem
                                if ($RealItem -match '^(.*?)\s+\+(\d+)(?:\s+\[(.*?)\])?$') { $BaseName = $Matches[1]; $CurrentLvl = [int]$Matches[2] }
                                
                                if ($CurrentLvl -ge 20) { $OutMsg += "That legendary artifact is already at maximum power (+20)!" }
                                elseif ($Player.$CurrencyProp -lt $CurrencyNeeded) { $OutMsg += "You need $CurrencyNeeded $CurrencyProp to upgrade this!" }
                                else {
                                    $Player.$CurrencyProp -= $CurrencyNeeded
                                    if ((Get-Random -Min 1 -Max 101) -le 50) { $OutMsg += "💥 The experiment FAILED! The volatile reaction consumed your $CurrencyProp, but the artifact survived." } else {
                                        $NewLvl = $CurrentLvl + 1; $NewName = "$BaseName +$NewLvl"
                                        $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList); $Player.Inventory += $NewName
                                        $OutMsg += "🧪 MAD INVENTOR SUCCESS! The artifact absorbs the energy and becomes [$NewName]!"
                                    }
                                }
                            } elseif ($ItemData.Element -in $CommonElements) {
                                $Count = @($Player.Inventory | Where-Object { $_ -eq $RealItem }).Count
                                if ($Count -lt 3) { $OutMsg += "You need 3x [$RealItem] to combine them!" } else {
                                    for ($i=0; $i -lt 3; $i++) { $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList) }
                                    if ((Get-Random -Min 1 -Max 101) -le 50) { $OutMsg += "💥 The experiment FAILED! The necklaces shattered into useless dust." } else {
                                        $LegRewards = @("Bonewerk Amulet", "Explosive Collar", "Energetic Locket", "Putrid Charm"); $Reward = $LegRewards | Get-Random; $Player.Inventory += $Reward
                                        $OutMsg += "🧪 MAD INVENTOR SUCCESS! The common elements fused into a legendary [$Reward]!"
                                    }
                                }
                            }
                        } elseif ($ItemData.Type -in @("Weapon", "Armor", "Shoulders", "Boots", "Trinket")) {
                            $Count = @($Player.Inventory | Where-Object { $_ -eq $RealItem }).Count
                            if ($Count -lt 3) { $OutMsg += "You need 3x identical [$RealItem] to combine them!" } else {
                                $CurrentLvl = 0; $BaseName = $RealItem
                                if ($RealItem -match '^(.*?)\s+\+(\d+)(?:\s+\[(.*?)\])?$') { $BaseName = $Matches[1]; $CurrentLvl = [int]$Matches[2] }
                                if ($CurrentLvl -ge 10) { $OutMsg += "That equipment is already at maximum upgrade (+10)!" } else {
                                    for ($i=0; $i -lt 3; $i++) { $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList) }
                                    if ((Get-Random -Min 1 -Max 101) -le 50) { $OutMsg += "💥 The experiment FAILED! The items were destroyed in the process." } else {
                                        $NewLvl = $CurrentLvl + 1; $NewName = "$BaseName +$NewLvl"
                                        if ((Get-Random -Min 1 -Max 101) -le 50) { $RStat = $PossibleStats | Get-Random; $NewName = "$NewName [$RStat]" }
                                        $Player.Inventory += $NewName; $OutMsg += "🧪 MAD INVENTOR SUCCESS! The items successfully fused into [$NewName]!"
                                    }
                                }
                            }
                        } else { $OutMsg += "You can't combine that type of item." }
                    }
                    $PassTurn = $true
                }
            }
            '^cheat legacy$' { $Player.Level += 25; $Player.Currency += 1000; $OutMsg += "CHEAT ACTIVATED: You instantly surged forward 25 levels!" }
            '^cheat pet$' {
                if ($null -eq $Player.ActivePet) { $OutMsg += "You don't have a pet! Go infect something first." } else {
                    $LevelsGained = 100 - $Player.ActivePet.Level
                    if ($LevelsGained -gt 0) {
                        $Player.ActivePet.Level = 100; $Player.ActivePet.MaxHP += ($LevelsGained * 15); $Player.ActivePet.HP = $Player.ActivePet.MaxHP
                        $Player.ActivePet.Damage += ($LevelsGained * 3); $Player.ActivePet.Armor += ($LevelsGained * 1); $OutMsg += "CHEAT ACTIVATED: Your $($Player.ActivePet.Name) violently mutated to Level 100!"
                    } else { $OutMsg += "Your pet is already at maximum level!" }
                }
            }
            '^cheat element$' { $Player.Bonechips += 1000; $Player.Gunpowder += 1000; $Player.EnergyOrbs += 1000; $Player.ToxicGarnets += 1000; $OutMsg += "CHEAT ACTIVATED: You injected 1000 of every element into your veins!" }
            '^(give up|suicide)$' { $Player.HP = 0; $OutMsg += "You can't take the nightmare anymore. You give up the will to live..."; $PassTurn = $true }
            '^skills$' {
                $SkillDBPath = Join-Path $PSScriptRoot "..\Data\skills.json"
                $SkillDB = ConvertFrom-Json (Get-Content $SkillDBPath -Raw)
                $SkillDisplay = @("=== YOUR LEARNED SKILLS ===")
                foreach ($LS in $Player.LearnedSkills) {
                    $SData = $SkillDB.$LS
                    if ($null -ne $SData) { $SkillDisplay += " - $($LS.PadRight(15)) | Cost: $($SData.Cost.PadRight(6)) | $($SData.Description)" } else { $SkillDisplay += " - $LS" }
                }
                $SkillDisplay += "--------------------------------------------------`n Type 'use [skillname]' in combat to activate."
                $OutMsg += $SkillDisplay -join "`n> "
            }
            '^stats$' { $OutMsg += "COMBAT STATS | STR: $($Player.Strength) | DEX: $($Player.Dexterity) | AC: $($Player.Armor) | WPN: $($Player.EquippedWeapon) ($($Player.Damage) DMG)" }
            '^(inv|inventory|i)$' {
                $InvDisplay = @("=== INVENTORY ===")
                $InvDisplay += " Elements: $($Player.Bonechips) Bonechips | $($Player.Gunpowder) Gunpowder | $($Player.EnergyOrbs) Orbs | $($Player.ToxicGarnets) Garnets"
                $InvDisplay += " Currency: $($Player.Currency) scrap coins`n--------------------------------------------------"
                if ($Player.Inventory.Count -gt 0) { 
                    $Grouped = @{}
                    foreach ($Item in $Player.Inventory) { if ($Grouped.ContainsKey($Item)) { $Grouped[$Item] += 1 } else { $Grouped[$Item] = 1 } }
                    foreach ($Key in $Grouped.Keys) { if ($Grouped[$Key] -gt 1) { $InvDisplay += " - $Key (x$($Grouped[$Key]))" } else { $InvDisplay += " - $Key" } }
                } else { $InvDisplay += " Your pockets are empty." }
                $OutMsg += $InvDisplay -join "`n> "
            }
            '^(char|character|sheet)$' {
                $ResourceLine = if ($Player.Class -eq "Vampire") { " HP: $("$($Player.HP)/$($Player.MaxHP)".PadRight(15)) BP: $($Player.BP)/$($Player.MaxBP)" } elseif ($Player.Class -eq "Immune Human") { " HP: $("$($Player.HP)/$($Player.MaxHP)".PadRight(15)) SP: $("$($Player.SP)/$($Player.MaxSP)".PadRight(12)) AMMO: $($Player.Ammo)/$($Player.MaxAmmo)" } else { " HP: $("$($Player.HP)/$($Player.MaxHP)".PadRight(15)) SP: $($Player.SP)/$($Player.MaxSP)" }
                $InfLine = " $("Resistance:".PadRight(14)) $($Player.Infectivity)"
                if ($Player.Class -ne "Immune Human") { $InfLine = " $("Infectivity:".PadRight(14)) $($Player.Infectivity)" }

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
                    $InfLine, "--------------------------------------------------", " [ EQUIPPED GEAR ]"
                )
                if ($Player.LearnedSkills -contains "Two Fisting") { $Sheet += " Main:      $("$($Player.EquippedWeapon)".PadRight(14)) Offhand:   $($Player.EquippedOffhand)" } else { $Sheet += " Weapon:    $($Player.EquippedWeapon)" }
                $Sheet += " Chest:     $("$($Player.EquippedArmor)".PadRight(14)) Shoulders: $($Player.EquippedShoulders)"
                $Sheet += " Boots:     $("$($Player.EquippedBoots)".PadRight(14)) Trinket:   $($Player.EquippedTrinket)"
                $Sheet += " Necklace:  $($Player.EquippedNecklace)"
                
                if ($null -ne $Player.ActivePet) {
                    $pLvl = $Player.ActivePet.Level; $NextXP = 10000
                    if ($pLvl -ge 100) { $NextXP = "MAX" } elseif ($pLvl -ge 99) { $NextXP = 1000000 } elseif ($pLvl -ge 61) { $NextXP = 250000 } elseif ($pLvl -ge 51) { $NextXP = 100000 } elseif ($pLvl -ge 41) { $NextXP = 50000 } elseif ($pLvl -ge 36) { $NextXP = 25000 } elseif ($pLvl -ge 31) { $NextXP = 17500 } elseif ($pLvl -ge 21) { $NextXP = 15000 } elseif ($pLvl -ge 11) { $NextXP = 12500 }
                    $Sheet += "--------------------------------------------------"; $Sheet += " [ ACTIVE PET COMPANION ]"
                    $Sheet += " Name:   $($Player.ActivePet.Name)"; $Sheet += " Level:  $("$($Player.ActivePet.Level)".PadRight(14)) XP: $($Player.ActivePet.XP) / $NextXP"
                    $Sheet += " Damage: $("$($Player.ActivePet.Damage)".PadRight(14)) Armor: $($Player.ActivePet.Armor)"
                }
                $Sheet += "=================================================="
                $OutMsg += $Sheet -join "`n> "
            }
            '^equip offhand\s+(.+)' {
                if ($Player.LearnedSkills -notcontains "Two Fisting") { $OutMsg += "You do not know the Two Fisting technique to equip an offhand weapon!" } else {
                    $TargetItem = $Matches[1].Trim()
                    $RealItem = $Player.Inventory | Where-Object { $_ -ieq $TargetItem } | Select-Object -First 1
                    if ($null -ne $RealItem) {
                        $ItemData = Get-ItemStats -ItemName $RealItem
                        if ($null -ne $ItemData -and $ItemData.Type -eq "Weapon") {
                            if ($Player.EquippedOffhand -ne "None") { $Player.Inventory += $Player.EquippedOffhand }
                            $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList)
                            $Player.EquippedOffhand = $RealItem; $OutMsg += "You equipped the [$RealItem] in your offhand."; $PassTurn = $true
                        } else { $OutMsg += "You can only equip weapons in your offhand." }
                    } else { $OutMsg += "You don't have a '$TargetItem' in your inventory." }
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
                        $OutMsg += "You equipped the [$RealItem]. Your base damage is now $($Player.Damage)."; $PassTurn = $true
                    } elseif ($null -ne $ItemData -and $ItemData.Type -in @("Armor", "Shoulders", "Boots", "Trinket", "Necklace")) {
                        $SlotName = "Equipped" + $ItemData.Type; if ($ItemData.Type -eq "Armor") { $SlotName = "EquippedArmor" }
                        $CurrentEquipped = $Player.$SlotName; if ($CurrentEquipped -ne "None") { $Player.Inventory += $CurrentEquipped }
                        $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList)
                        $Player.$SlotName = $RealItem; $OutMsg += "You equipped the [$RealItem]."; $PassTurn = $true
                    } else { $OutMsg += "You cannot equip the [$RealItem]." }
                } else { $OutMsg += "You don't have a '$TargetItem' in your inventory." }
            }
            '^use\s+(.+)' {
                $TargetItem = $Matches[1].Trim()
                $RealItem = $Player.Inventory | Where-Object { $_ -ieq $TargetItem } | Select-Object -First 1
                if ($null -ne $RealItem) {
                    $ItemData = Get-ItemStats -ItemName $RealItem
                    if ($null -ne $ItemData -and $ItemData.Type -eq "Consumable") {
                        if ($RealItem -eq "Bandage") {
                            $Player.HP = [math]::Min($Player.MaxHP, ($Player.HP + $ItemData.Value)); $OutMsg += "You applied the [$RealItem] and recovered $($ItemData.Value) HP."
                            $Bleed = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Bleeding" }
                            if ($null -ne $Bleed) { $Player.ActiveEffects = @($Player.ActiveEffects | Where-Object { $_.Name -ne "Bleeding" }); $OutMsg += "`n> The tight wrapping completely stopped your bleeding!" }
                            $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList); $PassTurn = $true
                        } elseif ($RealItem -eq "Energy Drink") {
                            if ($Player.SP -ge $Player.MaxSP -and ($null -eq (@($Player.ActiveEffects) | Where-Object { $_.Name -eq "Zombie Rot" -or $_.Name -eq "Infected Wound" }))) { $OutMsg += "You feel jittery, but you are already at maximum stamina and have no infections to cure." } else {
                                $Player.SP = [math]::Min($Player.MaxSP, ($Player.SP + $ItemData.Value)); $OutMsg += "You chugged the [$RealItem] and recovered $($ItemData.Value) SP."
                                $Rot = @($Player.ActiveEffects) | Where-Object { $_.Name -eq "Zombie Rot" -or $_.Name -eq "Infected Wound" }
                                if ($null -ne $Rot) { $Player.ActiveEffects = @($Player.ActiveEffects | Where-Object { $_.Name -ne "Zombie Rot" -and $_.Name -ne "Infected Wound" }); $OutMsg += "`n> The intense chemical rush purged the infection from your veins!" }
                                $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList); $PassTurn = $true
                            }
                        } elseif ($RealItem -eq "Pistol Ammo") {
                            if ($Player.Class -ne "Immune Human") { $OutMsg += "You have no idea how to use this." } elseif ($Player.Ammo -ge $Player.MaxAmmo) { $OutMsg += "Your magazine is already full!" } else {
                                $Player.Ammo = [math]::Min($Player.MaxAmmo, ($Player.Ammo + $ItemData.Value)); $OutMsg += "You loaded $($ItemData.Value) rounds into your Glock. (Ammo: $($Player.Ammo)/$($Player.MaxAmmo))"
                                $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList); $PassTurn = $true
                            }
                        }
                    } else { $OutMsg += "You cannot use the [$RealItem] right now." }
                } else { $OutMsg += "You don't have a '$TargetItem' in your inventory." }
            }
            '^reload$' {
                if ($Player.Class -ne "Immune Human") { $OutMsg += "You don't have a gun to reload." } elseif ($Player.Ammo -ge $Player.MaxAmmo) { $OutMsg += "Your magazine is already full!" } else {
                    $AmmoItem = $Player.Inventory | Where-Object { $_ -ieq "Pistol Ammo" } | Select-Object -First 1
                    if ($null -ne $AmmoItem) {
                        $ItemData = Get-ItemStats -ItemName $AmmoItem; $Player.Ammo = [math]::Min($Player.MaxAmmo, ($Player.Ammo + $ItemData.Value))
                        $OutMsg += "You slammed a new magazine into your Glock. (Ammo: $($Player.Ammo)/$($Player.MaxAmmo))"
                        $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($AmmoItem); $Player.Inventory = @($InvList); $PassTurn = $true
                    } else { $OutMsg += "You reach into your pockets... but you are completely out of Pistol Ammo!" }
                }
            }
            '^release(\s+pet)?$' {
                if ($null -ne $Player.ActivePet) {
                    $HealAmount = $Player.ActivePet.HP; $Player.HP = [math]::Min($Player.MaxHP, ($Player.HP + $HealAmount))
                    $OutMsg += "You drain the energy from the $($Player.ActivePet.Name), adding it to your own. You were healed for $HealAmount HP."; $Player.ActivePet = $null; $PassTurn = $true
                } else { $OutMsg += "You do not have an active pet to release!" }
            }
            '^stash$' {
                if ($RoomID -ne "1") { $OutMsg += "There is no storage box here. It is only accessible in the Awakening Cell." } else {
                    $MaxSlots = [math]::Floor($LegacyBonuses.MaxLevelReached / 10)
                    $StashDisplay = @("=== THE IRON STORAGE BOX ===", " Capacity: $($LegacyBonuses.Stash.Count) / $MaxSlots slots", "--------------------------------------------------")
                    if ($LegacyBonuses.Stash.Count -gt 0) {
                        $Grouped = @{}; foreach ($Item in $LegacyBonuses.Stash) { if ($Grouped.ContainsKey($Item)) { $Grouped[$Item] += 1 } else { $Grouped[$Item] = 1 } }
                        foreach ($Key in $Grouped.Keys) { if ($Grouped[$Key] -gt 1) { $StashDisplay += " - $Key (x$($Grouped[$Key]))" } else { $StashDisplay += " - $Key" } }
                    } else { $StashDisplay += " The box is empty." }
                    $StashDisplay += "--------------------------------------------------`n Type 'stash put [item]' or 'stash take [item]'."; $OutMsg += $StashDisplay -join "`n> "
                }
            }
            '^stash put\s+(.+)' {
                if ($RoomID -ne "1") { $OutMsg += "There is no storage box here." } else {
                    $TargetItem = $Matches[1].Trim(); $RealItem = $Player.Inventory | Where-Object { $_ -ieq $TargetItem } | Select-Object -First 1
                    if ($null -ne $RealItem) {
                        $ItemData = Get-ItemStats -ItemName $RealItem
                        if ($null -ne $ItemData -and $ItemData.Type -in @("Weapon", "Armor", "Shoulders", "Boots", "Trinket", "Necklace")) {
                            $MaxSlots = [math]::Floor($LegacyBonuses.MaxLevelReached / 10)
                            if ($LegacyBonuses.Stash.Count -ge $MaxSlots) { $OutMsg += "The storage box is full! (Capacity: $MaxSlots). You need to reach a higher historical level for more space." } else {
                                $InvList = [System.Collections.ArrayList]$Player.Inventory; $InvList.Remove($RealItem); $Player.Inventory = @($InvList)
                                $LegacyBonuses.Stash += $RealItem; $OutMsg += "You safely locked the [$RealItem] in the storage box."
                            }
                        } else { $OutMsg += "The storage box only accepts Weapons and Armor." }
                    } else { $OutMsg += "You don't have a '$TargetItem' in your inventory." }
                }
            }
            '^stash take\s+(.+)' {
                if ($RoomID -ne "1") { $OutMsg += "There is no storage box here." } else {
                    $TargetItem = $Matches[1].Trim(); $RealItem = $LegacyBonuses.Stash | Where-Object { $_ -ieq $TargetItem } | Select-Object -First 1
                    if ($null -ne $RealItem) {
                        $StashList = [System.Collections.ArrayList]$LegacyBonuses.Stash; $StashList.Remove($RealItem); $LegacyBonuses.Stash = @($StashList)
                        $Player.Inventory += $RealItem; $OutMsg += "You retrieved the [$RealItem] from the storage box."
                    } else { $OutMsg += "There is no '$TargetItem' in the storage box." }
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
                $LegacyDisplay += "--------------------------------------------------`n Highest Level Reached: $($LegacyBonuses.MaxLevelReached)"
                if ($LegacyBonuses.HasOuroboros) { $LegacyDisplay += "`n 🐍 Ouroboros Unlocked: +5 to ALL base stats for all lives." }
                $LegacyDisplay += "`n (Hit Levels 25, 50, 75, etc. on any character to permanently buff future lives!)"
                $OutMsg += $LegacyDisplay -join "`n> "
            }
            '^unlock\s+(.+)' {
                $DirMap = @{'n'='North'; 'north'='North'; 'e'='East'; 'east'='East'; 's'='South'; 'south'='South'; 'w'='West'; 'west'='West'; 'u'='Up'; 'up'='Up'; 'd'='Down'; 'down'='Down'}
                $TargetDir = $Matches[1].Trim().ToLower()
                if ($DirMap.ContainsKey($TargetDir)) {
                    $IntendedDirection = $DirMap[$TargetDir]
                    if ($null -ne $Room.Locked -and $Room.Locked.ContainsKey($IntendedDirection)) {
                        $RequiredKey = $Room.Locked[$IntendedDirection]
                        if ($Player.Inventory -contains $RequiredKey) {
                            $Room.Locked.Remove($IntendedDirection); $WorldMap[$Room.ID].Locked.$IntendedDirection = $null
                            $OutMsg += "You insert the $RequiredKey and turn it. The $IntendedDirection door is now permanently unlocked!"; $PassTurn = $true
                        } else { $OutMsg += "You don't have the $RequiredKey required to unlock this." }
                    } else { $OutMsg += "The $IntendedDirection path is not locked." }
                } else { $OutMsg += "Unlock which direction? (e.g., 'unlock north')" }
            }
            '^open\s+(.+)' {
                $TargetObj = $Matches[1].Trim().ToLower()
                if ($Room.Interactables.ContainsKey($TargetObj)) {
                    if ($Room.Interactables[$TargetObj].State -ne "open") {
                        $Room.Interactables[$TargetObj].State = "open"; $Room.Exits += $TargetObj 
                        $OutMsg += "You pushed the $TargetObj aside. It is now open, revealing a path!"; $PassTurn = $true
                    } else { $OutMsg += "The $TargetObj is already open." }
                } else { $OutMsg += "You cannot open the '$TargetObj' here." }
            }
            '^enter\s+(.+)' {
                $TargetObj = $Matches[1].Trim().ToLower()
                if ($Room.Interactables.ContainsKey($TargetObj)) {
                    if ($Room.Interactables[$TargetObj].State -eq "open") {
                        $RoomID = $Room.Interactables[$TargetObj].TargetRoom; $OutMsg += "You squeeze into the $TargetObj..."; $PassTurn = $true
                    } else { $OutMsg += "The $TargetObj is closed." }
                } else { $OutMsg += "There is no '$TargetObj' to enter here." }
            }
            '^(n|north|e|east|s|south|w|west|ne|northeast|nw|northwest|se|southeast|sw|southwest|up|u|down|d|out|o)$' {
                $DirMap = @{'n'='North'; 'north'='North'; 'e'='East'; 'east'='East'; 's'='South'; 'south'='South'; 'w'='West'; 'west'='West'; 'ne'='Northeast'; 'northeast'='Northeast'; 'nw'='Northwest'; 'northwest'='Northwest'; 'se'='Southeast'; 'southeast'='Southeast'; 'sw'='Southwest'; 'southwest'='Southwest'; 'u'='Up'; 'up'='Up'; 'd'='Down'; 'down'='Down'; 'o'='Out'; 'out'='Out'}
                $IntendedDirection = $DirMap[$matches[1]]
                $IsLocked = $false
                if ($null -ne $Room.Locked -and $Room.Locked.ContainsKey($IntendedDirection)) {
                    $RequiredKey = $Room.Locked[$IntendedDirection]; $OutMsg += "The $IntendedDirection door is locked! You need a $RequiredKey. Try typing 'unlock $IntendedDirection'."; $IsLocked = $true
                }
                if (-not $IsLocked) {
                    if ($Room.ExitMap.ContainsKey($IntendedDirection)) {
                        $RoomID = $Room.ExitMap[$IntendedDirection]; $OutMsg += "You travel $IntendedDirection."; $PassTurn = $true
                        if ($Player.LearnedSkills -contains "Stealth" -and -not $Player.IsStealthed) { $Player.IsStealthed = $true; $OutMsg += "`n> 🌑 You naturally fade back into the shadows." }
                    } else { $OutMsg += "You cannot go that way." }
                }
            }
            '^(help|commands|\?)$' { $OutMsg += "AVAILABLE COMMANDS:`n  look   - Examine surroundings`n  talk   - Speak to NPCs`n  search - Look for enemies`n  char   - View Character Sheet`n  inv    - View Inventory & Loot`n  stats  - View quick combat stats`n  skills - View abilities`n  legacy - View account milestones`n  equip [item] - Equip armor or weapons`n  stash  - View storage box (Room 1 only)`n  unlock [dir] - Open locked doors`n  open [obj] - Interact`n  enter [obj] - Use hidden path`n  combine [item] - Technologist Upgrade`n  use foresight - Scan room for enemies`n  n/s/e/w - Move directions`n  quit   - Exit" }
            default { $OutMsg += "Command not recognized: '$Command'" }
        }
    }

    return [PSCustomObject]@{
        Message = ($OutMsg -join "`n> ")
        TurnPassed = $PassTurn
        Mob = $Mob
        NPC = $NPC
        RoomID = $RoomID
        IsRunning = $IsRunning
    }
}