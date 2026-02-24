function Write-GameMessage {
    Param(
        [string]$Message,
        [string]$Color = 'Gray'
    )

    if (Get-Command Add-UiMessage -ErrorAction SilentlyContinue) {
        Add-UiMessage -Message $Message
        return
    }

    Write-Host $Message -ForegroundColor $Color
}

function New-Enemy {
    Param(
        [int]$Floor
    )

    if (($Floor % 5) -eq 0) {
        return New-BossEnemy -Floor $Floor
    }

    if ($Floor -lt 3) {
        $health = 18 + ($Floor * 3)
        return [Skeleton]::new('Skeleton Scout', $health)
    }

    if ($Floor -eq 3) {
        $orc = [Orc]::new('Orc Raider', 36)
        $orc.DamageModifier = 0.5
        $orc.HealModifier = 0.85
        return $orc
    }

    if ($Floor -eq 4) {
        $orc = [Orc]::new('Orc Raider', 56)
        $orc.DamageModifier = 0.8
        $orc.HealModifier = 0.9
        return $orc
    }

    $health = 62 + ($Floor * 6)
    return [Orc]::new('Orc Brute', $health)
}

function New-BossEnemy {
    Param(
        [int]$Floor
    )

    $health = 140 + ($Floor * 12)
    $boss = [Orc]::new('Warlord', $health)
    $boss.IsBoss = $true
    $boss.DamageModifier = 1.2 + (($Floor / 10.0))
    $boss.HealModifier = 1.1 + (($Floor / 20.0))
    return $boss
}

function Grant-VictoryRewards {
    Param(
        $Hero,
        [int]$Floor,
        $Enemy
    )

    $goldReward = Get-Random -Minimum (2 + $Floor) -Maximum (6 + ($Floor * 2))
    $Hero.Gold += $goldReward
    Write-GameMessage -Message "You recovered $goldReward gold from the fallen enemy."

    $xpReward = Get-ExperienceReward -Enemy $Enemy -Floor $Floor
    Add-HeroExperience -Hero $Hero -ExperienceGained $xpReward

    if ((Get-Random -Minimum 1 -Maximum 101) -le 30) {
        $Hero.Potions += 1
        Write-GameMessage -Message 'You found a healing potion.'
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
        $Hero,
        [int]$ExperienceGained,
        [int]$PerkChoice
    )

    if ($ExperienceGained -le 0) {
        return
    }

    $Hero.Experience += $ExperienceGained
    Write-GameMessage -Message "$($Hero.Name) gained $ExperienceGained XP."

    while ($Hero.Experience -ge (Get-ExperienceForNextLevel -Level $Hero.Level)) {
        $required = Get-ExperienceForNextLevel -Level $Hero.Level
        $Hero.Experience -= $required
        $Hero.Level += 1
        $Hero.MaxHealth += 10
        $Hero.Health = $Hero.MaxHealth
        Write-GameMessage -Message "LEVEL UP! You are now level $($Hero.Level). Health fully restored to $($Hero.MaxHealth)." -Color Green
        Unlock-HeroWeaponsForLevel -Hero $Hero
        if ($PSBoundParameters.ContainsKey('PerkChoice')) {
            Grant-LevelPerk -Hero $Hero -PerkChoice $PerkChoice
        }
        else {
            Grant-LevelPerk -Hero $Hero
        }
    }
}

function Unlock-HeroWeaponsForLevel {
    Param(
        $Hero,
        [int]$Level = 0
    )

    if ($Level -le 0) {
        $Level = $Hero.Level
    }

    if ($null -eq $Hero.UnlockedWeapons -or $Hero.UnlockedWeapons.Count -eq 0) {
        $Hero.UnlockedWeapons = @('Broken_Shortsword')
    }

    $unlockMilestones = @(
        @{ Level = 2; Weapon = 'Short_Sword' },
        @{ Level = 3; Weapon = 'Hatchet' },
        @{ Level = 4; Weapon = 'Long_Sword' },
        @{ Level = 5; Weapon = 'Zweihander' }
    )

    $newUnlocks = @()

    foreach ($milestone in $unlockMilestones) {
        if ($Level -ge $milestone.Level -and $Hero.UnlockedWeapons -notcontains $milestone.Weapon) {
            $Hero.UnlockedWeapons += $milestone.Weapon
            $newUnlocks += $milestone.Weapon
        }
    }

    if ($newUnlocks.Count -gt 0) {
        Write-GameMessage -Message "New weapon unlocked: $($newUnlocks -join ', ')." -Color Yellow
    }
}

function Grant-LevelPerk {
    Param(
        $Hero,
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
            Write-GameMessage -Message 'Perk: Brutality (+5% crit, +1 base damage).'
        }

        2 {
            $Hero.DodgeChance += 5
            $Hero.MaxHealth += 5
            $Hero.Health = $Hero.MaxHealth
            Write-GameMessage -Message 'Perk: Survivor (+5% dodge, +5 max health).'
        }

        3 {
            $Hero.HealPowerModifier = [Math]::Round($Hero.HealPowerModifier + 0.2, 2)
            $Hero.Potions += 1
            Write-GameMessage -Message 'Perk: Alchemist (+20% healing, +1 potion).'
        }

        Default {
            $Hero.CritChance += 5
            $Hero.BonusDamage += 1
            Write-GameMessage -Message 'Perk fallback: Brutality (+5% crit, +1 base damage).'
        }
    }
}

function Select-HeroPerkChoice {
    Param(
        $Hero
    )

    if (Get-Command Read-SingleKeyChoice -ErrorAction SilentlyContinue) {
        $choice = Read-SingleKeyChoice -ValidChoices @('1', '2', '3') -Prompt 'Choose a level perk' -OptionLabels @(
            'Brutality (+5% crit chance, +1 base damage)',
            'Survivor (+5% dodge chance, +5 max health)',
            'Alchemist (+20% healing power, +1 potion)'
        )

        if ($choice -as [int]) {
            return [int]$choice
        }
    }

    $choice = Read-Host 'Select perk (1/2/3)'
    if ($choice -as [int]) {
        $parsed = [int]$choice
        if ($parsed -ge 1 -and $parsed -le 3) {
            return $parsed
        }
    }

    Write-GameMessage -Message 'Invalid perk selection. Defaulting to Brutality.'
    return 1
}

function Search-Floor {
    Param(
        $Hero,
        [int]$Floor
    )

    $roll = Get-Random -Minimum 1 -Maximum 101

    if ($roll -le 45) {
        $goldFound = Get-Random -Minimum 1 -Maximum (4 + $Floor)
        $Hero.Gold += $goldFound
        Write-GameMessage -Message "You searched the floor and found $goldFound gold."
        return
    }

    if ($roll -le 70) {
        $Hero.Potions += 1
        Write-GameMessage -Message 'You found a dusty potion vial and packed it into your bag.'
        return
    }

    Write-GameMessage -Message 'You search for a while but find nothing useful.'
}

function Grant-FloorEntryAid {
    Param(
        $Hero,
        [int]$Floor
    )

    if ($Floor -ne 3) {
        return
    }

    $gaveAid = $false

    if ($Hero.Health -lt $Hero.MaxHealth) {
        $Hero.Health = $Hero.MaxHealth
        Write-GameMessage -Message 'A calm breath restores your strength before the raider ambush.' -Color Green
        $gaveAid = $true
    }

    if ($Hero.Potions -lt 2) {
        $potionsAdded = 2 - $Hero.Potions
        $Hero.Potions = 2
        Write-GameMessage -Message "You find $potionsAdded emergency potion(s) before the fight." -Color Green
        $gaveAid = $true
    }

    if ($gaveAid) {
        Write-GameMessage -Message 'You feel ready for the next challenge.' -Color DarkGreen
    }
}
