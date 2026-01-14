cd %USERPROFILE%\Documents\GitHub\Puzzlots\CosmicLauncher
call flutter build windows
call makensis.exe installer.nsi
call enigmavbconsole.exe portable.evb