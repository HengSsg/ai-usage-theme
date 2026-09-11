# 테마: 자동차 (애니메이션) — 승용차 = 5시간, 화물차 = 7일. 결승 깃발까지 달린다.
# 차의 '위치'가 사용률이고, 차선 스크롤·바퀴 회전·상하 진동·배기로 '달리는 중'을 표현한다.
#
# ⚠️ 애니메이션 비용 — 매 프레임 전부 벡터로 그리면 6.8ms/frame 이라 8fps 에서 CPU 8% 를 먹었다(실측).
# 비싼 건 DrawImage 가 아니라(0.04ms) 호출마다 GraphicsPath+Arc 를 만드는 Fill-RoundRect 다.
# → 도로·깃발·라벨·%(정적), 차선 띠, 차량 4프레임을 전부 **미리 구워 두고** 프레임마다 붙이기만 한다.
@{
    # 프레임 간격 120ms. 150ms 로 낮춰도 CPU 가 안 떨어진다(고정 재합성 비용이 지배적) — 같은 값이면 부드러운 쪽.
    Id = 'cars'; Name = '자동차 (움직임)'; Width = 260; Anim = 120
    Draw = {
        param($g, $d, $w, $h)

        # ── 정적 레이어: 도로·결승깃발·라벨·% (값이 바뀔 때만) ──
        $bgKey = "$w|$h|$($d.BG.ToArgb())|$($d.L5)|$($d.L7)|$($d.S5)|$($d.S7)"
        if ($script:carsKey -ne $bgKey) {
            if ($script:carsBg) { $script:carsBg.Dispose() }
            $script:carsBg = New-Object Drawing.Bitmap $w, $h
            $bg = [Drawing.Graphics]::FromImage($script:carsBg)
            $bg.SmoothingMode = 'AntiAlias'; $bg.TextRenderingHint = 'ClearTypeGridFit'
            $bg.Clear($d.BG)
            Fill-RoundRect $bg $Col.Road 0 2 254 44 4
            $bl = New-Object Drawing.SolidBrush $Col.Light
            $bd = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(30, 30, 30))
            for ($row = 0; $row -lt 10; $row++) {                       # 결승 깃발
                for ($c = 0; $c -lt 2; $c++) {
                    $br = if (($row + $c) % 2 -eq 0) { $bl } else { $bd }
                    $bg.FillRectangle($br, 244 + $c * 4, 4 + $row * 4, 4, 4)
                }
            }
            $bl.Dispose(); $bd.Dispose()
            Draw-Text $bg $d.L5 9 $true $Col.Dim 4 13
            Draw-Text $bg $d.L7 9 $true $Col.Dim 4 35
            # 오른쪽 정렬 — 100% 처럼 자릿수가 늘어도 도로 쪽으로 번지지 않는다
            Draw-Text $bg "$($d.S5)%" 10 $true $d.C5 70 13 'Far'
            Draw-Text $bg "$($d.S7)%" 10 $true $d.C7 70 35 'Far'
            $bg.Dispose()

            if ($script:carsDash) { $script:carsDash.Dispose() }         # 차선 띠 (주기 13px, 한 주기 여유)
            $script:carsDash = New-Object Drawing.Bitmap 181, 2
            $dg = [Drawing.Graphics]::FromImage($script:carsDash)
            $db = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(90, 90, 90))
            for ($x = 0; $x -lt 181; $x += 13) { $dg.FillRectangle($db, $x, 0, 7, 2) }
            $db.Dispose(); $dg.Dispose()
            $script:carsKey = $bgKey
        }

        # ── 차량 스프라이트 4프레임 (바퀴 각도·배기 위치가 다르다). 색이 바뀔 때만 다시 굽는다 ──
        $sprKey = "$($d.C5.ToArgb())|$($d.C7.ToArgb())"
        if ($script:carsSprKey -ne $sprKey) {
            foreach ($old in @($script:carsCar) + @($script:carsTruck)) { if ($old) { $old.Dispose() } }
            $script:carsCar = @(); $script:carsTruck = @()
            $win  = [Drawing.Color]::FromArgb(140, 26, 26, 26)
            $tire = [Drawing.Color]::FromArgb(17, 17, 17)
            $hub  = [Drawing.Color]::FromArgb(136, 136, 136)
            for ($fi = 0; $fi -lt 4; $fi++) {
                $ang = $fi * [Math]::PI / 2
                $wx = 1.7 * [Math]::Cos($ang); $wy = 1.7 * [Math]::Sin($ang)
                $ex = 6 - ($fi % 3) * 2                                  # 배기 — 뒤로 흘러간다
                $lamp = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, 248, 192))
                $puff = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(90, 150, 150, 150))

                $cb = New-Object Drawing.Bitmap 40, 24                   # 승용차 (차체 local x=12)
                $cg = [Drawing.Graphics]::FromImage($cb); $cg.SmoothingMode = 'AntiAlias'
                $cg.FillEllipse($puff, $ex, (11 - ($fi % 3)), 4, 4)
                Fill-RoundRect $cg $d.C5 18 4 13 6 2                     # 지붕
                Fill-RoundRect $cg $d.C5 12 9 26 8 2                     # 차체
                Fill-RoundRect $cg $win 20 5 9 4 1                       # 창
                $cg.FillRectangle($lamp, 36, 11, 2, 3)                   # 전조등
                foreach ($cx in 18, 32) {
                    Fill-Circle $cg $tire $cx 18 2.8; Fill-Circle $cg $hub $cx 18 1.1
                    Fill-Circle $cg $hub ($cx + $wx) (18 + $wy) 0.6      # 스포크 — 회전해 보이게
                }
                $cg.Dispose(); $script:carsCar += $cb

                $tb = New-Object Drawing.Bitmap 48, 22                   # 화물차 (local y = 원좌표 - 26)
                $tg = [Drawing.Graphics]::FromImage($tb); $tg.SmoothingMode = 'AntiAlias'
                $tg.FillEllipse($puff, $ex, (8 - ($fi % 3)), 4, 4)
                Fill-RoundRect $tg $d.C7 12 1 22 13 1.5                  # 적재함
                Fill-RoundRect $tg $d.C7 35 5 11 9 2                     # 운전석
                Fill-RoundRect $tg $win 39 6.5 5.5 4 1                   # 창
                $tg.FillRectangle($lamp, 45, 9, 1.5, 3)
                foreach ($cx in 17, 26, 41) {
                    Fill-Circle $tg $tire $cx 15 2.8; Fill-Circle $tg $hub $cx 15 1.1
                    Fill-Circle $tg $hub ($cx + $wx) (15 + $wy) 0.6
                }
                $tg.Dispose(); $script:carsTruck += $tb
                $lamp.Dispose(); $puff.Dispose()
            }
            $script:carsSprKey = $sprKey
        }

        # ── 프레임 합성: 붙이기 4번이 전부 ──
        $f = [int]$d.F
        $g.DrawImageUnscaled($script:carsBg, 0, 0)
        $off = ($f * 3) % 13                                             # 차선이 뒤로 흘러 달리는 느낌
        $g.DrawImage($script:carsDash, (New-Object Drawing.Rectangle 74, 23, 168, 2), $off, 0, 168, 2, [Drawing.GraphicsUnit]::Pixel)
        $bob = @(0, 0, 1, 1)[$f % 4]                                     # 노면 진동
        $g.DrawImageUnscaled($script:carsCar[$f % 4],   ([int](76 + 138 * $d.S5 / 100) - 12), $bob)
        $g.DrawImageUnscaled($script:carsTruck[$f % 4], ([int](76 + 130 * $d.S7 / 100) - 12), (26 + $bob))
    }
}
