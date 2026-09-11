# 테마: 모래시계 (픽셀) — 위 전구 모래 = 남은 한도, 아래 = 쓴 양. 흐르는 중이면 목에서 모래가 떨어진다
@{
    Id = 'hourglass'; Name = '모래시계'; Width = 120
    Draw = {
        param($g, $d, $w, $h)
        Use-PixelMode $g
        $blink = (Get-Date).Minute % 2
        $frame = @('###########', '.#.......#.', '.#.......#.', '.#.......#.', '.#.......#.', '..#.....#..', '...#...#...', '....#.#....',
                   '.....#.....', '....#.#....', '...#...#...', '..#.....#..', '.#.......#.', '.#.......#.', '.#.......#.', '.#.......#.', '###########')
        # 행별 안쪽 (시작x, 폭) — 위 전구 1~7행, 아래 전구 9~15행
        $inner = @{ 1 = @(2, 7); 2 = @(2, 7); 3 = @(2, 7); 4 = @(2, 7); 5 = @(3, 5); 6 = @(4, 3); 7 = @(5, 1)
                    9 = @(5, 1); 10 = @(4, 3); 11 = @(3, 5); 12 = @(2, 7); 13 = @(2, 7); 14 = @(2, 7); 15 = @(2, 7) }
        $cells = @(
            @{ X = 0;  L = $d.L5; S = $d.S5; C = $d.C5 },
            @{ X = 30; L = $d.L7; S = $d.S7; C = $d.C7 }
        )
        foreach ($c in $cells) {
            $x = $c.X + 2; $r = 100 - $c.S
            $topRows = [int][Math]::Floor(7 * $r / 100 + 0.5); $botRows = 7 - $topRows
            for ($i = 0; $i -lt $topRows; $i++) { $row = 7 - $i;  Px-Fill $g $Px.Sand ($x + $inner[$row][0]) $row $inner[$row][1] 1 }
            for ($i = 0; $i -lt $botRows; $i++) { $row = 15 - $i; Px-Fill $g $Px.Sand ($x + $inner[$row][0]) $row $inner[$row][1] 1 }
            if ($topRows -gt 0 -and $botRows -gt 0) { Px-Fill $g $Px.Sand ($x + 5) (8 + $blink) 1 1 }    # 떨어지는 모래
            Draw-Sprite $g $frame $x 0 @{ '#' = $Px.Wood }
            Draw-PixelText $g "$($c.S)%" ($c.X + 15) 6 $c.C
            Draw-PixelText $g $c.L $c.X 18 $Col.Label
        }
    }
}
