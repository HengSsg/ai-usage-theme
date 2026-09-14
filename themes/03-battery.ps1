# 테마: 배터리 — 잔량 = 남은 한도(비워질수록 소진), 옆 숫자 = 사용률, 아래 [남은시간/창]
@{
    Id = 'battery'; Name = '배터리'; Width = 190
    Desc = '배터리 잔량 = 남은 한도. 쓸수록 칸이 줄고 색이 바뀐다.'
    Draw = {
        param($g, $d, $w, $h)
        $frame = [Drawing.Color]::FromArgb(154, 154, 154)
        $cells = @(
            @{ X = 4;   L = $d.L5; S = $d.S5; C = $d.C5 },
            @{ X = 100; L = $d.L7; S = $d.S7; C = $d.C7 }
        )
        foreach ($c in $cells) {
            Draw-RoundRect $g $frame 1.5 $c.X 9 44 18 3                          # 몸체 (세로 중심 18)
            Fill-RoundRect $g $frame ($c.X + 44.5) 14 3 8 1                       # 단자
            Fill-RoundRect $g $c.C ($c.X + 2.5) 11.5 (39 * (100 - $c.S) / 100) 13 1.5   # 잔량
            Draw-Text $g "$($c.S)%" 11 $true $c.C ($c.X + 54) 18
            Draw-Text $g $c.L 9 $true $Col.Label ($c.X + 22) 38 'Center'         # 배터리 아래 라벨
        }
    }
}
