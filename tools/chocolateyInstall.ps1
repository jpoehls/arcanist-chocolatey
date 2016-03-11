$installDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Get-ChocolateyUnzip (Join-Path $installDir "arcanist.zip") $installDir
Get-ChocolateyUnzip (Join-Path $installDir "libphutil.zip") $installDir

# Ignore any EXEs that happen to be in those ZIPs.
$files = Get-ChildItem $installDir -Include *.exe -Recurse
foreach ($file in $files) {
  # generate an ignore file
  New-Item "$file.ignore" -type file -force | Out-Null
}

$arcDir = (Get-ChildItem (Join-Path $installDir "arcanist-*") | select -First 1).Name
$phuDir = (Get-ChildItem (Join-Path $installDir "libphutil-*") | select -First 1).Name

# Create an arc.bat script that will forward to the arc.bat
# included in arcanist's bin directory.
# This will be the "arc" command added to the PATH by Chocolatey.
@"
@echo off
"%~dp0arcanist-$arcDir\bin\arc.cmd" %*
"@ | Out-File "$installDir/arc.bat" -Encoding ascii

# Symlink libphutil into arcanist's externals\includes folder.
Start-ChocolateyProcessAsAdmin "cmd /C mklink /D `"$(Join-Path $installDir "$arcDir\externals\includes\libphutil")`" `"$(Join-Path $installDir $phuDir)`""
