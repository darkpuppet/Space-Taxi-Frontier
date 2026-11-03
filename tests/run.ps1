param([string]$GodotPath = "C:\software\godot\godot.exe")
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path -Parent $PSScriptRoot
$engine = (Get-Command $GodotPath -ErrorAction Stop).Source
$checks = @(
    @{ Name = 'import'; Args = '--headless --path . --editor --quit' },
    @{ Name = 'startup-cache'; Args = '--headless --path . --script tests/startup-cache.gd --quit-after 3000' },
    @{ Name = 'window-scaling'; Args = '--path . --rendering-driver opengl3 --audio-driver Dummy --position -32000,-32000 --script tests/window-scaling.gd --quit-after 3000' },
    @{ Name = 'impatient-sprites'; Args = '--path . --rendering-driver opengl3 --audio-driver Dummy --position -32000,-32000 --script tests/impatient-sprites.gd --quit-after 3000' },
    @{ Name = 'hazard-animation'; Args = '--path . --rendering-driver opengl3 --audio-driver Dummy --position -32000,-32000 --script tests/hazard-animation.gd --quit-after 3000' },
    @{ Name = 'background-traffic'; Args = '--path . --rendering-driver opengl3 --audio-driver Dummy --position -32000,-32000 --script tests/background-traffic.gd --quit-after 3000' },
    @{ Name = 'tombstone-dissolve'; Args = '--path . --rendering-driver opengl3 --audio-driver Dummy --position -32000,-32000 --script tests/tombstone-dissolve.gd --quit-after 3000' },
    @{ Name = 'dispatch-radio'; Args = '--headless --path . --script tests/dispatch-radio.gd --quit-after 3000' },
    @{ Name = 'abductions'; Args = '--headless --path . --script tests/abductions.gd --quit-after 3000' },
    @{ Name = 'economy'; Args = '--headless --path . --script tests/economy.gd --quit-after 3000' },
    @{ Name = 'towing-fuel'; Args = '--headless --path . --script tests/towing-fuel.gd --quit-after 3000' },
    @{ Name = 'settings-scores'; Args = '--headless --path . --script tests/settings-scores.gd --quit-after 3000' },
    @{ Name = 'controller'; Args = '--headless --path . --script tests/controller.gd --quit-after 3000' },
    @{ Name = 'developer-level-01'; Args = '--headless --path . --script tests/developer-launch.gd --quit-after 3000 -- --dev-level=1' },
    @{ Name = 'developer-level-09'; Args = '--headless --path . --script tests/developer-launch.gd --quit-after 3000 -- --dev-level=9' },
    @{ Name = 'developer-level-20'; Args = '--headless --path . --script tests/developer-launch.gd --quit-after 3000 -- --dev-level=20' },
    @{ Name = 'integration'; Args = '--headless --path . --script tests/integration.gd --quit-after 3000' },
    @{ Name = 'campaign'; Args = '--headless --path . --script tests/campaign.gd --quit-after 3000' },
    @{ Name = 'menus'; Args = '--headless --path . --script tests/menus.gd --quit-after 3000' },
    @{ Name = 'collisions'; Args = '--headless --path . --script tests/collisions.gd --quit-after 3000' },
    @{ Name = 'platforms'; Args = '--headless --path . --script tests/platforms.gd --quit-after 3000' },
    @{ Name = 'exit'; Args = '--headless --path . --script tests/exit.gd --quit-after 3000' },
    @{ Name = 'passengers'; Args = '--headless --path . --script tests/passengers.gd --quit-after 3000' },
    @{ Name = 'worlds'; Args = '--headless --path . --script tests/worlds.gd --quit-after 12000' },
    @{ Name = 'flight'; Args = '--headless --path . --script tests/flight.gd --quit-after 12000' }
)
foreach ($check in $checks) {
    $outPath = Join-Path $PSScriptRoot ($check.Name + '.log')
    $errPath = Join-Path $PSScriptRoot ($check.Name + '-errors.log')
    $process = Start-Process -FilePath $engine -ArgumentList $check.Args -WorkingDirectory $projectPath -WindowStyle Hidden -Wait -PassThru -RedirectStandardOutput $outPath -RedirectStandardError $errPath
    $report = (Get-Content -Raw $outPath) + (Get-Content -Raw $errPath)
    if ($process.ExitCode -ne 0 -or $report -match '(?m)^(SCRIPT ERROR:|ERROR:|WARNING:|FAIL:)') {
        Write-Output $report
        throw ($check.Name + ' failed validation.')
    }
    if ($check.Name -ne 'import' -and $report -notmatch '0 failures') {
        throw ($check.Name + ' exited without completing all checks.')
    }
    Write-Output ('PASS: ' + $check.Name)
}
Write-Output 'All validation passed: missions, patience, menus, collisions, sprites, tall worlds, suction, 60 fares, and 20 random gates.'
