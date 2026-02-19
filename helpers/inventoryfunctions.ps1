function Get-InventoryWindow {
    Param (
        [Hero]$Hero
    )

    if ($null -eq $Hero.WeaponStats) {
        $Hero.WeaponStats = Get-Weapon -WeaponName 'Broken_Shortsword'
        $Hero.Weapon = $Hero.WeaponStats.Name
    }

    $response = ''
    :mainLoop while ($response -ne 'Q') {
        Clear-GameScreen
        Write-Host '=================== INVENTORY ===================' -ForegroundColor DarkGray
        Write-Host "Hero: $($Hero.Name)" -ForegroundColor Cyan
        Write-Host "Armor: $($Hero.Armor)" -ForegroundColor Gray
        Write-Host "Weapon: $($Hero.Weapon)  Damage: $($Hero.WeaponStats.MinDamage)-$($Hero.WeaponStats.MaxDamage)" -ForegroundColor Gray
        Write-Host "Level: $($Hero.Level)  XP: $($Hero.Experience)/$(Get-ExperienceForNextLevel -Level $Hero.Level)" -ForegroundColor Gray
        Write-Host "Crit: $($Hero.CritChance)%  Dodge: $($Hero.DodgeChance)%  Heal: x$($Hero.HealPowerModifier)" -ForegroundColor Gray
        Write-Host "Gold: $($Hero.Gold)  Potions: $($Hero.Potions)" -ForegroundColor Gray
        Write-Host '=================================================' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '[1] Swap Weapon   [2] Use Potion   [3] Inspect Weapon   [Q] Exit' -ForegroundColor White

        if (Get-Command Read-SingleKeyChoice -ErrorAction SilentlyContinue) {
            $response = Read-SingleKeyChoice -ValidChoices @('1', '2', '3', 'Q') -Prompt 'Choose inventory action key:'
        }
        else {
            $response = (Read-Host 'Enter a choice').ToUpperInvariant()
        }

        switch ($response) {
            '1' {
                Set-HeroWeapon -Hero $Hero
                Pause-ForContinue
            }

            '2' {
                if ($Hero.Potions -gt 0) {
                    $healPoints = Get-Heal -Character $Hero
                    $healPoints = [Math]::Max(1, [Math]::Floor($healPoints * $Hero.HealPowerModifier))
                    $Hero.Heal($healPoints)
                    $Hero.Potions -= 1
                    Write-Host "$($Hero.Name) restored $healPoints health." -ForegroundColor Green
                }
                else {
                    Write-Host 'No potions left.' -ForegroundColor DarkYellow
                }
                Pause-ForContinue
            }

            '3' {
                Show-WeaponDetails -Hero $Hero
            }
        }
    }
}

function Show-WeaponDetails {
    Param(
        [Hero]$Hero
    )

    Clear-GameScreen
    Write-Host @"
$($Hero.WeaponStats.Image)
+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
|Weapon: $($Hero.Weapon)
|Description: $($Hero.WeaponStats.Description)
+~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
"@

    Pause-ForContinue -Message 'Press any key to return to inventory...'
}

function Set-HeroWeapon {
    Param(
        [Hero]$Hero
    )

    $weaponOptions = @(
        'Broken_Shortsword',
        'Short_Sword',
        'Hatchet',
        'Long_Sword',
        'Zweihander'
    )

    Clear-GameScreen
    Write-Host 'Choose your weapon:' -ForegroundColor White
    for ($i = 0; $i -lt $weaponOptions.Count; $i++) {
        $index = $i + 1
        Write-Host "$index. $($weaponOptions[$i])"
    }

    if (Get-Command Read-SingleKeyChoice -ErrorAction SilentlyContinue) {
        $selected = Read-SingleKeyChoice -ValidChoices @('1', '2', '3', '4', '5') -Prompt 'Choose weapon key:'
    }
    else {
        $selected = Read-Host 'Selection'
    }

    if ($selected -as [int]) {
        $selectedIndex = [int]$selected - 1
        if ($selectedIndex -ge 0 -and $selectedIndex -lt $weaponOptions.Count) {
            $weapon = Get-Weapon -WeaponName $weaponOptions[$selectedIndex]
            Equip-Weapon -Hero $Hero -Weapon $weapon
            Write-Host "$($Hero.Name) equipped $($Hero.Weapon)." -ForegroundColor Green
            return
        }
    }

    Write-Host 'Invalid weapon selection.' -ForegroundColor DarkYellow
}
