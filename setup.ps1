# Claude Code 사용량 위젯 설치/제거 — install.cmd / uninstall.cmd 가 호출한다.
# 직접: powershell -ExecutionPolicy Bypass -File setup.ps1 [-Uninstall]
param([switch]$Uninstall)

$Widget   = Join-Path $PSScriptRoot 'usage-tray.ps1'
$Lnk      = Join-Path ([Environment]::GetFolderPath('Startup')) 'Claude Code Usage.lnk'
$Cred     = Join-Path $env:USERPROFILE '.claude\.credentials.json'
$StopFlag = Join-Path $PSScriptRoot 'stopped.flag'
$TaskName = 'Claude Code Usage Widget'

# 감시자 — 로그온 시 + 5분마다 실행. 이미 돌고 있으면 MultipleInstances=IgnoreNew 로 새로 안 띄우므로
# 평소엔 아무 일도 안 하고, 위젯이 어떤 이유로든 죽으면 5분 안에 되살아난다.
# (시작프로그램 바로가기만으로는 죽은 뒤 다음 로그온까지 안 돌아온다.)
function Register-Watchdog {
    try {
        $act = New-ScheduledTaskAction -Execute "$env:WINDIR\System32\WindowsPowerShell\v1.0\powershell.exe" `
                   -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$Widget`"" -WorkingDirectory $PSScriptRoot
        $tLogon  = New-ScheduledTaskTrigger -AtLogOn
        $tRepeat = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(2) `
                       -RepetitionInterval (New-TimeSpan -Minutes 5) -RepetitionDuration ([TimeSpan]::MaxValue)
        $set = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
                   -StartWhenAvailable -MultipleInstances IgnoreNew -ExecutionTimeLimit ([TimeSpan]::Zero)
        Register-ScheduledTask -TaskName $TaskName -Action $act -Trigger $tLogon, $tRepeat -Settings $set -Force -ErrorAction Stop | Out-Null
        return $true
    } catch { return $false }
}

function Stop-Widget {
    # 자기 자신(setup.ps1)은 usage-tray.ps1 을 -File 로 갖지 않으므로 안 걸린다. $PID 가드는 이중 안전장치.
    Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" |
        Where-Object { $_.ProcessId -ne $PID -and $_.CommandLine -like '*-File*usage-tray.ps1*' } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
}

if ($Uninstall) {
    try { Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction Stop } catch {}
    Stop-Widget
    Remove-Item $Lnk -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $PSScriptRoot 'config.json'), (Join-Path $PSScriptRoot 'last.json'), $StopFlag -Force -ErrorAction SilentlyContinue
    Write-Host '제거 완료 — 위젯 종료, 감시자(예약 작업)·시작프로그램 해제, 개인 설정 삭제. 폴더는 직접 지우세요.'
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

# zip 설치본은 현재 커밋을 모른다 — 설치 시점의 GitHub main sha 를 기록해 두면 위젯의 업데이트 점검이 정확해진다 (실패해도 무시)
if (-not (Test-Path (Join-Path $PSScriptRoot '.git'))) {
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $sha = (Invoke-RestMethod 'https://api.github.com/repos/HengSsg/ai-usage-theme/commits/main' -TimeoutSec 10 -Headers @{ 'User-Agent' = 'cc-usage-tray' }).sha
        if ($sha) { Set-Content (Join-Path $PSScriptRoot 'version.txt') $sha -Encoding ASCII }
    } catch {}
}

Remove-Item $StopFlag -Force -ErrorAction SilentlyContinue     # 이전에 "종료" 했어도 설치하면 다시 켠다
$wd = Register-Watchdog

Stop-Widget; Start-Sleep -Milliseconds 500
Start-Process powershell -ArgumentList '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', $Widget
Write-Host "설치 완료 — 작업표시줄에 위젯이 뜹니다(로그인 시 자동 시작). 우클릭 → 테마 / 위치 / 종료."
if ($wd) {
    Write-Host "감시자(예약 작업) 등록됨 — 프로세스가 통째로 사라져도 5분 안에 다시 뜹니다."
} else {
    Write-Host "감시자(예약 작업) 등록 실패 — 권한/정책 문제일 수 있습니다(관리자 아님)." -ForegroundColor Yellow
    Write-Host "  위젯 내부 워치독은 그대로 동작하므로 멈춤(hang) 은 스스로 복구합니다." -ForegroundColor Yellow
}
Write-Host "폴더를 옮기면 시작프로그램 링크가 끊어지니 옮긴 뒤 install.cmd 를 다시 실행하세요. ($PSScriptRoot)"
