BeforeAll {
    $repoRoot = (Resolve-Path "$PSScriptRoot/..").Path
    . "$repoRoot/classes.ps1"
    . "$repoRoot/helpers/gameplayfunctions.ps1"
}

Describe 'Gameplay Progression Helpers' {
    It 'Calculates increasing XP thresholds by level' {
        (Get-ExperienceForNextLevel -Level 1) | Should -Be 10
        (Get-ExperienceForNextLevel -Level 2) | Should -Be 15
        (Get-ExperienceForNextLevel -Level 3) | Should -Be 20
    }

    It 'Levels up hero and restores health when enough XP is gained' {
        $hero = [Hero]::new('Ari')
        $hero.Health = 20

        Add-HeroExperience -Hero $hero -ExperienceGained 10 -PerkChoice 1

        $hero.Level | Should -Be 2
        $hero.Experience | Should -Be 0
        $hero.MaxHealth | Should -Be 90
        $hero.Health | Should -Be 90
        $hero.CritChance | Should -Be 10
    }

    It 'Carries surplus XP after leveling up' {
        $hero = [Hero]::new('Ari')

        Add-HeroExperience -Hero $hero -ExperienceGained 13 -PerkChoice 2

        $hero.Level | Should -Be 2
        $hero.Experience | Should -Be 3
        $hero.DodgeChance | Should -Be 5
    }

    It 'Unlocks weapons as the hero levels up' {
        $hero = [Hero]::new('Ari')

        $hero.UnlockedWeapons | Should -Be @('Broken_Shortsword')

        Add-HeroExperience -Hero $hero -ExperienceGained 10 -PerkChoice 1

        $hero.Level | Should -Be 2
        $hero.UnlockedWeapons | Should -Contain 'Short_Sword'
        $hero.UnlockedWeapons | Should -Not -Contain 'Long_Sword'

        Add-HeroExperience -Hero $hero -ExperienceGained 100 -PerkChoice 1

        $hero.Level | Should -BeGreaterOrEqual 5
        $hero.UnlockedWeapons | Should -Contain 'Hatchet'
        $hero.UnlockedWeapons | Should -Contain 'Long_Sword'
        $hero.UnlockedWeapons | Should -Contain 'Zweihander'
    }

    It 'Spawns a boss on every 5th floor with boosted modifiers' {
        $enemy = New-Enemy -Floor 5

        $enemy.IsBoss | Should -BeTrue
        $enemy.Name | Should -Match 'Warlord'
        $enemy.DamageModifier | Should -BeGreaterThan 1
        $enemy.HealModifier | Should -BeGreaterThan 1
    }

    It 'Keeps floor 2 as a skeleton encounter' {
        $enemy = New-Enemy -Floor 2

        $enemy.GetType().Name | Should -Be 'Skeleton'
        $enemy.Name | Should -Match 'Skeleton'
    }

    It 'Smooths floor 3 and 4 orc stats to avoid a sudden spike' {
        $floor3Enemy = New-Enemy -Floor 3
        $floor4Enemy = New-Enemy -Floor 4

        $floor3Enemy.Name | Should -Match 'Orc Raider'
        $floor3Enemy.MaxHealth | Should -Be 36
        $floor3Enemy.DamageModifier | Should -BeLessThan 1

        $floor4Enemy.Name | Should -Match 'Orc Raider'
        $floor4Enemy.MaxHealth | Should -Be 56
        $floor4Enemy.DamageModifier | Should -BeLessThan 1
    }

    It 'Provides floor 3 entry aid to smooth first orc encounter' {
        $hero = [Hero]::new('Ari')
        $hero.Health = 20
        $hero.Potions = 0

        Grant-FloorEntryAid -Hero $hero -Floor 3

        $hero.Health | Should -Be $hero.MaxHealth
        $hero.Potions | Should -Be 2
    }

    It 'Seeds run state with bounded floor count and valid shop floor' {
        $state = Initialize-RunState -MinimumFloors 8 -MaximumFloors 10

        $state.MaxFloors | Should -BeGreaterOrEqual 8
        $state.MaxFloors | Should -BeLessOrEqual 10
        $state.ShopFloor | Should -BeGreaterThan 3
        $state.ShopFloor | Should -BeLessOrEqual $state.MaxFloors
        $state.Floors.Keys.Count | Should -Be $state.MaxFloors
        $state.ShopStock.Count | Should -Be 3
    }

    It 'Depletes seeded floor loot through search and then reports empty floor' {
        $hero = [Hero]::new('Ari')
        $state = @{
            Floors = @{
                1 = @{
                    SearchLoot = @(
                        @{ Type = 'Gold'; Amount = 4 },
                        @{ Type = 'Potion'; Amount = 1 }
                    )
                }
            }
        }

        $script:messages = @()
        function Add-UiMessage { Param([string]$Message) $script:messages += $Message }

        Search-Floor -Hero $hero -Floor 1 -RunState $state
        Search-Floor -Hero $hero -Floor 1 -RunState $state
        Search-Floor -Hero $hero -Floor 1 -RunState $state

        Remove-Item Function:\Add-UiMessage

        $hero.Gold | Should -Be 4
        $hero.Potions | Should -Be 1
        @( $state.Floors[1].SearchLoot ).Count | Should -Be 0
        ($script:messages -join ' ') | Should -Match 'picked clean'
    }

    It 'Only triggers the shop once on the seeded shop floor' {
        $state = @{
            ShopFloor = 6
            ShopVisited = $false
        }

        (Should-TriggerShopEncounter -RunState $state -Floor 5) | Should -BeFalse
        (Should-TriggerShopEncounter -RunState $state -Floor 6) | Should -BeTrue

        $state.ShopVisited = $true
        (Should-TriggerShopEncounter -RunState $state -Floor 6) | Should -BeFalse
    }

    It 'Blocks unaffordable shop purchases and keeps stock unsold' {
        $hero = [Hero]::new('Ari')
        $hero.Gold = 10
        $state = @{
            ShopVisited = $false
            ShopStock = @(
                @{
                    Id = 1
                    Name = 'Atomic Bomb'
                    Type = 'Weapon'
                    WeaponName = 'Atomic_Bomb'
                    Price = 999
                    Sold = $false
                }
            )
        }

        $script:messages = @()
        $script:shopCalls = 0
        function Add-UiMessage { Param([string]$Message) $script:messages += $Message }
        function Read-SingleKeyChoice {
            $script:shopCalls += 1
            if ($script:shopCalls -eq 1) { return '1' }
            return 'Q'
        }

        Invoke-ShopEncounter -Hero $hero -RunState $state -Floor 6

        Remove-Item Function:\Add-UiMessage
        Remove-Item Function:\Read-SingleKeyChoice

        $hero.Gold | Should -Be 10
        $state.ShopStock[0].Sold | Should -BeFalse
        ($script:messages -join ' ') | Should -Match 'cannot afford'
        $state.ShopVisited | Should -BeTrue
    }
}
