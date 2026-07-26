; ============================================================================
;  Inno Setup script — installer Windows untuk "Manafidh Store" (Gallery POS)
; ----------------------------------------------------------------------------
;  Cara membuat Setup.exe:
;   A. Cara mudah (disarankan): jalankan  installer\build_installer.ps1
;      (otomatis: flutter build release + bundling runtime + compile installer)
;   B. Manual: pastikan sudah "flutter build windows --release" dan runtime VC++
;      tersalin ke folder Release, lalu buka file ini di Inno Setup > Build.
;
;  Hasil: installer\output\ManafidhStore-Setup-8.2.1.exe
; ============================================================================

#define MyAppName "Manafidh Office"
#define MyAppVersion "8.2.2"
#define MyAppPublisher "Gallery Makassar"
#define MyAppExeName "myapp.exe"
; Folder hasil `flutter build windows --release` (relatif ke file .iss ini):
#define SourceDir "..\build\windows\x64\runner\Release"

[Setup]
; AppId unik aplikasi — JANGAN diubah agar update memakai identitas yang sama.
AppId={{7F3A9C21-5E64-4B8A-9D12-8C4E1F2A6B3D}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
DisableProgramGroupPage=yes
UninstallDisplayIcon={app}\{#MyAppExeName}
UninstallDisplayName={#MyAppName}
OutputDir=output
OutputBaseFilename=ManafidhStore-Setup-{#MyAppVersion}
SetupIconFile=..\windows\runner\resources\app_icon.ico
Compression=lzma2
SolidCompression=yes
WizardStyle=modern
; Aplikasi 64-bit → pasang ke Program Files 64-bit, hanya di Windows x64.
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin

[Languages]
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Buat ikon di Desktop"; GroupDescription: "Ikon tambahan:"

[Files]
; Bundel folder Release (exe, semua DLL plugin/flutter, folder data\, dan
; runtime VC++ yang disalin ke sana oleh build_installer.ps1).
; Kecualikan artefak linker (*.lib, *.exp, *.pdb) - bukan file runtime.
Source: "{#SourceDir}\*"; DestDir: "{app}"; Excludes: "*.lib,*.exp,*.pdb"; Flags: recursesubdirs createallsubdirs ignoreversion

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\Uninstall {#MyAppName}"; Filename: "{uninstallexe}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "Jalankan {#MyAppName} sekarang"; Flags: nowait postinstall skipifsilent
