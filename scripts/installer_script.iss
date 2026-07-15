[Setup]
AppName=Polaris Launcher
AppVersion={#MyAppVersion}
DefaultDirName={autopf}\PolarisLauncher
DefaultGroupName=Polaris Launcher
OutputBaseFilename=polaris_launcher_setup-{#MyAppVersion}
OutputDir=..\build\bin\
Compression=lzma
SolidCompression=yes
AppPublisher=Puzzlots
AppPublisherURL=https://github.com/Puzzlots
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\windows\runner\resources\app_icon.ico

[Files]
Source: "..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: recursesubdirs

[Icons]
Name: "{group}\PolarisLauncher"; Filename: "{app}\polaris_launcher.exe"
