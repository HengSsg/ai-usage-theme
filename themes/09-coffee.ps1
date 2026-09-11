# 테마: 커피 (픽셀) — 잔 속 커피 = 남은 한도. 에스프레소(작은 잔) = 5h, 머그 = 7d. 가득하면 김이 난다
@{
    Id = 'coffee'; Name = '커피'; Width = 136
    Draw = {
        param($g, $d, $w, $h)
        Use-PixelMode $g
        $blink = (Get-Date).Minute % 2
        # X, 잔 왼쪽(CX), 잔 윗행(Top), 폭(W), 높이(H)
        $cups = @(
            @{ X = 0;  L = $d.L5; S = $d.S5; C = $d.C5; CX = 3; Top = 7; W = 9;  H = 9 },
            @{ X = 34; L = $d.L7; S = $d.S7; C = $d.C7; CX = 2; Top = 4; W = 11; H = 12 }
        )
        foreach ($c in $cups) {
            $x = $c.X + $c.CX; $top = $c.Top; $cw = $c.W; $ch = $c.H; $bot = $top + $ch - 1
            Px-Fill $g $Px.White $x $top $cw $ch                                                         # 잔
            Px-Fill $g $Px.Gray $x $bot 1 1; Px-Fill $g $Px.Gray ($x + $cw - 1) $bot 1 1                # 바닥 모서리
            Px-Fill $g $Px.White ($x + $cw) ($top + 2) 2 1                                               # 손잡이
            Px-Fill $g $Px.White ($x + $cw + 1) ($top + 3) 1 ($ch - 6)
            Px-Fill $g $Px.White ($x + $cw) ($bot - 3) 2 1
            Px-Fill $g $Px.Gray ($x - 1) ($bot + 1) ($cw + 2) 1                                          # 받침
            $r = 100 - $c.S; $inner = $ch - 2
            $fill = [int][Math]::Floor($inner * $r / 100 + 0.5)
            if ($fill -gt 0) { Px-Fill $g $Px.Coffee ($x + 1) ($bot - $fill) ($cw - 2) $fill }           # 커피
            if ($r -ge 60) {                                                                             # 김 (분마다 흔들림)
                foreach ($sx in ($x + 2), ($x + $cw - 3)) {
                    for ($i = 0; $i -lt 4; $i++) { Px-Fill $g $Px.Gray ($sx + (($i + $blink) % 2)) ($top - 2 - $i) 1 1 }
                }
            }
            if ($r -le 0) { Px-Fill $g $Px.Coffee ($x + 2) ($bot - 1) 2 1 }                              # 바닥에 남은 얼룩
            Draw-PixelText $g "$($c.S)%" ($c.X + 18) 6 $c.C
            Draw-PixelText $g $c.L $c.X 18 $Col.Label
        }
    }
}
