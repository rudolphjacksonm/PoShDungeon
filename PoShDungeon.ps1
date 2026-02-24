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

Clear-UiMessages
Add-UiMessage -Message "Welcome, $name. You descend into the dungeon with a $($global:Hero.Weapon)."
$global:RunState = Initialize-RunState
Add-UiMessage -Message "You sense $($global:RunState.MaxFloors) floors in this run."

$floor = 1
$continueGame = $true

while ($continueGame -and $global:Hero.Status -ne [State]::Dead) {
    $xpToNext = Get-ExperienceForNextLevel -Level $global:Hero.Level
    $maxFloors = $global:RunState.MaxFloors
    $remainingLoot = Get-RemainingFloorLootCount -RunState $global:RunState -Floor $floor
    $renderMainFrame = {
        Show-MainGameWindow -Title "Floor $floor/$maxFloors" -StatusLines @(
            "HP: $($global:Hero.Health)/$($global:Hero.MaxHealth)  Lvl: $($global:Hero.Level)  XP: $($global:Hero.Experience)/$xpToNext",
            "Crit: $($global:Hero.CritChance)%  Dodge: $($global:Hero.DodgeChance)%  Gold: $($global:Hero.Gold)  Potions: $($global:Hero.Potions)",
            "Discoveries left on this floor: $remainingLoot"
        )
    }

    & $renderMainFrame

    $command = Read-SingleKeyChoice -ValidChoices @('D', 'S', 'I', 'Q') -Prompt 'Choose your action' -OptionLabels @('Descend deeper', 'Search floor', 'Inventory', 'Quit run') -RenderFrame $renderMainFrame

    switch ($command) {
        'I' {
            Get-InventoryWindow -Hero $global:Hero
        }

        'S' {
            Search-Floor -Hero $global:Hero -Floor $floor -RunState $global:RunState
        }

        'D' {
            if ($floor -ge $global:RunState.MaxFloors) {
                Add-UiMessage -Message "You reach the end of the seeded dungeon at floor $floor."
                Add-UiMessage -Message 'No deeper stairs remain.'
                $continueGame = $false
                continue
            }

            $floor += 1
            Add-UiMessage -Message "You descend to floor $floor."

            if (Should-TriggerShopEncounter -RunState $global:RunState -Floor $floor) {
                Invoke-ShopEncounter -Hero $global:Hero -RunState $global:RunState -Floor $floor
            }

            Grant-FloorEntryAid -Hero $global:Hero -Floor $floor
            $enemy = New-Enemy -Floor $floor
            if ($enemy.IsBoss) {
                Add-UiMessage -Message "BOSS ENCOUNTER! $($enemy.Name) emerges with overwhelming force."
            }
            else {
                Add-UiMessage -Message "$($enemy.Name) appears from the dark."
            }

            Battle -Attacker $global:Hero -Defender $enemy

            if ($global:Hero.Status -eq [State]::Dead) {
                Add-UiMessage -Message 'GAME OVER'
                $continueGame = $false
                continue
            }

            if ($enemy.Status -eq [State]::Dead) {
                Grant-VictoryRewards -Hero $global:Hero -Floor $floor -Enemy $enemy
            }
        }

        'Q' {
            Add-UiMessage -Message 'You retreat from the dungeon... for now.'
            $continueGame = $false
        }
    }
}

if ($global:Hero.Status -ne [State]::Dead) {
    Add-UiMessage -Message "Run complete. Floors reached: $floor | Gold: $($global:Hero.Gold)"
    Show-MainGameWindow -Title "Floor $floor/$($global:RunState.MaxFloors)" -StatusLines @(
        "HP: $($global:Hero.Health)/$($global:Hero.MaxHealth)  Lvl: $($global:Hero.Level)",
        "Gold: $($global:Hero.Gold)  Potions: $($global:Hero.Potions)"
    )
}
