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
    $g.Dispose(); return $bmp
}

# 자가점검 — 테마 x (38/72, 91/12) 두 데이터로 1x·2x 렌더 시트를 만들고 종료
if ($RenderTest) {
    $dark = [Drawing.Color]::FromArgb(32, 32, 32)
    $sheet = New-Object Drawing.Bitmap 820, ($Themes.Count * 2 * 104 + 8)
    $sg = [Drawing.Graphics]::FromImage($sheet); $sg.Clear($dark); $sg.InterpolationMode = 'NearestNeighbor'
    $y = 4
    $now = (Get-Date).ToUniversalTime()
    foreach ($t in $Themes.Values) {
        # (5h%, 7d%, 5h 남은분, 7d 남은분) — 2:21/5h·1/7d 와 0:40/5h·23h/7d 두 경우
        foreach ($p in @(@(38, 72, 141, 1620), @(91, 12, 40, 1380))) {
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
[void]$menu.Items.Add('종료', $null, { $form.Close() }.GetNewClosure())
$form.ContextMenuStrip = $menu; $pic.ContextMenuStrip = $menu

$poll = New-Object Windows.Forms.Timer;  $poll.Interval = $PollSec * 1000;   $poll.Add_Tick({ Update-Widget }.GetNewClosure())
$place = New-Object Windows.Forms.Timer; $place.Interval = $PlaceSec * 1000; $place.Add_Tick({ Set-Placement }.GetNewClosure())

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
    $poll.Start(); $place.Start()
}.GetNewClosure())
[Windows.Forms.Application]::Run($form)
