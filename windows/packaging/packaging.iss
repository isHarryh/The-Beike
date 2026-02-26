; *** Inno Setup Script for ArkPets ***
; This script is based on Inno Setup 6, a free installer for Windows programs.
; Documentation: https://jrsoftware.org/ishelp.php
; Download Inno Setup: https://jrsoftware.org/isdl.php

#define MyAppName "TheBeike"
#define MyAppFileName "the_beike"
#define MyAppVersion "1.0.0"
#define MyAppPublisher "Harry Huang"
#define MyAppURL "https://thebeike.cn/"

[Setup]
; WARN: The value of AppId uniquely identifies this app. Do not use the same AppId value in installers for other apps.
; (To generate a new GUID, click Tools | Generate GUID inside the Inno Setup IDE.)
AppCopyright        = Copyright (C) 2025 {#MyAppPublisher}
AppId               ={{8AD17B42-067B-4C08-9520-C882948E4CD4}
AppName             ={#MyAppName}
AppVersion          ={#MyAppVersion}
AppVerName          ="{#MyAppName} {#MyAppVersion}"
AppPublisher        ={#MyAppPublisher}
AppPublisherURL     ={#MyAppURL}
AppSupportURL       ={#MyAppURL}

AllowNoIcons        =yes
Compression         =lzma2/max
DefaultDirName      ="{userpf}\{#MyAppName}"
DefaultGroupName    ={#MyAppName}
PrivilegesRequired  =lowest
OutputBaseFilename  ={#MyAppName}-v{#MyAppVersion}-Windows
OutputDir           =..\..\dist\windows
SetupIconFile       =..\runner\resources\app_icon.ico
SolidCompression    =yes
UninstallDisplayIcon={app}\{#MyAppName}.ico
WizardStyle         =modern
ChangesEnvironment  =true

[Languages]
Name: "chinese_simplified";  MessagesFile: "ChineseSimplified.isl"
Name: "chinese_traditional";  MessagesFile: "ChineseTraditional.isl"
Name: "english";  MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\LICENSE"; DestDir: "{app}"; Flags: ignoreversion
; NOTE: Don't use "Flags: ignoreversion" on any shared system files

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppFileName}.exe"; WorkingDir: "{app}"
Name: "{group}\{cm:ProgramOnTheWeb,{#MyAppName}}"; Filename: "{#MyAppURL}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppFileName}.exe"; Tasks: desktopicon; WorkingDir: "{app}"

[Run]
Filename: "{app}\{#MyAppFileName}.exe"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall

[InstallDelete]
Type: filesandordirs; Name: "{app}\data"
