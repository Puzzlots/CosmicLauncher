cd %USERPROFILE%\Documents\GitHub\CosmicLauncher
call flutter build windows
call makensis.exe installer.nsi
call enigmavbconsole.exe portable.evb