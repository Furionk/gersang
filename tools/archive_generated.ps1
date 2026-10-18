[CmdletBinding()]
param([ValidateSet('Plan','Apply','Restore')][string]$Mode='Plan',[ValidatePattern('^[a-zA-Z0-9_-]+$')][string]$Run='2026-10-13')
$ErrorActionPreference='Stop'
$taskRoot=[IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
$taskArchive=[IO.Path]::GetFullPath((Join-Path $taskRoot ('artifacts/history/'+$Run)))
function SafePath([string]$Relative){
 if([IO.Path]::IsPathRooted($Relative) -or ($Relative.Split([char[]]@('/','\')) -contains '..')){throw 'Unsafe relative path'}
 $absolute=[IO.Path]::GetFullPath((Join-Path $taskRoot $Relative))
 if(!$absolute.StartsWith($taskRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Path outside project'}
 $cursor=$absolute
 while($cursor -and $cursor -ne $taskRoot){
  if(Test-Path -LiteralPath $cursor){if((Get-Item -LiteralPath $cursor -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw ('Directory/file link forbidden: '+$cursor)}}
  $cursor=Split-Path -Parent $cursor
 }
 return $absolute
}
if(!$taskArchive.StartsWith($taskRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Archive outside project'}
$manifest=Join-Path $taskArchive 'manifest.json'
if($Mode -eq 'Restore'){
 $data=Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json
 foreach($row in $data.files){
  $source=SafePath $row.destination; $destination=SafePath $row.source
  if(!(Test-Path -LiteralPath $source -PathType Leaf)){throw ('Archived file missing: '+$source)}
  if(Test-Path -LiteralPath $destination){throw ('Restore would overwrite: '+$destination)}
  if((Get-FileHash -LiteralPath $source).Hash -ne $row.sha256){throw 'Archived hash mismatch'}
 }
 foreach($row in $data.files){Move-Item -LiteralPath (SafePath $row.destination) -Destination (SafePath $row.source)}
 Write-Output ('ARCHIVE_RESTORED files='+$data.files.Count); exit
}
$files=@(Get-ChildItem -LiteralPath $taskRoot -File -Filter '*.log')
$files+=@(Get-ChildItem -LiteralPath (Join-Path $taskRoot 'tests') -File|Where-Object{$_.Extension -in @('.log','.png') -or $_.Name -in @('acceptance-results.json','v2-results.json')})
foreach($image in @($files|Where-Object{$_.Extension -eq '.png'})){if(Test-Path -LiteralPath ($image.FullName+'.import') -PathType Leaf){$files+=Get-Item -LiteralPath ($image.FullName+'.import')}}
$rows=@(foreach($file in $files){
 $relative=$file.FullName.Substring($taskRoot.Length+1).Replace('\','/')
 $bucket=if($relative -notmatch '^tests/'){'root_logs'}elseif($file.Extension -eq '.log'){'test_logs'}elseif($file.Extension -eq '.json'){'test_results'}else{'test_screenshots'}
 $dest='artifacts/history/'+$Run+'/'+$bucket+'/'+$file.Name
 $null=SafePath $relative; $null=SafePath $dest
 [ordered]@{source=$relative;destination=$dest;sha256=(Get-FileHash -LiteralPath $file.FullName).Hash;bytes=$file.Length;lastWriteUtc=$file.LastWriteTimeUtc.ToString('o')}
})
if($Mode -eq 'Plan'){$rows|ConvertTo-Json -Depth 4;exit}
if(Test-Path -LiteralPath $manifest){throw 'Archive run already exists; use another Run or restore explicitly'}
foreach($row in $rows){
 $source=SafePath $row.source;$destination=SafePath $row.destination
 if(Test-Path -LiteralPath $destination){throw ('Destination exists: '+$destination)}
 if((Get-FileHash -LiteralPath $source).Hash -ne $row.sha256){throw ('Active/changed file: '+$source)}
}
New-Item -ItemType Directory -Path $taskArchive -Force|Out-Null
[IO.File]::WriteAllText($manifest,([ordered]@{schema=1;root=$taskRoot;files=$rows;restoreCommand='./tools/archive_generated.ps1 -Mode Restore -Run '+$Run}|ConvertTo-Json -Depth 5),[Text.UTF8Encoding]::new($false))
foreach($row in $rows){
 $source=SafePath $row.source;$destination=SafePath $row.destination
 New-Item -ItemType Directory -Path (Split-Path -Parent $destination) -Force|Out-Null
 Move-Item -LiteralPath $source -Destination $destination
 if((Get-FileHash -LiteralPath $destination).Hash -ne $row.sha256){throw 'Post-move hash mismatch'}
}
Write-Output ('ARCHIVE_APPLIED files='+$rows.Count+' manifest='+$manifest)
