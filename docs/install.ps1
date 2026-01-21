$ErrorActionPreference = "Stop"

$repo = "nodos-dev/workspace"
$api = "https://api.github.com/repos/$repo/releases/latest"

function Show-Banner {
@'
--------------------------------------------
███╗   ██╗ ██████╗ ██████╗  ██████╗ ███████╗
████╗  ██║██╔═══██╗██╔══██╗██╔═══██╗██╔════╝
██╔██╗ ██║██║   ██║██║  ██║██║   ██║███████╗
██║╚██╗██║██║   ██║██║  ██║██║   ██║╚════██║
██║ ╚████║╚██████╔╝██████╔╝╚██████╔╝███████║
╚═╝  ╚═══╝ ╚═════╝ ╚═════╝  ╚═════╝ ╚══════╝
--------------------------------------------
'@ | Write-Host
  Write-Host "Nodos - Highly Extensible Node-Based Computing Platform"
  Write-Host "nosman - Nodos Workspace & Package Manager"
  Write-Host "Latest nosman release (and optionally, Nodos release) will be downloaded and installed for your platform."
}

function Prompt-Choice {
  param(
    [string]$Prompt,
    [string]$Default
  )
  Write-Host ""
  $value = Read-Host "$Prompt [$Default]"
  if (-not $value) { $value = $Default }
  return $value
}

function Prompt-YesNo {
  param(
    [string]$Prompt,
    [string]$Default
  )
  Write-Host ""
  $value = Read-Host "$Prompt [$Default] (y/n)"
  if (-not $value) { $value = $Default }
  return $value -match "^(y|yes)$"
}

function Get-Architecture {
  $arch = $env:PROCESSOR_ARCHITECTURE
  $archWow = $env:PROCESSOR_ARCHITEW6432

  if ($arch -eq "ARM64" -or $archWow -eq "ARM64") { return "aarch64" }
  return "x86_64"
}

function Download-WithProgress {
  param(
    [string]$Url,
    [string]$Destination
  )

  $handler = New-Object System.Net.Http.HttpClientHandler
  $client = New-Object System.Net.Http.HttpClient($handler)
  $client.DefaultRequestHeaders.UserAgent.ParseAdd("nosman-installer")

  $response = $client.GetAsync($Url, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).Result
  $response.EnsureSuccessStatusCode() | Out-Null

  $total = $response.Content.Headers.ContentLength
  $stream = $response.Content.ReadAsStreamAsync().Result
  $fileStream = New-Object System.IO.FileStream($Destination, [System.IO.FileMode]::Create, [System.IO.FileAccess]::Write, [System.IO.FileShare]::None)

  $buffer = New-Object byte[] (1024 * 1024)
  $read = 0
  $completed = 0L

  while (($read = $stream.Read($buffer, 0, $buffer.Length)) -gt 0) {
    $fileStream.Write($buffer, 0, $read)
    $completed += $read
    if ($total -gt 0) {
      $percent = [math]::Round(($completed / $total) * 100, 2)
      Write-Progress -Activity "Downloading nosman" -Status "$percent% complete" -PercentComplete $percent
    } else {
      Write-Progress -Activity "Downloading nosman" -Status "$completed bytes"
    }
  }

  $fileStream.Close()
  $stream.Close()
  $client.Dispose()
  Write-Progress -Activity "Downloading nosman" -Completed
}

function Ensure-Path {
  param(
    [string]$Dir,
    [ValidateSet("User", "Machine")] [string]$Scope
  )

  $current = [Environment]::GetEnvironmentVariable("Path", $Scope)
  if ($current -and $current.Split(";") -contains $Dir) {
    return
  }

  $newPath = if ($current) { "$current;$Dir" } else { $Dir }
  [Environment]::SetEnvironmentVariable("Path", $newPath, $Scope)
  if ($Scope -eq "User") { $env:Path = $newPath }
}

function Find-NodosExe {
  param(
    [string]$InstallDir
  )

  $default = Join-Path $InstallDir "nodos.exe"
  if (Test-Path $default) { return $default }

  $found = Get-ChildItem -Path $InstallDir -Recurse -Filter "nodos.exe" -ErrorAction SilentlyContinue | Select-Object -First 1
  if ($found) { return $found.FullName }

  throw "Could not locate nodos.exe in $InstallDir"
}

function New-Shortcut {
  param(
    [string]$ShortcutPath,
    [string]$Target,
    [string]$WorkingDir
  )

  $shortcutDir = Split-Path $ShortcutPath -Parent
  if (-not (Test-Path $shortcutDir)) {
    New-Item -ItemType Directory -Force -Path $shortcutDir | Out-Null
  }

  $shell = New-Object -ComObject WScript.Shell
  $shortcut = $shell.CreateShortcut($ShortcutPath)
  $shortcut.TargetPath = $Target
  $shortcut.WorkingDirectory = $WorkingDir
  $shortcut.Save()
}

Show-Banner

$installScope = Prompt-Choice -Prompt "Install for all users or current user?" -Default "current"
switch -Regex ($installScope) {
  "^(all|system|all-users)$" { $installScope = "all" }
  "^(current|user|current-user)$" { $installScope = "current" }
  default { throw "Choose 'all' or 'current'." }
}

if ($installScope -eq "all") {
  $defaultInstallDir = Join-Path $env:ProgramFiles "nosman\\bin"
  $pathScope = "Machine"
} else {
  $defaultInstallDir = Join-Path $env:LOCALAPPDATA "Programs\\nosman\\bin"
  $pathScope = "User"
}

$installDir = Prompt-Choice -Prompt "Install directory" -Default $defaultInstallDir
$addPath = Prompt-YesNo -Prompt "Add install directory to PATH" -Default "y"

$arch = Get-Architecture

Write-Host "Fetching latest nosman release..."
$release = Invoke-RestMethod -Uri $api -Headers @{ "User-Agent" = "nosman-installer" }

$asset = $release.assets | Where-Object { $_.name -match "nosman-windows-$arch" } | Select-Object -First 1
if (-not $asset) {
  throw "No matching asset for windows/$arch."
}

if (-not (Test-Path $installDir)) {
  New-Item -ItemType Directory -Force -Path $installDir | Out-Null
}

$tmp = Join-Path $env:TEMP "nosman-windows-$arch.exe"
Download-WithProgress -Url $asset.browser_download_url -Destination $tmp

$dest = Join-Path $installDir "nosman.exe"
Copy-Item -Force $tmp $dest
Remove-Item -Force $tmp

if ($addPath) {
  Ensure-Path -Dir $installDir -Scope $pathScope
}

Write-Host "Installed nosman to $dest"
if ($addPath) {
  Write-Host "If this is a new PATH entry, restart your shell."
}

$installNodos = Prompt-YesNo -Prompt "Install latest Nodos release?" -Default "y"
if ($installNodos) {
  if ($installScope -eq "all") {
    $nodosInstallDir = Join-Path $env:ProgramFiles "Nodos"
    $shortcutDirs = @(
      (Join-Path $env:ProgramData "Microsoft\\Windows\\Start Menu\\Programs"),
      (Join-Path $env:Public "Desktop")
    )
  } else {
    $nodosInstallDir = Join-Path $env:LOCALAPPDATA "Nodos"
    $shortcutDirs = @(
      (Join-Path $env:APPDATA "Microsoft\\Windows\\Start Menu\\Programs"),
      (Join-Path $env:USERPROFILE "Desktop")
    )
  }

  if (-not (Test-Path $nodosInstallDir)) {
    New-Item -ItemType Directory -Force -Path $nodosInstallDir | Out-Null
  }

  Write-Host "Installing latest Nodos release with nosman..."
  & $dest --workspace $nodosInstallDir get -y

  $nodosExe = Find-NodosExe -InstallDir $nodosInstallDir
  foreach ($dir in $shortcutDirs) {
    New-Shortcut -ShortcutPath (Join-Path $dir "Nodos.lnk") -Target $nodosExe -WorkingDir (Split-Path $nodosExe -Parent)
  }

  Write-Host "Installed Nodos to $nodosInstallDir"
  Write-Host "Created shortcuts:"
  foreach ($dir in $shortcutDirs) {
    Write-Host "  - $(Join-Path $dir "Nodos.lnk")"
  }
}
