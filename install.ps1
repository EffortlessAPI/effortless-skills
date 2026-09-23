<#
.SYNOPSIS
  Install / Uninstall the Effortless Claude skills for Claude Code (Windows, PowerShell).

.DESCRIPTION
  Copies every skill folder under skills\ into %USERPROFILE%\.claude\skills\.
  Each skill gets its own folder, as Claude Code requires.

  This is the PowerShell equivalent of install-windows.sh, for Windows users who
  do not have Git Bash. Same behavior, same flags.

.PARAMETER Yes
  Non-interactive. Overwrite existing skills without asking.

.PARAMETER Uninstall
  Remove all installed effortless-* skills instead of installing them.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File install.ps1

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File install.ps1 -Yes

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall
#>

[CmdletBinding()]
param(
    [Alias('y')]
    [switch]$Yes,
    [switch]$Uninstall
)

$ErrorActionPreference = 'Stop'

$ScriptDir  = $PSScriptRoot
$SkillsSrc  = Join-Path $ScriptDir 'skills'

# Prefer USERPROFILE on Windows, fall back to HOME so this also works under
# PowerShell Core on macOS/Linux.
if ($env:USERPROFILE) {
    $SkillsDest = Join-Path $env:USERPROFILE '.claude\skills'
} elseif ($env:HOME) {
    $SkillsDest = Join-Path $env:HOME '.claude/skills'
} else {
    Write-Host "ERROR: Could not determine your home directory (USERPROFILE and HOME are both unset)."
    exit 1
}

if (-not (Test-Path -LiteralPath $SkillsSrc)) {
    Write-Host "ERROR: No skills directory found at $SkillsSrc"
    Write-Host "       Run this script from inside the cloned effortless-skills repo."
    exit 1
}

# Dynamically discover all skill folders under skills\
$Skills = @(Get-ChildItem -LiteralPath $SkillsSrc -Directory | Select-Object -ExpandProperty Name | Sort-Object)

if ($Skills.Count -eq 0) {
    Write-Host "ERROR: No skill folders found in $SkillsSrc"
    exit 1
}

# ---------- helpers ----------

function Get-ModTime {
    param([string]$Path)
    if (Test-Path -LiteralPath $Path) {
        return (Get-Item -LiteralPath $Path).LastWriteTime.ToString('yyyy-MM-dd HH:mm:ss')
    }
    return 'unknown'
}

# Compare directory contents. Returns $true when the two trees are identical.
function Test-DirsIdentical {
    param([string]$Left, [string]$Right)

    if (-not (Test-Path -LiteralPath $Right)) { return $false }

    $leftFiles  = @(Get-ChildItem -LiteralPath $Left  -Recurse -File -ErrorAction SilentlyContinue)
    $rightFiles = @(Get-ChildItem -LiteralPath $Right -Recurse -File -ErrorAction SilentlyContinue)

    if ($leftFiles.Count -ne $rightFiles.Count) { return $false }

    $leftRoot  = (Resolve-Path -LiteralPath $Left).Path
    $rightRoot = (Resolve-Path -LiteralPath $Right).Path

    foreach ($lf in $leftFiles) {
        $rel = $lf.FullName.Substring($leftRoot.Length).TrimStart('\', '/')
        $rp  = Join-Path $rightRoot $rel
        if (-not (Test-Path -LiteralPath $rp)) { return $false }
        $lh = (Get-FileHash -LiteralPath $lf.FullName -Algorithm SHA256).Hash
        $rh = (Get-FileHash -LiteralPath $rp -Algorithm SHA256).Hash
        if ($lh -ne $rh) { return $false }
    }

    return $true
}

function Read-YesNo {
    param([string]$Prompt, [string]$Default = 'n')

    if ($Yes) { return $true }

    while ($true) {
        $answer = Read-Host "$Prompt [y/n]"
        if ([string]::IsNullOrWhiteSpace($answer)) { $answer = $Default }
        switch -Regex ($answer) {
            '^[Yy]' { return $true }
            '^[Nn]' { return $false }
            default { Write-Host "  Please answer y or n." }
        }
    }
}

# First line of the description in a skill's SKILL.md frontmatter.
# Handles both inline (description: text) and folded (description: >\n  text) YAML.
function Get-SkillDescription {
    param([string]$SkillMd)

    if (-not (Test-Path -LiteralPath $SkillMd)) { return '' }

    # -Encoding UTF8 matters on Windows PowerShell 5.1, which otherwise decodes
    # these files as ANSI and turns every non-ASCII character into mojibake.
    $lines = Get-Content -LiteralPath $SkillMd -Encoding UTF8 -ErrorAction SilentlyContinue
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^description:\s*(.*)$') {
            $desc = $Matches[1].Trim()
            if ($desc -eq '>' -or $desc -eq '|' -or $desc -eq '') {
                if ($i + 1 -lt $lines.Count) { $desc = $lines[$i + 1].Trim() }
            }
            if ($desc.Length -gt 60) { $desc = $desc.Substring(0, 60) }
            return $desc
        }
    }
    return ''
}

# ================================================================
#  UNINSTALL
# ================================================================
if ($Uninstall) {
    Write-Host ""
    Write-Host "=== Effortless Claude Skills - Uninstall (PowerShell) ==="
    Write-Host ""
    Write-Host "This will remove the following skills from ${SkillsDest}:"
    Write-Host ""

    $found = @()
    foreach ($skill in $Skills) {
        $dest = Join-Path $SkillsDest $skill
        if (Test-Path -LiteralPath $dest) {
            $found += $skill
            $mt = Get-ModTime (Join-Path $dest 'SKILL.md')
            Write-Host ("  {0}  (modified {1})" -f $skill, $mt)
        }
    }

    if ($found.Count -eq 0) {
        Write-Host "  (none found - nothing to uninstall)"
        Write-Host ""
        exit 0
    }

    Write-Host ""
    if (-not (Read-YesNo "Remove these $($found.Count) skill(s)?")) {
        Write-Host "Aborted."
        exit 0
    }

    $removed = 0
    foreach ($skill in $found) {
        $dest = Join-Path $SkillsDest $skill
        Remove-Item -LiteralPath $dest -Recurse -Force -Confirm:$false
        Write-Host "  Removed: $skill"
        $removed++
    }

    Write-Host ""
    Write-Host "Done - removed $removed skill(s)."
    Write-Host "Changes take effect in your next Claude Code session."
    Write-Host ""
    exit 0
}

# ================================================================
#  INSTALL
# ================================================================
Write-Host ""
Write-Host "=== Effortless Claude Skills - Install (PowerShell) ==="
Write-Host ""
Write-Host "Source:      $SkillsSrc"
Write-Host "Destination: $SkillsDest"
Write-Host "Mode:        copy"
Write-Host ""

# Guard: if the suite is already installed as the `effortless` plugin, loose
# copies under ~/.claude/skills would duplicate every skill and never update.
$pluginManifest = Join-Path (Split-Path $SkillsDest -Parent) 'plugins\installed_plugins.json'
if (Test-Path -LiteralPath $pluginManifest) {
    $manifestText = Get-Content -LiteralPath $pluginManifest -Raw -ErrorAction SilentlyContinue
    if ($manifestText -and $manifestText.Contains('"effortless-skills"')) {
        Write-Host "WARNING: the 'effortless' Claude Code plugin is already installed"
        Write-Host "         (effortless@effortless-skills). Installing loose copies as well"
        Write-Host "         gives Claude two copies of every skill; the loose ones never update."
        Write-Host "         Prefer updating the plugin instead:"
        Write-Host "         claude plugin update effortless@effortless-skills"
        Write-Host ""
        if (-not (Read-YesNo "Install loose copies anyway?" 'n')) {
            Write-Host "Aborted."
            exit 0
        }
        Write-Host ""
    }
}

# Pre-flight: show what will happen for each skill
Write-Host "--- Plan ---"
Write-Host ""
$actionsNeeded = 0

foreach ($skill in $Skills) {
    $src  = Join-Path $SkillsSrc $skill
    $dest = Join-Path $SkillsDest $skill

    if (-not (Test-Path -LiteralPath $dest)) {
        Write-Host "  NEW    $skill - will be installed"
        $actionsNeeded++
    } elseif (Test-DirsIdentical $src $dest) {
        Write-Host "  OK     $skill - installed copy is identical (no change needed)"
    } else {
        $srcTime  = Get-ModTime (Join-Path $src 'SKILL.md')
        $destTime = Get-ModTime (Join-Path $dest 'SKILL.md')
        Write-Host "  UPDATE $skill - content differs"
        Write-Host "           source modified:    $srcTime"
        Write-Host "           installed modified: $destTime"
        $actionsNeeded++
    }
}

Write-Host ""

if ($actionsNeeded -eq 0) {
    Write-Host "Everything is up to date - nothing to do."
    Write-Host ""
    exit 0
}

if (-not $Yes) {
    Write-Host "$actionsNeeded skill(s) to install or update."
    Write-Host ""
}

# ---------- perform install ----------
if (-not (Test-Path -LiteralPath $SkillsDest)) {
    New-Item -ItemType Directory -Path $SkillsDest -Force | Out-Null
}

$installed = 0
$updated   = 0
$skipped   = 0

foreach ($skill in $Skills) {
    $src  = Join-Path $SkillsSrc $skill
    $dest = Join-Path $SkillsDest $skill

    # Already up to date?
    if ((Test-Path -LiteralPath $dest) -and (Test-DirsIdentical $src $dest)) {
        continue
    }

    # Destination exists and differs - ask before overwriting
    $isNew = $true
    if (Test-Path -LiteralPath $dest) {
        $isNew = $false

        if (-not $Yes) {
            $existingDesc = Get-ModTime (Join-Path $dest 'SKILL.md')
            $sourceDesc   = Get-ModTime (Join-Path $src 'SKILL.md')
            Write-Host "  $skill already exists (modified $existingDesc)"
            if (-not (Read-YesNo "  Overwrite with source (modified $sourceDesc)?")) {
                Write-Host "  Skipped."
                $skipped++
                continue
            }
        }

        Remove-Item -LiteralPath $dest -Recurse -Force -Confirm:$false
    }

    Copy-Item -LiteralPath $src -Destination $dest -Recurse -Force

    if ($isNew) {
        Write-Host "  Installed: $skill"
        $installed++
    } else {
        Write-Host "  Updated:   $skill"
        $updated++
    }
}

# ---------- summary ----------
Write-Host ""
Write-Host "--- Summary ---"
Write-Host ""
if ($installed -gt 0) { Write-Host "  Installed: $installed new skill(s)" }
if ($updated -gt 0)   { Write-Host "  Updated:   $updated skill(s)" }
if ($skipped -gt 0)   { Write-Host "  Skipped:   $skipped skill(s) (kept existing)" }
if ($installed -eq 0 -and $updated -eq 0 -and $skipped -eq 0) { Write-Host "  No changes made." }
Write-Host ""
Write-Host "Skills installed to: $SkillsDest\"
Write-Host ""

foreach ($skill in $Skills) {
    $dest = Join-Path $SkillsDest $skill
    if (Test-Path -LiteralPath $dest) {
        $desc = Get-SkillDescription (Join-Path $SkillsSrc "$skill\SKILL.md")
        if ($desc) {
            Write-Host ("  {0,-25} - {1}" -f $skill, $desc)
        } else {
            Write-Host "  $skill"
        }
    }
}

Write-Host ""
Write-Host "Skills will activate automatically in your next Claude Code session."
Write-Host "To uninstall: powershell -ExecutionPolicy Bypass -File install.ps1 -Uninstall"
Write-Host ""
