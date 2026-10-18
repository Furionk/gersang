param([switch]$Publish)
$ErrorActionPreference='Stop'
$sourceRoot=[IO.Path]::GetFullPath('W:\wMacSync\SynologyDrive\Godot Projects\gersang\artifacts\branding5\web')
$targetRoot=[IO.Path]::GetFullPath('L:\git\furionkcom\gersang')
$backupRoot=[IO.Path]::GetFullPath('L:\gersang-export-backups')
$stamp=Get-Date -Format 'yyyyMMdd-HHmmss'
$incoming=Join-Path $backupRoot "incoming-$stamp"
$backup=Join-Path $backupRoot "gersang-$stamp"
if($targetRoot -ne 'L:\git\furionkcom\gersang' -or $sourceRoot -notlike '*\gersang\artifacts\branding5\web'){throw 'Unexpected roots'}
foreach($path in @($sourceRoot,$targetRoot,'L:\git','L:\git\furionkcom',$backupRoot)){
 if((Test-Path -LiteralPath $path) -and ((Get-Item -LiteralPath $path -Force).Attributes -band [IO.FileAttributes]::ReparsePoint)){throw "Linked path refused: $path"}
}
if(Test-Path -LiteralPath (Join-Path $targetRoot '.git')){throw 'Target is a repository root; preserve separately'}
$state=Get-Content -LiteralPath (Join-Path $sourceRoot 'web-export-state.json') -Raw | ConvertFrom-Json
$report=Get-Content -LiteralPath (Join-Path $sourceRoot 'build-report.json') -Raw | ConvertFrom-Json
if($state.history.Count -ne 1 -or -not $report.object_audit.latest_only){throw 'Source must contain one fully audited release'}
$files=@($state.history[0].files.PSObject.Properties)
foreach($entry in $files){
 $full=[IO.Path]::GetFullPath((Join-Path $sourceRoot $entry.Name))
 if(-not $full.StartsWith($sourceRoot+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Path escape'}
 if((Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.Value){throw "Source hash mismatch: $($entry.Name)"}
}
if(-not $Publish){Write-Output "SOURCE VERIFIED $($report.release) / $($files.Count) files"; exit}
New-Item -ItemType Directory -Path $incoming -Force | Out-Null
foreach($entry in ($files | Sort-Object {if($_.Name -eq 'index.html'){1}else{0}})){
 $out=[IO.Path]::GetFullPath((Join-Path $incoming $entry.Name))
 if(-not $out.StartsWith($incoming+'\',[StringComparison]::OrdinalIgnoreCase)){throw 'Destination escape'}
 New-Item -ItemType Directory -Path (Split-Path $out) -Force | Out-Null
 Copy-Item -LiteralPath (Join-Path $sourceRoot $entry.Name) -Destination $out
 if((Get-FileHash -LiteralPath $out -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.Value){throw "Copy hash mismatch: $($entry.Name)"}
}
foreach($name in @('web-export-state.json','build-report.json','.gdignore')){if(Test-Path -LiteralPath (Join-Path $sourceRoot $name)){Copy-Item -LiteralPath (Join-Path $sourceRoot $name) -Destination (Join-Path $incoming $name)}}
$actual=@(Get-ChildItem -LiteralPath (Join-Path $incoming 'objects') -File)
$expected=@($files | Where-Object Name -Like 'objects/*')
$releases=@(Get-ChildItem -LiteralPath (Join-Path $incoming 'releases') -Directory)
if($actual.Count -ne $expected.Count -or $releases.Count -ne 1 -or $releases[0].Name -ne $report.release){throw 'Unexpected object/release set'}
if(Test-Path -LiteralPath $targetRoot){Move-Item -LiteralPath $targetRoot -Destination $backup}
try{Move-Item -LiteralPath $incoming -Destination $targetRoot}catch{if(Test-Path -LiteralPath $backup){Move-Item -LiteralPath $backup -Destination $targetRoot};throw}
foreach($entry in $files){if((Get-FileHash -LiteralPath (Join-Path $targetRoot $entry.Name) -Algorithm SHA256).Hash.ToLowerInvariant() -ne $entry.Value){throw 'Post-publish mismatch'}}
$result=[ordered]@{target=$targetRoot;backup=$backup;release=$report.release;releases=$releases.Count;objects=$actual.Count;verified_files=$files.Count;first_transfer_bytes=$report.first_transfer_bytes;latest_only=$true;timestamp=(Get-Date -Format o)}
$result | ConvertTo-Json | Set-Content -LiteralPath 'W:\wMacSync\SynologyDrive\Godot Projects\gersang\artifacts\branding5\delivery.json' -Encoding utf8
$result | ConvertTo-Json

