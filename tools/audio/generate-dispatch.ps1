# Run from PowerShell on Windows to regenerate the bundled dispatch sources.
param([switch]$GateOnly, [switch]$DestinationOnly, [switch]$PickupOnly)
$ErrorActionPreference = 'Stop'
if (($GateOnly -and $DestinationOnly) -or ($GateOnly -and $PickupOnly) -or ($DestinationOnly -and $PickupOnly)) { throw 'Choose only one clip subset.' }
$projectRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
$sourceDir = Join-Path $projectRoot '.development\dispatch-voices'
New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
Add-Type -AssemblyName System.Speech
$speaker = New-Object System.Speech.Synthesis.SpeechSynthesizer
try {
    $speaker.Rate = 2
    $speaker.Volume = 100
    $numbers = @('one', 'two', 'three', 'four', 'five')
    foreach ($voice in @('male', 'female', 'robot')) {
        $speaker.SelectVoice($(if ($voice -eq 'female') { 'Microsoft Zira Desktop' } else { 'Microsoft David Desktop' }))
        if (-not ($GateOnly -or $DestinationOnly)) {
            $phrases = @(
                'Fare waiting at pad {0}. Over.',
                'Customer at pad {0}. Over.',
                'You have a customer at pad {0}. Over.',
                'Taxi, pickup requested at pad {0}. Over.',
                'Passenger needs a ride at pad {0}. Over.',
                'Dispatch to taxi. Head to pad {0} for a fare. Over.'
            )
            for ($phrase = 1; $phrase -le $phrases.Count; $phrase++) {
                for ($pad = 1; $pad -le 5; $pad++) {
                    $target = Join-Path $sourceDir ('{0}-pickup-phrase-{1:00}-pad-{2:00}.wav' -f $voice, $phrase, $pad)
                    $speaker.SetOutputToWaveFile($target)
                    $speaker.Speak(($phrases[$phrase - 1] -f $numbers[$pad - 1]))
                }
            }
        }
        if (-not ($DestinationOnly -or $PickupOnly)) {
            $target = Join-Path $sourceDir ('{0}-stargate.wav' -f $voice)
            $speaker.SetOutputToWaveFile($target)
            $speaker.Speak('Taxi, star gate is open. Head for the gate. Over.')
        }
        if (-not ($GateOnly -or $PickupOnly)) {
            for ($pad = 1; $pad -le 5; $pad++) {
                $target = Join-Path $sourceDir ('{0}-destination-pad-{1:00}.wav' -f $voice, $pad)
                $speaker.SetOutputToWaveFile($target)
                $speaker.Speak(('Platform {0}, please.' -f $numbers[$pad - 1]))
            }
        }
    }
} finally {
    $speaker.Dispose()
}
Write-Output 'Sources generated. Run py tools/audio/filter-dispatch.py next.'
