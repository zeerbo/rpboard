; RPBoard Windows installer
; Built with build.ps1: flutter build windows --release, then ISCC this script.
; MyAppVersion is passed in via /DMyAppVersion=x.y.z; DefaultVersion below is only
; used if the script is compiled directly without that define.
#ifndef MyAppVersion
  #define MyAppVersion "0.0.0"
#endif

#define MyAppName "RPBoard"
#define MyAppPublisher "com.zeerbo"
#define MyAppExeName "rpboard.exe"
#define ReleaseDir "..\build\windows\x64\runner\Release"
#define DataFolderName "rpboard"

[Setup]
AppId={{AE3ECD00-F158-4881-A821-EB0FB5632BB6}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={userpf}\{#MyAppName}
DefaultGroupName={#MyAppName}
PrivilegesRequired=lowest
DisableProgramGroupPage=yes
OutputDir=output
OutputBaseFilename=RPBoard-Setup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#MyAppExeName}
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "italian"; MessagesFile: "compiler:Languages\Italian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#ReleaseDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /quiet /norestart"; StatusMsg: "Installazione Visual C++ Redistributable..."; Flags: waituntilterminated
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[Code]
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
var
  DataDir: String;
begin
  if CurUninstallStep = usPostUninstall then
  begin
    DataDir := ExpandConstant('{userdocs}\{#DataFolderName}');
    if DirExists(DataDir) then
    begin
      if MsgBox('Vuoi rimuovere anche i dati salvati (personaggi, campagne)?' + #13#10 +
                'Do you want to remove your saved data (characters, campaigns) as well?',
                mbConfirmation, MB_YESNO) = IDYES then
      begin
        DelTree(DataDir, True, True, True);
      end;
    end;
  end;
end;
