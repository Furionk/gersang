param([switch]$CheckOnly)
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$project = Split-Path $PSScriptRoot -Parent
$settingsFile = Join-Path $PSScriptRoot 'web_export_settings.json'
$settings = Get-Content -LiteralPath $settingsFile -Raw | ConvertFrom-Json
$form = New-Object Windows.Forms.Form
$form.Text = 'Gersang Web 匯出（無 BGM）'
$form.Size = New-Object Drawing.Size(740,430)
$form.StartPosition = 'CenterScreen'
$form.FormBorderStyle = 'FixedDialog'
$form.MaximizeBox = $false
function Add-Field($label,$value,$y) {
    $caption = New-Object Windows.Forms.Label
    $caption.Text = $label; $caption.SetBounds(20,$y,130,24)
    $field = New-Object Windows.Forms.TextBox
    $field.Text = $value; $field.SetBounds(155,$y,470,26)
    $form.Controls.AddRange(@($caption,$field)); return $field
}
$godotField = Add-Field 'Godot 執行檔' $settings.Godot 25
$templateField = Add-Field '網站 HTML 模板' $settings.Template 70
$destinationField = Add-Field '匯出位置' $settings.Destination 115
$browse = New-Object Windows.Forms.Button
$browse.Text = '選擇'; $browse.SetBounds(632,115,70,27)
$browse.Add_Click({
    $dialog = New-Object Windows.Forms.FolderBrowserDialog
    $dialog.SelectedPath = $destinationField.Text
    if ($dialog.ShowDialog() -eq 'OK') { $destinationField.Text = $dialog.SelectedPath }
    $dialog.Dispose()
})
$form.Controls.Add($browse)
$chunkLabel = New-Object Windows.Forms.Label
$chunkLabel.Text = '每塊大小 (MiB)'; $chunkLabel.SetBounds(20,165,130,25)
$chunk = New-Object Windows.Forms.NumericUpDown
$chunk.Minimum = 1; $chunk.Maximum = 4; $chunk.Value = $settings.ChunkMiB
$chunk.SetBounds(155,165,85,26)
$note = New-Object Windows.Forms.Label
$note.Text = '建議 2 MiB。本地 hash 快取已啟用；保留字體、入口及戰鬥檢查。'
$note.SetBounds(255,165,455,40)
$status = New-Object Windows.Forms.Label
$status.Text = '設定會記住；完成後手動 FTP 上傳，最後上傳 index.html。'
$status.SetBounds(20,225,680,65)
$build = New-Object Windows.Forms.Button
$build.Text = '一鍵匯出'; $build.SetBounds(155,310,160,40)
$open = New-Object Windows.Forms.Button
$open.Text = '開啟輸出資料夾'; $open.SetBounds(340,310,160,40)
$open.Add_Click({ if (Test-Path -LiteralPath $destinationField.Text) { Start-Process explorer.exe -ArgumentList ('"'+$destinationField.Text+'"') } })
$form.Controls.AddRange(@($chunkLabel,$chunk,$note,$status,$build,$open))
$timer = New-Object Windows.Forms.Timer
$timer.Interval = 1000
$script:job = $null
$timer.Add_Tick({
    if (!$script:job -or !$script:job.HasExited) { return }
    $timer.Stop()
    try {
        if ($script:job.ExitCode -ne 0) { throw ('匯出失敗；請查看：'+$script:buildLog) }
        $manifest = Get-ChildItem -LiteralPath (Join-Path $script:staging 'downloads') -Filter manifest.json -Recurse | Select-Object -First 1
        $data = Get-Content -LiteralPath $manifest.FullName -Raw | ConvertFrom-Json
        New-Item -ItemType Directory -Path $script:destination -Force | Out-Null
        # Publish local files only after all checks finish; HTML is copied last.
        Get-ChildItem -LiteralPath $script:staging -Force | Where-Object { $_.Name -notin @('index.html','index.pck','index.wasm') } | ForEach-Object {
            Copy-Item -LiteralPath $_.FullName -Destination $script:destination -Recurse -Force
        }
        Copy-Item -LiteralPath (Join-Path $script:staging 'index.html') -Destination $script:destination -Force
        $status.Text = '完成！版本 '+$data.release+'。上傳輸出檔案及 downloads/'+$data.release+'/，index.html 最後上傳。'
    } catch { $status.Text = $_.Exception.Message }
    $build.Enabled = $true; $godotField.Enabled = $true; $templateField.Enabled = $true
    $destinationField.Enabled = $true; $chunk.Enabled = $true; $browse.Enabled = $true
    $script:job.Dispose(); $script:job = $null
})
$build.Add_Click({
    try {
        if (!(Test-Path -LiteralPath $godotField.Text -PathType Leaf)) { throw '找不到 Godot 執行檔。' }
        if (![IO.Path]::IsPathRooted($destinationField.Text)) { throw '請輸入完整輸出路徑。' }
        $script:destination = [IO.Path]::GetFullPath($destinationField.Text)
        if ($script:destination.TrimEnd('\') -eq $project.TrimEnd('\')) { throw '輸出位置不能是專案根目錄。' }
        $values = @{Godot=$godotField.Text; Template=$templateField.Text; ChunkMiB=[int]$chunk.Value; Destination=$script:destination}
        $values | ConvertTo-Json | Set-Content -LiteralPath $settingsFile -Encoding UTF8
        $script:staging = Join-Path $project ('artifacts/manual-web/'+[guid]::NewGuid().ToString()+'/web')
        New-Item -ItemType Directory -Path $script:staging -Force | Out-Null
        $script:buildLog = Join-Path (Split-Path $script:staging -Parent) 'build.log'
        # Serialize values into a task file; never interpolate user paths into shell code.
        $values.Output = $script:staging
        $taskFile = Join-Path (Split-Path $script:staging -Parent) 'task.json'
        $values.Remove('Destination')
        $values | ConvertTo-Json | Set-Content -LiteralPath $taskFile -Encoding UTF8
        $arguments = @('-NoProfile','-ExecutionPolicy','Bypass','-File',('"'+(Join-Path $PSScriptRoot 'web_export_worker.ps1')+'"'),'-TaskFile',('"'+$taskFile+'"'))
        $script:job = Start-Process powershell.exe -ArgumentList $arguments -WindowStyle Hidden -PassThru -RedirectStandardOutput $script:buildLog -RedirectStandardError ($script:buildLog+'.errors')
        $build.Enabled = $false; $godotField.Enabled = $false; $templateField.Enabled = $false
        $destinationField.Enabled = $false; $chunk.Enabled = $false; $browse.Enabled = $false
        $status.Text = '正在檢查、建置及分塊，請稍候。記錄：'+$script:buildLog
        $timer.Start()
    } catch { $status.Text = $_.Exception.Message }
})
$form.Add_FormClosing({ param($sender,$event) if ($script:job -and !$script:job.HasExited) { $event.Cancel = $true; $status.Text = '建置中，請等待完成再關閉。' } })
if ($CheckOnly) { Write-Output ('WEB_EXPORT_UI_READY controls='+$form.Controls.Count+' chunkMiB='+$chunk.Value+' destination='+$destinationField.Text) }
else { [void]$form.ShowDialog() }
$timer.Dispose(); $form.Dispose()
