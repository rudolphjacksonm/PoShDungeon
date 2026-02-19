# Import classes
. "$PSScriptRoot/classes.ps1"

# Import helper functions
. "$PSScriptRoot/helpers/uihelpers.ps1"
. "$PSScriptRoot/helpers/battlefunctions.ps1"
. "$PSScriptRoot/helpers/inventoryfunctions.ps1"
. "$PSScriptRoot/helpers/gameplayfunctions.ps1"

# Set background color and clear screen
$HOST.UI.RawUI.BackgroundColor = 'Black'
Clear-GameScreen

Write-Host @"

:::::::::   ::::::::   ::::::::  :::    :::  :::::::::  :::    ::: ::::    :::  ::::::::  :::::::::: ::::::::  ::::    :::
:+:    :+: :+:    :+: :+:    :+: :+:    :+:  :+:    :+: :+:    :+: :+:+:   :+: :+:    :+: :+:       :+:    :+: :+:+:   :+:
+:+    +:+ +:+    +:+ +:+        +:+    +:+  +:+    +:+ +:+    +:+ :+:+:+  +:+ +:+        +:+       +:+    +:+ :+:+:+  +:+
+#++:++#+  +#+    +:+ +#++:++#++ +#++:++#++  +#+    +:+ +#+    +:+ +#+ +:+ +#+ :#:        +#++:++#  +#+    +:+ +#+ +:+ +#+
+#+        +#+    +#+        +#+ +#+    +#+  +#+    +#+ +#+    +#+ +#+  +#+#+# +#+   +#+# +#+       +#+    +#+ +#+  +#+#+#
#+#        #+#    #+# #+#    #+# #+#    #+#  #+#    #+# #+#    #+# #+#   #+#+# #+#    #+# #+#       #+#    #+# #+#   #+#+#
###         ########   ########  ###    ###  #########   ########  ###    ####  ########  ########## ########  ###    ####

"@ -ForegroundColor Red -BackgroundColor Black

$name = Read-Host 'What is your name?'
$global:Hero = [Hero]::new($name)
$global:Hero.Armor = 'Cloth_Sack'
$global:Hero.Potions = 1
$starterWeapon = Get-Weapon -WeaponName 'Broken_Shortsword'
Equip-Weapon -Hero $global:Hero -Weapon $starterWeapon

Write-Host "Welcome, $name. You descend into the dungeon with a $($global:Hero.Weapon)."
Pause-ForContinue

$floor = 1
$continueGame = $true

while ($continueGame -and $global:Hero.Status -ne [State]::Dead) {
    Clear-GameScreen
    $xpToNext = Get-ExperienceForNextLevel -Level $global:Hero.Level

    Write-Host '==================== DUNGEON ====================' -ForegroundColor DarkGray
    Write-Host "Floor $floor" -ForegroundColor Gray
    Write-Host "HP: $($global:Hero.Health)/$($global:Hero.MaxHealth)  Lvl: $($global:Hero.Level)  XP: $($global:Hero.Experience)/$xpToNext" -ForegroundColor Cyan
    Write-Host "Crit: $($global:Hero.CritChance)%  Dodge: $($global:Hero.DodgeChance)%  Gold: $($global:Hero.Gold)  Potions: $($global:Hero.Potions)" -ForegroundColor Gray
    Write-Host '=================================================' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '[D] Descend deeper   [S] Search floor   [I] Inventory   [Q] Quit' -ForegroundColor White

    $command = Read-SingleKeyChoice -ValidChoices @('D', 'S', 'I', 'Q') -Prompt 'Choose action key:'

    switch ($command) {
        'I' {
            Get-InventoryWindow -Hero $global:Hero
        }

        'S' {
            Search-Floor -Hero $global:Hero -Floor $floor
            Pause-ForContinue
        }

        'D' {
            $floor += 1
            Clear-GameScreen
            Write-Host "You descend to floor $floor." -ForegroundColor Gray

            $enemy = New-Enemy -Floor $floor
            if ($enemy.IsBoss) {
                Write-Host "BOSS ENCOUNTER! $($enemy.Name) emerges with overwhelming force." -ForegroundColor Magenta
            }
            else {
                Write-Host "$($enemy.Name) appears from the dark." -ForegroundColor DarkYellow
            }
            Pause-ForContinue

            Battle -Attacker $global:Hero -Defender $enemy

            if ($global:Hero.Status -eq [State]::Dead) {
                Write-Host 'GAME OVER' -ForegroundColor Red
                $continueGame = $false
                continue
            }

            if ($enemy.Status -eq [State]::Dead) {
                Grant-VictoryRewards -Hero $global:Hero -Floor $floor -Enemy $enemy
                Pause-ForContinue
            }
        }

        'Q' {
            Write-Host 'You retreat from the dungeon... for now.' -ForegroundColor Gray
            $continueGame = $false
        }
    }
}

if ($global:Hero.Status -ne [State]::Dead) {
    Write-Host "Run complete. Floors reached: $floor | Gold: $($global:Hero.Gold)"
}
