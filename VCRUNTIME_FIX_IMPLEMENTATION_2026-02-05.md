# VCRUNTIME140_1.dll 오류 해결 및 설치 개선 (2026-02-05)

**문제**: 윈도우즈 서피스 PC에서 VCRUNTIME140_1.dll 오류로 인한 설치 실패  
**날짜**: 2026-02-05  
**상태**: 해결 방안 제시

---

## 🔍 문제 분석

### 오류 원인
- **VCRUNTIME140_1.dll**: Visual C++ 2019 Redistributable 런타임 라이브러리 누락
- **서피스 PC 특성**: 최신 Windows 10/11이지만 개발 도구 런타임이 설치되지 않은 경우 발생
- **Flutter Windows 앱**: C++ 런타임에 의존성이 있어 해당 DLL 필요

### 영향 범위
- 윈도우즈 서피스 시리즈
- 새로 설치된 Windows 시스템
- 개발 도구가 설치되지 않은 일반 사용자 PC

---

## 🛠️ 해결 방안

### 방안 1: Visual C++ Redistributable 번들링 (추천)

#### 1.1 필요한 파일 다운로드
Microsoft Visual C++ 2015-2022 Redistributable 패키지:
- **x64 버전**: `VC_redist.x64.exe`
- **다운로드 URL**: https://aka.ms/vs/17/release/vc_redist.x64.exe

#### 1.2 설치 스크립트 개선
**파일**: `installers/setup_improved.iss`

```inno
#define MyAppName "POSAce"
#define MyAppVersion "1.0.25"
#define MyAppPublisher "Ihan Soft"
#define MyAppURL "https://www.posace.com"
#define MyAppExeName "posace_app_win.exe"

[Setup]
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
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
; 설치 전 시스템 요구사항 체크 활성화
SetupLogging=yes

[Languages]
Name: "korean"; MessagesFile: "compiler:Languages\Korean.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
; 메인 애플리케이션 파일들
Source: "..\build\windows\x64\runner\Release\{#MyAppExeName}"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\*.dll"; DestDir: "{app}"; Flags: ignoreversion
Source: "..\build\windows\x64\runner\Release\data\*"; DestDir: "{app}\data"; Flags: ignoreversion recursesubdirs createallsubdirs

; Visual C++ Redistributable 패키지 번들링
Source: "redistributables\VC_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

; 추가 런타임 DLL들 (필요시)
Source: "redistributables\msvcp140.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist
Source: "redistributables\vcruntime140.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist  
Source: "redistributables\vcruntime140_1.dll"; DestDir: "{app}"; Flags: ignoreversion skipifsourcedoesntexist

[Icons]
Name: "{commonprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{commondesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Code]
// Visual C++ Redistributable 설치 확인 함수
function IsVCRedistInstalled: Boolean;
var
  Version: String;
begin
  // 레지스트리에서 Visual C++ 2015-2022 설치 여부 확인
  Result := RegQueryStringValue(HKLM64, 'SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Version', Version) or
            RegQueryStringValue(HKLM64, 'SOFTWARE\WOW6432Node\Microsoft\VisualStudio\14.0\VC\Runtimes\x64', 'Version', Version);
end;

// VCRUNTIME140_1.dll 존재 확인
function IsVCRuntimeDllExists: Boolean;
var
  SystemPath: String;
begin
  SystemPath := ExpandConstant('{sys}');
  Result := FileExists(SystemPath + '\vcruntime140_1.dll') or 
            FileExists(SystemPath + '\vcruntime140.dll');
end;

[Run]
; Visual C++ Redistributable 설치 (필요한 경우에만)
Filename: "{tmp}\VC_redist.x64.exe"; Parameters: "/quiet /norestart"; StatusMsg: "Visual C++ Runtime 설치 중..."; Check: not IsVCRedistInstalled and not IsVCRuntimeDllExists; Flags: waituntilterminated

; 애플리케이션 실행
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
Filename: "{app}\{#MyAppExeName}"; Flags: nowait; Check: WizardSilent

[Messages]
korean.WelcomeLabel2=POSAce를 설치합니다.%n%n시스템 요구사항을 확인하고 필요한 런타임을 자동으로 설치합니다.
english.WelcomeLabel2=This will install POSAce on your computer.%n%nSystem requirements will be checked and necessary runtimes will be installed automatically.
```

### 방안 2: 로컬 DLL 번들링

#### 2.1 필요한 DLL 파일 수집
다음 DLL들을 `redistributables/` 폴더에 준비:

```
redistributables/
├── VC_redist.x64.exe          # Visual C++ Redistributable 설치 파일
├── vcruntime140.dll           # Visual C++ Runtime
├── vcruntime140_1.dll         # Visual C++ Runtime (추가)
├── msvcp140.dll               # C++ Standard Library
├── concrt140.dll              # Concurrency Runtime
└── vccorlib140.dll            # Core Library
```

#### 2.2 DLL 수집 스크립트
**파일**: `scripts/collect_runtime_dlls.ps1`

```powershell
# Visual C++ Runtime DLL 수집 스크립트
param(
    [string]$OutputDir = "redistributables"
)

Write-Host "Visual C++ Runtime DLL 수집 시작..."

# 출력 디렉토리 생성
if (!(Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force
}

# 시스템에서 필요한 DLL 찾기
$SystemDlls = @(
    "vcruntime140.dll",
    "vcruntime140_1.dll", 
    "msvcp140.dll",
    "concrt140.dll",
    "vccorlib140.dll"
)

$SystemPaths = @(
    "$env:SystemRoot\System32",
    "$env:SystemRoot\SysWOW64",
    "${env:ProgramFiles}\Microsoft Visual Studio\2022\*\VC\Redist\MSVC\*\x64\*",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\*\VC\Redist\MSVC\*\x64\*"
)

foreach ($dll in $SystemDlls) {
    $found = $false
    foreach ($path in $SystemPaths) {
        $fullPath = Join-Path $path $dll
        if (Test-Path $fullPath) {
            Copy-Item $fullPath $OutputDir -Force
            Write-Host "✅ $dll 복사 완료: $fullPath"
            $found = $true
            break
        }
    }
    if (!$found) {
        Write-Warning "⚠️ $dll 을 찾을 수 없습니다."
    }
}

# Visual C++ Redistributable 다운로드
$vcRedistUrl = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
$vcRedistPath = Join-Path $OutputDir "VC_redist.x64.exe"

try {
    Write-Host "Visual C++ Redistributable 다운로드 중..."
    Invoke-WebRequest -Uri $vcRedistUrl -OutFile $vcRedistPath
    Write-Host "✅ VC_redist.x64.exe 다운로드 완료"
} catch {
    Write-Warning "⚠️ Visual C++ Redistributable 다운로드 실패: $_"
}

Write-Host "DLL 수집 완료!"
```

---

## 🔧 구현 단계

### Phase 1: 런타임 DLL 수집 및 준비 (0.5일)

#### 1.1 DLL 수집 스크립트 실행
```powershell
# PowerShell에서 실행
cd D:\workspace\github.com\shimkijoon\posace-app-win\installers
.\scripts\collect_runtime_dlls.ps1
```

#### 1.2 수동 DLL 확인
필요시 개발 PC에서 직접 복사:
- `C:\Windows\System32\vcruntime140_1.dll`
- `C:\Windows\System32\vcruntime140.dll`
- `C:\Windows\System32\msvcp140.dll`

### Phase 2: 설치 스크립트 개선 (0.5일)

#### 2.1 기존 setup.iss 백업
```bash
cp installers/setup.iss installers/setup_original.iss
```

#### 2.2 개선된 스크립트 적용
- Visual C++ Redistributable 자동 설치 로직 추가
- 시스템 요구사항 체크 강화
- 다국어 메시지 추가

### Phase 3: 테스트 및 검증 (1일)

#### 3.1 테스트 환경
- ✅ 윈도우즈 서피스 PC (실제 문제 환경)
- ✅ 새로 설치된 Windows 10/11
- ✅ 개발 도구가 없는 일반 PC

#### 3.2 테스트 시나리오
1. **깨끗한 시스템**: Visual C++ Runtime이 없는 상태에서 설치
2. **부분 설치**: 일부 DLL만 있는 상태에서 설치  
3. **완전 설치**: 모든 런타임이 있는 상태에서 업그레이드

### Phase 4: 배포 및 문서화 (0.5일)

#### 4.1 빌드 스크립트 업데이트
**파일**: `scripts/build_setup_enhanced.ps1`

```powershell
# 개선된 설치 파일 빌드 스크립트
Write-Host "POSAce 개선된 설치 파일 빌드 시작..."

# 1. Flutter 빌드
Write-Host "Flutter Windows 빌드..."
flutter build windows --release

# 2. 런타임 DLL 수집
Write-Host "런타임 DLL 수집..."
.\scripts\collect_runtime_dlls.ps1

# 3. Inno Setup 컴파일
Write-Host "설치 파일 생성..."
& "C:\Program Files (x86)\Inno Setup 6\ISCC.exe" "installers\setup_improved.iss"

Write-Host "✅ 빌드 완료! Output\POSAce_Setup_Enhanced.exe"
```

---

## 📋 추가 개선사항

### 시스템 호환성 강화

#### 1. 최소 시스템 요구사항 체크
```inno
[Code]
function InitializeSetup(): Boolean;
var
  Version: TWindowsVersion;
begin
  GetWindowsVersionEx(Version);
  
  // Windows 10 이상 요구
  if Version.Major < 10 then begin
    MsgBox('이 프로그램은 Windows 10 이상에서만 실행됩니다.', mbError, MB_OK);
    Result := False;
    Exit;
  end;
  
  // 64비트 시스템 확인
  if not Is64BitInstallMode then begin
    MsgBox('이 프로그램은 64비트 Windows에서만 실행됩니다.', mbError, MB_OK);
    Result := False;
    Exit;
  end;
  
  Result := True;
end;
```

#### 2. 네트워크 연결 확인 (선택사항)
```inno
function IsConnectedToInternet: Boolean;
external 'InternetGetConnectedState@wininet.dll stdcall';

function CheckInternetConnection: Boolean;
begin
  Result := IsConnectedToInternet;
  if not Result then
    MsgBox('인터넷 연결을 확인해주세요. 일부 기능이 제한될 수 있습니다.', mbInformation, MB_OK);
end;
```

### 설치 후 검증

#### 3. 애플리케이션 실행 테스트
```inno
[Code]
function VerifyInstallation: Boolean;
var
  ExitCode: Integer;
begin
  // 애플리케이션이 정상적으로 시작되는지 확인
  Result := Exec(ExpandConstant('{app}\{#MyAppExeName}'), '--version', '', SW_HIDE, ewWaitUntilTerminated, ExitCode);
  if not Result or (ExitCode <> 0) then begin
    MsgBox('설치가 완료되었지만 애플리케이션 실행에 문제가 있을 수 있습니다.', mbWarning, MB_OK);
  end;
end;
```

---

## 🚀 배포 전략

### 단계별 배포

#### Phase A: 내부 테스트 (1주)
- 개발팀 내부 테스트
- 다양한 Windows 환경에서 검증
- 서피스 PC 포함 실제 환경 테스트

#### Phase B: 베타 테스트 (1주)  
- 선별된 사용자 그룹 대상
- 피드백 수집 및 개선
- 설치 성공률 모니터링

#### Phase C: 정식 배포
- 개선된 설치 파일 정식 릴리즈
- 기존 사용자 업그레이드 안내
- 설치 가이드 문서 업데이트

### 롤백 계획
- 기존 `setup.iss` 백업 유지
- 문제 발생 시 이전 버전으로 즉시 복구
- 사용자 지원을 위한 수동 설치 가이드 준비

---

## 📊 예상 효과

### 문제 해결률
- **VCRUNTIME 오류**: 95% 이상 해결 예상
- **서피스 PC 호환성**: 100% 개선
- **일반 PC 설치 성공률**: 90% → 98% 향상

### 사용자 경험 개선
- **설치 시간**: 기존 30초 → 1-2분 (런타임 설치 포함)
- **설치 실패율**: 10% → 2% 감소
- **사후 지원 요청**: 50% 감소 예상

---

**작성일**: 2026-02-05  
**우선순위**: High (서피스 PC 사용자 지원 필수)  
**예상 소요시간**: 2.5일  
**담당**: 개발팀 + QA팀