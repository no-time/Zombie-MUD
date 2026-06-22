# --- Modules\Renderer.psm1 ---

function Out-MudScreen {
    param(
        [Parameter(Mandatory=$true)][object]$PlayerState,
        [Parameter(Mandatory=$true)][object]$RoomState,
        [Parameter(Mandatory=$false)][string]$SystemMessage,
        [Parameter(Mandatory=$false)][object]$MobState
    )

    Clear-Host
    Write-Host "" # Hidden buffer flush for the ISE

    # 1. Render the Room
    Write-Host "=== $($RoomState.Name) ===" -ForegroundColor Cyan
    Write-Host $RoomState.Description -ForegroundColor Gray

    $ExitDisplay = foreach ($Exit in $RoomState.Exits) {
        if ($null -ne $RoomState.Locked -and $RoomState.Locked.ContainsKey($Exit)) { "$Exit (Locked)" } else { $Exit }
    }
    
    # --- NPC PRESENCE & DIALOGUE ---
    if ($null -ne $RoomState.NPC) {
        Write-Host ""
        Write-Host " $($RoomState.NPC): `"Stranger. Type 'talk' to see my wares.`" " -ForegroundColor Yellow -BackgroundColor DarkGray
    }

    # --- PET PRESENCE & HP BAR ---
    if ($null -ne $PlayerState.ActivePet) {
        Write-Host " Your Level $($PlayerState.ActivePet.Level) $($PlayerState.ActivePet.Name) shambles close behind you. (HP: $($PlayerState.ActivePet.HP)/$($PlayerState.ActivePet.MaxHP))" -ForegroundColor DarkGreen
    }

    Write-Host "Exits: $($ExitDisplay -join ', ')" -ForegroundColor DarkGray

    # 2. Render the Player Stats
    Write-Host "" # Hidden buffer flush
    Write-Host "--------------------------------------------------" -ForegroundColor DarkCyan
    
    if ($PlayerState.Class -eq 'Vampire') {
        $StatLine = "HP: {0}/{1} | BP: {2} | Class: {3} | SP: {4}" -f $PlayerState.HP, $PlayerState.MaxHP, $PlayerState.BP, $PlayerState.Class, $PlayerState.SP
    } else {
        $StatLine = "HP: {0}/{1} | Class: {2} | SP: {3}" -f $PlayerState.HP, $PlayerState.MaxHP, $PlayerState.Class, $PlayerState.SP
    }
    
    # --- RENDER PLAYER STATUS LINE ---
    Write-Host $StatLine -ForegroundColor Yellow -NoNewline
    Write-Host " | Status: " -ForegroundColor Yellow -NoNewline

    if ($null -eq $PlayerState.ActiveEffects -or $PlayerState.ActiveEffects.Count -eq 0) {
        Write-Host "Normal" -ForegroundColor DarkGray
    } else {
        for ($i = 0; $i -lt $PlayerState.ActiveEffects.Count; $i++) {
            $Eff = $PlayerState.ActiveEffects[$i]
            $Color = "Cyan" 
            
            # Switch to a "Debuff" Red if it does DoT or has a negative keyword
            if ($Eff.DoT -gt 0 -or $Eff.Name -match "Bleeding|Rot|Wound|Crippled|Exposed|Shocked|Distracted|Curse|Sundered") {
                $Color = "Red"
            }

            Write-Host "[$($Eff.Name)]" -ForegroundColor $Color -NoNewline
            if ($i -lt ($PlayerState.ActiveEffects.Count - 1)) { Write-Host " " -NoNewline }
        }
        Write-Host "" # Drops down to the next line when finished
    }
    
    Write-Host "--------------------------------------------------" -ForegroundColor DarkCyan

    # 3. Render Enemy Stats (IF IN COMBAT)
    if ($null -ne $MobState -and $MobState.HP -gt 0) {
        Write-Host "ENEMY: $($MobState.Name) | HP: $($MobState.HP)/$($MobState.MaxHP)" -ForegroundColor Red -NoNewline
        Write-Host " | Status: " -ForegroundColor Red -NoNewline
        
        # --- RENDER ENEMY STATUS LINE ---
        if ($null -eq $MobState.ActiveEffects -or $MobState.ActiveEffects.Count -eq 0) {
            Write-Host "Normal" -ForegroundColor DarkGray
        } else {
            for ($i = 0; $i -lt $MobState.ActiveEffects.Count; $i++) {
                $Eff = $MobState.ActiveEffects[$i]
                $Color = "Cyan" 
                
                # Switch to a "Debuff" Magenta (to stand out against the Red UI) if it's a negative status
                if ($Eff.DoT -gt 0 -or $Eff.Name -match "Bleeding|Rot|Wound|Crippled|Exposed|Shocked|Distracted|Curse|Sundered") {
                    $Color = "Magenta"
                }

                Write-Host "[$($Eff.Name)]" -ForegroundColor $Color -NoNewline
                if ($i -lt ($MobState.ActiveEffects.Count - 1)) { Write-Host " " -NoNewline }
            }
            Write-Host "" # Drops down to the next line when finished
        }
        
        Write-Host "--------------------------------------------------" -ForegroundColor DarkRed
    }

    # 4. Render Action/Combat Messages
    if (-not [string]::IsNullOrWhiteSpace($SystemMessage)) {
        Write-Host "" # Replaces the inline newline
        Write-Host "> $SystemMessage" -ForegroundColor Green
    }
}