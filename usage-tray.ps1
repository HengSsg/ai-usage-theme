# Claude Code 사용량 작업표시줄 위젯 — 기본 틀
# /api/oauth/usage 를 폴링해 5시간·주간 한도 소진률을 작업표시줄 빈 공간에 그린다.
# 그리는 방식은 themes\*.ps1 플러그인이 담당(우클릭 → 테마). 위치는 우클릭 → 위치(자동/왼쪽/오른쪽).
# 설치(시작프로그램 등록 + 실행): install.cmd  /  제거: uninstall.cmd  — 자세한 건 README.md
# 직접 실행:
#   powershell -WindowStyle Hidden -ExecutionPolicy Bypass -File usage-tray.ps1
# 자가점검(모든 테마를 PNG 한 장으로 렌더, UI 안 띄움):
#   powershell -ExecutionPolicy Bypass -File usage-tray.ps1 -RenderTest out.png
param([string]$RenderTest)

Add-Type -AssemblyName System.Windows.Forms, System.Drawing
Add-Type @'
using System;using System.Runtime.InteropServices;
public class TBW {
 [DllImport("user32.dll",CharSet=CharSet.Auto)] public static extern IntPtr FindWindow(string c,string w);
 [DllImport("user32.dll",CharSet=CharSet.Auto)] public static extern IntPtr FindWindowEx(IntPtr p,IntPtr c,string cl,string w);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h,out RECT r);
 [DllImport("user32.dll")] public static extern int GetWindowLong(IntPtr h,int i);
 [DllImport("user32.dll")] public static extern int SetWindowLong(IntPtr h,int i,int v);
 [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int w,int t,uint f);
 [StructLayout(LayoutKind.Sequential)] public struct RECT { public int L,T,R,B; }
 public static readonly IntPtr TOPMOST = new IntPtr(-1);
}
'@
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$CredFile   = Join-Path $env:USERPROFILE '.claude\.credentials.json'
$ConfigFile = Join-Path $PSScriptRoot 'config.json'
$CacheFile  = Join-Path $PSScriptRoot 'last.json'   # 마지막 응답 — 재시작 직후 재호출 방지
$UsageUrl   = 'https://api.anthropic.com/api/oauth/usage'
$PollSec    = 120   # API 폴링. 5시간 창은 분 단위로 천천히 움직인다 — 더 짧게 하면 429 위험
$PlaceSec   = 2     # 위치·z순서 재확인 (explorer 재시작·해상도 변경 대응)
$RepoUrl    = 'https://github.com/HengSsg/ai-usage-theme'   # 업데이트 원본
$VersionFile = Join-Path $PSScriptRoot 'version.txt'        # zip 설치본의 현재 커밋 sha (git clone 이면 .git 이 정본)
$UpdateCheckHours = 24
$MarginX    = 12    # 작업표시줄 왼쪽 여백
$H          = 48    # 작업표시줄 높이(실측으로 덮어씀)

# ── 테마가 쓰는 공용 팔레트·헬퍼 ─────────────────────────────────────────────
$Col = @{
    Green = [Drawing.Color]::FromArgb(80, 230, 120)
    Gold  = [Drawing.Color]::Gold
    Red   = [Drawing.Color]::FromArgb(255, 99, 71)
    Track = [Drawing.Color]::FromArgb(58, 58, 58)     # 게이지 바탕
    Label = [Drawing.Color]::FromArgb(160, 160, 160)  # 5h/7d 라벨
    Dim   = [Drawing.Color]::FromArgb(138, 138, 138)
    Light = [Drawing.Color]::FromArgb(232, 232, 232)
    Road  = [Drawing.Color]::FromArgb(44, 44, 44)
}
function Get-LevelColor([int]$pct) {
    if ($pct -lt 60) { return $Col.Green }
    if ($pct -lt 85) { return $Col.Gold }
    return $Col.Red
}
function New-Font([float]$px, [bool]$bold = $true) {
    $style = if ($bold) { [Drawing.FontStyle]::Bold } else { [Drawing.FontStyle]::Regular }
    New-Object Drawing.Font('Segoe UI', $px, $style, [Drawing.GraphicsUnit]::Pixel)
}
# 세로 중심 cy 에 맞춰 텍스트를 그린다. align: Near(x=왼쪽) | Center(x=중심) | Far(x=오른쪽)
function Draw-Text($g, [string]$text, [float]$px, [bool]$bold, $color, [float]$x, [float]$cy, [string]$align = 'Near') {
    $f = New-Font $px $bold
    $sf = New-Object Drawing.StringFormat ([Drawing.StringFormat]::GenericTypographic)
    $sf.LineAlignment = 'Center'; $sf.Alignment = $align
    $sf.FormatFlags = $sf.FormatFlags -bor [Drawing.StringFormatFlags]::NoWrap
    $left = switch ($align) { 'Center' { $x - 300 } 'Far' { $x - 600 } default { $x } }
    $b = New-Object Drawing.SolidBrush $color
    $g.DrawString($text, $f, $b, (New-Object Drawing.RectangleF $left, ($cy - 24), 600, 48), $sf)
    $b.Dispose(); $f.Dispose(); $sf.Dispose()
}
function Measure-Text([string]$text, [float]$px, [bool]$bold = $true) {
    $f = New-Font $px $bold
    $w = [Windows.Forms.TextRenderer]::MeasureText($text, $f).Width
    $f.Dispose(); return $w
}
function Get-RoundRect([float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = New-Object Drawing.Drawing2D.GraphicsPath
    $r = [Math]::Min($r, [Math]::Min($w, $h) / 2)
    $d = $r * 2
    if ($d -le 0.01) { $p.AddRectangle((New-Object Drawing.RectangleF $x, $y, $w, $h)); return $p }
    $p.AddArc($x, $y, $d, $d, 180, 90)
    $p.AddArc($x + $w - $d, $y, $d, $d, 270, 90)
    $p.AddArc($x + $w - $d, $y + $h - $d, $d, $d, 0, 90)
    $p.AddArc($x, $y + $h - $d, $d, $d, 90, 90)
    $p.CloseFigure(); return $p
}
function Fill-RoundRect($g, $color, [float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    if ($w -le 0 -or $h -le 0) { return }
    $p = Get-RoundRect $x $y $w $h $r
    $b = New-Object Drawing.SolidBrush $color
    $g.FillPath($b, $p); $b.Dispose(); $p.Dispose()
}
function Draw-RoundRect($g, $color, [float]$width, [float]$x, [float]$y, [float]$w, [float]$h, [float]$r) {
    $p = Get-RoundRect $x $y $w $h $r
    $pen = New-Object Drawing.Pen $color, $width
    $g.DrawPath($pen, $p); $pen.Dispose(); $p.Dispose()
}
function Fill-Circle($g, $color, [float]$cx, [float]$cy, [float]$r) {
    $b = New-Object Drawing.SolidBrush $color
    $g.FillEllipse($b, $cx - $r, $cy - $r, $r * 2, $r * 2); $b.Dispose()
}

# ── 픽셀아트 헬퍼 — 2px 셀 격자(48px = 24행). 좌표·크기는 전부 "셀" 단위 ─────────────────
# 스프라이트 = 문자열 배열(한 글자 = 한 셀), 글자 → 팔레트 색, '.'/' ' 는 투명.
$PxScale = 2
$Px = @{
    Ink    = [Drawing.Color]::FromArgb(28, 28, 32)
    White  = [Drawing.Color]::FromArgb(242, 242, 242)
    Gray   = [Drawing.Color]::FromArgb(130, 130, 138)
    Dark   = [Drawing.Color]::FromArgb(64, 64, 72)
    Red    = [Drawing.Color]::FromArgb(232, 72, 72)
    Pink   = [Drawing.Color]::FromArgb(255, 150, 170)
    Orange = [Drawing.Color]::FromArgb(255, 150, 50)
    Yellow = [Drawing.Color]::FromArgb(255, 222, 80)
    Green  = [Drawing.Color]::FromArgb(90, 210, 110)
    Blue   = [Drawing.Color]::FromArgb(90, 160, 255)
    Sky    = [Drawing.Color]::FromArgb(160, 210, 255)
    Brown  = [Drawing.Color]::FromArgb(150, 100, 50)
    Wood   = [Drawing.Color]::FromArgb(205, 155, 90)
    Cream  = [Drawing.Color]::FromArgb(255, 235, 190)
    Sand   = [Drawing.Color]::FromArgb(240, 200, 110)
    Coffee = [Drawing.Color]::FromArgb(110, 70, 40)
}
# 픽셀 테마는 Draw 첫 줄에서 호출 — 안티앨리어싱을 꺼 셀 경계를 또렷하게
function Use-PixelMode($g) { $g.SmoothingMode = 'None'; $g.PixelOffsetMode = 'None'; $g.InterpolationMode = 'NearestNeighbor' }
function Px-Fill($g, $color, [int]$cx, [int]$cy, [int]$cw, [int]$ch) {
    if ($cw -le 0 -or $ch -le 0) { return }
    $b = New-Object Drawing.SolidBrush $color
    $g.FillRectangle($b, $cx * $PxScale, $cy * $PxScale, $cw * $PxScale, $ch * $PxScale); $b.Dispose()
}
function Px-Circle($g, $color, [int]$cx, [int]$cy, [int]$r) {
    for ($dy = -$r; $dy -le $r; $dy++) {
        $half = [int][Math]::Floor([Math]::Sqrt($r * $r - $dy * $dy) + 0.5)
        Px-Fill $g $color ($cx - $half) ($cy + $dy) (2 * $half + 1) 1
    }
}
function Draw-Sprite($g, [string[]]$rows, [int]$cx, [int]$cy, [hashtable]$pal) {
    $brushes = @{}
    for ($r = 0; $r -lt $rows.Count; $r++) {
        $line = $rows[$r]
        for ($c = 0; $c -lt $line.Length; $c++) {
            $k = [string]$line[$c]
            if ($k -eq '.' -or $k -eq ' ' -or -not $pal.ContainsKey($k)) { continue }
            if (-not $brushes.ContainsKey($k)) { $brushes[$k] = New-Object Drawing.SolidBrush $pal[$k] }
            $g.FillRectangle($brushes[$k], ($cx + $c) * $PxScale, ($cy + $r) * $PxScale, $PxScale, $PxScale)
        }
    }
    foreach ($b in $brushes.Values) { $b.Dispose() }
}
# 3x5 픽셀 폰트 — 라벨(2:21/5h · 4/7d · 38%)에 필요한 글자만. 글자 폭 3 + 간격 1 = 4셀
$PxFont = @{
    '0' = @('###', '#.#', '#.#', '#.#', '###'); '1' = @('.#.', '##.', '.#.', '.#.', '###'); '2' = @('###', '..#', '###', '#..', '###')
    '3' = @('###', '..#', '###', '..#', '###'); '4' = @('#.#', '#.#', '###', '..#', '..#'); '5' = @('###', '#..', '###', '..#', '###')
    '6' = @('###', '#..', '###', '#.#', '###'); '7' = @('###', '..#', '..#', '..#', '..#'); '8' = @('###', '#.#', '###', '#.#', '###')
    '9' = @('###', '#.#', '###', '..#', '###'); ':' = @('...', '.#.', '...', '.#.', '...'); '/' = @('..#', '..#', '.#.', '#..', '#..')
    '%' = @('#.#', '..#', '.#.', '#..', '#.#'); 'h' = @('#..', '#..', '###', '#.#', '#.#'); 'd' = @('..#', '..#', '###', '#.#', '###')
    'm' = @('...', '...', '##.', '###', '#.#'); ' ' = @('...', '...', '...', '...', '...')
}
function Draw-PixelText($g, [string]$text, [int]$cx, [int]$cy, $color) {
    $pal = @{ '#' = $color }
    foreach ($ch in $text.ToCharArray()) {
        $gl = $PxFont[[string]$ch]; if (-not $gl) { $gl = $PxFont[' '] }
        Draw-Sprite $g $gl $cx $cy $pal
        $cx += 4
    }
}
function Measure-PixelText([string]$text) { return $text.Length * 4 - 1 }

# ── 테마 로딩: themes\*.ps1 은 @{ Id; Name; Width(int|scriptblock); Draw={param($g,$d,$w,$h)} } 를 반환 ──
$Themes = [ordered]@{}
foreach ($f in (Get-ChildItem (Join-Path $PSScriptRoot 'themes\*.ps1') | Sort-Object Name)) {
    $t = . $f.FullName
    if ($t -and $t.Id) { $Themes[$t.Id] = $t }
}
if ($Themes.Count -eq 0) { throw "themes\ 폴더에 테마가 없습니다." }

function Get-Config {
    if (Test-Path $ConfigFile) { try { return Get-Content $ConfigFile -Raw -Encoding UTF8 | ConvertFrom-Json } catch {} }
    return [pscustomobject]@{ theme = 'bars'; position = 'auto' }
}
$cfg = Get-Config
$script:themeId  = if ($Themes.Contains([string]$cfg.theme)) { [string]$cfg.theme } else { $Themes.Keys | Select-Object -First 1 }
$script:position = if (@('auto', 'left', 'right') -contains [string]$cfg.position) { [string]$cfg.position } else { 'auto' }
function Save-Config { @{ theme = $script:themeId; position = $script:position } | ConvertTo-Json | Set-Content $ConfigFile -Encoding UTF8 }
# 위치 auto: 작업표시줄 아이콘이 가운데 정렬(Win11 기본)이면 왼쪽 빈 공간, 왼쪽 정렬이면 트레이 앞(오른쪽) — 시작 버튼을 덮지 않게
function Get-EffectivePosition {
    if ($script:position -ne 'auto') { return $script:position }
    try { $al = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' -Name TaskbarAl -ErrorAction Stop).TaskbarAl } catch { $al = 1 }
    if ($al -eq 0) { return 'right' } else { return 'left' }
}

# ── 데이터 ─────────────────────────────────────────────────────────────────────
function Get-Usage {
    # 토큰은 매번 파일에서 다시 읽는다 — Claude Code 가 갱신해 두면 그대로 따라간다.
    $tok = (Get-Content $CredFile -Raw -Encoding UTF8 | ConvertFrom-Json).claudeAiOauth.accessToken
    Invoke-RestMethod -Uri $UsageUrl -Method Get -TimeoutSec 20 -Headers @{
        'Authorization'  = "Bearer $tok"
        'anthropic-beta' = 'oauth-2025-04-20'
    }
}
function Format-Reset($iso) {
    if (-not $iso) { return '-' }
    $left = ([datetime]$iso).ToUniversalTime() - (Get-Date).ToUniversalTime()
    if ($left.TotalSeconds -le 0) { return '곧 리셋' }
    if ($left.TotalDays  -ge 1)   { return ('{0}일 {1}시간' -f [int]$left.TotalDays,  $left.Hours) }
    if ($left.TotalHours -ge 1)   { return ('{0}시간 {1}분'  -f [int]$left.TotalHours, $left.Minutes) }
    return ('{0}분' -f [int]$left.TotalMinutes)
}
# 라벨용 압축 표기 — 5h 창: H:MM/5h (5시간 초과·음수는 5:00 / 0:00 클램프)
function Format-Left5($iso) {
    if (-not $iso) { return '5h' }
    $left = ([datetime]$iso).ToUniversalTime() - (Get-Date).ToUniversalTime()
    if ($left.TotalHours -gt 5)   { $left = [TimeSpan]::FromHours(5) }
    if ($left.TotalSeconds -lt 0) { $left = [TimeSpan]::Zero }
    return ('{0}:{1:00}/5h' -f [int][Math]::Floor($left.TotalHours), $left.Minutes)
}
# 7d 창: 1일 이상 N/7d · 24시간 미만 Nh/7d · 1시간 미만 Nm/7d
function Format-Left7($iso) {
    if (-not $iso) { return '7d' }
    $left = ([datetime]$iso).ToUniversalTime() - (Get-Date).ToUniversalTime()
    if ($left.TotalSeconds -lt 0) { return '0m/7d' }
    if ($left.TotalDays  -ge 1)   { return ('{0}/7d'  -f [int][Math]::Floor($left.TotalDays)) }
    if ($left.TotalHours -ge 1)   { return ('{0}h/7d' -f [int][Math]::Floor($left.TotalHours)) }
    return ('{0}m/7d' -f [int][Math]::Floor($left.TotalMinutes))
}
# 테마에 넘기는 데이터 묶음. Ok=$false 면 Err 문구만 유효. L5/L7 은 렌더 시점에 I5/I7 로 계산.
$script:data = @{ Ok = $false; Err = 'CC  ...'; S5 = 0; S7 = 0; C5 = $Col.Dim; C7 = $Col.Dim; CD = $Col.Dim; R5 = '-'; R7 = '-' }
function Set-DataFromUsage([int]$s5, [int]$s7, $reset5, $reset7) {
    $script:data = @{
        Ok = $true; Err = ''
        S5 = $s5; S7 = $s7
        C5 = Get-LevelColor $s5; C7 = Get-LevelColor $s7; CD = Get-LevelColor ([Math]::Max($s5, $s7))
        R5 = Format-Reset $reset5; R7 = Format-Reset $reset7
        I5 = [string]$reset5; I7 = [string]$reset7
    }
}
# 캐시가 PollSec 보다 새로우면 @{ c=응답; age=초 } 를 돌려준다 — 그 동안은 API 를 치지 않는다
function Load-Cache {
    if (-not (Test-Path $CacheFile)) { return $null }
    try {
        $c = Get-Content $CacheFile -Raw -Encoding UTF8 | ConvertFrom-Json
        $age = ((Get-Date).ToUniversalTime() - ([datetime]$c.at).ToUniversalTime()).TotalSeconds
        if ($age -ge 0 -and $age -lt $PollSec) { return @{ c = $c; age = $age } }
    } catch {}
    return $null
}
function Refresh-Data {
    try {
        $u = Get-Usage
        Set-DataFromUsage ([int]$u.five_hour.utilization) ([int]$u.seven_day.utilization) $u.five_hour.resets_at $u.seven_day.resets_at
        @{ at = (Get-Date).ToUniversalTime().ToString('o'); s5 = $script:data.S5; s7 = $script:data.S7
           r5 = [string]$u.five_hour.resets_at; r7 = [string]$u.seven_day.resets_at } | ConvertTo-Json | Set-Content $CacheFile -Encoding UTF8
        if ($poll) { $poll.Interval = $PollSec * 1000 }   # 백오프 원복
    } catch {
        $code = $_.Exception.Response.StatusCode.value__
        if ($script:data.Ok -and $code -ne 401) {
            # 일시 실패(429·네트워크)는 마지막 값을 그대로 보여주고 툴팁에만 표시
            $script:data.Stale = $true
            $script:data.Msg = "갱신 실패($code) — 마지막 값 표시 중"
        } else {
            $script:data = @{ Ok = $false; Msg = $_.Exception.Message
                              Err = $(if ($code -eq 401) { 'CC  재로그인 필요' } elseif ($code -eq 429) { 'CC  잠시 후 재시도' } else { 'CC  조회 실패' }) }
        }
        # 429 면 다음 폴링을 두 배로 늦춘다(최대 10분) — 연타하면 더 오래 막힌다
        if ($code -eq 429 -and $poll) { $poll.Interval = [Math]::Min($poll.Interval * 2, 600000) }
    }
}

# ── 작업표시줄 위치·색 ───────────────────────────────────────────────────────────
function Get-TaskbarRect {
    $tray = [TBW]::FindWindow('Shell_TrayWnd', $null)
    if ($tray -eq [IntPtr]::Zero) { return $null }
    $r = New-Object TBW+RECT
    if (-not [TBW]::GetWindowRect($tray, [ref]$r)) { return $null }
    # 트레이(알림영역) 왼쪽 끝 — 오른쪽 배치 기준. 못 찾으면 화면 오른쪽 끝에서 330px 안쪽으로 가정
    $trayL = $r.R - 330
    $tn = [TBW]::FindWindowEx($tray, [IntPtr]::Zero, 'TrayNotifyWnd', $null)
    if ($tn -ne [IntPtr]::Zero) { $tr = New-Object TBW+RECT; if ([TBW]::GetWindowRect($tn, [ref]$tr)) { $trayL = $tr.L } }
    return @{ L = $r.L; T = $r.T; R = $r.R; B = $r.B; TrayL = $trayL }
}
# 작업표시줄 색을 실제 화면에서 1px 샘플링 — 라이트/다크·투명도까지 자동으로 맞는다.
function Get-TaskbarColor($r, [int]$sampleX) {
    try {
        $b = New-Object Drawing.Bitmap 1, 1
        $g = [Drawing.Graphics]::FromImage($b)
        $g.CopyFromScreen($sampleX, ($r.T + [int](($r.B - $r.T) / 2)), 0, 0, (New-Object Drawing.Size 1, 1))
        $c = $b.GetPixel(0, 0); $g.Dispose(); $b.Dispose(); return $c
    } catch { return [Drawing.Color]::FromArgb(32, 32, 32) }
}

# ── 업데이트 — git clone 이면 fetch/pull, zip 설치면 GitHub main.zip 재다운로드. 개인 파일(config/last)은 보존 ──
$script:updateAvail = $false
$script:remoteSha   = ''
function Test-GitClone { Test-Path (Join-Path $PSScriptRoot '.git') }
function Get-RemoteSha {
    $api = $RepoUrl -replace '^https://github\.com/', 'https://api.github.com/repos/'
    (Invoke-RestMethod -Uri "$api/commits/main" -TimeoutSec 10 -Headers @{ 'User-Agent' = 'cc-usage-tray' }).sha
}
# $true = 새 버전 / $false = 최신 / $null = 현재 버전 미확인(zip 설치인데 version.txt 없음)
function Test-UpdateAvailable {
    if (Test-GitClone) {
        git -C $PSScriptRoot fetch -q origin main 2>&1 | Out-Null
        if ($LASTEXITCODE -ne 0) { throw 'git fetch 실패 (네트워크 또는 git 미설치)' }
        return ([int](git -C $PSScriptRoot rev-list --count HEAD..origin/main) -gt 0)
    }
    $script:remoteSha = Get-RemoteSha
    $local = if (Test-Path $VersionFile) { (Get-Content $VersionFile -Raw).Trim() } else { '' }
    if (-not $local) { return $null }
    return ($script:remoteSha -ne $local)
}
function Invoke-Update {
    if (Test-GitClone) {
        $out = git -C $PSScriptRoot pull --ff-only origin main 2>&1 | Out-String
        if ($LASTEXITCODE -ne 0) { throw "git pull 실패:`n$out" }
        return
    }
    $tmp = Join-Path $env:TEMP ('cc-usage-tray-upd-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    $zip = Join-Path $tmp 'main.zip'
    Invoke-WebRequest -Uri "$RepoUrl/archive/refs/heads/main.zip" -OutFile $zip -TimeoutSec 60 -Headers @{ 'User-Agent' = 'cc-usage-tray' }
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    $src = (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName
    Get-ChildItem $src -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($src.Length + 1)
        if ($rel -in @('config.json', 'last.json', 'version.txt')) { return }
        $dst = Join-Path $PSScriptRoot $rel
        New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null
        Copy-Item $_.FullName $dst -Force
    }
    if (-not $script:remoteSha) { $script:remoteSha = Get-RemoteSha }
    Set-Content $VersionFile $script:remoteSha -Encoding ASCII
    Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
}
function Restart-Self {
    # 새 인스턴스가 뮤텍스를 잡을 수 있게 먼저 놓는다
    try { $mutex.ReleaseMutex(); $mutex.Dispose() } catch {}
    Start-Process powershell -ArgumentList '-WindowStyle', 'Hidden', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath
    $form.Close()
}
function Show-Msg([string]$text, [string]$title = 'Claude Code 사용량 위젯', $buttons = 'OK', $icon = 'Information') {
    [Windows.Forms.MessageBox]::Show($form, $text, $title, [Windows.Forms.MessageBoxButtons]$buttons, [Windows.Forms.MessageBoxIcon]$icon)
}
# quiet=$true: 자동 점검(표시만 갱신) / $false: 메뉴에서 눌렀을 때(결과 안내 + 설치 여부 질문)
function Check-Update([bool]$quiet = $true) {
    try {
        $avail = Test-UpdateAvailable
        $script:updateAvail = ($avail -eq $true)
        if ($updItem) { $updItem.Text = if ($script:updateAvail) { '업데이트 설치 — 새 버전 있음' } else { '업데이트 확인' } }
        Render-Widget
        if ($quiet) { return }
        $q = if ($avail -eq $true) { "새 버전이 있습니다. 지금 업데이트할까요?`n(위젯이 자동으로 재시작됩니다)" }
             elseif ($null -eq $avail) { "현재 버전을 확인할 수 없습니다(zip 설치).`n최신 버전으로 다시 받을까요? 개인 설정은 유지됩니다." }
             else { $null }
        if (-not $q) { Show-Msg '최신 버전입니다.' | Out-Null; return }
        if ((Show-Msg $q '업데이트' 'YesNo' 'Question') -ne 'Yes') { return }
        Invoke-Update
        Restart-Self
    } catch {
        if (-not $quiet) { Show-Msg ("업데이트 실패:`n" + $_.Exception.Message) '업데이트' 'OK' 'Warning' | Out-Null }
    }
}

# ── 단일 인스턴스 — 두 개가 돌면 폴링이 두 배가 돼 429 를 부른다 ─────────────────────
$mutex = New-Object Threading.Mutex($false, 'Local\CCUsageTray')
if (-not $RenderTest -and -not $mutex.WaitOne(0)) { exit 0 }   # 자가점검은 UI 없이 끝나므로 예외

# ── UI ────────────────────────────────────────────────────────────────────────
$form = New-Object Windows.Forms.Form
$form.FormBorderStyle = 'None'; $form.ShowInTaskbar = $false; $form.StartPosition = 'Manual'; $form.TopMost = $true
$pic = New-Object Windows.Forms.PictureBox
$pic.Dock = 'Fill'; $pic.SizeMode = 'Normal'
$form.Controls.Add($pic)
$tip = New-Object Windows.Forms.ToolTip
$script:width = 200
$script:bg = [Drawing.Color]::FromArgb(32, 32, 32)

function Get-ThemeWidth($t, $d) { if ($t.Width -is [scriptblock]) { [int](& $t.Width $d) } else { [int]$t.Width } }

function Render-Bitmap($t, $d, $bg, [int]$h) {
    $w = if ($d.Ok) { Get-ThemeWidth $t $d } else { (Measure-Text $d.Err 15) + 20 }
    $bmp = New-Object Drawing.Bitmap $w, $h
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'; $g.PixelOffsetMode = 'HighQuality'
    $g.Clear($bg)
    if ($d.Ok) { $d.L5 = Format-Left5 $d.I5; $d.L7 = Format-Left7 $d.I7; & $t.Draw $g $d $w $h }
    else       { Draw-Text $g $d.Err 15 $true $Col.Dim 8 ($h / 2) }
    $g.SmoothingMode = 'AntiAlias'   # 픽셀 테마가 꺼 놨을 수 있음
    if ($script:updateAvail) { Fill-Circle $g $Col.Gold ($w - 6) 6 3 }   # 새 버전 표시점 (우상단)
    $g.Dispose(); return $bmp
}

# 자가점검 — 테마 x (38/72, 91/12) 두 데이터로 1x·2x 렌더 시트를 만들고 종료
if ($RenderTest) {
    $dark = [Drawing.Color]::FromArgb(32, 32, 32)
    $sheet = New-Object Drawing.Bitmap 840, ($Themes.Count * 3 * 104 + 8)
    $sg = [Drawing.Graphics]::FromImage($sheet); $sg.Clear($dark); $sg.InterpolationMode = 'NearestNeighbor'
    $y = 4
    $now = (Get-Date).ToUniversalTime()
    foreach ($t in $Themes.Values) {
        # (5h%, 7d%, 5h 남은분, 7d 남은분) — 2:21/5h·1/7d / 0:40/5h·23h/7d / 둘 다 100%(끊어짐·기절·펑)
        foreach ($p in @(@(38, 72, 141, 1620), @(91, 12, 40, 1380), @(100, 100, 5, 30))) {
            $d = @{ Ok = $true; S5 = $p[0]; S7 = $p[1]; C5 = (Get-LevelColor $p[0]); C7 = (Get-LevelColor $p[1])
                    CD = (Get-LevelColor ([Math]::Max($p[0], $p[1]))); R5 = '-'; R7 = '-'
                    I5 = $now.AddMinutes($p[2]).ToString('o'); I7 = $now.AddMinutes($p[3]).ToString('o') }
            $b = Render-Bitmap $t $d $dark 48
            $sg.DrawImage($b, 4, ($y + 24), $b.Width, 48)
            $sg.DrawImage($b, 280, $y, ($b.Width * 2), 96)
            $b.Dispose(); $y += 104
        }
    }
    $sg.Dispose(); $sheet.Save($RenderTest, [Drawing.Imaging.ImageFormat]::Png)
    Write-Output "rendered $($Themes.Count) themes -> $RenderTest"; exit 0
}

function Render-Widget {
    $t = $Themes[$script:themeId]; $d = $script:data
    $bmp = Render-Bitmap $t $d $script:bg $H
    $script:width = $bmp.Width
    $old = $pic.Image; $pic.Image = $bmp; if ($old) { $old.Dispose() }
    $text = if ($d.Ok) { "5시간 {0}%  리셋 {1}`n주간 {2}%  리셋 {3}`n테마: {4}" -f $d.S5, $d.R5, $d.S7, $d.R7, $t.Name } else { $d.Msg }
    if ($d.Ok -and $d.Stale) { $text += "`n⚠ " + $d.Msg }
    if ($script:updateAvail) { $text += "`n● 새 버전 있음 — 우클릭 → 업데이트 설치" }
    $tip.SetToolTip($pic, $text)
}

function Set-Placement {
    $r = Get-TaskbarRect
    if ($null -eq $r) { return }
    $script:H = $r.B - $r.T
    # WS_EX_TOOLWINDOW(0x80): Alt+Tab 숨김 / WS_EX_NOACTIVATE(0x08000000): 클릭해도 포커스 안 뺏김
    $ex = [TBW]::GetWindowLong($form.Handle, -20)
    [void][TBW]::SetWindowLong($form.Handle, -20, $ex -bor 0x80 -bor 0x08000000)
    $right = ((Get-EffectivePosition) -eq 'right')
    # 배경색은 위젯이 덮지 않는 옆자리에서 샘플 — 왼쪽 배치면 오른쪽 옆, 오른쪽 배치면 왼쪽 옆
    $x0 = if ($right) { $r.TrayL - $MarginX - $script:width } else { $r.L + $MarginX }
    $c = Get-TaskbarColor $r $(if ($right) { $x0 - 40 } else { $x0 + $script:width + 40 })
    # 배경색 변화(테마 전환) 또는 분이 바뀌면(남은시간 라벨) 다시 그린다
    $need = $false
    if ($c.ToArgb() -ne $script:bg.ToArgb()) { $script:bg = $c; $form.BackColor = $c; $need = $true }
    $m = (Get-Date).Minute
    if ($m -ne $script:lastMin) { $script:lastMin = $m; $need = $true }
    if ($need) { Render-Widget }
    # 렌더로 폭이 바뀔 수 있으니 x 는 마지막에 확정. 매번 TOPMOST 재지정 — 다른 창이 위로 올라오는 걸 되돌린다. SWP_NOACTIVATE(0x0010)
    $x = if ($right) { $r.TrayL - $MarginX - $script:width } else { $r.L + $MarginX }
    [void][TBW]::SetWindowPos($form.Handle, [TBW]::TOPMOST, [int]$x, $r.T, $script:width, $script:H, 0x0010)
}

function Update-Widget { Refresh-Data; Render-Widget; Set-Placement }

# 우클릭 메뉴: 테마 ▸ (라디오) / 새로고침 / 종료
$menu = New-Object Windows.Forms.ContextMenuStrip
$themeMenu = New-Object Windows.Forms.ToolStripMenuItem '테마'
# 파일 스코프 함수여야 한다 — GetNewClosure 안에서 $script:themeId 를 대입하면 클로저 모듈 스코프에 써져
# 렌더 함수가 읽는 파일 스코프 값은 안 바뀐다(실측: 메뉴 눌러도 테마 안 바뀜).
function Set-Theme([string]$id) {
    if (-not $Themes.Contains($id)) { return }
    $script:themeId = $id; Save-Config
    foreach ($m in $themeMenu.DropDownItems) { $m.Checked = ([string]$m.Tag -eq $id) }
    Render-Widget; Set-Placement
}
foreach ($id in $Themes.Keys) {
    $mi = New-Object Windows.Forms.ToolStripMenuItem $Themes[$id].Name
    $mi.Tag = $id
    $mi.Add_Click({ Set-Theme $id }.GetNewClosure())   # $id 는 이 회차 값으로 캡처
    [void]$themeMenu.DropDownItems.Add($mi)
}
foreach ($m in $themeMenu.DropDownItems) { $m.Checked = ([string]$m.Tag -eq $script:themeId) }
[void]$menu.Items.Add($themeMenu)

$posMenu = New-Object Windows.Forms.ToolStripMenuItem '위치'
function Set-Position([string]$p) {
    $script:position = $p; Save-Config
    foreach ($m in $posMenu.DropDownItems) { $m.Checked = ([string]$m.Tag -eq $p) }
    Set-Placement
}
foreach ($pair in @(@('auto', '자동 (아이콘 정렬에 따라)'), @('left', '왼쪽'), @('right', '오른쪽 (트레이 앞)'))) {
    $mi = New-Object Windows.Forms.ToolStripMenuItem $pair[1]
    $mi.Tag = $pair[0]; $mi.Checked = ($pair[0] -eq $script:position)
    $p = $pair[0]
    $mi.Add_Click({ Set-Position $p }.GetNewClosure())
    [void]$posMenu.DropDownItems.Add($mi)
}
[void]$menu.Items.Add($posMenu)
[void]$menu.Items.Add('지금 새로고침', $null, { Update-Widget }.GetNewClosure())
[void]$menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
$updItem = New-Object Windows.Forms.ToolStripMenuItem '업데이트 확인'
$updItem.Add_Click({ Check-Update $false }.GetNewClosure())
[void]$menu.Items.Add($updItem)
[void]$menu.Items.Add('종료', $null, { $form.Close() }.GetNewClosure())
$form.ContextMenuStrip = $menu; $pic.ContextMenuStrip = $menu

$poll = New-Object Windows.Forms.Timer;  $poll.Interval = $PollSec * 1000;   $poll.Add_Tick({ Update-Widget }.GetNewClosure())
$place = New-Object Windows.Forms.Timer; $place.Interval = $PlaceSec * 1000; $place.Add_Tick({ Set-Placement }.GetNewClosure())
# 업데이트 자동 점검 — 시작 20초 뒤 1회, 이후 24시간마다 (표시만, 설치는 사용자가 메뉴에서)
$upd = New-Object Windows.Forms.Timer; $upd.Interval = 20000
$upd.Add_Tick({ $upd.Interval = $UpdateCheckHours * 3600 * 1000; Check-Update $true }.GetNewClosure())

$form.Add_Shown({
    Set-Placement
    $cached = Load-Cache
    if ($cached) {
        # 방금 받은 응답이 있으면 그걸 그리고, 남은 주기만큼 기다린 뒤 첫 폴링
        Set-DataFromUsage ([int]$cached.c.s5) ([int]$cached.c.s7) $cached.c.r5 $cached.c.r7
        Render-Widget; Set-Placement
        $poll.Interval = [int](($PollSec - $cached.age) * 1000) + 500
    } else {
        Update-Widget
    }
    $poll.Start(); $place.Start(); $upd.Start()
}.GetNewClosure())
[Windows.Forms.Application]::Run($form)
