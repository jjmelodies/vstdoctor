; Inno Setup 6 installer script.
;
; Compile via tools\build-installer.ps1 — that wrapper exports the env vars
; this script reads (PROJECT_NAME / PRODUCT_NAME / COMPANY_NAME / PLUGIN_BUILD_DIR).

#define Version    Trim(FileRead(FileOpen("..\VERSION")))
#define ProjectName GetEnv('PROJECT_NAME')
#define ProductName GetEnv('PRODUCT_NAME')
#define Publisher   GetEnv('COMPANY_NAME')
#define Year        GetDateTimeString("yyyy","","")

#define BuildDir GetEnv('PLUGIN_BUILD_DIR')
#if BuildDir == ""
  #define BuildDir "BuildsRelease"
#endif

[Types]
Name: "full";   Description: "Full installation"
Name: "custom"; Description: "Custom installation"; Flags: iscustom

[Components]
Name: "vst3";       Description: "VST3 plugin (required)";  Types: full custom; Flags: fixed
Name: "standalone"; Description: "Standalone application";  Types: full custom
Name: "manual";     Description: "User manual (PDF)";       Types: full custom

[Tasks]
Name: "desktopicon";   Description: "Create a &desktop shortcut";    \
    GroupDescription: "Additional shortcuts:"; Components: standalone
Name: "startmenuicon"; Description: "Create a &Start Menu shortcut"; \
    GroupDescription: "Additional shortcuts:"; Components: standalone

[Setup]
; Stable upgrade key. REPLACE WITH A FRESH GUID before first release.
; Add/Remove Programs uses this to recognise upgrades vs. parallel installs.
; Once shipped, never change it.
AppId={{CC83E21E-D97B-4210-9F19-9660EC1D12EE}

AppName={#ProductName}
AppVersion={#Version}
AppVerName={#ProductName} {#Version}
AppPublisher={#Publisher}
AppCopyright=Copyright (C) {#Year} {#Publisher}

OutputBaseFilename={#ProductName}-{#Version}-Windows

; Default VST3 system path. The user can redirect on the Directory page.
DefaultDirName={commoncf64}\VST3\{#ProductName}.vst3

DisableReadyPage=yes
DisableProgramGroupPage=yes
WizardStyle=modern

ArchitecturesInstallIn64BitMode=x64compatible
ArchitecturesAllowed=x64compatible
PrivilegesRequired=admin

UninstallDisplayName={#ProductName} {#Version}
UninstallDisplayIcon={commonpf64}\{#Publisher}\{#ProductName}\{#ProductName}.exe
UninstallFilesDir={commonappdata}\{#ProductName}\uninstall

[Files]
; VST3 bundle -> {app} (user-chosen on the Directory page).
Source: "..\{#BuildDir}\{#ProjectName}_artefacts\Release\VST3\{#ProductName}.vst3\*"; \
    DestDir: "{app}"; \
    Excludes: "*.ilk"; \
    Flags: ignoreversion recursesubdirs createallsubdirs; \
    Components: vst3

; Standalone -> Program Files\<Publisher>\<ProductName>.
Source: "..\{#BuildDir}\{#ProjectName}_artefacts\Release\Standalone\{#ProductName}.exe"; \
    DestDir: "{commonpf64}\{#Publisher}\{#ProductName}"; \
    Flags: ignoreversion; \
    Components: standalone

; Manual PDF (only if you ship one — drop the [Files] line and the manual
; component above if you don't).
Source: "..\docs\manual.pdf"; \
    DestDir: "{commonpf64}\{#Publisher}\{#ProductName}"; \
    DestName: "{#ProductName}-Manual.pdf"; \
    Flags: ignoreversion; \
    Components: manual

[Icons]
Name: "{autoprograms}\{#Publisher}\{#ProductName}"; \
    Filename: "{commonpf64}\{#Publisher}\{#ProductName}\{#ProductName}.exe"; \
    Tasks: startmenuicon; Components: standalone

Name: "{autodesktop}\{#ProductName}"; \
    Filename: "{commonpf64}\{#Publisher}\{#ProductName}\{#ProductName}.exe"; \
    Tasks: desktopicon; Components: standalone

Name: "{autoprograms}\{#Publisher}\{#ProductName} Manual"; \
    Filename: "{commonpf64}\{#Publisher}\{#ProductName}\{#ProductName}-Manual.pdf"; \
    Components: manual

Name: "{autoprograms}\{#Publisher}\Uninstall {#ProductName}"; \
    Filename: "{uninstallexe}"
