function Get-HealthBar {
    Param(
        [int]$Current,
        [int]$Maximum,
        [int]$Width = 20
    )

    if ($Maximum -le 0) {
        $Maximum = [Math]::Max($Current, 1)
    }

    $ratio = [Math]::Min([Math]::Max(($Current / [double]$Maximum), 0), 1)
    $filled = [Math]::Floor($ratio * $Width)
    $empty = $Width - $filled

    ('#' * $filled) + ('-' * $empty)
}

function Get-BattleWindow {
    Param(
        $Attacker,
        $Defender,
        [int]$Turn,
        [string]$LastEvent
    )

    Clear-GameScreen

    $attackerBar = Get-HealthBar -Current $Attacker.Health -Maximum $Attacker.MaxHealth
    $defenderBar = Get-HealthBar -Current $Defender.Health -Maximum $Defender.MaxHealth

    Write-Host '====================== BATTLE ======================' -ForegroundColor DarkGray
    Write-Host "Turn: $Turn" -ForegroundColor Gray

    if ($LastEvent) {
        Write-Host "Last: $LastEvent" -ForegroundColor Yellow
    }

    Write-Host ''
    Write-Host ("{0,-18} HP {1,4}/{2,-4} [{3}]" -f $Attacker.Name, $Attacker.Health, $Attacker.MaxHealth, $attackerBar) -ForegroundColor Cyan
    Write-Host ("{0,-18} HP {1,4}/{2,-4} [{3}]" -f $Defender.Name, $Defender.Health, $Defender.MaxHealth, $defenderBar) -ForegroundColor Red
    Write-Host '====================================================' -ForegroundColor DarkGray
}

function Battle {
    Param(
        [Parameter(Mandatory = $true)]
        $Attacker,
        [Parameter(Mandatory = $true)]
        $Defender,
        [bool]$Ambush = $false
    )

    if (($Attacker.Health -le 0) -or ($Defender.Health -le 0)) {
        Write-Host 'Cannot fight, one of these creatures is already dead.' -ForegroundColor DarkYellow
        return
    }

    $attackerIsHero = $Attacker.GetType().Name -eq 'Hero'
    $enemyGoesFirst = $Ambush -or (-not $attackerIsHero)
    $turn = 1
    $lastEvent = if ($enemyGoesFirst) { 'Ambush! Enemy acts first.' } else { 'Battle started.' }

    :battle while (($Attacker.Health -gt 0) -and ($Defender.Health -gt 0)) {
        Get-BattleWindow -Attacker $Attacker -Defender $Defender -Turn $turn -LastEvent $lastEvent

        if ($enemyGoesFirst) {
            $lastEvent = Invoke-EnemyTurn -Enemy $Attacker -Target $Defender
            if ($Defender.Health -le 0) { break }

            Get-BattleWindow -Attacker $Attacker -Defender $Defender -Turn $turn -LastEvent $lastEvent
            $heroAction = Invoke-HeroTurn -Hero $Defender -Enemy $Attacker
            $lastEvent = $heroAction.Message

            if (-not $heroAction.Continue) { break battle }
        }
        else {
            $heroAction = Invoke-HeroTurn -Hero $Attacker -Enemy $Defender
            $lastEvent = $heroAction.Message

            if (-not $heroAction.Continue) { break battle }
            if ($Defender.Health -le 0) { break }

            Get-BattleWindow -Attacker $Attacker -Defender $Defender -Turn $turn -LastEvent $lastEvent
            $lastEvent = Invoke-EnemyTurn -Enemy $Defender -Target $Attacker
        }

        $turn += 1
    }

    Get-BattleWindow -Attacker $Attacker -Defender $Defender -Turn $turn -LastEvent $lastEvent
    Write-Host '[BATTLE END]' -ForegroundColor DarkGray
    Pause-ForContinue
}

function Invoke-HeroTurn {
    Param(
        [Hero]$Hero,
        $Enemy
    )

    Write-Host ''
    Write-Host 'Actions: [1] Attack  [2] Heal  [3] Run' -ForegroundColor White

    if (Get-Command Read-SingleKeyChoice -ErrorAction SilentlyContinue) {
        $action = Read-SingleKeyChoice -ValidChoices @('1', '2', '3') -Prompt 'Choose action key:'
    }
    else {
        $action = Read-Host 'Choose action key (1/2/3)'
    }

    switch ($action) {
        '1' {
            $heroDamage = Get-HeroDamage -Hero $Hero
            $heroDamage += $Hero.BonusDamage

            if ((Get-Random -Minimum 1 -Maximum 101) -le $Hero.CritChance) {
                $heroDamage *= 2
                $Enemy.Hit($heroDamage)
                return [PSCustomObject]@{ Continue = $true; Message = "CRITICAL HIT! $($Hero.Name) dealt $heroDamage." }
            }

            $Enemy.Hit($heroDamage)
            return [PSCustomObject]@{ Continue = $true; Message = "$($Hero.Name) attacked for $heroDamage." }
        }

        '2' {
            $healPoints = Get-Heal -Character $Hero
            $healPoints = [Math]::Max(1, [Math]::Floor($healPoints * $Hero.HealPowerModifier))
            $Hero.Heal($healPoints)
            return [PSCustomObject]@{ Continue = $true; Message = "$($Hero.Name) healed for $healPoints." }
        }

        '3' {
            return [PSCustomObject]@{ Continue = $false; Message = "$($Hero.Name) fled the battle." }
        }

        Default {
            return [PSCustomObject]@{ Continue = $true; Message = 'Invalid action. Turn spent hesitating.' }
        }
    }
}

function Invoke-EnemyTurn {
    Param(
        $Enemy,
        $Target
    )

    $enemyAction = Get-EnemyAction -Enemy $Enemy

    switch ($enemyAction) {
        'Attack' {
            $damage = Get-Damage -Character $Enemy
            if (($Target.GetType().Name -eq 'Hero') -and ((Get-Random -Minimum 1 -Maximum 101) -le $Target.DodgeChance)) {
                return "$($Target.Name) dodged the attack from $($Enemy.Name)!"
            }
            $Target.Hit($damage)
            return "$($Enemy.Name) attacked for $damage."
        }

        'Heal' {
            $healPoints = Get-Heal -Character $Enemy
            $Enemy.Heal($healPoints)
            return "$($Enemy.Name) healed for $healPoints."
        }

        'PiercingStrike' {
            $damage = (Get-Damage -Character $Enemy) + 2
            if (($Target.GetType().Name -eq 'Hero') -and ((Get-Random -Minimum 1 -Maximum 101) -le $Target.DodgeChance)) {
                return "$($Target.Name) dodged Piercing Strike!"
            }
            $Target.Hit($damage)
            return "$($Enemy.Name) used Piercing Strike for $damage."
        }

        'CrushingBlow' {
            if ((Get-Random -Minimum 1 -Maximum 101) -le 25) {
                return "$($Enemy.Name) missed Crushing Blow."
            }

            $damage = (Get-Damage -Character $Enemy) + 6
            if (($Target.GetType().Name -eq 'Hero') -and ((Get-Random -Minimum 1 -Maximum 101) -le $Target.DodgeChance)) {
                return "$($Target.Name) dodged Crushing Blow!"
            }

            $Target.Hit($damage)
            return "$($Enemy.Name) landed Crushing Blow for $damage."
        }
    }
}

function Get-EnemyAction {
    Param(
        $Enemy,
        [int]$Roll
    )

    if ($Roll -le 0) {
        $roll = Get-Random -Minimum 1 -Maximum 101
    }
    else {
        $roll = $Roll
    }

    switch ($Enemy.GetType().Name) {
        'Skeleton' {
            if ($roll -le 60) { return 'Attack' }
            if ($roll -le 80) { return 'PiercingStrike' }
            return 'Heal'
        }

        'Orc' {
            if ($roll -le 50) { return 'Attack' }
            if ($roll -le 85) { return 'CrushingBlow' }
            return 'Heal'
        }

        default {
            if ($roll -le 70) { return 'Attack' }
            return 'Heal'
        }
    }
}

Function Get-Damage {
    Param(
        $Character
    )

    switch ($Character.GetType().Name) {
        Orc {
            $damage = Get-Random -Minimum 3 -Maximum 26
        }

        Skeleton {
            $damage = Get-Random -Minimum 2 -Maximum 16
        }

        Default {
            $damage = Get-Random -Minimum 1 -Maximum 6
        }
    }

    $damage = [Math]::Max(1, [Math]::Floor($damage * $Character.DamageModifier))
    $damage
}

Function Get-Heal {
    Param(
        $Character
    )

    $healpoints = Get-Random -Minimum 2 -Maximum 7
    if ($null -ne $Character) {
        $healpoints = [Math]::Max(1, [Math]::Floor($healpoints * $Character.HealModifier))
    }
    $healpoints
}

Function Get-HeroDamage {
    Param(
        [Hero]$Hero
    )

    if ($null -ne $Hero.WeaponStats) {
        return Get-Random -Minimum $Hero.WeaponStats.MinDamage -Maximum ($Hero.WeaponStats.MaxDamage + 1)
    }

    Get-Random -Minimum 1 -Maximum 4
}
