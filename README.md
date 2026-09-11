# Claude Code 사용량 작업표시줄 위젯

Claude Code 구독 한도(5시간 창 · 주간 창) 소진률을 Windows 11 **작업표시줄에 상시 표시**합니다.
PowerShell 단일 스크립트 — 설치할 것 없음.

![테마 3종 — 막대 게이지 · 자동차 · 배터리 (왼쪽 실제 크기, 오른쪽 2배)](docs/themes.png)

```
2:21/5h ████████░░░░░░░░ 38%      ← 5시간 창: 리셋까지 2시간 21분, 38% 사용
   4/7d ██████████████░░ 72%      ← 주간 창: 리셋까지 4일, 72% 사용
```

## 요구사항

- Windows 11 (작업표시줄 48px 기준, 배율 100%에서 확인됨) · PowerShell 5.1 (기본 내장)
- **Claude Code 로그인 상태** — `%USERPROFILE%\.claude\.credentials.json` 이 있어야 합니다.
  구독(Pro/Max/Team) OAuth 로그인만 지원 — API 키 로그인엔 사용량 API 가 없습니다.

## 설치 / 제거

1. 받기 — 둘 중 하나:
   ```
   git clone https://github.com/HengSsg/ai-usage-theme.git %USERPROFILE%\tools\cc-usage-tray
   ```
   또는 GitHub 에서 **Code → Download ZIP** 을 풀어 원하는 위치에 둡니다. (git clone 이면 나중에 `git pull` 로 업데이트)
2. **`install.cmd` 더블클릭** → 시작프로그램 등록 + 즉시 실행
3. 제거: **`uninstall.cmd`** (위젯 종료 · 시작프로그램 해제 · 개인 설정 삭제)

폴더를 옮기면 시작프로그램 링크가 끊어집니다 — 옮긴 뒤 `install.cmd` 를 다시 실행하세요.

## 사용

위젯에서 **우클릭**:

| 메뉴 | 내용 |
|---|---|
| 테마 | 막대 게이지(기본) · 자동차(승용차=5h, 화물차=7d) · 배터리(잔량=남은 한도) |
| 위치 | 자동(아이콘 가운데 정렬이면 왼쪽, 왼쪽 정렬이면 트레이 앞) · 왼쪽 · 오른쪽 |
| 지금 새로고침 | 즉시 재조회 |
| 종료 | 위젯 종료 (다음 로그인 때 다시 뜸 — 완전 제거는 uninstall.cmd) |

마우스를 올리면 리셋까지 남은 시간이 툴팁으로 나옵니다.

- 라벨: `2:21/5h` = 5시간 창 리셋까지 2시간 21분 · `4/7d` = 주간 창 리셋까지 4일 (24시간 미만이면 `23h/7d`)
- 색: 사용률 60% 미만 초록 · 85% 미만 노랑 · 그 이상 빨강
- 표시 문구: `CC 잠시 후 재시도` = API 429(자동 회복) · `CC 재로그인 필요` = 토큰 만료(`claude` 실행해 로그인) · `CC 조회 실패` = 네트워크/프록시(툴팁에 원문)

## 동작 원리

- Claude Code 의 `/usage` 가 쓰는 `GET https://api.anthropic.com/api/oauth/usage` 를 **120초마다** 조회합니다.
  비공개 엔드포인트라 Anthropic 이 바꾸면 깨질 수 있습니다. 토큰은 매번 `.credentials.json` 에서 읽어 Claude Code 의 토큰 갱신을 그대로 따라갑니다(별도 갱신 로직 없음).
- Windows 11 은 작업표시줄에 위젯을 꽂는 공식 API 가 없어 **작업표시줄 위에 TOPMOST 창**을 얹습니다. 2초마다 위치·z순서를 재확인하고, 배경색은 작업표시줄 픽셀을 샘플링해 라이트/다크 테마에 맞춥니다.
- 429 방지: 단일 인스턴스(뮤텍스) · 마지막 응답 캐시 `last.json`(재시작 직후 재호출 안 함) · 실패 시 폴링 간격 2배(최대 10분).

## 테마 추가

`themes\N-이름.ps1` 파일이 아래 해시테이블을 **마지막 표현식으로 반환**하면 메뉴에 자동 등록됩니다(숫자 접두 = 메뉴 순서).

```powershell
@{
    Id = 'myTheme'; Name = '내 테마'; Width = 200      # Width 는 int 또는 { param($d) ... }
    Draw = {
        param($g, $d, $w, $h)                          # $g = System.Drawing.Graphics, 캔버스 $w x $h
        Draw-Text $g $d.L5 11 $true $Col.Label 8 15    # 5h 라벨(예: 2:21/5h)
        Fill-RoundRect $g $d.C5 40 11 100 9 2          # $d.S5 = 5h 사용률(%), $d.C5 = 그 색
    }
}
```

`$d`: `S5` `S7`(사용률 %) · `C5` `C7` `CD`(색, CD 는 둘 중 높은 쪽) · `L5` `L7`(남은시간/창 라벨) · `R5` `R7`(리셋 문구).
헬퍼: `Draw-Text`(세로중심 기준) · `Fill-RoundRect` · `Draw-RoundRect` · `Fill-Circle` · `Measure-Text` · `$Col`(Green/Gold/Red/Track/Label/Dim/Light/Road) · `Get-LevelColor`.

확인은 API 호출 없이:

```
powershell -ExecutionPolicy Bypass -File usage-tray.ps1 -RenderTest out.png
```

모든 테마를 두 가지 표본 데이터로 1x·2x 렌더한 PNG 한 장이 나옵니다.

## 알려진 한계

- 작업표시줄 **자동 숨김** 미대응 · 전체화면 앱 위에도 표시됨
- 라이트 테마 작업표시줄에선 회색 라벨 대비가 낮음
- 배율 100% 외에선 미검증

## 파일

| 파일 | 역할 |
|---|---|
| `usage-tray.ps1` | 본체 |
| `themes\*.ps1` | 테마 플러그인 |
| `setup.ps1` · `install.cmd` · `uninstall.cmd` | 설치/제거 |
| `config.json` · `last.json` | 개인 설정·캐시 (자동 생성, 공유 불필요) |
| `design\` | 테마 목업 생성기(선택) |

## 라이선스

[MIT](LICENSE)
