# --- Modules\CharacterCreator.psm1 ---

function New-PlayerCharacter {
    param(
        [array]$UnlockedClasses = @(),
        [bool]$HasLegendaryPet = $false
    )

    Write-Host "--- NEW SURVIVOR ---" -ForegroundColor Cyan
    $Name = Read-Host "Enter your name"
    if ([string]::IsNullOrWhiteSpace($Name)) { $Name = "Unknown Survivor" }

    $ValidClasses = @("Bruiser", "Tank", "Popular", "Stealthy", "Tactician", "Technologist", "Charmed", "Lobber", "Plaguebringer", "Beserker", "Immune Human")
    
    # Add any unlocked legacy classes (like Vampire) to the selection pool
    foreach ($UC in $UnlockedClasses) {
        if ($ValidClasses -notcontains $UC) { $ValidClasses += $UC }
    }
    $ClassDescriptions = @{
        "Bruiser"       = "A hulking behemoth. High HP and Strength. Crushes skulls."
        "Tank"          = "A walking fortress. Massive Constitution and defensive skills."
        "Popular"       = "Charismatic and wealthy. Stuns enemies and deals massive ego damage."
        "Stealthy"      = "Fast and lethal. High Dexterity for devastating bleeding backstabs."
        "Tactician"     = "Calculated and precise. Exploits enemy armor weaknesses."
        "Technologist"  = "A master of salvaged tech. Overloads enemies with shock damage."
        "Charmed"       = "Unnaturally lucky. Relies on massive critical hits and aura buffs."
        "Lobber"        = "A twisted mutant. Throws infected tissue to cripple and convert enemies."
        "Plaguebringer" = "A walking biohazard. High Infectivity. Melts enemies with toxic rot."
        "Beserker"      = "Fueled by pure rage. Transforms into an unstoppable high-damage Hulk."
        "Immune Human"  = "A fragile survivor with unpredictable stats... but starts with a loaded Glock."
        "Vampire"       = "A creature of the night. Drains blood to heal and commands undead servants."
    }

    $Class = ""
    while ($Class -eq "") {
        Write-Host "`n=== SURVIVOR CLASSES ===" -ForegroundColor DarkYellow
        for ($i = 0; $i -lt $ValidClasses.Count; $i++) {
            $cName = $ValidClasses[$i]
            $cDesc = if ($ClassDescriptions.ContainsKey($cName)) { $ClassDescriptions[$cName] } else { "A mysterious survivor." }
            
            # Formats the number and name, then pads it so the descriptions all line up perfectly
            $Prefix = "  $($i + 1). $cName"
            Write-Host "$($Prefix.PadRight(20)) - $cDesc" -ForegroundColor White
        }
        
        $Choice = Read-Host "`nChoose your class (Enter a number)"
        
        if ($Choice -match '^\d+$') {
            $Index = [int]$Choice - 1
            if ($Index -ge 0 -and $Index -lt $ValidClasses.Count) {
                $Class = $ValidClasses[$Index]
            } else {
                Write-Host "[!] Invalid number. Please choose between 1 and $($ValidClasses.Count)." -ForegroundColor Red
            }
        } else {
            Write-Host "[!] Please enter the number corresponding to the class." -ForegroundColor Red
        }
    }

    # Base Template for ALL characters
    $Player = [PSCustomObject]@{
        Name = $Name
        Class = $Class
        Level = 1
        XP = 0
        NextLevelXP = 100
        
        MaxHP = 100; HP = 100
        MaxSP = 20; SP = 20
        MaxBP = 0; BP = 0
        MaxAmmo = 0; Ammo = 0
        
        BaseStrength = 5; Strength = 5
        BaseDexterity = 5; Dexterity = 5
        BaseCON = 5; CON = 5
        BaseCHA = 5; CHA = 5
        BaseTactics = 5; Tactics = 5
        BaseInt = 5; Int = 5
        BaseLuck = 5; Luck = 5
        BaseInfectivity = 1; Infectivity = 1
        
        BaseArmor = 0; Armor = 0
        Damage = 2
        
        EquippedWeapon = "Fists"
        Inventory = @()
        Currency = 0
        ActiveEffects = @()
        ActivePet = $null
        
        # --- NEW: ELEMENTAL CURRENCY & SCALING TRACKERS ---
        Bonechips = 0
        AppliedBonechipTiers = 0
        Gunpowder = 0
        AppliedGunpowderTiers = 0
        EnergyOrbs = 0
        AppliedOrbTiers = 0
        ToxicGarnets = 0
        AppliedGarnetTiers = 0
        PetBonusHP = 0
        BaseWeaponDamage = 0
    }

    # --- APPLY CLASS SPECIFIC STATS ---
    switch ($Class) {
        "Bruiser" {
            $Player.MaxHP = 250; $Player.HP = 250; $Player.MaxSP = 15; $Player.SP = 15;
            $Player.BaseStrength = 10; $Player.BaseDexterity = 3; $Player.BaseCON = 8
            $Player.BaseCHA = 2; $Player.BaseTactics = 3; $Player.BaseInt = 2; $Player.BaseInfectivity = 1
        }
        "Tank" {
            $Player.MaxHP = 300; $Player.HP = 300; $Player.MaxSP = 15; $Player.SP = 15;
            $Player.BaseStrength = 6; $Player.BaseDexterity = 2; $Player.BaseCON = 12
            $Player.BaseCHA = 3; $Player.BaseTactics = 5; $Player.BaseInt = 3; $Player.BaseInfectivity = 1
        }
        "Popular" {
            $Player.MaxHP = 120; $Player.HP = 120; $Player.MaxSP = 20; $Player.SP = 20;
            $Player.BaseStrength = 3; $Player.BaseDexterity = 4; $Player.BaseCON = 4
            $Player.BaseCHA = 12; $Player.BaseTactics = 4; $Player.BaseLuck = 3; $Player.BaseInfectivity = 5
            
            # --- POPULAR STARTING WEALTH ---
            $Player.Inventory += "Valuable Watch"
            $Player.Inventory += "Rusty Pipe"
        }
        "Stealthy" {
            $Player.MaxHP = 150; $Player.HP = 150; $Player.MaxSP = 30; $Player.SP = 30;
            $Player.BaseStrength = 4; $Player.BaseDexterity = 10; $Player.BaseCON = 4
            $Player.BaseCHA = 4; $Player.BaseTactics = 6; $Player.BaseLuck = 2; $Player.BaseInfectivity = 1
        }
        "Tactician" {
            $Player.MaxHP = 140; $Player.HP = 140; $Player.MaxSP = 25; $Player.SP = 25;
            $Player.BaseStrength = 4; $Player.BaseDexterity = 5; $Player.BaseCON = 5
            $Player.BaseCHA = 6; $Player.BaseTactics = 12; $Player.BaseInt = 8; $Player.BaseInfectivity = 1
        }
        "Technologist" {
            $Player.MaxHP = 110; $Player.HP = 110; $Player.MaxSP = 20; $Player.SP = 20;
            $Player.BaseStrength = 3; $Player.BaseDexterity = 6; $Player.BaseCON = 4
            $Player.BaseTactics = 7; $Player.BaseInt = 12; $Player.BaseInfectivity = 1
        }
        "Charmed" {
            $Player.MaxHP = 100; $Player.HP = 100; $Player.MaxSP = 25; $Player.SP = 25;
            $Player.BaseStrength = 3; $Player.BaseDexterity = 5; $Player.BaseCON = 4
            $Player.BaseCHA = 8; $Player.BaseLuck = 10; $Player.BaseInfectivity = 1
        }
        "Lobber" {
            $Player.MaxHP = 160; $Player.HP = 160; $Player.MaxSP = 20; $Player.SP = 20;
            $Player.BaseStrength = 7; $Player.BaseDexterity = 8; $Player.BaseCON = 5
            $Player.BaseTactics = 5; $Player.BaseInfectivity = 10
        }
        "Plaguebringer" {
            $Player.MaxHP = 180; $Player.HP = 180; $Player.MaxSP = 20; $Player.SP = 20;
            $Player.BaseStrength = 4; $Player.BaseDexterity = 4; $Player.BaseCON = 8
            $Player.BaseCHA = 1; $Player.BaseInfectivity = 30
        }
        "Beserker" {
            $Player.MaxHP = 150; $Player.HP = 150; $Player.MaxSP = 20; $Player.SP = 20;
            $Player.BaseInfectivity = -20 
        }
        "Immune Human" {
            $Player.MaxHP = Get-Random -Minimum 80 -Maximum 151; $Player.HP = $Player.MaxHP
            $Player.MaxSP = Get-Random -Minimum 10 -Maximum 31; $Player.SP = $Player.MaxSP
            $Player.BaseStrength = Get-Random -Minimum 1 -Maximum 21
            $Player.BaseDexterity = Get-Random -Minimum 1 -Maximum 21
            $Player.BaseCON = Get-Random -Minimum 1 -Maximum 21
            $Player.BaseCHA = Get-Random -Minimum 1 -Maximum 21
            $Player.BaseTactics = Get-Random -Minimum 1 -Maximum 21
            $Player.BaseInt = Get-Random -Minimum 1 -Maximum 21
            $Player.BaseLuck = Get-Random -Minimum 1 -Maximum 21
            
            $Player.BaseInfectivity = 0 
            
            $Player.MaxAmmo = 10
            $Player.Ammo = 10
            $Player.Inventory += "Glock .45"
        }
        "Vampire" {
            $Player.MaxHP = 200; $Player.HP = 200; $Player.MaxSP = 25; $Player.SP = 25;
            $Player.MaxBP = 100 + (2 * $Player.Level) + 6
            $Player.BP = $Player.MaxBP 
            
            $Player.BaseStrength = 8; $Player.BaseDexterity = 8; $Player.BaseCON = 8
            $Player.BaseCHA = 10; $Player.BaseTactics = 5; $Player.BaseInt = 8
            $Player.BaseLuck = 2; $Player.BaseInfectivity = 5
        }
    }

    # Sync current stats to base stats so they start correct
    $Player.Strength = $Player.BaseStrength
    $Player.Dexterity = $Player.BaseDexterity
    $Player.CON = $Player.BaseCON
    $Player.CHA = $Player.BaseCHA
    $Player.Tactics = $Player.BaseTactics
    $Player.Int = $Player.BaseInt
    $Player.Luck = $Player.BaseLuck
    $Player.Infectivity = $Player.BaseInfectivity

    # Recalculate Base Armor derived from DEX and CON
    $Player.BaseArmor = [math]::Floor($Player.BaseDexterity / 3) + [math]::Floor($Player.BaseCON / 10)
    $Player.Armor = $Player.BaseArmor

    # --- LEGACY PET SELECTION ---
    # Only offer this if the player has unlocked the legendary pet milestone
    if ($HasLegendaryPet) {
        $Pets = @(
            [PSCustomObject]@{ Name="Healer Drone"; Skill="Mend"; Damage=10; HP=200; Armor=5; Role="Heal" },
            [PSCustomObject]@{ Name="Damage Brute"; Skill="Smash"; Damage=50; HP=300; Armor=2; Role="Damage" },
            [PSCustomObject]@{ Name="Support Imp"; Skill="Buff"; Damage=25; HP=150; Armor=8; Role="Buff" }
        )
        
        Write-Host "`n=== LEGACY COMPANION AVAILABLE ===" -ForegroundColor Magenta
        Write-Host "As a legacy survivor, you can start with a loyal companion."
        for ($i = 0; $i -lt $Pets.Count; $i++) { Write-Host "  $($i + 1). $($Pets[$i].Name) ($($Pets[$i].Role))" }
        
        $PetChoice = Read-Host "Choose a companion (or press Enter to decline)"
        if ($PetChoice -match '^\d+$' -and [int]$PetChoice -le $Pets.Count) {
            $Chosen = $Pets[[int]$PetChoice - 1]
            $Player.ActivePet = [PSCustomObject]@{ 
                Name=$Chosen.Name; Level=1; XP=0; MaxHP=$Chosen.HP; HP=$Chosen.HP; 
                Damage=$Chosen.Damage; Armor=$Chosen.Armor; Role=$Chosen.Role;
                IsLegacyPet = $true # THIS IS THE KEY FLAG
            }
            # Permanent Legacy Stats
            $Player.MaxHP += 50; $Player.HP = $Player.MaxHP
            $Player.MaxSP += 20; $Player.SP = $Player.MaxSP
        }
    }

    return $Player
}