param([Parameter(Mandatory=$true)][string]$TaskFile)
$ErrorActionPreference = 'Stop'
try {
    $task = Get-Content -LiteralPath $TaskFile -Raw | ConvertFrom-Json
    & (Join-Path $PSScriptRoot 'build_web.ps1') -Godot $task.Godot -Output $task.Output -Template $task.Template -ChunkMiB $task.ChunkMiB
    exit 0
} catch { Write-Error $_; exit 1 }
