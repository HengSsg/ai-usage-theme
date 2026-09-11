# 테마: 젠가 (픽셀) — 6층 x 3블록. 쓸수록 블록이 빠지고 70% 부터 기울다가 100% 에 와르르
@{
    Id = 'jenga'; Name = '젠가'; Width = 132
    Draw = {
        param($g, $d, $w, $h)
        Use-PixelMode $g
        # 빼는 순서 (층, 블록) — 층 0 = 바닥. 위층 가운데부터 빠져 점점 불안해 보이게
        $order = @(@(4, 1), @(3, 1), @(5, 0), @(2, 1), @(4, 2), @(3, 0), @(1, 1), @(5, 2), @(2, 0), @(4, 0), @(3, 2), @(1, 0), @(2, 2), @(0, 1), @(5, 1), @(1, 2), @(0, 0), @(0, 2))
        $cells = @(
            @{ X = 0;  L = $d.L5; S = $d.S5; C = $d.C5 },
            @{ X = 32; L = $d.L7; S = $d.S7; C = $d.C7 }
        )
        foreach ($c in $cells) {
            $p = $c.S; $bx = $c.X + 3
            if ($p -ge 100) {
                # 와르르 — 바닥에 흩어진 블록 (x, y, 폭)
                foreach ($f in @(@(0, 16, 4), @(5, 16, 4), @(10, 16, 4), @(2, 14, 4), @(8, 14, 4), @(13, 15, 3), @(5, 12, 4))) {
                    Px-Fill $g $(if ($f[0] % 2 -eq 0) { $Px.Wood } else { $Px.Sand }) ($bx + $f[0]) $f[1] $f[2] 2
                }
            } else {
                $gone = [int][Math]::Floor(18 * $p / 100 + 0.5)
                $removed = @{}
                for ($i = 0; $i -lt $gone; $i++) { $removed["$($order[$i][0]),$($order[$i][1])"] = $true }
                $lean = if ($p -ge 70) { 1 } else { 0 }
                for ($layer = 0; $layer -lt 6; $layer++) {
                    $y = 15 - $layer * 3
                    $shift = if ($layer -ge 3) { $lean } else { 0 }
                    for ($k = 0; $k -lt 3; $k++) {
                        if ($removed["$layer,$k"]) { continue }
                        # 변수명은 대소문자 무시 — `$col` 로 쓰면 팔레트 `$Col` 을 가려 라벨 색이 null 이 된다
                        $blk = if (($layer + $k) % 2 -eq 0) { $Px.Wood } else { $Px.Sand }
                        Px-Fill $g $blk ($bx + $shift + $k * 4) $y 4 3
                        Px-Fill $g $Px.Brown ($bx + $shift + $k * 4 + 3) $y 1 3      # 블록 경계선
                    }
                }
            }
            Draw-PixelText $g "$p%" ($c.X + 17) 6 $c.C
            Draw-PixelText $g $c.L $c.X 18 $Col.Label
        }
    }
}
