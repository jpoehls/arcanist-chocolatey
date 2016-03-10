$installDir = Split-Path -parent $MyInvocation.MyCommand.Definition
 
Install-ChocolateyZipPackage 'arcanist' 'https://github.com/phacility/arcanist/archive/3876d9358390ee9a6290689ca38d8a1e972233b8.zip' $installDir
Install-ChocolateyZipPackage 'libphutil' 'https://github.com/phacility/libphutil/archive/ad3f475c8c13e22096c8c3c60df5f3d886483699.zip' $installDir

# Add the 'arc' command to the PATH.
Install-ChocolateyPath $installDir\arcanist-3876d9358390ee9a6290689ca38d8a1e972233b8\bin

# Symlink libphutil into arcanist's externals\includes folder.
Start-ChocolateyProcessAsAdmin "cmd /C mklink /D `"$(Join-Path $installDir 'arcanist-3876d9358390ee9a6290689ca38d8a1e972233b8\externals\includes\libphutil')`" `"$(Join-Path $installDir 'libphutil-ad3f475c8c13e22096c8c3c60df5f3d886483699')`""
