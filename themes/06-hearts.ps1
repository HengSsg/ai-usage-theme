# 테마: 하트 HP (픽셀) — 하트 10개 = 남은 한도, 10% 마다 하나씩 비어간다
@{
    Id = 'hearts'; Name = '하트 HP'; Width = 252
    Draw = {
        param($g, $d, $w, $h)
        Use-PixelMode $g
        $heart = @('.##.##.', '#######', '#######', '.#####.', '..###..', '...#...')
        $bands = @(
            @{ Y = 0;  L = $d.L5; S = $d.S5; C = $d.C5 },
            @{ Y = 12; L = $d.L7; S = $d.S7; C = $d.C7 }
        )
        foreach ($b in $bands) {
            $y0 = $b.Y
            Draw-PixelText $g $b.L 0 ($y0 + 3) $Col.Label
            $full = [int][Math]::Floor((100 - $b.S) / 10 + 0.5)          # 남은 하트 수
            for ($i = 0; $i -lt 10; $i++) {
                $pal = if ($i -lt $full) { @{ '#' = $Px.Red } } else { @{ '#' = $Px.Dark } }
                Draw-Sprite $g $heart (30 + $i * 8) ($y0 + 3) $pal
            }
            Draw-PixelText $g "$($b.S)%" 111 ($y0 + 3) $b.C
        }
    }
}
