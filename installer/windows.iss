; SENDIT Windows 安装包（Inno Setup 6）
; 由 GitHub Actions 传入 /DAppVersion=x.y.z /DSourceDir=<flutter build 输出目录>
#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif

[Setup]
AppId={{8D2C0B3E-5A61-4C1B-9B4E-SENDIT000001}
AppName=SENDIT
AppVersion={#AppVersion}
AppPublisher=SENDIT
AppPublisherURL=https://sendit-73d.pages.dev
DefaultDirName={autopf}\SENDIT
DefaultGroupName=SENDIT
UninstallDisplayIcon={app}\sendit.exe
OutputDir=..\dist
OutputBaseFilename=SENDIT-{#AppVersion}-windows-setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog

[Tasks]
Name: "desktopicon"; Description: "创建桌面快捷方式 / Create a desktop shortcut"; GroupDescription: "快捷方式 / Shortcuts:"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\SENDIT"; Filename: "{app}\sendit.exe"
Name: "{autodesktop}\SENDIT"; Filename: "{app}\sendit.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\sendit.exe"; Description: "启动 SENDIT / Launch SENDIT"; Flags: nowait postinstall skipifsilent
