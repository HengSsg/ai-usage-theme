# 테마: 커피 (픽셀) — 잔 속 커피 = 남은 한도. 위 = 5시간(작은 잔), 아래 = 주간(머그). 남으면 김이 난다.
# 라벨/잔/% 를 열로 정렬한 2행 구조 — 아이콘·숫자·라벨을 한 칸에 겹쳐 놓으면 48px 에서 뭉쳐 안 읽힌다.
@{
    Id = 'coffee'; Name = '커피'
    Desc = '픽셀 — 잔에 남은 커피가 남은 한도. 작은 잔 = 5시간, 머그 = 7일.'
    # % 자릿수만큼만 차지한다 (한 자리면 104px, 100% 면 120px)
    Width = { param($d) 2 * (46 + [Math]::Max((Measure-PixelText "$($d.S5)%"), (Measure-PixelText "$($d.S7)%"))) }
    Draw = {
        param($g, $d, $w, $h)
        Use-PixelMode $g
        $blink = (Get-Date).Minute % 2
        $rows = @(
            @{ Y = 0;  L = $d.L5; S = $d.S5; C = $d.C5; W = 8 },
            @{ Y = 12; L = $d.L7; S = $d.S7; C = $d.C7; W = 10 }
        )
        foreach ($r in $rows) {
            $y0 = $r.Y; $cw = $r.W
            $x = 30 + [int]((12 - ($cw + 2)) / 2)      # 잔 폭이 달라도 아이콘 열 가운데
            $top = $y0 + 2; $bot = $y0 + 10
            Draw-PixelText $g $r.L (28 - (Measure-PixelText $r.L)) ($y0 + 3) $Col.Label   # 오른쪽 정렬
            Px-Fill $g $Px.White $x $top $cw 9                                            # 잔
            Px-Fill $g $Px.White ($x + $cw) ($top + 2) 2 1                                 # 손잡이
            Px-Fill $g $Px.White ($x + $cw + 1) ($top + 3) 1 2
            Px-Fill $g $Px.White ($x + $cw) ($top + 5) 2 1
            Px-Fill $g $Px.Gray ($x - 1) ($bot + 1) ($cw + 2) 1                            # 받침
            $rem = 100 - $r.S
            $fill = [int][Math]::Floor(7 * $rem / 100 + 0.5)
            if ($fill -gt 0) { Px-Fill $g $Px.Coffee ($x + 1) ($bot - $fill) ($cw - 2) $fill }
            if ($rem -ge 60) {                                                             # 김 (분마다 흔들림)
                foreach ($sx in ($x + 2), ($x + $cw - 3)) {
                    for ($i = 0; $i -lt 2; $i++) { Px-Fill $g $Px.Gray ($sx + (($i + $blink) % 2)) ($y0 + $i) 1 1 }
                }
            }
            if ($rem -le 0) { Px-Fill $g $Px.Coffee ($x + 2) ($bot - 1) 2 1 }               # 바닥 얼룩
            Draw-PixelText $g "$($r.S)%" 45 ($y0 + 3) $r.C
        }
    }
}
