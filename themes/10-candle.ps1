# 테마: 양초 (픽셀) — 남은 한도만큼 초가 남고 불꽃이 분마다 깜빡. 다 타면 심지에서 연기만.
# 라벨/초/% 를 열로 정렬한 2행 구조 (커피와 동일 — 한 칸에 겹치면 48px 에서 안 읽힌다).
@{
    Id = 'candle'; Name = '양초'
    Desc = '픽셀 — 남은 한도만큼 초가 남는다. 다 타면 심지에서 연기만 난다.'
    Width = { param($d) 2 * (46 + [Math]::Max((Measure-PixelText "$($d.S5)%"), (Measure-PixelText "$($d.S7)%"))) }
    Draw = {
        param($g, $d, $w, $h)
        Use-PixelMode $g
        $blink = (Get-Date).Minute % 2
        $flames = @(@('.#.', '###'), @('.#.', '.##'))
        $rows = @(
            @{ Y = 0;  L = $d.L5; S = $d.S5; C = $d.C5 },
            @{ Y = 12; L = $d.L7; S = $d.S7; C = $d.C7 }
        )
        foreach ($r in $rows) {
            $y0 = $r.Y; $x = 33; $rem = 100 - $r.S
            Draw-PixelText $g $r.L (28 - (Measure-PixelText $r.L)) ($y0 + 3) $Col.Label
            Px-Fill $g $Px.Brown 31 ($y0 + 10) 10 1                        # 촛대
            Px-Fill $g $Px.Brown 32 ($y0 + 11) 8 1
            $hgt = 1 + [int][Math]::Floor(5 * $rem / 100 + 0.5)             # 초 높이 1~6
            $top = $y0 + 10 - $hgt
            Px-Fill $g $Px.Cream $x $top 6 $hgt
            Px-Fill $g $Px.White ($x + 1) $top 1 $hgt                       # 하이라이트
            if ($rem -lt 60 -and $hgt -ge 3) { Px-Fill $g $Px.Cream ($x - 1) ($top + 1) 1 2 }   # 흘러내린 촛농
            if ($rem -gt 0) {
                Draw-Sprite $g $flames[$blink] ($x + 1) ($top - 3) @{ '#' = $Px.Orange }
                Px-Fill $g $Px.Yellow ($x + 2) ($top - 2) 2 1               # 불꽃 속
            } else {
                Px-Fill $g $Px.Ink ($x + 2) ($top - 1) 2 1                  # 다 탄 심지
                for ($i = 0; $i -lt 3; $i++) { Px-Fill $g $Px.Gray ($x + 2 + (($i + $blink) % 2)) ($top - 2 - $i) 1 1 }
            }
            Draw-PixelText $g "$($r.S)%" 45 ($y0 + 3) $r.C
        }
    }
}
