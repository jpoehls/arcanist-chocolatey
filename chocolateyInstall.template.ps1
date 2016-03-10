

$installDir = Split-Path -parent $MyInvocation.MyCommand.Definition
 
Install-ChocolateyZipPackage 'arcanist' $ArcDownloadUrl $installDir
Install-ChocolateyZipPackage 'libphutil' $PhuDownloadUrl $installDir

# Add the 'arc' command to the PATH.
Install-ChocolateyPath (Join-Path $installDir "arcanist-$ArcRevision\bin")

# Symlink libphutil into arcanist's externals\includes folder.
Start-ChocolateyProcessAsAdmin "cmd /C mklink /D `"$(Join-Path $installDir "arcanist-$ArcRevision\externals\includes\libphutil")`" `"$(Join-Path $installDir "libphutil-$PhuRevision")`""