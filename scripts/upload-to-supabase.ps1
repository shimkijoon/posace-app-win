# Supabase Storage에 MSIX 파일 업로드 스크립트
# 사용법: .\scripts\upload-to-supabase.ps1

$PROJECT_ID = "wqjirowshlxfjcjmydfk"
$MSIX_FILE = "build\windows\x64\runner\Release\posace_app_win.msix"
$STORAGE_PATH = "releases/windows/posace_app_win.msix"

Write-Host "🚀 Supabase Storage 업로드 시작..." -ForegroundColor Cyan

# 파일 존재 확인
if (-not (Test-Path $MSIX_FILE)) {
    Write-Host "❌ MSIX 파일을 찾을 수 없습니다: $MSIX_FILE" -ForegroundColor Red
    exit 1
}

$fileSize = (Get-Item $MSIX_FILE).Length / 1MB
Write-Host "📦 파일 크기: $([math]::Round($fileSize, 2)) MB" -ForegroundColor Green

# Supabase CLI 확인
$supabaseInstalled = Get-Command supabase -ErrorAction SilentlyContinue
if (-not $supabaseInstalled) {
    Write-Host "⚠️  Supabase CLI가 설치되어 있지 않습니다." -ForegroundColor Yellow
    Write-Host "설치 방법: npm install -g supabase" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "또는 Supabase 대시보드에서 수동 업로드:" -ForegroundColor Yellow
    Write-Host "1. https://supabase.com/dashboard 접속" -ForegroundColor Yellow
    Write-Host "2. Storage > releases 버킷 (없으면 생성, Public: Yes)" -ForegroundColor Yellow
    Write-Host "3. windows/ 폴더 생성" -ForegroundColor Yellow
    Write-Host "4. $MSIX_FILE 업로드" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Public URL:" -ForegroundColor Cyan
    Write-Host "https://$PROJECT_ID.supabase.co/storage/v1/object/public/releases/windows/posace_app_win.msix" -ForegroundColor Green
    exit 0
}

# Supabase 로그인 확인
Write-Host "🔐 Supabase 로그인 확인 중..." -ForegroundColor Cyan
$loginCheck = supabase projects list 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "⚠️  Supabase에 로그인되어 있지 않습니다." -ForegroundColor Yellow
    Write-Host "로그인: supabase login" -ForegroundColor Yellow
    exit 1
}

# 파일 업로드
Write-Host "📤 파일 업로드 중..." -ForegroundColor Cyan
$uploadResult = supabase storage upload $STORAGE_PATH $MSIX_FILE --project-ref $PROJECT_ID 2>&1

if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ 업로드 성공!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Public URL:" -ForegroundColor Cyan
    Write-Host "https://$PROJECT_ID.supabase.co/storage/v1/object/public/releases/windows/posace_app_win.msix" -ForegroundColor Green
} else {
    Write-Host "❌ 업로드 실패:" -ForegroundColor Red
    Write-Host $uploadResult -ForegroundColor Red
    Write-Host ""
    Write-Host "수동 업로드 방법:" -ForegroundColor Yellow
    Write-Host "1. https://supabase.com/dashboard 접속" -ForegroundColor Yellow
    Write-Host "2. Storage > releases 버킷" -ForegroundColor Yellow
    Write-Host "3. windows/ 폴더에 파일 업로드" -ForegroundColor Yellow
    exit 1
}
