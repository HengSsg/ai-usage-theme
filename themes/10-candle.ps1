# 테마: 양초 (픽셀) — 남은 한도만큼 초가 남아 있고 불꽃이 분마다 깜빡. 다 타면 심지에서 연기만
@{
    Id = 'candle'; Name = '양초'; Width = 128
    Draw = {
        param($g, $d, $w, $h)
        Use-PixelMode $g
        $blink = (Get-Date).Minute % 2
        $flames = @(@('.#.', '.##', '###', '.#.'), @('.#.', '##.', '###', '.#.'))
        $cells = @(
            @{ X = 0;  L = $d.L5; S = $d.S5; C = $d.C5; Max = 8 },
            @{ X = 32; L = $d.L7; S = $d.S7; C = $d.C7; Max = 10 }
        )
        foreach ($c in $cells) {
            $x = $c.X + 5; $r = 100 - $c.S
            Px-Fill $g $Px.Brown ($x - 2) 15 10 1; Px-Fill $g $Px.Brown ($x - 1) 16 8 2                # 촛대
            $hgt = 1 + [int][Math]::Floor(($c.Max - 1) * $r / 100 + 0.5)                                # 초 높이 1~Max
            $top = 15 - $hgt
            Px-Fill $g $Px.Cream $x $top 6 $hgt
            Px-Fill $g $Px.White ($x + 1) $top 1 $hgt                                                   # 하이라이트
            if ($r -lt 60) { Px-Fill $g $Px.Cream ($x - 1) ($top + 1) 1 3; Px-Fill $g $Px.Cream ($x + 6) ($top + 2) 1 2 }   # 흘러내린 촛농
            Px-Fill $g $Px.Ink ($x + 2) ($top - 1) 2 1                                                  # 심지
            if ($r -gt 0) {
                Draw-Sprite $g $flames[$blink] ($x + 1) ($top - 5) @{ '#' = $Px.Orange }
                Px-Fill $g $Px.Yellow ($x + 2) ($top - 3) 2 2                                           # 불꽃 속
            } else {
                for ($i = 0; $i -lt 5; $i++) { Px-Fill $g $Px.Gray ($x + 2 + (($i + $blink) % 2)) ($top - 3 - $i * 2) 1 1 }   # 연기
            }
            Draw-PixelText $g "$($c.S)%" ($c.X + 16) 6 $c.C
            Draw-PixelText $g $c.L $c.X 18 $Col.Label
        }
    }
}
