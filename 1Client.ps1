# --- Client.ps1 ---

# Import our custom modules
$RequiredModules = @(
    "CharacterCreator.psm1", "Renderer.psm1", "CombatEngine.psm1",
    "SkillEngine.psm1", "RoomManager.psm1", "Bestiary.psm1", "InventoryManager.psm1"
)
foreach ($Mod in $RequiredModules) {
    $ModPath = Join-Path $PSScriptRoot "Modules\$Mod"
    if (-not (Test-Path $ModPath)) { Write-Host "[!] FATAL ERROR: Missing $Mod" -ForegroundColor Red; exit }
    try { Import-Module $ModPath -Force -ErrorAction Stop }
    catch { Write-Host "[!] SYNTAX ERROR IN: $Mod - $($_.Exception.Message)" -ForegroundColor Red; exit }
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

Clear-Host
Write-Host $banner -ForegroundColor DarkRed
Read-Host "`nPress [Enter] to awaken..."

$Player = New-PlayerCharacter
$WorldMap = Load-WorldMap
$CurrentRoom = Get-RoomState -WorldMap $WorldMap -RoomID "1"
$CurrentMob = $null
$GameIsRunning = $true
$LastActionMessage = "You have woken up. The nightmare begins. Type 'search' to look for trouble."

while ($GameIsRunning) {
    Out-MudScreen -PlayerState $Player -RoomState $CurrentRoom -SystemMessage $LastActionMessage -MobState $CurrentMob

    if ($Player.HP -le 0) {
        Write-Host "`nYOU HAVE DIED." -ForegroundColor Red; Read-Host "Press [Enter]..."
        $Player = New-PlayerCharacter
        $CurrentRoom = Get-RoomState -WorldMap $WorldMap -RoomID "1"
        $CurrentMob = $null
        $LastActionMessage = "Death was only a temporary setback."
        continue 
    }

    $Command = Read-Host "`nWhat would you like to do?"
    $CleanCommand = $Command.ToLower().Trim()
    
    if ($null -ne $CurrentMob -and $CurrentMob.HP -gt 0) {
        switch -Regex ($CleanCommand) {
            '^a$|^attack$' { $LastActionMessage = Invoke-CombatRound -Player $Player -Mob $CurrentMob -Action 'attack' }
            '^r$|^run$'    { $LastActionMessage = Invoke-CombatRound -Player $Player -Mob $CurrentMob -Action 'run' }
            '^skills$'     { $LastActionMessage = "Skills: $((Get-ClassSkills -ClassName $Player.Class) -join ', ')" }
            '^use\s+(.+)'  { $LastActionMessage = Invoke-SkillRound -Player $Player -Mob $CurrentMob -SkillName $Matches[1] }
            default        { $LastActionMessage = "You are in combat!" }
        }
    }
    else {
        $CurrentMob = $null 
        switch -Regex ($CleanCommand) {
            '^quit$' { $GameIsRunning = $false }
            '^look$' { 
                if ($CurrentRoom.Interactables.Count -gt 0) {
                    $LastActionMessage = ($CurrentRoom.Interactables.Keys | ForEach-Object { "You notice a $_." }) -join " "
                } else { $LastActionMessage = "Nothing jumps out at you." }
            }
            '^search$' { $CurrentMob = Get-RandomMob; $LastActionMessage = "Found a $($CurrentMob.Name)!" }
            '^stats$'  { $LastActionMessage = "STR: $($Player.Strength) | WPN: $($Player.EquippedWeapon)" }
            '^(inv|inventory|i)$' { 
                $InvDisplay = @("=== INVENTORY ===", "Currency: $($Player.Currency)", "Equipped: $($Player.EquippedWeapon)")
                $InvDisplay += ($Player.Inventory.Count -gt 0 ? $Player.Inventory : "Empty")
                $LastActionMessage = $InvDisplay -join "`n> "
            }
            '^equip\s+(.+)' {
                $RealItem = $Player.Inventory | Where-Object { $_ -ieq $Matches[1] } | Select-Object -First 1
                if ($RealItem) {
                    $Data = Get-ItemStats -ItemName $RealItem
                    if ($Data.Type -eq "Weapon") {
                        if ($Player.EquippedWeapon -ne "Fists") { $Player.Inventory += $Player.EquippedWeapon }
                        $List = [System.Collections.ArrayList]$Player.Inventory; $List.Remove($RealItem); $Player.Inventory = @($List)
                        $Player.EquippedWeapon = $RealItem; $Player.Damage = $Data.Value
                        $LastActionMessage = "Equipped $RealItem."
                    }
                }
            }
            '^(n|north|e|east|s|south|w|west|up|u|down|d)$' {
                $DirMap = @{'n'='North'; 'e'='East'; 's'='South'; 'w'='West'; 'u'='Up'; 'd'='Down'}
                $Dir = $DirMap[$Matches[1]]
                $IsLocked = $false
                if ($CurrentRoom.Locked.ContainsKey($Dir)) {
                    if ($Player.Inventory -contains $CurrentRoom.Locked[$Dir]) { $LastActionMessage = "Unlocked." }
                    else { $LastActionMessage = "Locked! Need $($CurrentRoom.Locked[$Dir])"; $IsLocked = $true }
                }
                if (-not $IsLocked -and $CurrentRoom.ExitMap.ContainsKey($Dir)) {
                    $CurrentRoom = Get-RoomState -WorldMap $WorldMap -RoomID $CurrentRoom.ExitMap[$Dir]
                }
            }
            default { $LastActionMessage = "Command not recognized." }
        }
    }
}