Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Update-NuSpec {
    param(
        [string]$Path,
        [string]$Version,
        [string]$ReleaseNotes
    )

    $ns = @{ nuspec = 'http://schemas.microsoft.com/packaging/2015/06/nuspec.xsd' }
    $xml = [xml](Get-Content -LiteralPath $Path -Raw)
   
    $el = $xml | Select-Xml -XPath '/nuspec:package/nuspec:metadata/nuspec:version' -Namespace $ns
    $el.Node.InnerText = $Version

    $el = $xml | Select-Xml -XPath '/nuspec:package/nuspec:metadata/nuspec:releaseNotes' -Namespace $ns
    $el.Node.InnerText = $ReleaseNotes

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
        "PhuRevision" = $phuRevision;
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

function Get-CommitZip {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Sha
    )

    Invoke-WebRequest -Uri "https://github.com/$Owner/$Repo/archive/$Sha.zip" -OutFile (Join-Path (Split-Path $PSCommandPath) "tools/$Repo.zip")
}

Write-Output "Getting latest Phabricator release info..."
$release = Get-PhabLatestRelease
Write-Output $release
Write-Output ""

Write-Output "Downloading arcanist..."
Get-CommitZip -Owner phacility -Repo arcanist -Sha $release.ArcRevision

Write-Output "Downloading libphutil..."
Get-CommitZip -Owner phacility -Repo libphutil -Sha $release.PhuRevision

$releaseNotes = @"
Read Phabricator's changelog for [$($release.ReleaseName)]($($release.ChangelogUrl)).

Bundles arcanist revision [$($release.ArcRevision.Substring(0,12))](https://secure.phabricator.com/diffusion/ARC/history/master/;$($release.ArcRevision))
and libphutil revision [$($release.PhuRevision.Substring(0,12))](https://secure.phabricator.com/diffusion/PHU/history/master/;$($release.PhuRevision)).
"@

$nuspec = Join-Path (Split-Path $PSCommandPath) 'arcanist.nuspec'
Write-Output "Updating $(Split-Path $nuspec -Leaf)..."
Update-NuSpec -Path $nuspec `
              -Version $release.Version `
              -ReleaseNotes $releaseNotes

Write-Output "Packing..."
choco pack $nuspec