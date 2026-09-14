# 테마: 모래시계 (픽셀) — 위 전구 모래 = 남은 한도, 아래 = 쓴 양. 흐르는 중이면 목에서 모래가 떨어진다.
# 커피·양초와 같은 2행 열 정렬 (라벨 오른쪽 정렬 | 아이콘 | %).
@{
    Id = 'hourglass'; Name = '모래시계'
    Desc = '픽셀 — 위쪽 모래가 남은 한도, 아래쪽이 이미 쓴 양.'
    Width = { param($d) 2 * (46 + [Math]::Max((Measure-PixelText "$($d.S5)%"), (Measure-PixelText "$($d.S7)%"))) }
    Draw = {
        param($g, $d, $w, $h)
        Use-PixelMode $g
        $blink = (Get-Date).Minute % 2
        # 테두리만 — 속이 찬 스프라이트를 쓰면 모래를 덮어버려 통나무처럼 보인다
        $frame = @('#########', '.#.....#.', '.#.....#.', '..#...#..', '...#.#...', '....#....',
                   '...#.#...', '..#...#..', '.#.....#.', '.#.....#.', '#########')
        # 행별 안쪽 (시작x, 폭). 위 전구는 아래(4)부터, 아래 전구는 아래(9)부터 채운다
        $inner = @{ 1 = @(2, 5); 2 = @(2, 5); 3 = @(3, 3); 4 = @(4, 1)
                    6 = @(4, 1); 7 = @(3, 3); 8 = @(2, 5); 9 = @(2, 5) }
        $rows = @(
            @{ Y = 0;  L = $d.L5; S = $d.S5; C = $d.C5 },
            @{ Y = 12; L = $d.L7; S = $d.S7; C = $d.C7 }
        )
        foreach ($r in $rows) {
            $y0 = $r.Y; $x = 31; $rem = 100 - $r.S
            Draw-PixelText $g $r.L (28 - (Measure-PixelText $r.L)) ($y0 + 3) $Col.Label
            $topRows = [int][Math]::Floor(4 * $rem / 100 + 0.5); $botRows = 4 - $topRows
            for ($i = 0; $i -lt $topRows; $i++) { $row = 4 - $i;  Px-Fill $g $Px.Sand ($x + $inner[$row][0]) ($y0 + $row) $inner[$row][1] 1 }
            for ($i = 0; $i -lt $botRows; $i++) { $row = 9 - $i;  Px-Fill $g $Px.Sand ($x + $inner[$row][0]) ($y0 + $row) $inner[$row][1] 1 }
            if ($topRows -gt 0 -and $botRows -gt 0) { Px-Fill $g $Px.Sand ($x + 4) ($y0 + 5 + $blink) 1 1 }   # 떨어지는 모래
            Draw-Sprite $g $frame $x $y0 @{ '#' = $Px.Wood }
            Draw-PixelText $g "$($r.S)%" 45 ($y0 + 3) $r.C
        }
    }
}
