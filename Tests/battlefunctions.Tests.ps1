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

        ($rolls | Measure-Object -Minimum).Minimum | Should -BeGreaterThanOrEqual 3
        ($rolls | Measure-Object -Maximum).Maximum | Should -BeLessThanOrEqual 9
    }

    It 'Returns a sensible fallback damage range with no weapon equipped' {
        $hero = [Hero]::new('Tess')

        $rolls = 1..25 | ForEach-Object { Get-HeroDamage -Hero $hero }

        ($rolls | Measure-Object -Minimum).Minimum | Should -BeGreaterThanOrEqual 1
        ($rolls | Measure-Object -Maximum).Maximum | Should -BeLessThanOrEqual 3
    }

    It 'Selects skeleton special action based on roll' {
        $skeleton = [Skeleton]::new('Bones', 20)
        Get-EnemyAction -Enemy $skeleton -Roll 75 | Should -Be 'PiercingStrike'
    }

    It 'Selects orc special action based on roll' {
        $orc = [Orc]::new('Brute', 100)
        Get-EnemyAction -Enemy $orc -Roll 80 | Should -Be 'CrushingBlow'
    }
}
