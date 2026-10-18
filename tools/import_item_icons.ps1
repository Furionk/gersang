$projectRoot = Split-Path -Parent $PSScriptRoot
$source = Get-Content -LiteralPath (Join-Path $projectRoot 'specs/sources/items52.json') -Raw | ConvertFrom-Json
Add-Type -AssemblyName System.Drawing
foreach ($item in $source.items) {
    $uri = [Uri]::new([Uri]'https://www.52jushang.com/item/',[string]$item.image)
    if ($uri.Host -ne 'www.52jushang.com') { throw 'Reference icon must come from the declared source host.' }
    $destination = Join-Path $projectRoot ('art/items/source52/' + $item.id + '.png')
    if (Test-Path -LiteralPath $destination) { Write-Output ('PRESERVED ' + $item.id); continue }
    $response = Invoke-WebRequest -Uri $uri.AbsoluteUri -UseBasicParsing -TimeoutSec 25
    $stream = New-Object System.IO.MemoryStream
    $response.RawContentStream.Position = 0
    $response.RawContentStream.CopyTo($stream)
    $stream.Position = 0
    $decoded = [System.Drawing.Image]::FromStream($stream)
    $decoded.Save($destination,[System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output ('IMPORTED ' + $item.id + ' ' + $decoded.Width + 'x' + $decoded.Height + ' ' + $uri.AbsoluteUri)
    $decoded.Dispose()
    $stream.Dispose()
}
