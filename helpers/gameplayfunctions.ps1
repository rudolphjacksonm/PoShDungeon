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

function New-FloorLootPool {
    Param(
        [int]$Floor
    )

    $lootCount = Get-Random -Minimum 1 -Maximum 4
    $lootPool = @()

    for ($i = 0; $i -lt $lootCount; $i++) {
        $roll = Get-Random -Minimum 1 -Maximum 101
        if ($roll -le 55) {
            $goldFound = Get-Random -Minimum 1 -Maximum (4 + $Floor)
            $lootPool += @{ Type = 'Gold'; Amount = $goldFound }
            continue
        }

        if ($roll -le 95) {
            $lootPool += @{ Type = 'Potion'; Amount = 1 }
            continue
        }

        $bonusXp = Get-Random -Minimum 2 -Maximum 6
        $lootPool += @{ Type = 'XP'; Amount = $bonusXp }
    }

    $lootPool
}

function Get-ShopCatalog {
    @(
        @{
            Id = 1
            Name = 'Laser Rifle'
            Type = 'Weapon'
            WeaponName = 'Laser_Rifle'
            Price = 250
            Description = 'A humming relic that burns brighter than torchlight.'
        },
        @{
            Id = 2
            Name = 'Atomic Bomb'
            Type = 'Weapon'
            WeaponName = 'Atomic_Bomb'
            Price = 999
            Description = 'Absolutely unsafe in enclosed spaces.'
        },
        @{
            Id = 3
            Name = 'Titanium Bathrobe'
            Type = 'Armor'
            ArmorName = 'Titanium_Bathrobe'
            Price = 180
            Description = 'Extremely impractical, undeniably stylish.'
        },
        @{
            Id = 4
            Name = 'Potion Crate'
            Type = 'PotionPack'
            PotionCount = 5
            Price = 140
            Description = 'A suspicious crate full of glowing vials.'
        },
        @{
            Id = 5
            Name = 'Moonblade'
            Type = 'Weapon'
            WeaponName = 'Moonblade'
            Price = 320
            Description = 'A crescent blade forged for impossible odds.'
        }
    )
}

function Get-RandomShopStock {
    Param(
        [int]$ItemCount = 3
    )

    $catalog = @(Get-ShopCatalog)
    $maxItems = [Math]::Min($ItemCount, $catalog.Count)
    $stock = @()
    $usedIndexes = @{}

    while ($stock.Count -lt $maxItems) {
        $candidate = Get-Random -Minimum 0 -Maximum $catalog.Count
        if ($usedIndexes.ContainsKey($candidate)) {
            continue
        }

        $usedIndexes[$candidate] = $true
        $item = $catalog[$candidate].Clone()
        $item.Sold = $false
        $stock += $item
    }

    $stock
}

function Initialize-RunState {
    Param(
        [int]$MinimumFloors = 10,
        [int]$MaximumFloors = 16
    )

    if ($MinimumFloors -lt 6) {
        $MinimumFloors = 6
    }
    if ($MaximumFloors -lt $MinimumFloors) {
        $MaximumFloors = $MinimumFloors
    }

    $maxFloors = Get-Random -Minimum $MinimumFloors -Maximum ($MaximumFloors + 1)
    $shopFloor = Get-Random -Minimum 4 -Maximum ($maxFloors + 1)
    $floors = @{}

    for ($floor = 1; $floor -le $maxFloors; $floor++) {
        $floors[$floor] = @{
            SearchLoot = @(New-FloorLootPool -Floor $floor)
        }
    }

    @{
        MaxFloors = $maxFloors
        Floors = $floors
        ShopFloor = $shopFloor
        ShopVisited = $false
        ShopStock = @(Get-RandomShopStock -ItemCount 3)
    }
}

function Get-RemainingFloorLootCount {
    Param(
        [hashtable]$RunState,
        [int]$Floor
    )

    if ($null -eq $RunState -or -not $RunState.ContainsKey('Floors')) {
        return 0
    }
    if (-not $RunState.Floors.ContainsKey($Floor)) {
        return 0
    }

    @($RunState.Floors[$Floor].SearchLoot).Count
}

function Should-TriggerShopEncounter {
    Param(
        [hashtable]$RunState,
        [int]$Floor
    )

    if ($null -eq $RunState) {
        return $false
    }
    if ($RunState.ShopVisited) {
        return $false
    }

    ($Floor -eq $RunState.ShopFloor)
}

function Apply-ShopPurchase {
    Param(
        $Hero,
        [hashtable]$Item
    )

    switch ($Item.Type) {
        'Weapon' {
            if ($Hero.UnlockedWeapons -notcontains $Item.WeaponName) {
                $Hero.UnlockedWeapons += $Item.WeaponName
            }
            Write-GameMessage -Message "Purchased: $($Item.Name). It is now available in your weapon inventory."
        }

        'Armor' {
            $Hero.Armor = $Item.ArmorName
            Write-GameMessage -Message "Purchased: $($Item.Name). You equip it immediately."
        }

        'PotionPack' {
            $Hero.Potions += [int]$Item.PotionCount
            Write-GameMessage -Message "Purchased: $($Item.Name). Potions +$($Item.PotionCount)."
        }
    }
}

function Invoke-ShopEncounter {
    Param(
        $Hero,
        [hashtable]$RunState,
        [int]$Floor
    )

    if ($null -eq $RunState -or $RunState.ShopVisited) {
        return
    }

    $RunState.ShopVisited = $true
    Write-GameMessage -Message "A neon-lit stall appears on floor $Floor. The shopkeeper grins."
    Write-GameMessage -Message "'Welcome, hero. Everything here is slightly overpriced.'"

    :shopLoop while ($true) {
        $available = @($RunState.ShopStock | Where-Object { -not $_.Sold })
        if ($available.Count -eq 0) {
            Write-GameMessage -Message 'The shopkeeper shrugs. "Sold out. Come back next apocalypse."'
            break
        }

        $labels = @()
        $choices = @()
        foreach ($item in $available) {
            $choices += [string]$item.Id
            $labels += "$($item.Name) - $($item.Price)g"
        }
        $choices += 'Q'
        $labels += 'Leave shop'

        $selected = Read-SingleKeyChoice -ValidChoices $choices -Prompt 'Shop action' -OptionLabels $labels
        if ($selected -eq 'Q') {
            Write-GameMessage -Message 'You leave the shop and continue deeper.'
            break
        }

        $selectedId = [int]$selected
        $itemToBuy = $available | Where-Object { $_.Id -eq $selectedId } | Select-Object -First 1
        if ($null -eq $itemToBuy) {
            Write-GameMessage -Message 'The shopkeeper squints. "That item is not on this shelf."'
            continue
        }

        if ($Hero.Gold -lt [int]$itemToBuy.Price) {
            $shortBy = [int]$itemToBuy.Price - $Hero.Gold
            Write-GameMessage -Message "You cannot afford $($itemToBuy.Name). Short by $shortBy gold."
            continue
        }

        $Hero.Gold -= [int]$itemToBuy.Price
        $itemToBuy.Sold = $true
        Apply-ShopPurchase -Hero $Hero -Item $itemToBuy
    }
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
        [int]$Floor,
        [hashtable]$RunState
    )

    if ($null -ne $RunState -and $RunState.ContainsKey('Floors') -and $RunState.Floors.ContainsKey($Floor)) {
        $lootRemaining = @( $RunState.Floors[$Floor].SearchLoot )
        if ($lootRemaining.Count -le 0) {
            Write-GameMessage -Message 'You search every corner, but this floor has already been picked clean.'
            return
        }

        $discovery = $lootRemaining[0]
        if ($lootRemaining.Count -eq 1) {
            $RunState.Floors[$Floor].SearchLoot = @()
        }
        else {
            $RunState.Floors[$Floor].SearchLoot = @($lootRemaining[1..($lootRemaining.Count - 1)])
        }

        switch ($discovery.Type) {
            'Gold' {
                $Hero.Gold += [int]$discovery.Amount
                Write-GameMessage -Message "You found $($discovery.Amount) gold."
            }

            'Potion' {
                $Hero.Potions += [int]$discovery.Amount
                Write-GameMessage -Message 'You found a dusty potion vial and packed it into your bag.'
            }

            'XP' {
                Write-GameMessage -Message 'You uncovered old battle notes and learned from them.'
                Add-HeroExperience -Hero $Hero -ExperienceGained ([int]$discovery.Amount)
            }

            default {
                Write-GameMessage -Message 'You found strange rubble. Nothing useful.'
            }
        }

        $remainingCount = Get-RemainingFloorLootCount -RunState $RunState -Floor $Floor
        if ($remainingCount -gt 0) {
            Write-GameMessage -Message "There are still $remainingCount hidden find(s) on this floor."
        }
        else {
            Write-GameMessage -Message 'No discoverable items remain on this floor.'
        }
        return
    }

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
