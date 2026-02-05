# Visual C++ Runtime Redistributables

이 디렉토리에는 POSAce Windows 앱 실행에 필요한 Visual C++ Runtime 파일들이 포함됩니다.

## 🎯 목적

Windows Surface PC 및 새로 설치된 Windows 시스템에서 발생하는 **VCRUNTIME140_1.dll** 오류를 해결하기 위한 파일들입니다.

## 📁 포함될 파일들

### 필수 파일
- `VC_redist.x64.exe` - Visual C++ 2015-2022 Redistributable (x64)
- `vcruntime140.dll` - Visual C++ Runtime Library
- `vcruntime140_1.dll` - Visual C++ Runtime Library (추가)
- `msvcp140.dll` - Microsoft C++ Standard Library
- `concrt140.dll` - Concurrency Runtime Library
- `vccorlib140.dll` - Visual C++ Core Library

## 🔧 파일 수집 방법

### 자동 수집 (권장)
```powershell
# PowerShell에서 실행
.\scripts\collect_runtime_dlls.ps1
```

### 수동 수집
1. **Visual C++ Redistributable 다운로드**
   - URL: https://aka.ms/vs/17/release/vc_redist.x64.exe
   - 파일명: `VC_redist.x64.exe`

2. **시스템 DLL 복사** (필요시)
   ```
   C:\Windows\System32\vcruntime140.dll
   C:\Windows\System32\vcruntime140_1.dll
   C:\Windows\System32\msvcp140.dll
   ```

## 🚀 사용 방법

1. 위 파일들을 이 디렉토리에 배치
2. `setup_enhanced.iss`로 설치 파일 빌드
3. 생성된 설치 파일이 자동으로 런타임을 설치

## ⚠️ 주의사항

- 이 파일들은 Microsoft의 저작권 보호를 받습니다
- 재배포는 Microsoft 라이선스 조건에 따라 허용됩니다
- 상업적 사용 시 Microsoft 라이선스를 확인하세요

## 🔍 문제 해결

### VCRUNTIME140_1.dll 오류가 계속 발생하는 경우
1. 이 디렉토리에 모든 필수 파일이 있는지 확인
2. `collect_runtime_dlls.ps1` 스크립트 재실행
3. 수동으로 Visual C++ Redistributable 설치 후 DLL 복사

### 설치 파일 크기가 너무 큰 경우
- 로컬 DLL 파일들을 제거하고 `VC_redist.x64.exe`만 포함
- 설치 시 온라인으로 다운로드하도록 설정

---

**생성일**: 2026-02-05  
**용도**: VCRUNTIME140_1.dll 오류 해결  
**대상**: Windows Surface PC 및 새 설치 시스템