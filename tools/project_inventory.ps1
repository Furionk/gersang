[CmdletBinding()]
param([switch]$Json,[switch]$Verify)
$ErrorActionPreference='Stop'
$taskRoot=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$roles=@{
 'common'='shared_schema';'features'='feature_runtime_and_native_data';'art'='shared_art';
 'addons'='editor_plugins';'docs'='documentation';'specs'='contracts_and_routes';
 'tests'='test_source_and_fixtures';'tools'='development_tools';'artifacts'='generated_evidence';
 '.godot'='engine_cache';'export_templates'='optional_editor_data';'feature_profiles'='optional_editor_data';
 'script_templates'='optional_editor_templates';'text_editor_themes'='optional_editor_data'
}
$folders=@();$issues=[Collections.Generic.List[string]]::new()
foreach($dir in Get-ChildItem -LiteralPath $taskRoot -Directory -Force){
 if($dir.Name -eq '.git'){continue}
 if($dir.Attributes -band [IO.FileAttributes]::ReparsePoint){$issues.Add('Directory link requires manual review: '+$dir.Name);continue}
 $role=if($roles.ContainsKey($dir.Name)){$roles[$dir.Name]}else{'unclassified'}
 if($role -eq 'unclassified'){$issues.Add('Unclassified root directory: '+$dir.Name)}
 # Cache size is intentionally not scanned; no imports or process launches.
 $files=if($dir.Name -eq '.godot'){@()}else{@(Get-ChildItem -LiteralPath $dir.FullName -Recurse -File -Force)}
 $folders+=[ordered]@{path=$dir.Name;role=$role;files=$files.Count;MiB=[math]::Round(($files|Measure-Object Length -Sum).Sum/1MB,2);size_scanned=($dir.Name -ne '.godot')}
}
$generated=@(Get-ChildItem -LiteralPath $taskRoot -File -Filter '*.log')
$generated+=@(Get-ChildItem -LiteralPath (Join-Path $taskRoot 'tests') -File|Where-Object{$_.Extension -in @('.log','.png') -or $_.Name -in @('acceptance-results.json','v2-results.json')})
$candidates=@($generated|ForEach-Object{[ordered]@{path=$_.FullName.Substring($taskRoot.Length+1).Replace('\','/');bytes=$_.Length}})
$fixtures=@(Get-ChildItem -LiteralPath (Join-Path $taskRoot 'tests/world') -File -Filter '*.json'|ForEach-Object{$_.FullName.Substring($taskRoot.Length+1).Replace('\','/')})
if(!(Test-Path -LiteralPath (Join-Path $taskRoot 'artifacts/.gdignore'))){$issues.Add('artifacts/.gdignore missing')}
if(!(Test-Path -LiteralPath (Join-Path $taskRoot '.ignore'))){$issues.Add('rg ignore policy missing')}
if($Verify -and $candidates.Count){$issues.Add('Generated files outside artifacts: '+$candidates.Count)}
$result=[ordered]@{schema=1;root=$taskRoot;read_only=$true;folders=$folders;generated_candidates=$candidates;preserved_fixtures=$fixtures;issues=@($issues);passed=($issues.Count -eq 0)}
if($Json){$result|ConvertTo-Json -Depth 6}else{
 foreach($row in $folders){Write-Output ($row.path+' | '+$row.role+' | files='+$row.files+' | MiB='+$row.MiB)}
 Write-Output ('STRUCTURE_INVENTORY candidates='+$candidates.Count+' fixtures='+$fixtures.Count+' issues='+$issues.Count+' passed='+$result.passed)
 foreach($issue in $issues){Write-Output ('ISSUE | '+$issue)}
}
if($Verify -and $issues.Count){exit 1}
