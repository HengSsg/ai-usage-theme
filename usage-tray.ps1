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
// 다른 창이 포그라운드가 되면(작업표시줄 클릭 포함) Windows 가 그 창을 topmost 최상단으로 올려 위젯을 덮는다.
// 2초 폴링이 돌 때까지 가려져 "사라졌다 다시 생기는" 것으로 보인다 → 포그라운드 변경 이벤트에 즉시 반응해 되올린다.
// WINEVENT_OUTOFCONTEXT 콜백은 훅을 건 스레드의 메시지 루프에서 실행되므로 UI 스레드에서 Start 해야 한다.
public class TopGuard {
 delegate void Proc(IntPtr hHook,uint ev,IntPtr hwnd,int idObj,int idChild,uint thread,uint time);
 [DllImport("user32.dll")] static extern IntPtr SetWinEventHook(uint mn,uint mx,IntPtr hmod,Proc cb,uint pid,uint tid,uint flags);
 [DllImport("user32.dll")] static extern bool UnhookWinEvent(IntPtr h);
 [DllImport("user32.dll")] static extern bool SetWindowPos(IntPtr h,IntPtr a,int x,int y,int w,int t,uint f);
 static Proc _cb;                                   // GC 가 수거하면 콜백 시점에 죽는다 — 반드시 참조 유지
 static IntPtr _hook = IntPtr.Zero, _target = IntPtr.Zero;
 static System.Threading.AutoResetEvent _sig = new System.Threading.AutoResetEvent(false);
 static System.Threading.Thread _worker; static bool _run;
 public static void Start(IntPtr target){
   _target = target;
   if (_hook != IntPtr.Zero) return;
   _run = true;
   _worker = new System.Threading.Thread(Loop); _worker.IsBackground = true; _worker.Start();
   _cb = new Proc(OnEvent);
   _hook = SetWinEventHook(0x0003,0x0003,IntPtr.Zero,_cb,0,0,0);          // EVENT_SYSTEM_FOREGROUND
 }
 public static void Stop(){ _run = false; _sig.Set(); if (_hook != IntPtr.Zero) { UnhookWinEvent(_hook); _hook = IntPtr.Zero; } }
 static void OnEvent(IntPtr h,uint ev,IntPtr hwnd,int o,int c,uint th,uint t){ Raise(); _sig.Set(); }
 static void Raise(){
   if (_target == IntPtr.Zero) return;
   // ⚠️ 이미 topmost 인 창에 HWND_TOPMOST 를 다시 주는 것만으로는 **topmost 밴드 안의 순서가 안 바뀐다**.
   // 밴드 맨 앞으로 올리려면 HWND_TOP 이 필요하다.
   SetWindowPos(_target,new IntPtr(-1),0,0,0,0,0x0013);   // HWND_TOPMOST | NOSIZE|NOMOVE|NOACTIVATE
   SetWindowPos(_target,IntPtr.Zero,   0,0,0,0,0x0013);   // HWND_TOP
 }
 static void Loop(){
   while (_run) {
     _sig.WaitOne();
     // 작업표시줄은 포그라운드 이벤트 **이후에** 스스로 올라오므로 한 번만 되올리면 늦는다(실측: 그 뒤 덮임).
     // 이벤트마다 짧게 반복해 경쟁을 이긴다. 평소엔 이벤트가 없어 유휴 비용 0.
     for (int i = 0; i < 8 && _run; i++) { System.Threading.Thread.Sleep(45); Raise(); }
   }
 }
}
'@
Add-Type -AssemblyName System.Net.Http
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# ⚠️ 네트워크 호출은 절대 UI 스레드(타이머 콜백)에서 동기로 하지 말 것.
# Invoke-RestMethod/git fetch 를 타이머 안에서 부르면 응답이 늦을 때 메시지 루프가 멈추고
# Windows 가 "응답 없음"으로 프로세스를 죽인다 (실측: 이벤트로그 Application Hang → 위젯이 조용히 사라짐).
# 그래서 HttpClient 비동기 Task 로 던져 두고 타이머가 IsCompleted 만 확인해 회수한다.
$script:http = New-Object Net.Http.HttpClient
$script:http.Timeout = [TimeSpan]::FromSeconds(25)
$script:http.DefaultRequestHeaders.Add('User-Agent', 'cc-usage-tray')

$ErrorLog = Join-Path $PSScriptRoot 'error.log'
function Write-ErrLog([string]$where, $err) {
    try {
        Add-Content $ErrorLog ("{0}  [{1}] {2}" -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $where, $err) -Encoding UTF8
        if ((Get-Item $ErrorLog).Length -gt 20480) { Set-Content $ErrorLog (Get-Content $ErrorLog -Tail 80) -Encoding UTF8 }
    } catch {}
}

$CredFile   = Join-Path $env:USERPROFILE '.claude\.credentials.json'
$ConfigFile = Join-Path $PSScriptRoot 'config.json'
$CacheFile  = Join-Path $PSScriptRoot 'last.json'   # 마지막 응답 — 재시작 직후 재호출 방지
$UsageUrl   = 'https://api.anthropic.com/api/oauth/usage'
$PollSec    = 120   # API 폴링. 5시간 창은 분 단위로 천천히 움직인다 — 더 짧게 하면 429 위험
$PlaceSec   = 2     # 위치·z순서 재확인 (explorer 재시작·해상도 변경 대응)
$AnimIdleX  = 4     # 마우스가 위젯 위에 없을 때 애니메이션을 이 배수만큼 느리게 (CPU 절약)
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
# 작업표시줄이 라이트 테마면 팔레트의 중성색·레벨색을 어두운 쪽으로 뒤집는다.
# (안 하면 밝은 작업표시줄 위에 회색 라벨·연두색 숫자가 거의 안 보인다)
$script:isLight = $null
function Set-PaletteForBackground($c) {
    $light = ((0.299 * $c.R + 0.587 * $c.G + 0.114 * $c.B) -gt 140)
    if ($light -eq $script:isLight) { return $false }
    $script:isLight = $light
    if ($light) {
        $Col.Green = [Drawing.Color]::FromArgb(20, 130, 60);  $Col.Gold = [Drawing.Color]::FromArgb(150, 105, 0)
        $Col.Red   = [Drawing.Color]::FromArgb(200, 40, 40)
        $Col.Track = [Drawing.Color]::FromArgb(203, 203, 210); $Col.Label = [Drawing.Color]::FromArgb(88, 88, 96)
        $Col.Dim   = [Drawing.Color]::FromArgb(108, 108, 116); $Col.Light = [Drawing.Color]::FromArgb(38, 38, 44)
        $Col.Road  = [Drawing.Color]::FromArgb(214, 214, 221)
        $Px.Ink    = [Drawing.Color]::FromArgb(38, 38, 44);    $Px.White = [Drawing.Color]::FromArgb(208, 216, 230)
        $Px.Gray   = [Drawing.Color]::FromArgb(118, 118, 126); $Px.Dark  = [Drawing.Color]::FromArgb(168, 168, 176)
        $Px.Cream  = [Drawing.Color]::FromArgb(232, 205, 150); $Px.Sky   = [Drawing.Color]::FromArgb(120, 175, 225)
    } else {
        $Col.Green = [Drawing.Color]::FromArgb(90, 210, 110); $Col.Gold = [Drawing.Color]::Gold
        $Col.Red   = [Drawing.Color]::FromArgb(255, 99, 71)
        $Col.Track = [Drawing.Color]::FromArgb(58, 58, 58);   $Col.Label = [Drawing.Color]::FromArgb(160, 160, 160)
        $Col.Dim   = [Drawing.Color]::FromArgb(138, 138, 138); $Col.Light = [Drawing.Color]::FromArgb(232, 232, 232)
        $Col.Road  = [Drawing.Color]::FromArgb(44, 44, 44)
        $Px.Ink    = [Drawing.Color]::FromArgb(28, 28, 32);    $Px.White = [Drawing.Color]::FromArgb(242, 242, 242)
        $Px.Gray   = [Drawing.Color]::FromArgb(130, 130, 138); $Px.Dark  = [Drawing.Color]::FromArgb(64, 64, 72)
        $Px.Cream  = [Drawing.Color]::FromArgb(255, 235, 190); $Px.Sky   = [Drawing.Color]::FromArgb(160, 210, 255)
    }
    # 이미 계산해 둔 레벨색도 새 팔레트로 다시 뽑는다
    if ($script:data -and $script:data.Ok) {
        $script:data.C5 = Get-LevelColor $script:data.S5
        $script:data.C7 = Get-LevelColor $script:data.S7
        $script:data.CD = Get-LevelColor ([Math]::Max($script:data.S5, $script:data.S7))
    }
    return $true
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
# 비동기 GET 요청 하나를 띄우고 Task 를 돌려준다 (UI 스레드를 막지 않는다)
function Start-Get([string]$url, [bool]$auth) {
    $req = New-Object Net.Http.HttpRequestMessage ([Net.Http.HttpMethod]::Get, $url)
    if ($auth) {
        # 토큰은 매번 파일에서 다시 읽는다 — Claude Code 가 갱신해 두면 그대로 따라간다.
        $tok = (Get-Content $CredFile -Raw -Encoding UTF8 | ConvertFrom-Json).claudeAiOauth.accessToken
        [void]$req.Headers.TryAddWithoutValidation('Authorization', "Bearer $tok")
        [void]$req.Headers.TryAddWithoutValidation('anthropic-beta', 'oauth-2025-04-20')
    }
    return $script:http.SendAsync($req)
}
# 완료된 Task → @{ Code; Json; Err }. 본문은 Task 완료 시점에 이미 버퍼링돼 있어 .Result 가 즉시 반환된다.
function Read-Task($task) {
    $resp = $null
    try {
        if ($task.IsFaulted) { return @{ Code = 0; Err = $task.Exception.GetBaseException().Message } }
        if ($task.IsCanceled) { return @{ Code = 0; Err = '요청 시간 초과' } }
        $resp = $task.Result
        $code = [int]$resp.StatusCode
        if ($code -ne 200) { return @{ Code = $code; Err = "HTTP $code" } }
        return @{ Code = 200; Json = ($resp.Content.ReadAsStringAsync().Result | ConvertFrom-Json) }
    } catch { return @{ Code = 0; Err = $_.Exception.Message } }
    finally { if ($resp) { $resp.Dispose() } }
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
# 툴팁용 리셋 절대시각 — "3시간 12분 뒤" 만 있으면 몇 시인지 계산해야 한다
function Format-ResetAt($iso) {
    if (-not $iso) { return '' }
    try {
        $t = ([datetime]$iso).ToLocalTime()
        $fmt = if (($t - (Get-Date)).TotalHours -lt 24) { 'HH:mm' } else { 'M/d HH:mm' }
        return ' (' + $t.ToString($fmt) + ')'
    } catch { return '' }
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
$script:usageTask    = $null
$script:lastFetchUtc = [datetime]::MinValue
$script:nextFetchSec = 0                 # 다음 요청까지 대기 초 (429 백오프로 늘어남)
function Start-Refresh {
    if ($script:usageTask) { return }
    try { $script:usageTask = Start-Get $UsageUrl $true }
    catch { Write-ErrLog 'start-refresh' $_; $script:lastFetchUtc = (Get-Date).ToUniversalTime() }
}
function Complete-Refresh {
    $r = Read-Task $script:usageTask
    $script:usageTask = $null
    $script:lastFetchUtc = (Get-Date).ToUniversalTime()
    if ($r.Code -eq 200) {
        $u = $r.Json
        Set-DataFromUsage ([int]$u.five_hour.utilization) ([int]$u.seven_day.utilization) $u.five_hour.resets_at $u.seven_day.resets_at
        try {
            @{ at = $script:lastFetchUtc.ToString('o'); s5 = $script:data.S5; s7 = $script:data.S7
               r5 = [string]$u.five_hour.resets_at; r7 = [string]$u.seven_day.resets_at } | ConvertTo-Json | Set-Content $CacheFile -Encoding UTF8
        } catch { Write-ErrLog 'cache-write' $_ }
        $script:nextFetchSec = $PollSec          # 백오프 원복
        return
    }
    if ($script:data.Ok -and $r.Code -ne 401) {
        # 일시 실패(429·네트워크)는 마지막 값을 그대로 두고 툴팁에만 표시
        $script:data.Stale = $true
        $script:data.Msg   = "갱신 실패($($r.Err)) — 마지막 값 표시 중"
    } else {
        $script:data = @{ Ok = $false; Msg = $r.Err
                          Err = $(if ($r.Code -eq 401) { 'CC  재로그인 필요' } elseif ($r.Code -eq 429) { 'CC  잠시 후 재시도' } else { 'CC  조회 실패' }) }
    }
    # 429 면 다음 요청을 두 배로 늦춘다(최대 10분) — 연타하면 더 오래 막힌다
    $script:nextFetchSec = if ($r.Code -eq 429) { [Math]::Min([Math]::Max($script:nextFetchSec, $PollSec) * 2, 600) } else { $PollSec }
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
    $b = $null; $g = $null
    try {
        $b = New-Object Drawing.Bitmap 1, 1
        $g = [Drawing.Graphics]::FromImage($b)
        # 화면 잠금·RDP 끊김 상태에선 여기서 예외가 난다. finally 로 안 버리면 2초마다 GDI 핸들이 새
        # 몇 시간 뒤 핸들 고갈로 프로세스가 죽는다.
        $g.CopyFromScreen($sampleX, ($r.T + [int](($r.B - $r.T) / 2)), 0, 0, (New-Object Drawing.Size 1, 1))
        return $b.GetPixel(0, 0)
    } catch { return $script:bg }
    finally { if ($g) { $g.Dispose() }; if ($b) { $b.Dispose() } }
}

# ── 업데이트 — git clone 이면 fetch/pull, zip 설치면 GitHub main.zip 재다운로드. 개인 파일(config/last)은 보존 ──
$script:updateAvail     = $false
$script:remoteSha       = ''
$script:updTask         = $null
$script:updInteractive  = $false
$script:lastUpdCheckUtc = [datetime]::MinValue
function Test-GitClone { Test-Path (Join-Path $PSScriptRoot '.git') }
# 현재 설치본의 커밋. git clone 이면 로컬 HEAD(디스크만 읽음 — `git fetch` 는 네트워크라 UI 스레드에서 쓰지 않는다),
# zip 설치면 setup.ps1 이 기록해 둔 version.txt. 모르면 빈 문자열.
function Get-LocalSha {
    if (Test-GitClone) {
        try { $s = (git -C $PSScriptRoot rev-parse HEAD 2>$null); if ($LASTEXITCODE -eq 0 -and $s) { return $s.Trim() } } catch {}
    }
    if (Test-Path $VersionFile) { return (Get-Content $VersionFile -Raw).Trim() }
    return ''
}
# 원격 커밋을 이미 갖고 있나? (git clone 전용, 로컬 전용 연산)
# ⚠️ `rev-parse HEAD` 와 원격 sha 를 단순 비교하면 **로컬이 앞서 있을 때**(미push 커밋) 항상
# "새 버전 있음" 으로 오판한다. 원격 커밋이 HEAD 의 조상이면 이미 포함한 것 (실측 2026-09-11).
# 그 커밋 객체가 로컬에 없으면 오류로 빠지는데, 그때는 실제로 안 갖고 있는 것이니 $false 가 맞다.
function Test-HaveCommit([string]$sha) {
    if (-not $sha) { return $true }
    git -C $PSScriptRoot merge-base --is-ancestor $sha HEAD 2>$null | Out-Null
    return ($LASTEXITCODE -eq 0)
}
function Start-UpdateCheck {
    if ($script:updTask) { return }
    $api = $RepoUrl -replace '^https://github\.com/', 'https://api.github.com/repos/'
    try { $script:updTask = Start-Get "$api/commits/main" $false } catch { Write-ErrLog 'start-updcheck' $_ }
}
# 설치는 사용자가 "예" 를 누른 뒤라 잠깐 기다려도 되지만, 그냥 블로킹하면 그 사이 메시지 루프가 멈춰
# Windows 가 "응답 없음" 으로 죽인다. DoEvents 로 펌프를 돌리며 기다린다.
function Wait-Pumping($isDone, [int]$timeoutSec) {
    $end = (Get-Date).AddSeconds($timeoutSec)
    while (-not (& $isDone)) {
        if ((Get-Date) -gt $end) { throw '시간 초과' }
        [Windows.Forms.Application]::DoEvents(); Start-Sleep -Milliseconds 50
    }
}
function Invoke-Update {
    $tmp = Join-Path $env:TEMP ('cc-usage-tray-upd-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $tmp | Out-Null
    if (Test-GitClone) {
        $o = Join-Path $tmp 'out.txt'; $e = Join-Path $tmp 'err.txt'
        $p = Start-Process git -ArgumentList '-C', $PSScriptRoot, 'pull', '--ff-only', 'origin', 'main' `
                 -NoNewWindow -PassThru -RedirectStandardOutput $o -RedirectStandardError $e
        try { Wait-Pumping { $p.HasExited } 90 } catch { try { $p.Kill() } catch {}; throw 'git pull 시간 초과' }
        # ⚠️ Start-Process -PassThru 로 받은 객체의 ExitCode 는 **빈 값**이라 `-ne 0` 이 항상 참이 된다
        # (실측 2026-09-11: git 이 "Already up to date" 로 성공했는데 실패로 보고). 결과 상태로 판정한다.
        if (-not (Test-HaveCommit $script:remoteSha)) {
            throw ("git pull 실패:`n" + ((Get-Content $e -Raw -EA SilentlyContinue) + (Get-Content $o -Raw -EA SilentlyContinue)))
        }
        Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue
        return
    }
    $zip = Join-Path $tmp 'main.zip'
    $dl = $script:http.GetByteArrayAsync("$RepoUrl/archive/refs/heads/main.zip")
    Wait-Pumping { $dl.IsCompleted } 90
    if ($dl.IsFaulted) { throw $dl.Exception.GetBaseException().Message }
    [IO.File]::WriteAllBytes($zip, $dl.Result)
    Expand-Archive -Path $zip -DestinationPath $tmp -Force
    $src = (Get-ChildItem $tmp -Directory | Select-Object -First 1).FullName
    Get-ChildItem $src -Recurse -File | ForEach-Object {
        $rel = $_.FullName.Substring($src.Length + 1)
        if ($rel -in @('config.json', 'last.json', 'version.txt')) { return }
        $dst = Join-Path $PSScriptRoot $rel
        New-Item -ItemType Directory -Path (Split-Path $dst) -Force | Out-Null
        Copy-Item $_.FullName $dst -Force
    }
    # 덮어쓰기만 하면 위에서 삭제된 테마가 계속 남아 메뉴에 유령 항목이 생긴다 — 새 목록에 없는 테마는 지운다
    $keep = @(Get-ChildItem (Join-Path $src 'themes') -Filter *.ps1 -EA SilentlyContinue | ForEach-Object Name)
    if ($keep.Count -gt 0) {
        Get-ChildItem (Join-Path $PSScriptRoot 'themes') -Filter *.ps1 -EA SilentlyContinue |
            Where-Object { $keep -notcontains $_.Name } | Remove-Item -Force -ErrorAction SilentlyContinue
    }
    # remoteSha 는 직전 Complete-UpdateCheck 가 채워 둔다(설치는 항상 점검 뒤에만 일어남)
    if ($script:remoteSha) { Set-Content $VersionFile $script:remoteSha -Encoding ASCII }
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
# 비동기 점검 결과 회수. $script:updInteractive 면 결과를 대화상자로 안내하고 설치까지 진행한다.
function Complete-UpdateCheck {
    $r = Read-Task $script:updTask
    $script:updTask = $null
    $script:lastUpdCheckUtc = (Get-Date).ToUniversalTime()
    $interactive = $script:updInteractive; $script:updInteractive = $false
    if ($r.Code -ne 200) {
        if ($interactive) { Show-Msg ("업데이트 확인 실패:`n" + $r.Err) '업데이트' 'OK' 'Warning' | Out-Null }
        return
    }
    $script:remoteSha = [string]$r.Json.sha
    if (Test-GitClone) {
        $known = $true
        $script:updateAvail = -not (Test-HaveCommit $script:remoteSha)
    } else {
        $local = Get-LocalSha                       # zip 설치본: version.txt 비교밖에 없다
        $known = [bool]$local
        $script:updateAvail = ($known -and $script:remoteSha -and $local -ne $script:remoteSha)
    }
    if ($updItem) { $updItem.Text = if ($script:updateAvail) { '업데이트 설치 — 새 버전 있음' } else { '업데이트 확인' } }
    Render-Widget
    if (-not $interactive) { return }
    $q = if ($script:updateAvail) { "새 버전이 있습니다. 지금 업데이트할까요?`n(위젯이 자동으로 재시작됩니다)" }
         elseif (-not $known)     { "현재 버전을 확인할 수 없습니다.`n최신 버전으로 다시 받을까요? 개인 설정은 유지됩니다." }
         else { $null }
    if (-not $q) { Show-Msg '최신 버전입니다.' | Out-Null; return }
    if ((Show-Msg $q '업데이트' 'YesNo' 'Question') -ne 'Yes') { return }
    try { Invoke-Update; Restart-Self }
    catch { Write-ErrLog 'update' $_; Show-Msg ("업데이트 실패:`n" + $_.Exception.Message) '업데이트' 'OK' 'Warning' | Out-Null }
}

# ── 단일 인스턴스 — 두 개가 돌면 폴링이 두 배가 돼 429 를 부른다 ─────────────────────
$mutex = New-Object Threading.Mutex($false, 'Local\CCUsageTray')
if (-not $RenderTest) {
    # 앞 인스턴스가 비정상 종료하면 뮤텍스가 "버려진" 상태가 되고 WaitOne 이 AbandonedMutexException 을
    # 던진다(소유권은 획득된 상태). 안 잡으면 크래시 뒤 자동시작이 계속 실패해 위젯이 영영 안 뜬다.
    $got = $false
    try { $got = $mutex.WaitOne(0) } catch [Threading.AbandonedMutexException] { $got = $true }
    if (-not $got) { exit 0 }   # 이미 떠 있음
}

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
    try {
        $g.SmoothingMode = 'AntiAlias'; $g.TextRenderingHint = 'ClearTypeGridFit'; $g.PixelOffsetMode = 'HighQuality'
        $g.Clear($bg)
        # 테마 Draw 가 던져도 위젯은 살아 있어야 한다 — 그 칸만 비우고 로그에 남긴다
        try {
            $d.F = $script:frame; $d.BG = $bg      # 애니메이션 프레임 번호 · 배경색(정적 레이어 캐시 키용)
            if ($d.Ok) { $d.L5 = Format-Left5 $d.I5; $d.L7 = Format-Left7 $d.I7; & $t.Draw $g $d $w $h }
            else       { Draw-Text $g $d.Err 15 $true $Col.Dim 8 ($h / 2) }
        } catch {
            Write-ErrLog "theme:$($t.Id)" $_
            $g.Clear($bg); Draw-Text $g 'CC  테마 오류' 15 $true $Col.Dim 8 ($h / 2)
        }
        $g.SmoothingMode = 'AntiAlias'   # 픽셀 테마가 꺼 놨을 수 있음
        if ($script:updateAvail) { Fill-Circle $g $Col.Gold ($w - 6) 6 3 }   # 새 버전 표시점 (우상단)
    } finally { $g.Dispose() }
    return $bmp
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

$script:frame = 0
# $tooltip=$false: 애니메이션 프레임 — 그림만 갈아끼운다(툴팁까지 매 프레임 다시 설정하면 낭비·깜빡임)
function Render-Widget([bool]$tooltip = $true) {
    $t = $Themes[$script:themeId]; $d = $script:data
    $bmp = Render-Bitmap $t $d $script:bg $H
    $script:width = $bmp.Width
    $old = $pic.Image; $pic.Image = $bmp; if ($old) { $old.Dispose() }
    if (-not $tooltip) { return }
    $text = if ($d.Ok) {
        "5시간 {0}%  ·  리셋 {1} 뒤{2}`n주간 {3}%  ·  리셋 {4} 뒤{5}`n테마: {6}  |  우클릭 = 메뉴" -f `
            $d.S5, $d.R5, (Format-ResetAt $d.I5), $d.S7, $d.R7, (Format-ResetAt $d.I7), $t.Name
    } else { $d.Msg }
    if ($d.Ok -and $d.Stale) { $text += "`n⚠ " + $d.Msg }
    if ($script:updateAvail) { $text += "`n● 새 버전 있음 — 우클릭 → 업데이트 설치" }
    $tip.SetToolTip($pic, $text)
}

function Set-Placement {
    $r = Get-TaskbarRect
    if ($null -eq $r) { return }
    # 자동 숨김이면 작업표시줄이 화면 밖으로 내려간다 — 따라 숨지 않으면 허공에 위젯만 떠 있다.
    # 세로(좌/우 배치) 작업표시줄은 이 위젯의 가로 레이아웃과 맞지 않으므로 역시 숨긴다.
    $screenB = [Windows.Forms.Screen]::PrimaryScreen.Bounds.Bottom
    $hidden = ($r.T -ge $screenB - 8) -or (($r.R - $r.L) -le ($r.B - $r.T))
    if ($hidden) { if ($form.Visible) { $form.Hide(); Sync-Anim }; return }
    if (-not $form.Visible) { $form.Show(); Sync-Anim }

    $script:H = $r.B - $r.T
    # WS_EX_TOOLWINDOW(0x80): Alt+Tab 숨김 / WS_EX_NOACTIVATE(0x08000000): 클릭해도 포커스 안 뺏김
    $ex = [TBW]::GetWindowLong($form.Handle, -20)
    [void][TBW]::SetWindowLong($form.Handle, -20, $ex -bor 0x80 -bor 0x08000000)
    $right = ((Get-EffectivePosition) -eq 'right')
    # 배경색은 위젯이 덮지 않는 옆자리에서 샘플 — 왼쪽 배치면 오른쪽 옆, 오른쪽 배치면 왼쪽 옆.
    # CopyFromScreen 이 이 위젯에서 제일 비싼 호출이라 10초에 한 번만 (테마 전환은 그 정도 지연이면 충분)
    $need = $false
    if ($script:colorTick-- -le 0) {
        $script:colorTick = 4
        $x0 = if ($right) { $r.TrayL - $MarginX - $script:width } else { $r.L + $MarginX }
        $c = Get-TaskbarColor $r $(if ($right) { $x0 - 40 } else { $x0 + $script:width + 40 })
        # 배경색 변화(테마 전환)·라이트↔다크 전환이면 다시 그린다
        $need = Set-PaletteForBackground $c
        if ($c.ToArgb() -ne $script:bg.ToArgb()) { $script:bg = $c; $form.BackColor = $c; $need = $true }
    }
    # 분이 바뀌면(남은시간 라벨) 다시 그린다
    $m = (Get-Date).Minute
    if ($m -ne $script:lastMin) { $script:lastMin = $m; $need = $true }
    if ($need) { Render-Widget }
    # 렌더로 폭이 바뀔 수 있으니 x 는 마지막에 확정. 매번 TOPMOST 재지정 — 다른 창이 위로 올라오는 걸 되돌린다. SWP_NOACTIVATE(0x0010)
    $x = if ($right) { $r.TrayL - $MarginX - $script:width } else { $r.L + $MarginX }
    [void][TBW]::SetWindowPos($form.Handle, [TBW]::TOPMOST, [int]$x, $r.T, $script:width, $script:H, 0x0010)
}

# 메뉴 "지금 새로고침" — 요청을 띄우기만 하고 회수는 틱이 한다(여기서 기다리면 UI 가 멈춘다)
function Request-Refresh { $script:nextFetchSec = 0; Start-Refresh }

# 우클릭 메뉴: 테마 ▸ (라디오) / 새로고침 / 종료
$menu = New-Object Windows.Forms.ContextMenuStrip
$themeMenu = New-Object Windows.Forms.ToolStripMenuItem '테마'
# 파일 스코프 함수여야 한다 — GetNewClosure 안에서 $script:themeId 를 대입하면 클로저 모듈 스코프에 써져
# 렌더 함수가 읽는 파일 스코프 값은 안 바뀐다(실측: 메뉴 눌러도 테마 안 바뀜).
function Set-Theme([string]$id) {
    try {
        if (-not $Themes.Contains($id)) { return }
        $script:themeId = $id; Save-Config
        foreach ($m in $themeMenu.DropDownItems) { $m.Checked = ([string]$m.Tag -eq $id) }
        Render-Widget; Set-Placement; Sync-Anim
    } catch { Write-ErrLog 'set-theme' $_ }
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
    try {
        $script:position = $p; Save-Config
        foreach ($m in $posMenu.DropDownItems) { $m.Checked = ([string]$m.Tag -eq $p) }
        Set-Placement
    } catch { Write-ErrLog 'set-position' $_ }
}
foreach ($pair in @(@('auto', '자동 (아이콘 정렬에 따라)'), @('left', '왼쪽'), @('right', '오른쪽 (트레이 앞)'))) {
    $mi = New-Object Windows.Forms.ToolStripMenuItem $pair[1]
    $mi.Tag = $pair[0]; $mi.Checked = ($pair[0] -eq $script:position)
    $p = $pair[0]
    $mi.Add_Click({ Set-Position $p }.GetNewClosure())
    [void]$posMenu.DropDownItems.Add($mi)
}
[void]$menu.Items.Add($posMenu)
[void]$menu.Items.Add('지금 새로고침', $null, { Request-Refresh }.GetNewClosure())
[void]$menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))
$updItem = New-Object Windows.Forms.ToolStripMenuItem '업데이트 확인'
# 여기도 같은 이유로 파일 스코프 함수 경유 — 인라인 `$script:updInteractive = $true` 는 클로저 안에만 써져 대화상자가 안 뜬다
function Request-UpdateCheck { $script:updInteractive = $true; Start-UpdateCheck }
$updItem.Add_Click({ Request-UpdateCheck }.GetNewClosure())
[void]$menu.Items.Add($updItem)
[void]$menu.Items.Add((New-Object Windows.Forms.ToolStripSeparator))   # 업데이트 바로 아래 붙어 오클릭하기 쉬웠다
[void]$menu.Items.Add('종료', $null, { [TopGuard]::Stop(); $form.Close() }.GetNewClosure())
$form.ContextMenuStrip = $menu; $pic.ContextMenuStrip = $menu

# ── 단일 틱: 비동기 요청 회수 → 다음 요청 발사 → 배치. 여기서 절대 블로킹하지 않는다 ──
# 주기를 1초로 하면 PowerShell 스크립트블록 실행 비용만으로 CPU 가 한 코어의 1% 가량 나간다. 2초면 충분.
function On-Tick {
    try {
        if ($script:usageTask -and $script:usageTask.IsCompleted) { Complete-Refresh; Render-Widget }
        if ($script:updTask   -and $script:updTask.IsCompleted)   { Complete-UpdateCheck }
        $nowU = (Get-Date).ToUniversalTime()
        if (-not $script:usageTask -and ($nowU - $script:lastFetchUtc).TotalSeconds -ge $script:nextFetchSec) { Start-Refresh }
        if (-not $script:updTask   -and ($nowU - $script:lastUpdCheckUtc).TotalHours -ge $UpdateCheckHours)   { Start-UpdateCheck }
        Set-Placement
    } catch { Write-ErrLog 'tick' $_ }
}
$tick = New-Object Windows.Forms.Timer
$tick.Interval = $PlaceSec * 1000
$tick.Add_Tick({ On-Tick }.GetNewClosure())

# 애니메이션 — 테마가 `Anim = <ms>` 를 선언하면 그 주기로 그림만 다시 그린다.
# 숨겨져 있을 땐 돌리지 않는다(자동숨김 작업표시줄에서 헛돌면 CPU 만 먹는다).
$anim = New-Object Windows.Forms.Timer
# ⚠️ 증가는 반드시 파일 스코프 함수에서 — 핸들러 스크립트블록(GetNewClosure) 안에서 `$script:frame++` 하면
# 클로저 모듈의 script 스코프에 써져 파일 쪽 값은 0 에 머문다(= 매 프레임 같은 그림, 애니메이션이 멈춘 것처럼 보임).
# 호버 부스트 — 마우스가 위젯 위에 있을 때만 선언된 프레임 간격으로 돌리고, 아니면 $AnimIdleX 배 느리게.
# 보는 순간엔 부드럽고 평소엔 CPU 를 덜 쓴다. 이벤트(MouseEnter/Leave) 대신 커서 위치를 보는 이유:
# 위젯이 다른 창에 덮이면 MouseLeave 가 안 오는 경우가 있고, 폴링은 이 틱에 얹으면 공짜다.
function Tick-Anim {
    $script:frame++
    Render-Widget $false
    $ms = [int]$Themes[$script:themeId].Anim
    if ($ms -le 0) { return }
    $want = if ($form.Bounds.Contains([Windows.Forms.Cursor]::Position)) { $ms } else { $ms * $AnimIdleX }
    if ($anim.Interval -ne $want) { $anim.Interval = $want }
}
$anim.Add_Tick({ try { Tick-Anim } catch { Write-ErrLog 'anim' $_ } }.GetNewClosure())
function Sync-Anim {
    try {
        $ms = [int]$Themes[$script:themeId].Anim
        if ($ms -gt 0 -and $form.Visible) {
            $want = $ms * $AnimIdleX            # 기동 직후는 느린 쪽에서 시작 — 호버하면 틱이 올린다
            if ($anim.Interval -ne $want -and -not $anim.Enabled) { $anim.Interval = $want }
            if (-not $anim.Enabled) { $anim.Start() }
        } elseif ($anim.Enabled) { $anim.Stop() }
    } catch { Write-ErrLog 'sync-anim' $_ }
}

$form.Add_Shown({
    try {
        Set-Placement
        $cached = Load-Cache
        if ($cached) {
            # 방금 받은 응답이 있으면 그걸 그리고, 남은 주기만큼 기다렸다 첫 요청 (재시작 연타로 429 나는 걸 막는다)
            Set-DataFromUsage ([int]$cached.c.s5) ([int]$cached.c.s7) $cached.c.r5 $cached.c.r7
            $script:lastFetchUtc = (Get-Date).ToUniversalTime().AddSeconds(-$cached.age)
        }
        $script:nextFetchSec = $PollSec
        # 업데이트 자동 점검은 기동 20초 뒤 첫 회, 이후 24시간마다 (표시만 — 설치는 메뉴에서)
        $script:lastUpdCheckUtc = (Get-Date).ToUniversalTime().AddHours(-$UpdateCheckHours).AddSeconds(20)
        Render-Widget; Set-Placement; Sync-Anim
        [TopGuard]::Start($form.Handle)      # 포그라운드 전환 시 즉시 최상단 복귀
        $tick.Start()
    } catch { Write-ErrLog 'shown' $_ }
}.GetNewClosure())
[Windows.Forms.Application]::Run($form)
