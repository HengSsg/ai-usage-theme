# 테마: 풍선 (픽셀) — 쓸수록 부풀어 오르고 100% 에 펑. 빨간 풍선 = 5h, 파란 풍선 = 7d
@{
    Id = 'balloon'; Name = '풍선'; Width = 140
    Draw = {
        param($g, $d, $w, $h)
        Use-PixelMode $g
        $cells = @(
            @{ X = 0;  L = $d.L5; S = $d.S5; C = $d.C5; Body = $Px.Red;  Hi = $Px.Pink },
            @{ X = 34; L = $d.L7; S = $d.S7; C = $d.C7; Body = $Px.Blue; Hi = $Px.Sky }
        )
        foreach ($c in $cells) {
            $cx = $c.X + 10; $cy = 9; $p = $c.S
            if ($p -ge 100) {
                # 펑 — 조각만 흩어지고 줄은 늘어짐
                foreach ($f in @(@(-6, -5), @(5, -6), @(-7, 2), @(7, 3), @(0, -8), @(-3, 6), @(4, 6), @(8, -2))) {
                    Px-Fill $g $c.Body ($cx + $f[0]) ($cy + $f[1]) 1 1
                }
                Px-Fill $g $Px.Gray $cx ($cy + 2) 1 8
            } else {
                $r = 2 + [int][Math]::Floor(6 * $p / 100)                 # 반지름 2~8
                Px-Circle $g $c.Body $cx $cy $r
                Px-Fill $g $c.Hi ($cx - [int]($r / 2)) ($cy - [int]($r / 2)) 1 1        # 하이라이트
                Px-Fill $g $c.Body ($cx - 1) ($cy + $r + 1) 3 1                          # 매듭
                for ($y = $cy + $r + 2; $y -le 17; $y++) { Px-Fill $g $Px.Gray ($cx + ($y % 2)) $y 1 1 }   # 줄
            }
            Draw-PixelText $g "$p%" ($c.X + 20) 6 $c.C
            Draw-PixelText $g $c.L $c.X 18 $Col.Label
        }
    }
}
