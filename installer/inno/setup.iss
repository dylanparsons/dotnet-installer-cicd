[Setup]
; NOTE: The value of AppId uniquely identifies this application
AppId={{2749448D-DC95-4BEC-AF51-5BA139F9F6DB}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableDirPage=yes
ChangesAssociations=yes
DisableProgramGroupPage=yes
OutputBaseFilename=MyAppSetup_{#MyAppVersion}
SetupIconFile=branding\app_icon.ico
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main executable and config files
Source: "publish\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "publish\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "publish\*.config"; DestDir: "{app}"; Flags: ignoreversion
Source: "publish\*.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "publish\PREFS\*"; DestDir: "{app}\PREFS"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
