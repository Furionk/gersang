param(
    [string]$Godot = 'R:\App\Godot_v4.7.1-stable_win64.exe',
    [string]$Output = 'artifacts/web-release-2026-10-14/web',
    [ValidateRange(1,4)][int]$ChunkMiB = 2,
    [string]$Template = 'features/web/demo_shell.html'
)
$ErrorActionPreference = 'Stop'
$projectPath = Split-Path $PSScriptRoot -Parent
if ([IO.Path]::IsPathRooted($Output)) { $outputPath = [IO.Path]::GetFullPath($Output) }
else { $outputPath = [IO.Path]::GetFullPath((Join-Path $projectPath $Output)) }
if ([IO.Path]::IsPathRooted($Template)) { $templatePath = [IO.Path]::GetFullPath($Template) }
else { $templatePath = [IO.Path]::GetFullPath((Join-Path $projectPath $Template)) }
if (!$templatePath.StartsWith($projectPath+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)) { throw 'Template must be inside this project.' }
$shell = Get-Content -LiteralPath $templatePath -Raw
foreach ($token in @('$GODOT_URL','$GODOT_CONFIG','__GERSANG_LOADER__','__GERSANG_MANIFEST__')) {
    if (!$shell.Contains($token)) { throw "Template is missing $token" }
}
$templateResource = 'res://'+$templatePath.Substring($projectPath.Length+1).Replace('\','/')
$evidencePath = Join-Path $projectPath 'artifacts/tests/web-build'
New-Item -ItemType Directory -Force $outputPath,$evidencePath | Out-Null
& node (Join-Path $projectPath 'tests/web_download_loader_test.js')
if ($LASTEXITCODE -ne 0) { throw 'Web download regression failed; export refused.' }
& node (Join-Path $projectPath 'tests/web_download_cache_test.js')
if ($LASTEXITCODE -ne 0) { throw 'Web persistent cache regression failed; export refused.' }
function Invoke-GodotChecked([string]$Name, [string[]]$Arguments, [string]$Expected) {
    $logPath = Join-Path $evidencePath ($Name+'.log')
    $engineArguments = @('--path',('"'+$projectPath+'"'),'--log-file',('"'+$logPath+'"'))+$Arguments
    $engineProcess = Start-Process -FilePath $Godot -ArgumentList $engineArguments -WindowStyle Hidden -PassThru
    if (!$engineProcess.WaitForExit(180000)) { $engineProcess.Kill(); throw "$Name timed out; export refused." }
    $log = Get-Content -LiteralPath $logPath -Raw
    if ($engineProcess.ExitCode -ne 0 -or $log -match '(?m)^(SCRIPT ERROR|ERROR):' -or ($Expected -and $log -notmatch $Expected)) {
        throw "$Name failed; export refused. See $logPath"
    }
    Write-Output "$Name passed"
}
# Memory-only tests never exercised the persistence gate shared by entry/combat.
# Keep this disk-backed regression mandatory before every release export.
Invoke-GodotChecked 'font-coverage' @('--headless','--script','res://tools/check_font_coverage.gd') 'FONT_COVERAGE_RESULT.*missing=0'
Invoke-GodotChecked 'font-ui' @('--headless','res://tests/font_coverage_suite.tscn') 'FONT_UI_RESULT.*failed=0'
Invoke-GodotChecked 'entry-persistence' @('--headless','res://tests/entry_persistence_suite.tscn') 'ENTRY_PERSISTENCE_RESULT passed=\d+ failed=0'
Invoke-GodotChecked 'demo-roster' @('--headless','res://tests/demo_roster_suite.tscn') 'DEMO_ROSTER_RESULT.*"failed":0'
Invoke-GodotChecked 'web-repairs' @('--headless','res://tests/web_repairs_suite.tscn') 'WEB_REPAIRS_RESULT passed=\d+ failed=0'
Invoke-GodotChecked 'portal-approach' @('--headless','res://tests/portal_approach_suite.tscn') 'PORTAL_APPROACH_RESULT passed=\d+ failed=0'
Invoke-GodotChecked 'hogwarts' @('--headless','res://tests/hogwarts_suite.tscn') 'HOGWARTS_RESULT.*"failed":0'
Invoke-GodotChecked 'movement' @('--headless','res://tests/world/movement_regression.tscn') 'MOVEMENT_RESULT.*failed=0'
Invoke-GodotChecked 'movement-render' @('res://tests/world/movement_regression.tscn') 'MOVEMENT_RESULT.*failed=0'
Invoke-GodotChecked 'allowlist' @('--headless','--script','res://tools/prepare_web_export.gd','--','--write-preset',('"--html-shell='+$templateResource+'"')) 'WEB_ALLOWLIST.*no_music=true'
Invoke-GodotChecked 'export' @('--headless','--export-release','"Web Demo No BGM"',('"'+(Join-Path $outputPath 'index.html')+'"')) ''
Copy-Item -LiteralPath (Join-Path $projectPath 'gersang_four.png') -Destination (Join-Path $outputPath 'gersang-logo.png') -Force
Copy-Item -LiteralPath (Join-Path $projectPath 'art/fonts/OFL.txt') -Destination (Join-Path $outputPath 'FONT-LICENSE.txt') -Force
Copy-Item -LiteralPath (Join-Path $projectPath 'art/fonts/NotoSansCJK-LICENSE.txt') -Destination (Join-Path $outputPath 'NOTO-CJK-LICENSE.txt') -Force
& python (Join-Path $PSScriptRoot 'package_web_downloads.py') $outputPath --chunk-mib $ChunkMiB
if ($LASTEXITCODE -ne 0) { throw 'Web chunk packaging failed; delivery refused.' }
Write-Output "Verified Web release: $outputPath"
