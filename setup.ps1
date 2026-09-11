# Claude Code 사용량 위젯 설치/제거 — install.cmd / uninstall.cmd 가 호출한다.
# 직접: powershell -ExecutionPolicy Bypass -File setup.ps1 [-Uninstall]
param([switch]$Uninstall)

$Widget = Join-Path $PSScriptRoot 'usage-tray.ps1'
$Lnk    = Join-Path ([Environment]::GetFolderPath('Startup')) 'Claude Code Usage.lnk'
$Cred   = Join-Path $env:USERPROFILE '.claude\.credentials.json'

function Stop-Widget {
    # 자기 자신(setup.ps1)은 usage-tray.ps1 을 -File 로 갖지 않으므로 안 걸린다. $PID 가드는 이중 안전장치.
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like '*-File*usage-tray.ps1*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

if ($Uninstall) {
    Stop-Widget
    Remove-Item $Lnk -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $PSScriptRoot 'config.json'), (Join-Path $PSScriptRoot 'last.json') -Force -ErrorAction SilentlyContinue
    Write-Host '제거 완료 — 위젯 종료, 시작프로그램 등록 해제, 개인 설정(config.json·last.json) 삭제. 폴더는 직접 지우세요.'
    exit 0
}

if (-not (Test-Path $Widget)) { Write-Host "usage-tray.ps1 이 같은 폴더에 없습니다: $PSScriptRoot" -ForegroundColor Red; exit 1 }
if (-not (Test-Path $Cred)) {
    Write-Host "Claude Code 로그인 정보가 없습니다: $Cred" -ForegroundColor Yellow
    Write-Host '터미널에서 claude 를 한 번 실행해 로그인(구독 계정)한 뒤 다시 install.cmd 를 실행하세요.'
    exit 1
}

$w = New-Object -ComObject WScript.Shell
$s = $w.CreateShortcut($Lnk)
$s.TargetPath       = "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe"
$s.Arguments        = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Widget`""
$s.WorkingDirectory = $PSScriptRoot
$s.WindowStyle      = 7
$s.Description      = 'Claude Code 사용량 작업표시줄 위젯'
$s.Save()

Stop-Widget; Start-Sleep -Milliseconds 500
Start-Process powershell -ArgumentList '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', $Widget
Write-Host "설치 완료 — 작업표시줄에 위젯이 뜹니다(로그인 시 자동 시작). 우클릭 → 테마 / 위치 / 종료."
Write-Host "폴더를 옮기면 시작프로그램 링크가 끊어지니 옮긴 뒤 install.cmd 를 다시 실행하세요. ($PSScriptRoot)"
