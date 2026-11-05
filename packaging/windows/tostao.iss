; Instalador do Windows (Inno Setup 6).
; Compilado no CI:  ISCC /DAppVersion=0.2.0 packaging/windows/tostao.iss
; Instala por usuário (sem pedir administrador), então a atualização
; automática roda em silêncio: o app executa este instalador com /VERYSILENT.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
; Não mude o AppId: é ele que faz a versão nova substituir a antiga.
AppId={{18F772C2-A43F-4666-8CF2-3A680E674FF4}
AppName=Tostão
AppVersion={#AppVersion}
AppPublisher=Adrian Rabelo
AppPublisherURL=https://github.com/oadrianrabelo/app-financas
DefaultDirName={localappdata}\Programs\Tostao
DisableProgramGroupPage=yes
DisableDirPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir=..\..\dist
OutputBaseFilename=Tostao_{#AppVersion}_windows-x64-setup
SetupIconFile=..\..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\tostao.exe
CloseApplications=force
RestartApplications=no
Compression=lzma2
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "ptbr"; MessagesFile: "compiler:Languages\BrazilianPortuguese.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Tostão"; Filename: "{app}\tostao.exe"
Name: "{autodesktop}\Tostão"; Filename: "{app}\tostao.exe"; Tasks: desktopicon

[Run]
; Instalação normal: checkbox "Abrir o Tostão" no fim.
Filename: "{app}\tostao.exe"; Description: "{cm:LaunchProgram,Tostão}"; Flags: nowait postinstall skipifsilent
; Atualização automática (silenciosa): reabre o app sozinho.
Filename: "{app}\tostao.exe"; Flags: nowait; Check: WizardSilent
