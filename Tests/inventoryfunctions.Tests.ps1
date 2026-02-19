BeforeAll {
    $repoRoot = (Resolve-Path "$PSScriptRoot/..").Path
    . "$repoRoot/classes.ps1"
    . "$repoRoot/helpers/inventoryfunctions.ps1"
}

Describe 'Weapon and Inventory Helpers' {
    It 'Builds a valid weapon hashtable' {
        $weapon = Get-Weapon -WeaponName 'Short_Sword'

        $weapon.Name | Should -Be 'Short_Sword'
        $weapon.MinDamage | Should -BeGreaterThan 0
        $weapon.MaxDamage | Should -BeGreaterThan $weapon.MinDamage
    }

    It 'Equips a weapon onto a hero' {
        $hero = [Hero]::new('Jane')
        $weapon = Get-Weapon -WeaponName 'Hatchet'

        Equip-Weapon -Hero $hero -Weapon $weapon

        $hero.Weapon | Should -Be 'Hatchet'
        $hero.WeaponStats.MinDamage | Should -Be 5
        $hero.WeaponStats.MaxDamage | Should -Be 7
    }
}
