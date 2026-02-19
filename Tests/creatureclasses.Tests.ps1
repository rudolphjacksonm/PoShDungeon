BeforeAll {
    $repoRoot = (Resolve-Path "$PSScriptRoot/..").Path
    . "$repoRoot/classes.ps1"
}

Describe 'Hero Class' {
    It 'Creates a hero with the provided name' {
        $hero = [Hero]::new('Jack')

        $hero | Should -Not -BeNullOrEmpty
        $hero.Name | Should -Be 'Jack'
        $hero.Status | Should -Be 'Alive'
    }

    It 'Starts with zero gold and zero potions by default' {
        $hero = [Hero]::new('Jack')

        $hero.Gold | Should -Be 0
        $hero.Potions | Should -Be 0
    }
}
