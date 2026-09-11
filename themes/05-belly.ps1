# 테마: 배부름 (픽셀) — 배 크기·표정 = 5h 남은 양, 옆 밥그릇 = 7d 남은 양(이번 주 식량). 100% 쓰면 기절
@{
    Id = 'belly'; Name = '배부름'; Width = 136
    Draw = {
        param($g, $d, $w, $h)
        Use-PixelMode $g
        $r5 = 100 - $d.S5; $r7 = 100 - $d.S7
        $stage = if ($r5 -ge 75) { 4 } elseif ($r5 -ge 50) { 3 } elseif ($r5 -ge 25) { 2 } elseif ($r5 -gt 0) { 1 } else { 0 }
        if ($stage -gt 0) {
            $bw = @(0, 10, 12, 14, 16)[$stage]; $bx = 9 - [int]($bw / 2); $top = 3; $bot = 16
            for ($y = $top; $y -le $bot; $y++) {
                $in = if ($y -eq $top -or $y -eq $bot) { 2 } elseif ($y -eq $top + 1 -or $y -eq $bot - 1) { 1 } else { 0 }
                Px-Fill $g $Px.Cream ($bx + $in) $y ($bw - 2 * $in) 1
            }
            Px-Fill $g $Px.Cream ($bx + 1) ($top - 2) 2 2; Px-Fill $g $Px.Cream ($bx + $bw - 3) ($top - 2) 2 2   # 귀
            Px-Fill $g $Px.Pink ($bx + 1) ($top - 1) 1 1;  Px-Fill $g $Px.Pink ($bx + $bw - 2) ($top - 1) 1 1  # 귓속
            Px-Fill $g $Px.Ink ($bx + 3) 7 1 2; Px-Fill $g $Px.Ink ($bx + $bw - 4) 7 1 2                          # 눈
            $mx = $bx + [int]($bw / 2) - 1
            if ($stage -ge 3) {
                Px-Fill $g $Px.Ink ($mx - 1) 10 1 1; Px-Fill $g $Px.Ink $mx 11 2 1; Px-Fill $g $Px.Ink ($mx + 2) 10 1 1   # 웃음
                Px-Fill $g $Px.Pink ($bx + 2) 10 1 1; Px-Fill $g $Px.Pink ($bx + $bw - 3) 10 1 1                    # 홍조
                Px-Fill $g $Px.White ($mx - 1) 13 2 1                                                              # 통통한 배 하이라이트
            } elseif ($stage -eq 2) {
                Px-Fill $g $Px.Ink ($mx - 1) 11 4 1                                                                # 무표정
            } else {
                Px-Fill $g $Px.Ink ($mx - 1) 12 1 1; Px-Fill $g $Px.Ink $mx 11 2 1; Px-Fill $g $Px.Ink ($mx + 2) 12 1 1   # 울상
                Px-Fill $g $Px.Sky ($bx + $bw + 1) 5 1 1; Px-Fill $g $Px.Sky ($bx + $bw + 1) 6 1 2                     # 땀
            }
        } else {
            # 기절 — 누워서 x_x
            for ($y = 10; $y -le 16; $y++) {
                $in = if ($y -eq 10 -or $y -eq 16) { 2 } elseif ($y -eq 11 -or $y -eq 15) { 1 } else { 0 }
                Px-Fill $g $Px.Cream (1 + $in) $y (16 - 2 * $in) 1
            }
            Px-Fill $g $Px.Cream 2 8 2 2; Px-Fill $g $Px.Cream 6 8 2 2                                            # 귀
            foreach ($ex in 4, 11) {
                Px-Fill $g $Px.Ink $ex 12 1 1; Px-Fill $g $Px.Ink ($ex + 2) 12 1 1; Px-Fill $g $Px.Ink ($ex + 1) 13 1 1
                Px-Fill $g $Px.Ink $ex 14 1 1; Px-Fill $g $Px.Ink ($ex + 2) 14 1 1
            }
        }
        Draw-PixelText $g "$($d.S5)%" 20 6 $d.C5
        Draw-PixelText $g $d.L5 0 18 $Col.Label

        # 밥그릇 (7d) — 밥 높이 0~4 단
        $ox = 34
        Px-Fill $g $Px.Blue ($ox + 2) 12 12 1                                          # 테두리
        Px-Fill $g $Px.Blue ($ox + 3) 13 10 3; Px-Fill $g $Px.Blue ($ox + 4) 16 8 1   # 몸통
        Px-Fill $g $Px.Sky ($ox + 4) 13 1 2                                            # 하이라이트
        $food = [int][Math]::Floor(4 * $r7 / 100 + 0.5)
        for ($i = 0; $i -lt $food; $i++) { Px-Fill $g $Px.White ($ox + 3 + $i) (11 - $i) (10 - 2 * $i) 1 }
        if ($food -ge 3) { Px-Fill $g $Px.Red ($ox + 7) (11 - $food) 2 1 }             # 고봉밥 위 고명
        Draw-PixelText $g "$($d.S7)%" ($ox + 18) 6 $d.C7
        Draw-PixelText $g $d.L7 $ox 18 $Col.Label
    }
}
