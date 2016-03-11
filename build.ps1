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

function Get-GitHubDownloadUrl {
    param(
        [string]$Owner,
        [string]$Repo,
        [string]$Sha
    )

    return "https://github.com/$Owner/$Repo/archive/$Sha.zip"
}

function Get-CommitZip {
    param(
        [string]$Url,
        [string]$Target
    )

    $file = (Join-Path (Split-Path $PSCommandPath) $Target)
    
    Write-Output "   URL: $Url"
    Invoke-WebRequest -Uri $Url -OutFile $file
    Write-Output "  FILE: $Target"
    Write-Output "   MD5: $((Get-FileHash $file -Algorithm MD5).Hash.ToLower())"
}

function New-VerificationFile {
    param(
        [string]$ArcDownloadUrl,
        [string]$PhuDownloadUrl,
        [string]$ReleaseName,
        [string]$ChangelogUrl,
        [string]$PackageVersion
    )
    
    $txt = @"
VERIFICATION.TXT is intended to assist the Chocolatey moderators and community
in verifying that this package's contents are trustworthy.

The following package files can be verified by comparing a hash of their content
to hash of the file available at the corresponding download URL.

These download URLs are what we assert to be the trusted source for those files.

    tools/arcanist.zip: $ArcDownloadUrl
    tools/libputil.zip: $PhuDownloadUrl

These commits were packaged as version $PackageVersion ($ReleaseName)
based on the Phabricator changelog at $ChangelogUrl
"@

    $outfile = "tools/verification.txt"
    $txt | Out-File $outfile -Encoding utf8
}

Write-Output "Getting latest Phabricator release info..."
$release = Get-PhabLatestRelease
Write-Output $release
Write-Output ""

Write-Output "Downloading arcanist..."
$arcDownloadUrl = Get-GitHubDownloadUrl -Owner phacility -Repo arcanist -Sha $release.ArcRevision 
Get-CommitZip -Url $arcDownloadUrl -Target "tools/arcanist.zip"

Write-Output "Downloading libphutil..."
$phuDownloadUrl = Get-GitHubDownloadUrl -Owner phacility -Repo libphutil -Sha $release.PhuRevision
Get-CommitZip -Url $phuDownloadUrl -Target "tools/libphutil.zip"

Write-Output "Writing verification.txt..."
New-VerificationFile -ArcDownloadUrl $arcDownloadUrl -PhuDownloadUrl $phuDownloadUrl -ReleaseName $release.ReleaseName -ChangelogUrl $release.ChangelogUrl -PackageVersion $release.Version

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