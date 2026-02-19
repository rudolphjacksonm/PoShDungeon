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

    It 'Spawns a boss on every 5th floor with boosted modifiers' {
        $enemy = New-Enemy -Floor 5

        $enemy.IsBoss | Should -BeTrue
        $enemy.Name | Should -Match 'Warlord'
        $enemy.DamageModifier | Should -BeGreaterThan 1
        $enemy.HealModifier | Should -BeGreaterThan 1
    }
}
