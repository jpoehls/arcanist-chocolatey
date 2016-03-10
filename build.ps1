Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Update-NuSpec {
    param(
        [string]$Path,
        [string]$Version,
        [string]$ReleaseName,
        [string]$ChangeLogUrl
    )

    $ns = @{ nuspec = 'http://schemas.microsoft.com/packaging/2015/06/nuspec.xsd' }
    $xml = [xml](Get-Content -LiteralPath $Path -Raw)
   
    $el = $xml | Select-Xml -XPath '/nuspec:package/nuspec:metadata/nuspec:version' -Namespace $ns
    $el.Node.InnerText = $Version

    $el = $xml | Select-Xml -XPath '/nuspec:package/nuspec:metadata/nuspec:releaseNotes' -Namespace $ns
    $el.Node.InnerText = "Read Phabricator's changelog for [$ReleaseName]($ChangelogUrl)."

    $xml.Save($Path)
}

function Get-PhabLatestRelease {

    $phabUri = [uri]'https://secure.phabricator.com/w/changelog/' 

    $resp = Invoke-WebRequest -Uri $phabUri
    $link = $resp.Links | ? { $_.href -match '/w/changelog/(\d{4}\.\d{2})/?$' } | select -First 1
    if (!$link) { throw "Failed to find a link to the latest release in the change log." }
    $releaseName = $link.outerText
    $version = $Matches[1]

    $changelogUri = New-Object Uri @($phabUri, $link.href)
    $resp = Invoke-WebRequest -Uri $changelogUri
    
    $link = $resp.Links | ? { $_.href -match '/rARC([0-9a-f]{40})$' } | select -First 1
    if (!$link) { throw "Failed to find a link to the arcanist revision on $changelogUri." }
    $arcRevision = $Matches[1]

    $link = $resp.Links | ? { $_.href -match '/rPHU([0-9a-f]{40})$' } | select -First 1
    if (!$link) { throw "Failed to find a link to the libphutil revision on $changelogUri." }
    $phuRevision = $Matches[1]

    return @{
        "ReleaseName" = $releaseName;
        "Version" = $version;
        "ArcRevision" = $arcRevision;
        "ArcDownloadUrl" = "https://github.com/phacility/arcanist/archive/$arcRevision.zip";
        "PhuRevision" = $phuRevision;
        "PhuDownloadUrl" = "https://github.com/phacility/libphutil/archive/$phuRevision.zip";
        "ChangelogUrl" = $changelogUri.ToString();
    }
}

function Test-GitHubCommit {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Sha
    )

    $resp = Invoke-WebRequest -Uri "https://api.github.com/repos/$Owner/$Repo/commits/$Sha" -ErrorAction SilentlyContinue
    return ($resp -and $resp.StatusCode -eq 200)
}

Write-Output "Getting latest Phabricator release info..."
$release = Get-PhabLatestRelease
Write-Output $release
Write-Output ""

Write-Output "Checking GitHub for release commits..."
if (-not (Test-GitHubCommit -Owner phacility -Repo arcanist -Sha $release.ArcRevision)) {
    throw "arcanist commit not found on GitHub: $($release.ArcRevision)"
}
if (-not (Test-GitHubCommit -Owner phacility -Repo libphutil -Sha $release.PhuRevision)) {
    throw "arcanist commit not found on GitHub: $($release.ArcRevision)"
}
Write-Output "Building chocolateyInstall.ps1..."
$chocolateyInstallTemplate = Get-Content .\chocolateyInstall.template.ps1 -Raw
$chocolateyInstallTemplate = $chocolateyInstallTemplate.Replace("#ArcDownloadUrl#", $release.ArcDownloadUrl)
$chocolateyInstallTemplate = $chocolateyInstallTemplate.Replace("#PhuDownloadUrl#", $release.PhuDownloadUrl)
$chocolateyInstallTemplate = $chocolateyInstallTemplate.Replace("#ArcRevision#", $release.ArcRevision)
$chocolateyInstallTemplate = $chocolateyInstallTemplate.Replace("#PhuRevision#", $release.PhuRevision)
$chocolateyInstallTemplate | Out-File .\tools\chocolateyInstall.ps1 -Encoding utf8

$nuspec = Join-Path (Split-Path $PSCommandPath) 'arcanist.nuspec'
Write-Output "Updating $(Split-Path $nuspec -Leaf)..."
Update-NuSpec -Path $nuspec `
              -Version $release.Version `
              -ReleaseName $release.ReleaseName `
              -ChangelogUrl $release.ChangelogUrl

Write-Output "Packing..."
choco pack $nuspec