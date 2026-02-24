BeforeAll {
    $repoRoot = (Resolve-Path "$PSScriptRoot/..").Path
    . "$repoRoot/classes.ps1"
    . "$repoRoot/helpers/battlefunctions.ps1"
    . "$repoRoot/helpers/inventoryfunctions.ps1"
}

Describe 'Battle Helpers' {
    It 'Uses hero weapon stats when rolling hero damage' {
        $hero = [Hero]::new('Tess')
        $weapon = Get-Weapon -WeaponName 'Short_Sword'
        Equip-Weapon -Hero $hero -Weapon $weapon

        $rolls = 1..25 | ForEach-Object { Get-HeroDamage -Hero $hero }

        ($rolls | Measure-Object -Minimum).Minimum | Should -BeGreaterOrEqual 4
        ($rolls | Measure-Object -Maximum).Maximum | Should -BeLessOrEqual 10
    }

    It 'Returns a sensible fallback damage range with no weapon equipped' {
        $hero = [Hero]::new('Tess')

        $rolls = 1..25 | ForEach-Object { Get-HeroDamage -Hero $hero }

        ($rolls | Measure-Object -Minimum).Minimum | Should -BeGreaterOrEqual 2
        ($rolls | Measure-Object -Maximum).Maximum | Should -BeLessOrEqual 4
    }

    It 'Selects skeleton special action based on roll' {
        $skeleton = [Skeleton]::new('Bones', 20)
        Get-EnemyAction -Enemy $skeleton -Roll 75 | Should -Be 'PiercingStrike'
    }

    It 'Selects orc special action based on roll' {
        $orc = [Orc]::new('Brute', 100)
        Get-EnemyAction -Enemy $orc -Roll 80 | Should -Be 'CrushingBlow'
    }

    It 'Consumes a potion when healing in combat' {
        $hero = [Hero]::new('Tess')
        $hero.Health = 20
        $hero.Potions = 1
        $enemy = [Skeleton]::new('Bones', 20)

        function Read-SingleKeyChoice { '2' }
        $result = Invoke-HeroTurn -Hero $hero -Enemy $enemy
        Remove-Item Function:\Read-SingleKeyChoice

        $result.Message | Should -Match 'drank a potion'
        $hero.Potions | Should -Be 0
        $hero.Health | Should -BeGreaterThan 20
    }

    It 'Does not heal in combat when no potions remain' {
        $hero = [Hero]::new('Tess')
        $hero.Health = 20
        $hero.Potions = 0
        $enemy = [Skeleton]::new('Bones', 20)

        function Read-SingleKeyChoice { '2' }
        $result = Invoke-HeroTurn -Hero $hero -Enemy $enemy
        Remove-Item Function:\Read-SingleKeyChoice

        $result.Message | Should -Be 'No potions left.'
        $hero.Health | Should -Be 20
    }

    It 'Supports higher heal modifiers for potion healing' {
        $hero = [Hero]::new('Tess')
        $hero.Health = 20
        $hero.Potions = 1
        $hero.HealPowerModifier = 2.0
        $enemy = [Skeleton]::new('Bones', 20)

        function Read-SingleKeyChoice { '2' }
        $result = Invoke-HeroTurn -Hero $hero -Enemy $enemy
        Remove-Item Function:\Read-SingleKeyChoice

        $result.Message | Should -Match 'drank a potion'
        $hero.Health | Should -BeGreaterThan 20
        $hero.Potions | Should -Be 0
    }

    It 'Persists flee messages to the UI log when a battle is escaped' {
        $hero = [Hero]::new('Tess')
        $enemy = [Skeleton]::new('Bones', 20)
        $script:loggedMessages = @()

        function Add-UiMessage { Param([string]$Message) $script:loggedMessages += $Message }
        function Get-BattleWindow {}
        function Invoke-HeroTurn {
            return [PSCustomObject]@{ Continue = $false; Message = 'Tess fled the battle.' }
        }

        Battle -Attacker $hero -Defender $enemy

        Remove-Item Function:\Add-UiMessage
        Remove-Item Function:\Get-BattleWindow
        Remove-Item Function:\Invoke-HeroTurn

        $script:loggedMessages | Should -Contain 'Tess fled the battle.'
    }
}
