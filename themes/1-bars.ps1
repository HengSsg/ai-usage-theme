# 테마: 막대 게이지 — [남은시간/창] 라벨(오른쪽 정렬) + 진행 막대 + 숫자
@{
    Id = 'bars'; Name = '막대 게이지'; Width = 215
    Draw = {
        param($g, $d, $w, $h)
        $rows = @(
            @{ L = $d.L5; S = $d.S5; C = $d.C5; Y = 11 },
            @{ L = $d.L7; S = $d.S7; C = $d.C7; Y = 28 }
        )
        foreach ($r in $rows) {
            $cy = $r.Y + 4.5
            Draw-Text $g $r.L 11 $true $Col.Label 56 $cy 'Far'      # 라벨 끝을 56 에 맞춰 막대 시작선 정렬
            Fill-RoundRect $g $Col.Track 62 $r.Y 108 9 2
            Fill-RoundRect $g $r.C 62 $r.Y (108 * $r.S / 100) 9 2
            Draw-Text $g "$($r.S)%" 11 $true $r.C 178 $cy
        }
    }
}
