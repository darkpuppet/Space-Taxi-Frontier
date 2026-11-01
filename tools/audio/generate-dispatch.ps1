# Run from PowerShell on Windows to regenerate the bundled dispatch sources.
$ErrorActionPreference = 'Stop'
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
        for ($pad = 1; $pad -le 5; $pad++) {
            $target = Join-Path $sourceDir ('{0}-pad-{1:00}.wav' -f $voice, $pad)
            $speaker.SetOutputToWaveFile($target)
            $speaker.Speak(('Taxi, customer waiting at pad {0}. Over.' -f $numbers[$pad - 1]))
        }
    }
} finally {
    $speaker.Dispose()
}
Write-Output 'Sources generated. Run py tools/audio/filter-dispatch.py next.'
