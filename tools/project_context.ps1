[CmdletBinding()]
param(
    [string]$Topic,
    [string]$Query,
    [switch]$List,
    [switch]$Inventory,
    [switch]$Verify,
    [switch]$Json,
    [switch]$Expand,
    [ValidateRange(1,100)][int]$MaxFiles = 12,
    [string]$RegistryFile = 'specs/context_map.json'
)
# Read-only navigation. Never run generators, import resources, or touch user://.
$taskRoot = [IO.Path]::GetFullPath((Split-Path -Parent $PSScriptRoot))
function ProjectPath([string]$Relative) {
    $normal = $Relative.Replace('\','/')
    if (!$normal -or $normal.StartsWith('/') -or $normal.Contains(':') -or ($normal.Split('/') -contains '..')) {
        throw ('Unsafe project-relative path: ' + $Relative)
    }
    return Join-Path $taskRoot $normal
}
function Emit($Value) {
    if ($Json) { $Value | ConvertTo-Json -Depth 14 -Compress; return }
    switch ($Value.kind) {
        'topics' { foreach ($row in $Value.topics) { Write-Output ($row.id + ' | ' + $row.label) }; return }
        'documents' { foreach ($row in $Value.documents) { Write-Output ($row.category + ' | ' + $row.path) }; return }
        'ambiguous' {
            Write-Output ('請指定主題，避免擴大讀取：' + $Value.query)
            foreach ($row in $Value.matches) { Write-Output ('-Topic ' + $row.id + ' | ' + $row.label) }
            return
        }
        'verification' {
            Write-Output ('CONTEXT_INDEX | passed=' + $Value.passed + ' issues=' + $Value.issues.Count + ' topics=' + $Value.topic_count + ' documents=' + $Value.document_count)
            foreach ($issue in $Value.issues) { Write-Output ('ISSUE | ' + $issue) }
            return
        }
    }
    Write-Output ('TOPIC: ' + $Value.topic + ' | ' + $Value.label)
    Write-Output ('STATUS: ' + $Value.status + ' (routing-only topics are not gameplay completion claims)')
    foreach ($warning in $Value.warnings) { Write-Output ('RULE: ' + $warning) }
    foreach ($row in $Value.read_first) { Write-Output ('READ_FIRST: ' + $row.path) }
    foreach ($row in $Value.entities) { Write-Output ('ENTITY: ' + $row.id + ' | ' + $row.path) }
    foreach ($row in $Value.authority) { Write-Output ('AUTHORITY: ' + $row.pattern + ' matches=' + $row.count) }
    foreach ($row in $Value.files) { Write-Output ($row.change + ' ' + $row.path + ' | ' + $row.symbols) }
    if ($Value.omitted -gt 0) { Write-Output ('OMITTED: ' + $Value.omitted + ' files; use -Expand only if necessary') }
    Write-Output ('RELATED (optional): ' + ($Value.related -join ', '))
    foreach ($row in $Value.evidence) { Write-Output ('EVIDENCE: ' + $row.path + ' passed=' + $row.passed + ' failed=' + $row.failed) }
    Write-Output 'Evidence can be stale: changed files require relevant revalidation; hashes alone are not acceptance.'
}
$registry = Get-Content -LiteralPath (ProjectPath $RegistryFile) -Raw | ConvertFrom-Json
if ($registry.schema -ne 1) { throw 'Unsupported context registry schema' }
$manifest = Get-Content -LiteralPath (ProjectPath 'specs/manifest.json') -Raw | ConvertFrom-Json
$topicRows = @($registry.topics.PSObject.Properties | ForEach-Object { [ordered]@{id=$_.Name;label=$_.Value.label} })
if ($Verify) {
    $issues = [Collections.Generic.List[string]]::new()
    foreach ($property in $registry.documents.PSObject.Properties) {
        try { if (!(Test-Path -LiteralPath (ProjectPath $property.Name) -PathType Leaf)) { $issues.Add('Missing document: ' + $property.Name) } }
        catch { $issues.Add($_.Exception.Message) }
    }
    foreach ($property in $registry.topics.PSObject.Properties) {
        $route = $property.Value
        if (@($route.read_first).Count -gt $registry.rules.max_read_first) { $issues.Add('Read-first budget exceeded: ' + $property.Name) }
        if ($route.feature -and !$manifest.features.PSObject.Properties[$route.feature]) { $issues.Add('Unknown feature: ' + $route.feature) }
        foreach ($related in $route.related) { if (!$registry.topics.PSObject.Properties[$related]) { $issues.Add('Unknown related topic: ' + $related) } }
        foreach ($relative in @($route.read_first)+@($route.code | ForEach-Object {$_.path})+@($route.entities | ForEach-Object {$_.path})) {
            if (!$relative) { continue }
            try { if (!(Test-Path -LiteralPath (ProjectPath $relative) -PathType Leaf)) { $issues.Add('Missing route file: ' + $relative) } }
            catch { $issues.Add($_.Exception.Message) }
        }
        foreach ($pattern in $route.authority) {
            try { if (@(Get-ChildItem -Path (ProjectPath $pattern) -File -ErrorAction SilentlyContinue).Count -eq 0) { $issues.Add('Empty authority pattern: ' + $pattern) } }
            catch { $issues.Add($_.Exception.Message) }
        }
    }
    # Coverage scans documentation only; never imports a scene or walks .godot/artifacts.
    $actual = @(Get-Item -LiteralPath (ProjectPath 'README.md'),(ProjectPath 'AGENTS.md'))
    foreach ($directory in @('docs','specs')) {
        $actual += @(Get-ChildItem -LiteralPath (ProjectPath $directory) -Recurse -File | Where-Object {$_.Extension -in @('.md','.json','.csv')})
    }
    $actual += @(Get-ChildItem -LiteralPath (ProjectPath 'tests') -File -Filter '*.json')
    foreach ($file in $actual) {
        $relative = $file.FullName.Substring($taskRoot.Length+1).Replace('\','/')
        if (!$registry.documents.PSObject.Properties[$relative]) { $issues.Add('Unclassified document: ' + $relative) }
    }
    $answer = [ordered]@{kind='verification';passed=($issues.Count -eq 0);topic_count=$topicRows.Count;document_count=@($registry.documents.PSObject.Properties).Count;issues=@($issues)}
    Emit $answer
    if ($issues.Count) { exit 1 }
    exit 0
}
if ($Inventory) {
    $rows = @($registry.documents.PSObject.Properties | ForEach-Object {[ordered]@{path=$_.Name;category=$_.Value.category;title=$_.Value.title}})
    Emit ([ordered]@{kind='documents';documents=$rows})
    exit 0
}
if ($List -or (!$Topic -and !$Query)) { Emit ([ordered]@{kind='topics';topics=$topicRows}); exit 0 }
$needle = if ($Query) {$Query.Trim().ToLowerInvariant()} else {''}
if (!$Topic) {
    $matches = @()
    foreach ($property in $registry.topics.PSObject.Properties) {
        $route = $property.Value
        $aliases = @($property.Name)+@($route.aliases)+@($route.entities | ForEach-Object {$_.aliases})
        $score = 0
        foreach ($alias in $aliases) {
            if (!$alias) { continue }
            $value = ([string]$alias).ToLowerInvariant()
            if ($value -eq $needle) { $score = 100; break }
            if ($needle.Contains($value)) { $score += $value.Length }
        }
        if ($score) { $matches += [PSCustomObject]@{id=$property.Name;label=$route.label;score=$score} }
    }
    $matches = @($matches | Sort-Object -Property @{Expression='score';Descending=$true},id)
    if (!$matches.Count) { throw ('No matching topic; use -List. Query: ' + $Query) }
    if ($matches.Count -gt 1 -and $matches[0].score -eq $matches[1].score) {
        Emit ([ordered]@{kind='ambiguous';query=$Query;matches=@($matches | Select-Object -First 5)})
        exit 0
    }
    $Topic = $matches[0].id
}
$property = $registry.topics.PSObject.Properties[$Topic.ToLowerInvariant()]
if (!$property) { throw ('Unknown topic; use -List: ' + $Topic) }
$Topic = $property.Name
$route = $property.Value
$entities = @($route.entities | Where-Object {
    $hit = $false
    foreach ($alias in $_.aliases) { if ($needle -and $needle.Contains(([string]$alias).ToLowerInvariant())) { $hit = $true } }
    $hit
})
$fileSet = [ordered]@{}
foreach ($row in $route.code) { $fileSet[$row.path] = $row.symbols }
$authorityRows = @()
foreach ($pattern in $route.authority) {
    $resolved = @(Get-ChildItem -Path (ProjectPath $pattern) -File -ErrorAction SilentlyContinue | Sort-Object FullName)
    $authorityRows += [ordered]@{pattern=$pattern;count=$resolved.Count}
    foreach ($file in $resolved) {
        $relative = $file.FullName.Substring($taskRoot.Length+1).Replace('\','/')
        if ($entities.Count -and $relative -match '\.(tres|tscn)$' -and $relative -notin @($entities.path)) { continue }
        if (!$fileSet.Contains($relative)) { $fileSet[$relative] = 'authoritative data/schema' }
    }
}
foreach ($entity in $entities) { if (!$fileSet.Contains($entity.path)) { $fileSet[$entity.path] = 'requested content entity' } }
$limit = if ($Expand) { $fileSet.Count } else { $MaxFiles }
$selectedPaths = @($fileSet.Keys | Select-Object -First $limit)
$files = foreach ($relative in $selectedPaths) {
    $absolute = ProjectPath $relative
    $hash = if (Test-Path -LiteralPath $absolute -PathType Leaf) {(Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash} else {''}
    $known = $manifest.validated_hashes.PSObject.Properties[$relative]
    [ordered]@{path=$relative;symbols=$fileSet[$relative];change=$(if (!$hash) {'MISSING'} elseif ($known -and $known.Value -eq $hash) {'UNCHANGED_VALIDATED'} else {'READ_CHANGED_OR_UNVALIDATED'})}
}
$evidence = @()
$reports = switch ($route.feature) {
    'controls' { 'artifacts/world/combat-ux-headless-results.json'; 'artifacts/world/combat-ux-render-results.json' }
    'items' { 'artifacts/world/items-results.json' }
    'character' { 'artifacts/world/character-sheet-results.json' }
    'editor_workflow' { 'artifacts/editor-workflow-2026-10-11/results.json' }
    'depth_sorting' { 'artifacts/depth-sorting-2026-10-11/results.json' }
    default { 'artifacts/world/results.json' }
}
if ($route.evidence) { $reports = @($reports)+@($route.evidence) }
foreach ($path in $reports) {
    if (Test-Path -LiteralPath (ProjectPath $path)) {
        $report = Get-Content -LiteralPath (ProjectPath $path) -Raw | ConvertFrom-Json
        $evidence += [ordered]@{path=$path;passed=$report.passed;failed=$report.failed;rendered=$report.rendered}
    }
}
$feature = if ($route.feature) {$manifest.features.PSObject.Properties[$route.feature].Value} else {$null}
Emit ([ordered]@{kind='context';topic=$Topic;feature=$route.feature;label=$route.label;status=$(if ($feature) {$feature.status} else {'routing_only'});read_first=@($route.read_first | ForEach-Object {[ordered]@{path=$_}});entities=$entities;authority=$authorityRows;files=@($files);omitted=($fileSet.Count-$selectedPaths.Count);related=@($route.related);warnings=@($route.warnings);evidence=$evidence})
