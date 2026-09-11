# 테마: 눈사람 (픽셀) — 쓸수록 녹아 작아지고 물웅덩이가 커진다. 100% 면 모자·당근·석탄만 남는다.
# 커피·양초와 같은 2행 열 정렬 (라벨 오른쪽 정렬 | 아이콘 | %).
@{
    Id = 'snowman'; Name = '눈사람'
    Width = { param($d) 2 * (46 + [Math]::Max((Measure-PixelText "$($d.S5)%"), (Measure-PixelText "$($d.S7)%"))) }
    Draw = {
        param($g, $d, $w, $h)
        Use-PixelMode $g
        # stage: 남은 한도 구간별 (머리 cy·r, 몸통 cy·r, 모자 행, 웅덩이 폭)
        $stages = @(
            @{ P = 0;  Hat = -1; HeadY = -1; HeadR = 0; BodyY = -1; BodyR = 0; Pool = 14 },
            @{ P = 1;  Hat = -1; HeadY = -1; HeadR = 0; BodyY = 9;  BodyR = 2; Pool = 11 },
            @{ P = 25; Hat = 4;  HeadY = 7;  HeadR = 2; BodyY = -1; BodyR = 0; Pool = 8 },
            @{ P = 50; Hat = 2;  HeadY = 5;  HeadR = 2; BodyY = 9;  BodyR = 2; Pool = 5 },
            @{ P = 75; Hat = 0;  HeadY = 3;  HeadR = 2; BodyY = 8;  BodyR = 3; Pool = 0 }
        )
        $rows = @(
            @{ Y = 0;  L = $d.L5; S = $d.S5; C = $d.C5 },
            @{ Y = 12; L = $d.L7; S = $d.S7; C = $d.C7 }
        )
        foreach ($r in $rows) {
            $y0 = $r.Y; $cx = 36; $rem = 100 - $r.S
            Draw-PixelText $g $r.L (28 - (Measure-PixelText $r.L)) ($y0 + 3) $Col.Label
            $st = $stages[0]
            foreach ($s in $stages) { if ($rem -ge $s.P) { $st = $s } }   # 마지막으로 통과한 구간

            if ($st.Pool -gt 0) { Px-Fill $g $Px.Sky ($cx - [int]($st.Pool / 2)) ($y0 + 11) $st.Pool 1 }
            if ($st.BodyR -gt 0) { Px-Circle $g $Px.White $cx ($y0 + $st.BodyY) $st.BodyR }
            if ($st.HeadR -gt 0) {
                Px-Circle $g $Px.White $cx ($y0 + $st.HeadY) $st.HeadR
                $hy = $y0 + $st.HeadY
                Px-Fill $g $Px.Ink ($cx - 1) $hy 1 1; Px-Fill $g $Px.Ink ($cx + 1) $hy 1 1      # 눈
                Px-Fill $g $Px.Orange ($cx + 2) ($hy + 1) 2 1                                    # 당근
            }
            if ($st.Hat -ge 0) {
                Px-Fill $g $Px.Ink ($cx - 2) ($y0 + $st.Hat + 1) 5 1
                Px-Fill $g $Px.Ink ($cx - 1) ($y0 + $st.Hat) 3 1
            }
            if ($st.BodyR -ge 3) {
                Px-Fill $g $Px.Brown ($cx - 6) ($y0 + $st.BodyY - 1) 3 1                         # 팔
                Px-Fill $g $Px.Brown ($cx + 4) ($y0 + $st.BodyY - 1) 3 1
                Px-Fill $g $Px.Ink $cx ($y0 + $st.BodyY) 1 1                                     # 단추
            }
            if ($rem -le 0) {                                                                    # 다 녹음 — 유품만
                Px-Fill $g $Px.Ink ($cx - 4) ($y0 + 10) 5 1; Px-Fill $g $Px.Ink ($cx - 3) ($y0 + 9) 3 1
                Px-Fill $g $Px.Orange ($cx + 2) ($y0 + 10) 3 1
                Px-Fill $g $Px.Ink ($cx + 6) ($y0 + 10) 1 1
            }
            Draw-PixelText $g "$($r.S)%" 45 ($y0 + 3) $r.C
        }
    }
}
