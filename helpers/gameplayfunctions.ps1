function New-Enemy {
    Param(
        [int]$Floor
    )

    if (($Floor % 5) -eq 0) {
        return New-BossEnemy -Floor $Floor
    }

    if ($Floor -lt 3) {
        $health = 18 + ($Floor * 3)
        return [Skeleton]::new("Skeleton Floor $Floor", $health)
    }

    $health = 70 + ($Floor * 5)
    return [Orc]::new("Orc Brute Floor $Floor", $health)
}

function New-BossEnemy {
    Param(
        [int]$Floor
    )

    $health = 140 + ($Floor * 12)
    $boss = [Orc]::new("Warlord of Floor $Floor", $health)
    $boss.IsBoss = $true
    $boss.DamageModifier = 1.2 + (($Floor / 10.0))
    $boss.HealModifier = 1.1 + (($Floor / 20.0))
    return $boss
}

function Grant-VictoryRewards {
    Param(
        [Hero]$Hero,
        [int]$Floor,
        $Enemy
    )

    $goldReward = Get-Random -Minimum (2 + $Floor) -Maximum (6 + ($Floor * 2))
    $Hero.Gold += $goldReward
    Write-Host "You recovered $goldReward gold from the fallen enemy."

    $xpReward = Get-ExperienceReward -Enemy $Enemy -Floor $Floor
    Add-HeroExperience -Hero $Hero -ExperienceGained $xpReward

    if ((Get-Random -Minimum 1 -Maximum 101) -le 30) {
        $Hero.Potions += 1
        Write-Host 'You found a healing potion.'
    }
}

function Get-ExperienceReward {
    Param(
        $Enemy,
        [int]$Floor
    )

    $base = switch ($Enemy.GetType().Name) {
        'Skeleton' { 5 }
        'Orc' { 10 }
        default { 4 }
    }

    $base + [Math]::Floor($Floor / 2)
}

function Get-ExperienceForNextLevel {
    Param(
        [int]$Level
    )

    10 + (($Level - 1) * 5)
}

function Add-HeroExperience {
    Param(
        [Hero]$Hero,
        [int]$ExperienceGained,
        [int]$PerkChoice
    )

    if ($ExperienceGained -le 0) {
        return
    }

    $Hero.Experience += $ExperienceGained
    Write-Host "$($Hero.Name) gained $ExperienceGained XP."

    while ($Hero.Experience -ge (Get-ExperienceForNextLevel -Level $Hero.Level)) {
        $required = Get-ExperienceForNextLevel -Level $Hero.Level
        $Hero.Experience -= $required
        $Hero.Level += 1
        $Hero.MaxHealth += 10
        $Hero.Health = $Hero.MaxHealth
        Write-Host "LEVEL UP! You are now level $($Hero.Level). Health fully restored to $($Hero.MaxHealth)." -ForegroundColor Green
        if ($PSBoundParameters.ContainsKey('PerkChoice')) {
            Grant-LevelPerk -Hero $Hero -PerkChoice $PerkChoice
        }
        else {
            Grant-LevelPerk -Hero $Hero
        }
    }
}

function Grant-LevelPerk {
    Param(
        [Hero]$Hero,
        [int]$PerkChoice = 0
    )

    $selectedPerk = $PerkChoice
    if ($selectedPerk -le 0) {
        $selectedPerk = Select-HeroPerkChoice -Hero $Hero
    }

    switch ($selectedPerk) {
        1 {
            $Hero.CritChance += 5
            $Hero.BonusDamage += 1
            Write-Host "Perk: Brutality (+5% crit, +1 base damage)."
        }

        2 {
            $Hero.DodgeChance += 5
            $Hero.MaxHealth += 5
            $Hero.Health = $Hero.MaxHealth
            Write-Host "Perk: Survivor (+5% dodge, +5 max health)."
        }

        3 {
            $Hero.HealPowerModifier = [Math]::Round($Hero.HealPowerModifier + 0.2, 2)
            $Hero.Potions += 1
            Write-Host "Perk: Alchemist (+20% healing, +1 potion)."
        }

        Default {
            $Hero.CritChance += 5
            $Hero.BonusDamage += 1
            Write-Host "Perk fallback: Brutality (+5% crit, +1 base damage)."
        }
    }
}

function Select-HeroPerkChoice {
    Param(
        [Hero]$Hero
    )

    Write-Host @"
Choose a level perk:
1. Brutality  (+5% crit chance, +1 base damage)
2. Survivor   (+5% dodge chance, +5 max health)
3. Alchemist  (+20% healing power, +1 potion)
"@
    $choice = Read-Host 'Select perk'

    if ($choice -as [int]) {
        $parsed = [int]$choice
        if ($parsed -ge 1 -and $parsed -le 3) {
            return $parsed
        }
    }

    Write-Host 'Invalid perk selection. Defaulting to Brutality.'
    return 1
}

function Search-Floor {
    Param(
        [Hero]$Hero,
        [int]$Floor
    )

    $roll = Get-Random -Minimum 1 -Maximum 101

    if ($roll -le 45) {
        $goldFound = Get-Random -Minimum 1 -Maximum (4 + $Floor)
        $Hero.Gold += $goldFound
        Write-Host "You searched the floor and found $goldFound gold."
        return
    }

    if ($roll -le 70) {
        $Hero.Potions += 1
        Write-Host 'You found a dusty potion vial and packed it into your bag.'
        return
    }

    Write-Host 'You search for a while but find nothing useful.'
}
