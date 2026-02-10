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

function Refresh-SessionPath {
  $machinePath = [Environment]::GetEnvironmentVariable("Path", "Machine")
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")

  if ($machinePath -and $userPath) {
    $env:Path = "$machinePath;$userPath"
  } elseif ($machinePath) {
    $env:Path = $machinePath
  } elseif ($userPath) {
    $env:Path = $userPath
  }
}

function Install-GitWithWinget {
  if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Warning "winget is not available; cannot auto-install Git."
    return $false
  }

  Write-Host "Installing Git via winget..."
  $args = @(
    "install",
    "--id", "Git.Git",
    "-e",
    "--source", "winget",
    "--accept-package-agreements",
    "--accept-source-agreements"
  )

  $process = Start-Process -FilePath "winget" -ArgumentList $args -Wait -PassThru -NoNewWindow
  if ($process.ExitCode -in @(0, 3010)) {
    return $true
  }

  Write-Warning "winget install for Git failed with exit code $($process.ExitCode)."
  return $false
}

function Ensure-Git {
  if (Get-Command git -ErrorAction SilentlyContinue) {
    return
  }

  Write-Host "Git is required to install Nodos packages."
  $installGit = Prompt-YesNo -Prompt "Git is missing. Install Git now (via winget)?" -Default "y"
  if (-not $installGit) {
    throw "Git is required. Install it manually and re-run the installer."
  }

  if (-not (Install-GitWithWinget)) {
    throw "Git installation failed. Install Git manually and re-run the installer."
  }

  Refresh-SessionPath

  $gitCmdDir = Join-Path $env:ProgramFiles "Git\\cmd"
  if (Test-Path (Join-Path $gitCmdDir "git.exe")) {
    if (-not ($env:Path.Split(";") -contains $gitCmdDir)) {
      $env:Path = "$gitCmdDir;$env:Path"
    }
  }

  if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    throw "Git appears to be installed but was not found on PATH. Restart shell and re-run installer."
  }
}

function Test-IsAdmin {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Get-VcRedistUrl {
  param(
    [string]$Arch
  )

  if ($Arch -eq "aarch64") {
    return "https://aka.ms/vs/17/release/vc_redist.arm64.exe"
  }
  return "https://aka.ms/vs/17/release/vc_redist.x64.exe"
}

function Test-VcRedistInstalled {
  param(
    [string]$Arch
  )

  $runtime = if ($Arch -eq "aarch64") { "arm64" } else { "x64" }
  $paths = @(
    "HKLM:\\SOFTWARE\\Microsoft\\VisualStudio\\14.0\\VC\\Runtimes\\$runtime",
    "HKLM:\\SOFTWARE\\WOW6432Node\\Microsoft\\VisualStudio\\14.0\\VC\\Runtimes\\$runtime"
  )

  foreach ($path in $paths) {
    if (Test-Path $path) {
      $props = Get-ItemProperty -Path $path -ErrorAction SilentlyContinue
      if ($props -and $props.Installed -eq 1) {
        return $true
      }
    }
  }

  return $false
}

function Install-VcRedist {
  param(
    [string]$Arch
  )

  $url = Get-VcRedistUrl -Arch $Arch
  $fileName = if ($Arch -eq "aarch64") { "vc_redist.arm64.exe" } else { "vc_redist.x64.exe" }
  $tmp = Join-Path $env:TEMP $fileName

  Write-Host "Downloading Microsoft Visual C++ Redistributable ($Arch)..."
  Download-WithProgress -Url $url -Destination $tmp

  try {
    $args = @("/install", "/quiet", "/norestart")
    if (Test-IsAdmin) {
      $process = Start-Process -FilePath $tmp -ArgumentList $args -Wait -PassThru
    } else {
      Write-Host "Requesting elevation to install Microsoft Visual C++ Redistributable..."
      $process = Start-Process -FilePath $tmp -ArgumentList $args -Verb RunAs -Wait -PassThru
    }

    if ($process.ExitCode -in @(0, 1638, 3010)) {
      if ($process.ExitCode -eq 3010) {
        Write-Host "Visual C++ Redistributable installed; a restart may be required."
      }
      return $true
    }

    Write-Warning "VC++ Redistributable installer failed with exit code $($process.ExitCode)."
    return $false
  } catch {
    Write-Warning "VC++ Redistributable installation failed: $($_.Exception.Message)"
    return $false
  } finally {
    Remove-Item -Force $tmp -ErrorAction SilentlyContinue
  }
}

function Ensure-VcRedist {
  param(
    [string]$Arch
  )

  if (Test-VcRedistInstalled -Arch $Arch) {
    return
  }

  Write-Host "Microsoft Visual C++ Redistributable is required."
  $installRuntime = Prompt-YesNo -Prompt "Visual C++ runtime is missing. Install it now?" -Default "y"
  if (-not $installRuntime) {
    throw "Microsoft Visual C++ Redistributable is required. Install it and re-run the installer."
  }

  if (-not (Install-VcRedist -Arch $Arch)) {
    throw "Microsoft Visual C++ Redistributable installation failed."
  }

  if (-not (Test-VcRedistInstalled -Arch $Arch)) {
    Write-Warning "Could not verify Visual C++ Redistributable via registry after install. Continuing."
  }
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
  Ensure-Git
  Ensure-VcRedist -Arch $arch

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
