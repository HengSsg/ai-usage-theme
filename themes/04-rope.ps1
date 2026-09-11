# 테마: 밧줄 (픽셀) — 쓸수록 가운데가 너덜너덜해지고 100% 에 끊어진다. 가는 줄 = 5h, 굵은 줄 = 7d
@{
    Id = 'rope'; Name = '밧줄'; Width = 272
    Draw = {
        param($g, $d, $w, $h)
        Use-PixelMode $g
        $bands = @(
            @{ Y = 0;  L = $d.L5; S = $d.S5; C = $d.C5; T = 2 },
            @{ Y = 12; L = $d.L7; S = $d.S7; C = $d.C7; T = 3 }
        )
        foreach ($b in $bands) {
            $y0 = $b.Y; $p = $b.S; $t = $b.T
            Draw-PixelText $g $b.L 0 ($y0 + 3) $Col.Label
            Px-Fill $g $Px.Brown 30 ($y0 + 1) 2 10                      # 왼쪽 기둥
            Px-Fill $g $Px.Brown 116 ($y0 + 1) 2 10                     # 오른쪽 기둥
            $x1 = 32; $x2 = 115; $ry = $y0 + 5; $mid = 74
            $cA = if ($p -ge 75) { $Px.Orange } else { $Px.Wood }; $cB = $Px.Brown
            if ($p -ge 100) {
                # 끊어짐 — 가운데 8셀이 비고 양쪽 끝이 늘어진다
                for ($x = $x1; $x -le $mid - 5; $x++) {
                    $dy = [Math]::Max(0, [Math]::Min(3, $x - ($mid - 10)))
                    Px-Fill $g $(if ([int](($x - $x1) / 2) % 2 -eq 0) { $cA } else { $cB }) $x ($ry + $dy) 1 $t
                }
                for ($x = $mid + 5; $x -le $x2; $x++) {
                    $dy = [Math]::Max(0, [Math]::Min(3, ($mid + 10) - $x))
                    Px-Fill $g $(if ([int](($x - $x1) / 2) % 2 -eq 0) { $cA } else { $cB }) $x ($ry + $dy) 1 $t
                }
                # 풀린 끝 가닥
                Px-Fill $g $cB ($mid - 4) ($ry + 2) 1 1; Px-Fill $g $cB ($mid - 3) ($ry + 4) 1 1
                Px-Fill $g $cB ($mid + 4) ($ry + 2) 1 1; Px-Fill $g $cB ($mid + 3) ($ry + 4) 1 1
            } else {
                for ($x = $x1; $x -le $x2; $x++) {
                    $c = if ([int](($x - $x1) / 2) % 2 -eq 0) { $cA } else { $cB }   # 꼬임 무늬
                    $dist = [Math]::Abs($x - $mid); $thick = $t; $yy = $ry
                    if ($p -ge 50 -and $dist -le 5) { $thick = [Math]::Max(1, $t - 1); $yy = $ry + 1 }   # 가운데가 가늘어짐
                    if ($p -ge 75 -and $dist -le 8) { $thick = 1; $yy = $ry + 1 }                         # 한 가닥에 매달림
                    Px-Fill $g $c $x $yy 1 $thick
                }
                # 잔털 — 25% 부터 12% 마다 하나씩
                $n = [Math]::Max(0, [Math]::Min(6, [int][Math]::Floor(($p - 13) / 12)))
                $fib = @(@(-3, -1), @(4, 1), @(-7, 1), @(6, -1), @(-10, -1), @(9, 1))
                for ($i = 0; $i -lt $n; $i++) {
                    $fx = $mid + $fib[$i][0]; $up = $fib[$i][1]
                    $fy = if ($up -lt 0) { $ry - 1 } else { $ry + $t }
                    Px-Fill $g $cB $fx $fy 1 1; Px-Fill $g $cB ($fx + $up) ($fy + $up) 1 1
                }
            }
            Draw-PixelText $g "$p%" 121 ($y0 + 3) $b.C
        }
    }
}
