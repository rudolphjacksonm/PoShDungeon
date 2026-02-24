function Get-InventoryWindow {
    Param (
        [Hero]$Hero
    )

    if ($null -eq $Hero.WeaponStats) {
        $Hero.WeaponStats = Get-Weapon -WeaponName 'Broken_Shortsword'
        $Hero.Weapon = $Hero.WeaponStats.Name
    }

    $response = ''
    $inventoryNotice = "Equipped: $($Hero.Weapon)"
    :mainLoop while ($response -ne 'Q') {
        $renderInventoryFrame = {
            $statusLines = @(
                "Hero: $($Hero.Name)  Armor: $($Hero.Armor)",
                "Weapon: $($Hero.Weapon)  Damage: $($Hero.WeaponStats.MinDamage)-$($Hero.WeaponStats.MaxDamage)",
                "Level: $($Hero.Level)  XP: $($Hero.Experience)/$(Get-ExperienceForNextLevel -Level $Hero.Level)",
                "Crit: $($Hero.CritChance)%  Dodge: $($Hero.DodgeChance)%  Heal: x$($Hero.HealPowerModifier)",
                "Gold: $($Hero.Gold)  Potions: $($Hero.Potions)"
            )
            $infoLines = @($inventoryNotice)
            Show-HudWindow -ModeTitle 'INVENTORY' -StatusLines $statusLines -InfoLines $infoLines -InfoHeight 8
        }

        & $renderInventoryFrame

        if (Get-Command Read-SingleKeyChoice -ErrorAction SilentlyContinue) {
            $response = Read-SingleKeyChoice -ValidChoices @('1', '2', '3', 'Q') -Prompt 'Inventory action' -OptionLabels @('Swap weapon', 'Use potion', 'Inspect weapon', 'Exit inventory') -RenderFrame $renderInventoryFrame
        }
        else {
            $response = (Read-Host 'Enter a choice').ToUpperInvariant()
        }

        switch ($response) {
            '1' {
                $equipMessage = Set-HeroWeapon -Hero $Hero
                if (-not [string]::IsNullOrWhiteSpace($equipMessage)) {
                    $inventoryNotice = $equipMessage
                }
                else {
                    $inventoryNotice = "Equipped: $($Hero.Weapon)"
                }
            }

            '2' {
                if ($Hero.Potions -gt 0) {
                    $healPoints = Get-Heal -Character $Hero
                    $scaledHeal = [Math]::Round(($healPoints * [double]$Hero.HealPowerModifier), 0, [System.MidpointRounding]::AwayFromZero)
                    $healPoints = [int][Math]::Max(1, $scaledHeal)
                    $Hero.Heal($healPoints)
                    $Hero.Potions -= 1
                    $inventoryNotice = "$($Hero.Name) restored $healPoints health."
                }
                else {
                    $inventoryNotice = 'No potions left.'
                }
            }

            '3' {
                Show-WeaponDetails -Hero $Hero
            }
        }
    }
}

function Get-HeroWeaponOptions {
    Param(
        [Hero]$Hero
    )

    if ($null -eq $Hero.UnlockedWeapons -or $Hero.UnlockedWeapons.Count -eq 0) {
        $Hero.UnlockedWeapons = @('Broken_Shortsword')
    }

    $Hero.UnlockedWeapons
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

function Format-WeaponLabel {
    Param(
        [string]$WeaponName
    )

    if ([string]::IsNullOrWhiteSpace($WeaponName)) {
        return ''
    }

    $WeaponName -replace '_', ' '
}

function Show-WeaponSelectScreen {
    Param(
        [string[]]$WeaponOptions,
        [int]$SelectedIndex
    )

    $selectedWeapon = Get-Weapon -WeaponName $WeaponOptions[$SelectedIndex]
    $displayName = Format-WeaponLabel -WeaponName $selectedWeapon.Name

    Clear-GameScreen
    Write-Host '=================== WEAPON SELECT ===================' -ForegroundColor DarkGray
    Write-Host 'Use Arrow Keys to move, Enter to equip, Q to cancel.' -ForegroundColor DarkGray
    Write-Host ''

    for ($i = 0; $i -lt $WeaponOptions.Count; $i++) {
        $cursor = if ($i -eq $SelectedIndex) { '>' } else { ' ' }
        $weaponData = Get-Weapon -WeaponName $WeaponOptions[$i]
        $weaponName = Format-WeaponLabel -WeaponName $weaponData.Name
        Write-Host ("{0} {1}. {2} ({3}-{4})" -f $cursor, ($i + 1), $weaponName, $weaponData.MinDamage, $weaponData.MaxDamage) -ForegroundColor White
    }

    Write-Host ''
    Write-Host ("Selected: {0} ({1}-{2})" -f $displayName, $selectedWeapon.MinDamage, $selectedWeapon.MaxDamage) -ForegroundColor Cyan
    if ($selectedWeapon.Image) {
        Write-Host $selectedWeapon.Image -ForegroundColor Gray
    }
    Write-Host $selectedWeapon.Description -ForegroundColor Gray
    Write-Host '=====================================================' -ForegroundColor DarkGray
}

function Select-WeaponWithCursor {
    Param(
        [string[]]$WeaponOptions
    )

    $selectedIndex = 0

    while ($true) {
        Show-WeaponSelectScreen -WeaponOptions $WeaponOptions -SelectedIndex $selectedIndex
        try {
            $keyInfo = $host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        }
        catch {
            return $null
        }

        switch ($keyInfo.VirtualKeyCode) {
            38 { # Up
                $selectedIndex = ($selectedIndex - 1 + $WeaponOptions.Count) % $WeaponOptions.Count
            }
            37 { # Left
                $selectedIndex = ($selectedIndex - 1 + $WeaponOptions.Count) % $WeaponOptions.Count
            }
            40 { # Down
                $selectedIndex = ($selectedIndex + 1) % $WeaponOptions.Count
            }
            39 { # Right
                $selectedIndex = ($selectedIndex + 1) % $WeaponOptions.Count
            }
            13 { # Enter
                return $selectedIndex
            }
            81 { # Q
                return -1
            }
        }
    }
}

function Set-HeroWeapon {
    Param(
        [Hero]$Hero
    )

    $weaponOptions = @(Get-HeroWeaponOptions -Hero $Hero)

    $selectedIndex = Select-WeaponWithCursor -WeaponOptions $weaponOptions
    if ($null -eq $selectedIndex) {
        Clear-GameScreen
        Write-Host 'Choose your weapon:' -ForegroundColor White
        for ($i = 0; $i -lt $weaponOptions.Count; $i++) {
            $index = $i + 1
            $weaponData = Get-Weapon -WeaponName $weaponOptions[$i]
            $weaponName = Format-WeaponLabel -WeaponName $weaponData.Name
            Write-Host "$index. $weaponName ($($weaponData.MinDamage)-$($weaponData.MaxDamage))"
        }

        $validChoices = @()
        for ($i = 1; $i -le $weaponOptions.Count; $i++) {
            $validChoices += $i.ToString()
        }
        $validChoices += 'Q'

        if (Get-Command Read-SingleKeyChoice -ErrorAction SilentlyContinue) {
            $selected = Read-SingleKeyChoice -ValidChoices $validChoices -Prompt 'Choose weapon key' -OptionLabels (($weaponOptions | ForEach-Object { Format-WeaponLabel -WeaponName $_ }) + @('Cancel'))
        }
        else {
            $selected = Read-Host 'Selection (number or Q to cancel)'
        }

        if ([string]::Equals([string]$selected, 'Q', [System.StringComparison]::OrdinalIgnoreCase)) {
            return 'Weapon selection cancelled.'
        }

        if ($selected -as [int]) {
            $selectedIndex = [int]$selected - 1
        }
    }

    if ($selectedIndex -eq -1) {
        return 'Weapon selection cancelled.'
    }

    if ($selectedIndex -ge 0 -and $selectedIndex -lt $weaponOptions.Count) {
        $weapon = Get-Weapon -WeaponName $weaponOptions[$selectedIndex]
        Equip-Weapon -Hero $Hero -Weapon $weapon
        return "$($Hero.Name) equipped $($Hero.Weapon)."
    }

    'Invalid weapon selection.'
}
