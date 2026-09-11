# 테마: 자동차 — 승용차 = 5시간, 화물차 = 7일. 결승 깃발(오른쪽)까지 달린다. 차선 앞에 [남은시간/창].
@{
    Id = 'cars'; Name = '자동차'; Width = 260
    Draw = {
        param($g, $d, $w, $h)
        # 도로 + 차선 (주행 구간 66~240, 그 앞은 라벨·% 자리)
        Fill-RoundRect $g $Col.Road 0 2 254 44 4
        $pen = New-Object Drawing.Pen ([Drawing.Color]::FromArgb(90, 90, 90)), 1.5
        $pen.DashPattern = [float[]]@(4.67, 4)      # 7px 선 / 6px 공백 (펜 폭 단위)
        $g.DrawLine($pen, [float]74, [float]24, [float]242, [float]24); $pen.Dispose()
        # 결승 깃발 — 4px 체크무늬 2열 x 10행
        $bl = New-Object Drawing.SolidBrush $Col.Light
        $bd = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(30, 30, 30))
        for ($row = 0; $row -lt 10; $row++) {
            for ($c = 0; $c -lt 2; $c++) {
                $br = if (($row + $c) % 2 -eq 0) { $bl } else { $bd }
                $g.FillRectangle($br, 244 + $c * 4, 4 + $row * 4, 4, 4)
            }
        }
        $bl.Dispose(); $bd.Dispose()
        Draw-Text $g $d.L5 9 $true $Col.Dim 4 13
        Draw-Text $g $d.L7 9 $true $Col.Dim 4 35
        # 오른쪽 정렬 — 100% 처럼 자릿수가 늘어도 도로 쪽으로 번지지 않는다(왼쪽 라벨과는 여백 확보)
        Draw-Text $g "$($d.S5)%" 10 $true $d.C5 70 13 'Far'
        Draw-Text $g "$($d.S7)%" 10 $true $d.C7 70 35 'Far'

        $win  = [Drawing.Color]::FromArgb(140, 26, 26, 26)
        $tire = [Drawing.Color]::FromArgb(17, 17, 17)
        $hub  = [Drawing.Color]::FromArgb(136, 136, 136)
        $lamp = New-Object Drawing.SolidBrush ([Drawing.Color]::FromArgb(255, 248, 192))

        # 승용차 (위 차선) — 폭 26
        $g.TranslateTransform([float](76 + 138 * $d.S5 / 100), [float]0)
        Fill-RoundRect $g $d.C5 6 4 13 6 2          # 지붕
        Fill-RoundRect $g $d.C5 0 9 26 8 2          # 차체
        Fill-RoundRect $g $win 8 5 9 4 1            # 창
        $g.FillRectangle($lamp, 24, 11, 2, 3)       # 전조등
        foreach ($cx in 6, 20) { Fill-Circle $g $tire $cx 18 2.8; Fill-Circle $g $hub $cx 18 1.1 }
        $g.ResetTransform()

        # 화물차 (아래 차선) — 폭 34
        $g.TranslateTransform([float](76 + 130 * $d.S7 / 100), [float]0)
        Fill-RoundRect $g $d.C7 0 27 22 13 1.5      # 적재함
        Fill-RoundRect $g $d.C7 23 31 11 9 2        # 운전석
        Fill-RoundRect $g $win 27 32.5 5.5 4 1      # 창
        $g.FillRectangle($lamp, 33, 35, 1.5, 3)
        foreach ($cx in 5, 14, 29) { Fill-Circle $g $tire $cx 41 2.8; Fill-Circle $g $hub $cx 41 1.1 }
        $g.ResetTransform()
        $lamp.Dispose()
    }
}
