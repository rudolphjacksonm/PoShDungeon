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

    $attackerBar = Get-HealthBar -Current $Attacker.Health -Maximum $Attacker.MaxHealth
    $defenderBar = Get-HealthBar -Current $Defender.Health -Maximum $Defender.MaxHealth
    $statusLines = @(
        "Turn: $Turn",
        ("{0,-18} HP {1,4}/{2,-4} [{3}]" -f $Attacker.Name, $Attacker.Health, $Attacker.MaxHealth, $attackerBar),
        ("{0,-18} HP {1,4}/{2,-4} [{3}]" -f $Defender.Name, $Defender.Health, $Defender.MaxHealth, $defenderBar)
    )
    $infoLines = @()
    if (-not [string]::IsNullOrWhiteSpace($LastEvent)) {
        $infoLines += "Last: $LastEvent"
    }
    else {
        $infoLines += 'Last: ...'
    }

    Show-HudWindow -ModeTitle 'BATTLE' -StatusLines $statusLines -InfoLines $infoLines -InfoHeight 8
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

            $renderBattleFrame = {
                Get-BattleWindow -Attacker $Attacker -Defender $Defender -Turn $turn -LastEvent $lastEvent
            }
            $heroAction = Invoke-HeroTurn -Hero $Defender -Enemy $Attacker -RenderFrame $renderBattleFrame
            $lastEvent = $heroAction.Message

            if (-not $heroAction.Continue) {
                if (Get-Command Add-UiMessage -ErrorAction SilentlyContinue) {
                    Add-UiMessage -Message $lastEvent
                }
                break battle
            }
        }
        else {
            $renderBattleFrame = {
                Get-BattleWindow -Attacker $Attacker -Defender $Defender -Turn $turn -LastEvent $lastEvent
            }
            $heroAction = Invoke-HeroTurn -Hero $Attacker -Enemy $Defender -RenderFrame $renderBattleFrame
            $lastEvent = $heroAction.Message

            if (-not $heroAction.Continue) {
                if (Get-Command Add-UiMessage -ErrorAction SilentlyContinue) {
                    Add-UiMessage -Message $lastEvent
                }
                break battle
            }
            if ($Defender.Health -le 0) { break }

            Get-BattleWindow -Attacker $Attacker -Defender $Defender -Turn $turn -LastEvent $lastEvent
            $lastEvent = Invoke-EnemyTurn -Enemy $Defender -Target $Attacker
        }

        $turn += 1
    }

    Get-BattleWindow -Attacker $Attacker -Defender $Defender -Turn $turn -LastEvent $lastEvent
    Write-Host '[BATTLE END]' -ForegroundColor DarkGray
}

function Invoke-HeroTurn {
    Param(
        [Hero]$Hero,
        $Enemy,
        [scriptblock]$RenderFrame
    )

    if (Get-Command Read-SingleKeyChoice -ErrorAction SilentlyContinue) {
        $action = Read-SingleKeyChoice -ValidChoices @('1', '2', '3') -Prompt 'Choose battle action' -OptionLabels @('Attack', "Drink potion ($($Hero.Potions) left)", 'Run') -RenderFrame $RenderFrame
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
            if ($Hero.Potions -le 0) {
                return [PSCustomObject]@{ Continue = $true; Message = 'No potions left.' }
            }

            $healPoints = Get-Heal -Character $Hero
            $scaledHeal = [Math]::Round(($healPoints * [double]$Hero.HealPowerModifier), 0, [System.MidpointRounding]::AwayFromZero)
            $healPoints = [int][Math]::Max(1, $scaledHeal)
            $Hero.Heal($healPoints)
            $Hero.Potions -= 1
            return [PSCustomObject]@{ Continue = $true; Message = "$($Hero.Name) drank a potion and healed for $healPoints." }
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
        }

        'Orc' {
            if ($roll -le 50) { return 'Attack' }
            if ($roll -le 85) { return 'CrushingBlow' }
        }

        default {
            if ($roll -le 70) { return 'Attack' }
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
        $baseDamage = Get-Random -Minimum $Hero.WeaponStats.MinDamage -Maximum ($Hero.WeaponStats.MaxDamage + 1)
        return ($baseDamage + 1)
    }

    (Get-Random -Minimum 1 -Maximum 4) + 1
}
