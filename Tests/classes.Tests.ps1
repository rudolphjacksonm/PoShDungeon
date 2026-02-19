BeforeAll {
    $repoRoot = (Resolve-Path "$PSScriptRoot/..").Path
    . "$repoRoot/classes.ps1"
}

Describe 'Creature Classes' {
    Context 'Instantiation' {
        It 'Creates base Creature' {
            $creature = [Creature]::new()
            $creature | Should -Not -BeNullOrEmpty
        }

        It 'Creates Orc' {
            $orc = [Orc]::new()
            $orc | Should -Not -BeNullOrEmpty
        }

        It 'Creates Human' {
            $human = [Human]::new()
            $human | Should -Not -BeNullOrEmpty
        }

        It 'Creates Skeleton' {
            $skeleton = [Skeleton]::new()
            $skeleton | Should -Not -BeNullOrEmpty
        }
    }

    Context 'State changes' {
        It 'Sets creature state to Dead when health falls to 0 or less' {
            $creature = [Creature]::new()
            $creature.Health = 10

            $creature.Hit(12)

            $creature.Status | Should -Be 'Dead'
            $creature.Health | Should -Be 0
        }

        It 'Heals creature by expected amount' {
            $creature = [Creature]::new()
            $creature.Health = 100

            $creature.Heal(10)

            $creature.Health | Should -Be 110
        }
    }
}
