; Enhanced Inno Setup Script for POSAce with VCRUNTIME Fix
; Resolves VCRUNTIME140_1.dll missing error on Surface PCs and clean Windows installations

#define MyAppName "POSAce"
#define MyAppVersion "1.0.25"
#define MyAppPublisher "Ihan Soft"
#define MyAppURL "https://www.posace.com"
#define MyAppExeName "posace_app_win.exe"

[Setup]
; NOTE: The value of AppId uniquely identifies this application.
AppId={{D41A23C7-852E-4748-8924-1770026540090}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
PrivilegesRequired=lowest
DefaultDirName={localappdata}\{#MyAppName}
UsePreviousAppDir=no
DisableProgramGroupPage=yes
OutputBaseFilename=POSAce_Setup_Enhanced
Compression=lzma
SolidCompression=yes
OutputDir=Output
; Enhanced system requirements
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
MinVersion=10.0
SetupLogging=yes
; Custom wizard pages for better user experience
WizardStyle=modern
; WizardSizePercent=120  ; Inno Setup 6 only - removed for IS5 compatibility

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"
Name: "startmenuicon"; Description: "Create Start Menu shortcut"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main application files
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; Visual C++ Redistributable package (bundled for offline installation)
Source: "redistributables\VC_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall; Check: not IsVCRedistInstalled

; Essential runtime DLLs (fallback if redistributable installation fails)
Source: "redistributables\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist; Check: not IsVCRuntimeDllExists
Source: "redistributables\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist; Check: not IsVCRuntimeDllExists  
Source: "redistributables\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist; Check: not IsVCRuntimeDllExists
Source: "redistributables\concrt140.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist; Check: not IsVCRuntimeDllExists
Source: "redistributables\vccorlib140.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist; Check: not IsVCRuntimeDllExists

[Icons]
Name: "{commonprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: startmenuicon
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Code]
var
  ProgressPage: TOutputProgressWizardPage;

// Helper function: Convert Boolean to String (for Inno Setup 5 compatibility)
function BoolToStr(Value: Boolean): String;
begin
  if Value then
    Result := 'True'
  else
    Result := 'False';
end;

// Check if Visual C++ Redistributable is installed
function IsVCRedistInstalled: Boolean;
var
  Version: String;
  MajorVersion, MinorVersion: Cardinal;
begin
  Result := False;
  
  // Check for Visual C++ 2015-2022 Redistributable (x64)
  if RegQueryStringValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Version', Version) then
  begin
    // Parse version string (format: v14.xx.xxxxx)
    if (Length(Version) > 3) and (Copy(Version, 1, 1) = 'v') then
    begin
      MajorVersion := StrToIntDef(Copy(Version, 2, 2), 0);
      Result := MajorVersion >= 14; // Visual Studio 2015 or later
    end;
  end
  else
  begin
    // Fallback: Check WOW6432Node for 32-bit registry view
    if RegQueryStringValue(HKLM64, 'SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Version', Version) then
    begin
      if (Length(Version) > 3) and (Copy(Version, 1, 1) = 'v') then
      begin
        MajorVersion := StrToIntDef(Copy(Version, 2, 2), 0);
        Result := MajorVersion >= 14;
      end;
    end;
  end;
  
  Log('Visual C++ Redistributable check result: ' + BoolToStr(Result));
end;

// Check if essential VCRUNTIME DLLs exist in system
function IsVCRuntimeDllExists: Boolean;
var
  SystemPath: String;
begin
  SystemPath := ExpandConstant('{sys}');
  Result := FileExists(SystemPath + '\vcruntime140_1.dll') and 
            FileExists(SystemPath + '\vcruntime140.dll') and
            FileExists(SystemPath + '\msvcp140.dll');
  
  Log('VCRUNTIME DLLs existence check: ' + BoolToStr(Result));
  Log('Checking path: ' + SystemPath);
end;

// Enhanced system requirements check
function InitializeSetup(): Boolean;
var
  Version: TWindowsVersion;
  ErrorMsg: String;
begin
  Result := True;
  
  GetWindowsVersionEx(Version);
  
  // Check Windows 10 or later
  if Version.Major < 10 then
  begin
    ErrorMsg := 'POSAce requires Windows 10 or later.' + #13#10 +
                'Current version: Windows ' + IntToStr(Version.Major) + '.' + IntToStr(Version.Minor);
    MsgBox(ErrorMsg, mbError, MB_OK);
    Result := False;
    Exit;
  end;
  
  // Check 64-bit architecture
  if not Is64BitInstallMode then
  begin
    MsgBox('POSAce requires 64-bit Windows.', mbError, MB_OK);
    Result := False;
    Exit;
  end;
  
  Log('System requirements check passed');
  Log('Windows version: ' + IntToStr(Version.Major) + '.' + IntToStr(Version.Minor) + '.' + IntToStr(Version.Build));
end;

// Initialize wizard with custom progress page
procedure InitializeWizard();
begin
  ProgressPage := CreateOutputProgressPage('System Preparation', 'Installing required components...');
end;

// Custom installation progress
procedure CurStepChanged(CurStep: TSetupStep);
begin
  case CurStep of
    ssInstall:
    begin
      ProgressPage.Show;
      try
        ProgressPage.SetText('Preparing installation...', '');
        ProgressPage.SetProgress(0, 100);
        Sleep(500);
        
        if not IsVCRedistInstalled and not IsVCRuntimeDllExists then
        begin
          ProgressPage.SetText('Installing Visual C++ Runtime...', 'This may take a few minutes.');
          ProgressPage.SetProgress(25, 100);
        end
        else
        begin
          ProgressPage.SetText('Runtime components already installed.', '');
          ProgressPage.SetProgress(50, 100);
        end;
        
      finally
        ProgressPage.Hide;
      end;
    end;
  end;
end;

// Verify installation after completion
function VerifyInstallation: Boolean;
var
  ExitCode: Integer;
  AppPath: String;
begin
  Result := True;
  AppPath := ExpandConstant('{app}\{#MyAppExeName}');
  
  // Basic file existence check
  if not FileExists(AppPath) then
  begin
    MsgBox('Installation verification failed: Main executable not found.', mbError, MB_OK);
    Result := False;
    Exit;
  end;
  
  Log('Installation verification: Main executable found');
  
  // Try to get version info (quick test)
  try
    if not Exec(AppPath, '--version', '', SW_HIDE, ewWaitUntilTerminated, ExitCode) then
    begin
      Log('Warning: Could not verify application startup');
      // Don't fail installation for this, just log warning
    end
    else
    begin
      Log('Application startup verification successful');
    end;
  except
    Log('Exception during application verification (non-critical)');
  end;
end;

// Post-installation cleanup and verification
procedure CurStepChanged2(CurStep: TSetupStep);
begin
  case CurStep of
    ssPostInstall:
    begin
      VerifyInstallation;
    end;
  end;
end;

[Run]
; Install Visual C++ Redistributable if needed
Filename: "{tmp}\VC_redist.x64.exe"; Parameters: "/quiet /norestart"; StatusMsg: "Installing Visual C++ Runtime components..."; Check: not IsVCRedistInstalled and not IsVCRuntimeDllExists; Flags: waituntilterminated runhidden

; Launch application after installation
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
; Silent mode auto-launch (for automated installations)
Filename: "{app}\{#MyAppExeName}"; Flags: nowait; Check: WizardSilent

[UninstallDelete]
Type: filesandordirs; Name: "{app}\data"
Type: filesandordirs; Name: "{app}\*.log"

[Messages]
; English messages  
english.WelcomeLabel2=This will install [name] on your computer.%n%nSystem requirements will be checked and necessary runtime components will be installed automatically.%n%nIt is recommended that you close all other applications before continuing.
english.FinishedHeadingLabel=Completing the [name] Setup Wizard
english.FinishedLabelNoIcons=Setup has finished installing [name] on your computer.
english.FinishedLabel=Setup has finished installing [name] on your computer. The application may be launched by selecting the installed icons.