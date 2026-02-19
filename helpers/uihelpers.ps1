function Read-SingleKeyChoice {
    Param(
        [Parameter(Mandatory = $true)]
        [string[]]$ValidChoices,
        [string]$Prompt = 'Choose an option:'
    )

    $normalized = $ValidChoices | ForEach-Object { $_.ToUpperInvariant() }

    while ($true) {
        Write-Host $Prompt -ForegroundColor Yellow
        $keyInfo = $host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
        $choice = ([string]$keyInfo.Character).ToUpperInvariant()

        if ($normalized -contains $choice) {
            return $choice
        }

        Write-Host "Invalid choice '$choice'. Valid: $($normalized -join ', ')" -ForegroundColor DarkYellow
    }
}

function Pause-ForContinue {
    Param(
        [string]$Message = 'Press any key to continue...'
    )

    Write-Host $Message -ForegroundColor DarkGray
    [void]$host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
}

function Clear-GameScreen {
    Clear-Host
}
