# 테마: 눈사람 (픽셀) — 쓸수록 녹아서 물웅덩이가 커지고, 100% 면 모자·당근·석탄만 남는다
@{
    Id = 'snowman'; Name = '눈사람'; Width = 128
    Draw = {
        param($g, $d, $w, $h)
        Use-PixelMode $g
        $cells = @(
            @{ X = 0;  L = $d.L5; S = $d.S5; C = $d.C5 },
            @{ X = 32; L = $d.L7; S = $d.S7; C = $d.C7 }
        )
        foreach ($c in $cells) {
            $r = 100 - $c.S; $cx = $c.X + 9
            $stage = if ($r -ge 75) { 4 } elseif ($r -ge 50) { 3 } elseif ($r -ge 25) { 2 } elseif ($r -gt 0) { 1 } else { 0 }
            $pw = @(18, 16, 14, 10, 0)[$stage]                                                          # 물웅덩이 폭
            if ($pw -gt 0) { Px-Fill $g $Px.Sky ($cx - [int]($pw / 2)) 16 $pw 2 }
            $hy = 0   # 당근(코) 행 — 눈은 그 위, 입은 그 아래
            switch ($stage) {
                4 { Px-Circle $g $Px.White $cx 14 3; Px-Circle $g $Px.White $cx 8 3; Px-Circle $g $Px.White $cx 3 2
                    Px-Fill $g $Px.Ink ($cx - 2) 1 5 1; Px-Fill $g $Px.Ink ($cx - 1) 0 3 1                     # 모자
                    Px-Fill $g $Px.Brown ($cx - 6) 8 3 1; Px-Fill $g $Px.Brown ($cx + 4) 8 3 1                 # 팔
                    Px-Fill $g $Px.Ink $cx 8 1 1; Px-Fill $g $Px.Ink $cx 10 1 1                                 # 단추
                    $hy = 3 }
                3 { Px-Circle $g $Px.White $cx 14 3; Px-Circle $g $Px.White $cx 9 2; Px-Circle $g $Px.White $cx 5 2
                    Px-Fill $g $Px.Ink ($cx - 2) 3 5 1; Px-Fill $g $Px.Ink ($cx - 1) 2 3 1
                    Px-Fill $g $Px.Brown ($cx - 5) 9 3 1; Px-Fill $g $Px.Brown ($cx + 3) 9 2 1
                    Px-Fill $g $Px.Ink $cx 9 1 1
                    $hy = 5 }
                2 { Px-Circle $g $Px.White $cx 14 3; Px-Circle $g $Px.White $cx 9 2
                    Px-Fill $g $Px.Ink ($cx - 1) 6 4 1                                                          # 기울어진 모자
                    $hy = 9 }
                1 { Px-Circle $g $Px.White $cx 14 2
                    Px-Fill $g $Px.Ink ($cx - 3) 11 4 1
                    $hy = 14 }
                0 { Px-Fill $g $Px.Ink ($cx - 3) 14 5 1; Px-Fill $g $Px.Orange ($cx + 3) 15 3 1               # 모자·당근
                    Px-Fill $g $Px.Ink ($cx - 5) 15 1 1; Px-Fill $g $Px.Ink ($cx - 1) 15 1 1 }                 # 석탄
            }
            if ($stage -gt 0) {
                Px-Fill $g $Px.Ink ($cx - 1) ($hy - 1) 1 1; Px-Fill $g $Px.Ink ($cx + 1) ($hy - 1) 1 1          # 눈
                Px-Fill $g $Px.Orange ($cx + 1) $hy 2 1                                                         # 당근
                if ($stage -ge 3) { Px-Fill $g $Px.Ink ($cx - 1) ($hy + 1) 3 1 }                                # 입
            }
            Draw-PixelText $g "$($c.S)%" ($c.X + 19) 6 $c.C
            Draw-PixelText $g $c.L $c.X 18 $Col.Label
        }
    }
}
