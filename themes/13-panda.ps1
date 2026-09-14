# 테마: 팬더와 대나무 (벡터 — 픽셀 아님) — 한 장면에 두 한도를 얹는다.
#   5시간 = 팬더 앞에 쌓인 죽순 더미 (먹어 치울수록 낮아진다)
#   7일   = 뒤편 대나무숲 (팬더에 가까운 쪽부터 베어져 그루터기만 남는다)
# 같은 땅바닥 위에 숲 → 베어낸 자리 → 팬더 앞 더미 순으로 이어 놓아 두 게이지가 따로 놀지 않게 했다.
# 맨 위 죽순 한 개와 마지막 대나무 한 그루는 '길이/키'로 소수점을 표현해 눈금이 부드럽게 움직인다.
#
# ⚠️ 팬더는 흰 원 + 검은 반점이라 비율이 조금만 틀어져도 해골로 보인다.
#    머리를 몸통보다 작게, 귀를 머리 밖으로 내밀게, 눈 반점은 작고 바깥쪽으로 — 이 셋이 핵심.
#
# ⚠️ 애니메이션 비용 — 매 프레임 전부 벡터로 다시 그리면 유휴 상태에서도 한 코어 3.3% 를 먹었다(실측).
#    비싼 건 숲의 Fill-RoundRect(호출마다 GraphicsPath) 와 라벨의 Measure-Text/DrawString 이다.
#    씹는 동작이 4프레임뿐이라 **완성본 4장을 통째로 구워 두고** 프레임마다 붙이기만 한다
#    (자동차 테마와 같은 수법). 굽기는 값이 바뀔 때 = 분이 바뀔 때 한 번뿐이다.
@{
    Id = 'panda'; Name = '팬더와 대나무'
    Desc = '팬더 앞 죽순 더미 = 5시간, 뒤편 대나무숲 = 7일. 먹어 치울수록 더미가 낮아지고 숲이 줄어든다.'
    Width = 224; Anim = 110          # 씹는 4프레임 주기(약 0.44초). 마우스를 안 올리면 자동으로 4배 느려진다
    Draw = {
        param($g, $d, $w, $h)
        $key = "$w|$h|$($d.BG.ToArgb())|$($d.L5)|$($d.L7)|$($d.S5)|$($d.S7)|$($d.C5.ToArgb())|$($d.C7.ToArgb())"
        if ($script:pandaKey -ne $key) {
            foreach ($old in @($script:pandaFrames)) { if ($old) { $old.Dispose() } }
            $gy   = 32                                          # 땅 높이 — 숲·팬더·더미가 모두 이 선에 선다
            $bam  = [Drawing.Color]::FromArgb(106, 196, 96)     # 대나무
            $bamD = [Drawing.Color]::FromArgb(64, 138, 68)      # 마디·잘린 단면
            $leaf = [Drawing.Color]::FromArgb(140, 216, 120)    # 잎
            $cut  = $Col.Track                                  # 베어낸 자리 = 빈 게이지(라이트/다크 자동)
            $fur  = $Px.White
            # ⚠️ 팬더의 '검정'에 $Px.Ink(28,28,32) 를 쓰면 안 된다 — 다크 작업표시줄이 (32,32,32) 라
            #    귀·어깨처럼 배경에 닿는 부분이 통째로 사라진다. 흰 테두리를 둘러도 검은 속은 여전히
            #    배경과 같아서 '속 빈 선화'가 된다. 배경보다 확실히 밝은 먹색을 쓰는 게 유일한 해법이다.
            #    (60,60,68) 은 다크 배경(32)에도, 라이트 배경(243)에도, 흰 털에도 모두 대비가 선다.
            #    반대로 흰 털은 라이트 작업표시줄에서 묻히므로 머리에는 먹색 테두리를 한 겹 깐다.
            $fx = [Drawing.Color]::FromArgb(60, 60, 68)
            $cx = 28
            $rem5 = (100 - $d.S5) / 100 * 4
            $rem7 = (100 - $d.S7) / 100 * 8
            $eat  = ($rem5 -gt 0)
            $script:pandaFrames = @()
            foreach ($chew in @(0, 1, 2, 1)) {                  # 턱이 내려간 정도 — 안 먹을 때는 한 장만 굽는다
                if (-not $eat -and $script:pandaFrames.Count -ge 1) { break }
                $bmp = New-Object Drawing.Bitmap $w, $h
                $b = [Drawing.Graphics]::FromImage($bmp)
                $b.SmoothingMode = 'AntiAlias'; $b.TextRenderingHint = 'ClearTypeGridFit'; $b.PixelOffsetMode = 'HighQuality'
                $b.Clear($d.BG)
                if (-not $eat) { $chew = 0 }
                $hb = [int]($chew -ge 2)                        # 씹을 때 머리가 1px 끄덕

                Fill-RoundRect $b $cut 6 ($gy + 1) ($w - 12) 2 1    # 땅 — 장면을 하나로 묶는 선

                # ── 뒤편 대나무숲 = 7일 한도 ──────────────────────────────────
                $lb = New-Object Drawing.SolidBrush $leaf
                for ($i = 0; $i -lt 8; $i++) {
                    $x = 92 + $i * 17
                    $f = [Math]::Max(0.0, [Math]::Min(1.0, $rem7 - (8 - $i) + 1))   # 이 그루가 남은 비율
                    if ($f -le 0) {                                                 # 베어낸 그루터기
                        Fill-RoundRect $b $cut $x ($gy - 5) 5 5 2
                        Fill-RoundRect $b $Col.Dim $x ($gy - 5) 5 1 0               # 잘린 단면
                        continue
                    }
                    $top = $gy - [int](6 + 22 * $f)
                    Fill-RoundRect $b $bam ($x + 1) $top 4 ($gy - $top) 2
                    for ($ny = $top + 7; $ny -lt $gy - 2; $ny += 8) { Fill-RoundRect $b $bamD ($x + 1) $ny 4 1 0 }
                    if ($f -gt 0.55) {                                              # 잎은 다 자란 대나무에만
                        # 잎은 바깥·아래로 처지는 가느다란 삼각 날. 가로 타원은 T 자, 위로 뻗으면 Y 자로 보인다.
                        # 좌우 높이를 어긋나게 붙여야 대칭 도형이 아니라 이파리로 읽힌다.
                        $b.FillPolygon($lb, [Drawing.PointF[]]@(
                            (New-Object Drawing.PointF ($x + 1), ($top + 4)),
                            (New-Object Drawing.PointF ($x + 1), ($top + 7)),
                            (New-Object Drawing.PointF ($x - 7), ($top + 10))))
                        $b.FillPolygon($lb, [Drawing.PointF[]]@(
                            (New-Object Drawing.PointF ($x + 4), ($top + 9)),
                            (New-Object Drawing.PointF ($x + 4), ($top + 12)),
                            (New-Object Drawing.PointF ($x + 11), ($top + 15))))
                    }
                }
                $lb.Dispose()

                # ── 팬더 앞 죽순 더미 = 5시간 한도 (맨 위 한 개는 길이로 소수점 표현) ──
                for ($j = 0; $j -lt 4; $j++) {
                    $f = [Math]::Max(0.0, [Math]::Min(1.0, $rem5 - $j))
                    if ($f -le 0) { break }
                    $y = $gy - 6 * ($j + 1); $len = [int](10 + 20 * $f)
                    Fill-RoundRect $b $bam 54 $y $len 5 2
                    Fill-RoundRect $b $bamD (54 + [int]($len / 2)) $y 1 5 0          # 마디
                    Fill-Ellipse   $b $bamD (52 + $len) ($y + 1) 3 3                 # 잘린 단면(속이 빈 통)
                }

                # ── 팬더 ──────────────────────────────────────────────────────
                # 48px 안에서 머리와 몸통이 둘 다 흰색이면 하나의 덩어리(유령)로 보인다.
                # 몸통 실루엣을 먹색(어깨·팔다리)으로 깔고 그 안에 흰 배를 작게 얹으면
                # 머리와 배 사이에 어두운 띠가 생겨 분리되고, 실제 팬더 무늬와도 맞는다.
                Fill-Ellipse $b $fx  ($cx - 11) ($gy - 17) 22 17                     # 몸통 = 어깨·팔다리
                Fill-Ellipse $b $fur ($cx - 7)  ($gy - 13) 14 11                     # 흰 배
                Fill-Ellipse $b $fx  ($cx - 10) ($gy - 31 + $hb) 7 7                 # 귀 (머리 밖으로 내밀어야 보인다)
                Fill-Ellipse $b $fx  ($cx + 4)  ($gy - 31 + $hb) 7 7
                Fill-Ellipse $b $fx  ($cx - 9)  ($gy - 31 + $hb) 19 18               # 머리 테두리
                Fill-Ellipse $b $fur ($cx - 8)  ($gy - 30 + $hb) 17 16               # 머리 (몸통보다 작게)
                Fill-Ellipse $b $fx  ($cx - 7)  ($gy - 27 + $hb) 6 7                 # 눈 반점 (작고 바깥쪽)
                Fill-Ellipse $b $fx  ($cx + 2)  ($gy - 27 + $hb) 6 7
                Fill-Ellipse $b $fur ($cx - 5)  ($gy - 25 + $hb) 2.5 2.5             # 눈
                Fill-Ellipse $b $fur ($cx + 4)  ($gy - 25 + $hb) 2.5 2.5
                Fill-Ellipse $b $fx  ($cx - 2)  ($gy - 20 + $hb) 4 3                 # 코
                if ($eat) {
                    $py = $gy - 13 + $chew * 0.5                                     # 죽순과 앞발이 씹는 박자로 오르내린다
                    $pen = New-Object Drawing.Pen $bam, 4                            # 입으로 가져가는 죽순
                    $pen.StartCap = 'Round'; $pen.EndCap = 'Round'
                    $b.DrawLine($pen, [float]($cx + 3), [float]($gy - 17 + $hb + $chew * 0.5), [float]($cx + 16), [float]($py + 5))
                    $pen.Dispose()
                    Fill-Ellipse $b $fx ($cx + 11) $py 9 8                           # 쥐고 있는 앞발
                    Fill-Ellipse $b $fx ($cx - 2)  ($gy - 17 + $hb) 4 (1 + $chew)    # 우물우물 — 입이 열렸다 닫힌다
                } else {
                    Fill-Ellipse $b $fx ($cx + 7)  ($gy - 15) 9 9                    # 빈 앞발
                    Fill-RoundRect $b $fx ($cx - 2) ($gy - 17) 4 2 1                 # 시무룩
                }

                # ── 라벨: 왼쪽 = 5시간(팬더·더미 아래), 오른쪽 = 7일(숲 아래) ──
                $cy = 41; $p7 = "$($d.S7)%"
                Draw-Text $b $d.L5 11 $false $Col.Label 8 $cy
                Draw-Text $b "$($d.S5)%" 12 $true $d.C5 (8 + (Measure-Text $d.L5 11 $false) + 5) $cy
                Draw-Text $b $p7 12 $true $d.C7 ($w - 8) $cy 'Far'
                Draw-Text $b $d.L7 11 $false $Col.Label ($w - 8 - (Measure-Text $p7 12 $true) - 5) $cy 'Far'

                $b.Dispose()
                $script:pandaFrames += $bmp
            }
            $script:pandaKey = $key
        }
        $g.DrawImageUnscaled($script:pandaFrames[$d.F % $script:pandaFrames.Count], 0, 0)
    }
}
