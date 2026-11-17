$ErrorActionPreference = "Stop"
$deck = "C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project\Capstone_Forecasting_Deck.pptx"
$outDir = "C:\Users\AshTrailer\Documents\MATLAB\Capstone_Project\qa_png"
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Path $outDir | Out-Null }
Remove-Item "$outDir\slide-*.png" -ErrorAction SilentlyContinue

$pp = New-Object -ComObject PowerPoint.Application
try {
    $pres = $pp.Presentations.Open($deck, $true, $false, $false)
    $i = 1
    foreach ($slide in $pres.Slides) {
        $name = "{0}\slide-{1:D2}.png" -f $outDir, $i
        $slide.Export($name, "PNG", 1600, 900)
        $i++
    }
    $pres.Close()
    Write-Output "Exported $($i - 1) slides to $outDir"
}
finally {
    $pp.Quit()
    [System.Runtime.Interopservices.Marshal]::ReleaseComObject($pp) | Out-Null
}
