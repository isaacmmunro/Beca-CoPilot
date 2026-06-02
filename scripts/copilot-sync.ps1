param(
    [ValidateSet("from-studio", "to-studio")]
    [string]$Direction = "from-studio",
    [string]$ProjectDir = ".\Draft Variation Assistant",
    [string]$Branch = "feature/pull-copilot-agent",
    [string]$CommitMessage = "Sync Copilot agent workspace"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Resolve-ToolPath {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        [string[]]$FallbackPaths = @()
    )

    $cmd = Get-Command $Name -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }

    foreach ($path in $FallbackPaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    throw "Required tool '$Name' was not found."
}

# Ensure this process can discover newly installed tools.
$env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")

$gitPath = Resolve-ToolPath -Name "git" -FallbackPaths @(
    "C:\Users\IM146\AppData\Local\Programs\Git\cmd\git.exe",
    "C:\Program Files\Git\cmd\git.exe",
    "C:\Program Files\Git\bin\git.exe"
)

$pacPath = Resolve-ToolPath -Name "pac"

if (-not (Test-Path $ProjectDir)) {
    throw "Project directory '$ProjectDir' does not exist."
}

$repoRoot = & $gitPath rev-parse --show-toplevel 2>$null
if (-not $repoRoot) {
    throw "Current directory is not inside a git repository."
}

if ($Direction -eq "from-studio") {
    Write-Host "Pulling latest changes from Copilot Studio..."
    & $pacPath copilot pull --project-dir $ProjectDir

    Write-Host "Switching to branch '$Branch'..."
    & $gitPath checkout -B $Branch

    Write-Host "Staging changes..."
    & $gitPath add .

    & $gitPath diff --cached --quiet
    if ($LASTEXITCODE -eq 0) {
        Write-Host "No local changes to commit."
    }
    else {
        $finalCommitMessage = "$CommitMessage ($(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'))"
        Write-Host "Committing changes..."
        & $gitPath commit -m $finalCommitMessage
    }

    Write-Host "Pushing branch '$Branch' to origin..."
    & $gitPath push -u origin $Branch

    Write-Host "Done. Studio to GitHub sync completed."
    exit 0
}

if ($Direction -eq "to-studio") {
    Write-Host "Pushing local workspace changes to Copilot Studio..."
    & $pacPath copilot push --project-dir $ProjectDir
    Write-Host "Done. Local to Studio sync completed."
    exit 0
}
