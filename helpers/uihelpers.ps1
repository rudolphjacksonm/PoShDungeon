function Read-SingleKeyChoice {
    Param(
        [Parameter(Mandatory = $true)]
        [string[]]$ValidChoices,
        [string]$Prompt = 'Choose an option:',
        [string[]]$OptionLabels,
        [scriptblock]$RenderFrame
    )

    $normalized = $ValidChoices | ForEach-Object { $_.ToUpperInvariant() }
    if (($null -eq $OptionLabels) -or ($OptionLabels.Count -ne $normalized.Count)) {
        $OptionLabels = @($normalized)
    }

    $displayOptions = @()
    $labelAliasToChoice = @{}
    for ($i = 0; $i -lt $normalized.Count; $i++) {
        $choiceKey = $normalized[$i]
        $label = $OptionLabels[$i]
        $displayOptions += "$choiceKey=$label"

        $trimmedLabel = [string]$label
        if (-not [string]::IsNullOrWhiteSpace($trimmedLabel)) {
            $aliasChar = $trimmedLabel.Trim().Substring(0, 1).ToUpperInvariant()
            if ($labelAliasToChoice.ContainsKey($aliasChar)) {
                $labelAliasToChoice[$aliasChar] = $null
            }
            else {
                $labelAliasToChoice[$aliasChar] = $choiceKey
            }
        }
    }

    $useRawInput = $true
    $selectedIndex = 0
    $menuLineCount = $OptionLabels.Count + 1
    $canUseAnsiRedraw = $false

    try {
        if ($Host.UI.SupportsVirtualTerminal) {
            $canUseAnsiRedraw = $true
        }
    }
    catch {
        $canUseAnsiRedraw = $false
    }

    function Write-ArrowMenuLines {
        Param(
            [int]$CurrentIndex
        )

        Write-Host $Prompt -ForegroundColor Yellow
        for ($i = 0; $i -lt $OptionLabels.Count; $i++) {
            $prefix = if ($i -eq $CurrentIndex) { '>' } else { ' ' }
            $color = if ($i -eq $CurrentIndex) { 'Cyan' } else { 'Gray' }
            Write-Host "$prefix $($OptionLabels[$i])" -ForegroundColor $color
        }
    }

    function Show-ArrowMenuFrame {
        Param(
            [int]$CurrentIndex
        )

        if ($null -ne $RenderFrame) {
            & $RenderFrame
        }
        else {
            Clear-GameScreen
        }

        Write-ArrowMenuLines -CurrentIndex $CurrentIndex
    }

    while ($true) {
        if ($useRawInput) {
            try {
                Show-ArrowMenuFrame -CurrentIndex $selectedIndex

                while ($true) {
                    $keyInfo = $host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                    $virtualKey = $keyInfo.VirtualKeyCode
                    $character = [string]$keyInfo.Character

                    switch ($virtualKey) {
                        38 { $selectedIndex = ($selectedIndex - 1 + $normalized.Count) % $normalized.Count } # Up
                        37 { $selectedIndex = ($selectedIndex - 1 + $normalized.Count) % $normalized.Count } # Left
                        40 { $selectedIndex = ($selectedIndex + 1) % $normalized.Count } # Down
                        39 { $selectedIndex = ($selectedIndex + 1) % $normalized.Count } # Right
                        13 { return $normalized[$selectedIndex] } # Enter
                        default { $virtualKey = 0 }
                    }

                    if ($virtualKey -ne 0) {
                        if ($canUseAnsiRedraw) {
                            Write-Host ("{0}[{1}A" -f [char]27, $menuLineCount) -NoNewline
                            Write-ArrowMenuLines -CurrentIndex $selectedIndex
                        }
                        else {
                            Show-ArrowMenuFrame -CurrentIndex $selectedIndex
                        }
                        continue
                    }

                    if (($character.Length -eq 1) -and ([int][char]$character -ge 32)) {
                        $choice = $character.ToUpperInvariant()
                        if ($normalized -contains $choice) {
                            return $choice
                        }
                    }
                }
            }
            catch {
                $useRawInput = $false
                Write-Host 'Arrow-key menu is unavailable. Switching to typed input mode.' -ForegroundColor DarkYellow
            }
            continue
        }

        $typedPrompt = "$Prompt ($($displayOptions -join '/'))"
        $typedChoice = Read-Host $typedPrompt
        if ($null -ne $typedChoice) {
            $typedChoice = $typedChoice.Trim().ToUpperInvariant()
            if ($typedChoice.Length -gt 0) {
                $choice = $typedChoice.Substring(0, 1)
                if ($normalized -contains $choice) {
                    return $choice
                }

                if ($labelAliasToChoice.ContainsKey($choice)) {
                    $mappedChoice = $labelAliasToChoice[$choice]
                    if (-not [string]::IsNullOrWhiteSpace($mappedChoice)) {
                        return $mappedChoice
                    }
                }
            }
        }

        Write-Host "Invalid choice. Valid: $($displayOptions -join ', ')" -ForegroundColor DarkYellow
    }
}

if ($null -eq $script:UiMessageLog) {
    $script:UiMessageLog = [System.Collections.Generic.List[string]]::new()
}

function Add-UiMessage {
    Param(
        [string]$Message
    )

    if ([string]::IsNullOrWhiteSpace($Message)) {
        return
    }

    $script:UiMessageLog.Add($Message.Trim())
    while ($script:UiMessageLog.Count -gt 50) {
        $script:UiMessageLog.RemoveAt(0)
    }
}

function Get-UiMessages {
    Param(
        [int]$Max = 8
    )

    if ($script:UiMessageLog.Count -le $Max) {
        return @($script:UiMessageLog)
    }

    $start = $script:UiMessageLog.Count - $Max
    return @($script:UiMessageLog[$start..($script:UiMessageLog.Count - 1)])
}

function Clear-UiMessages {
    $script:UiMessageLog.Clear()
}

function Show-MainGameWindow {
    Param(
        [string]$Title,
        [string[]]$StatusLines,
        [int]$MessageHeight = 8
    )

    $messages = @(Get-UiMessages -Max $MessageHeight)
    Show-HudWindow -ModeTitle $Title -StatusLines $StatusLines -InfoLines $messages -InfoHeight $MessageHeight
}

function Show-HudWindow {
    Param(
        [string]$ModeTitle,
        [string[]]$StatusLines,
        [string[]]$InfoLines,
        [int]$InfoHeight = 8
    )

    Clear-GameScreen
    Write-Host '==================== DUNGEON ====================' -ForegroundColor DarkGray
    if (-not [string]::IsNullOrWhiteSpace($ModeTitle)) {
        Write-Host $ModeTitle -ForegroundColor Gray
    }

    foreach ($line in $StatusLines) {
        Write-Host $line -ForegroundColor Gray
    }

    Write-Host '--------------------- Updates --------------------' -ForegroundColor DarkGray
    $safeInfo = @($InfoLines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    if ($safeInfo.Count -gt $InfoHeight) {
        $safeInfo = @($safeInfo[($safeInfo.Count - $InfoHeight)..($safeInfo.Count - 1)])
    }

    foreach ($line in $safeInfo) {
        Write-Host $line -ForegroundColor White
    }

    $emptyLines = [Math]::Max(0, ($InfoHeight - $safeInfo.Count))
    for ($i = 0; $i -lt $emptyLines; $i++) {
        Write-Host ''
    }

    Write-Host '=================================================' -ForegroundColor DarkGray
    Write-Host ''
}

function Pause-ForContinue {
    Param(
        [string]$Message = ''
    )

    if (-not [string]::IsNullOrWhiteSpace($Message)) {
        Write-Host $Message -ForegroundColor DarkGray
    }
    try {
        [void]$host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
    }
    catch {
        [void](Read-Host 'Press Enter to continue')
    }
}

function Clear-GameScreen {
    Clear-Host
}
