param([Parameter(Mandatory = $true)][string]$Manifest, [switch]$Overwrite)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$projectRoot = Split-Path -Parent $PSScriptRoot
$jobs = Get-Content -LiteralPath (Join-Path $projectRoot $Manifest) -Raw | ConvertFrom-Json
$names = @('distant-v2', 'middle-v2', 'far-v2', 'near-v2', 'front-v2')
foreach ($job in $jobs) {
    $folder = Join-Path $projectRoot ('assets/backgrounds/layers/level-{0:00}' -f $job.level)
    New-Item -ItemType Directory -Force -Path $folder | Out-Null
    $atlas = [System.Drawing.Bitmap]::FromFile($job.path)
    try {
        for ($i = 0; $i -lt 5; $i++) {
            $destination = Join-Path $folder ($names[$i] + '.png')
            # Keep individually repainted replacements unless explicitly asked.
            if ((Test-Path -LiteralPath $destination) -and -not $Overwrite) { continue }
            # Export atlas cells only. Never derive alpha or masks from colors.
            # Four pixels of uniform atlas bleed are omitted on every cell edge.
            $left = [int][math]::Round(($i % 3) * $atlas.Width / 3) + 4
            $top = [int][math]::Round([math]::Floor($i / 3) * $atlas.Height / 2) + 4
            $width = [int][math]::Floor($atlas.Width / 3) - 8
            $height = [int][math]::Floor($atlas.Height / 2) - 8
            $cell = $atlas.Clone([System.Drawing.Rectangle]::new($left, $top, $width, $height), [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
            try { $cell.Save($destination, [System.Drawing.Imaging.ImageFormat]::Png) }
            finally { $cell.Dispose() }
        }
    } finally { $atlas.Dispose() }
}
