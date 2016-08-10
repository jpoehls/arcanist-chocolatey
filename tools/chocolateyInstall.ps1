$installDir = Split-Path -Parent $MyInvocation.MyCommand.Definition

Get-ChocolateyUnzip -FileFullPath (Join-Path $installDir "arcanist.zip") -Destination $installDir
Get-ChocolateyUnzip -FileFullPath (Join-Path $installDir "libphutil.zip") -Destination $installDir

# Ignore any EXEs that happen to be in those ZIPs.
$files = Get-ChildItem $installDir -Include *.exe -Recurse
foreach ($file in $files) {
  # generate an ignore file
  New-Item "$file.ignore" -type file -force | Out-Null
}

$arcDir = (Get-ChildItem (Join-Path $installDir "arcanist-*") | select -First 1).Name
$phuDir = (Get-ChildItem (Join-Path $installDir "libphutil-*") | select -First 1).Name

# Create a shim file (arc.exe) that will be on the user's PATH.
Install-BinFile -Name "arc" -Path (Join-Path $installDir "$arcDir\bin\arc.bat")

# Symlink libphutil into arcanist's externals\includes folder.
Start-ChocolateyProcessAsAdmin "cmd /C mklink /D `"$(Join-Path $installDir "$arcDir\externals\includes\libphutil")`" `"$(Join-Path $installDir $phuDir)`""
