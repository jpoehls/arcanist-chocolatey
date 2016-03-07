$installDir = Split-Path -parent $MyInvocation.MyCommand.Definition
 
Install-ChocolateyZipPackage 'arcanist' 'https://github.com/phacility/arcanist/archive/master.zip' $installDir
Install-ChocolateyZipPackage 'libphutil' 'https://github.com/phacility/libphutil/archive/master.zip' $installDir

# Add the 'arc' command to the PATH.
Install-ChocolateyPath $installDir\arcanist-master\bin

# Symlink libphutil into arcanist's externals\includes folder.
Start-ChocolateyProcessAsAdmin "cmd /C mklink /D `"$(Join-Path $installDir 'arcanist-master\externals\includes\libphutil')`" `"$(Join-Path $installDir 'libphutil-master')`""