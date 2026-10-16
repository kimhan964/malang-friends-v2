# 말랑친구 v2

16종 동물이 바탕화면에서 함께 생활하는 Windows 데스크톱 펫 게임입니다.

## 다운로드와 실행

1. [최신 Windows 다운로드](https://github.com/kimhan964/malang-friends-v2/releases/latest)에서 `MalangFriends-v2-Windows-2026-10-16-fix1.zip`을 받습니다.
2. 압축을 전부 풉니다.
3. `MalangFriends-v2/DesktopFriends.exe`를 실행합니다.

`DesktopFriends.pck`, `animal-packs`, `addons`는 실행 파일과 함께 유지해 주세요. 별도 설치 없이 실행합니다. 비공개 저장소이므로 다운로드하려면 접근 권한이 있는 GitHub 계정으로 로그인해야 합니다.

자세한 조작은 [사용법](사용법.md)을 확인하세요. 기본 행동, 가구 이용, 장난감 놀이, 마우스로 들기, 행동 도감과 해금 조건을 제공합니다.

## 이번 수정판

요청한 19개 항목의 [수정·검수 기록](docs/validation/v2-review-20261016.md)을 제공합니다.

- 걷기·달리기 구분과 보폭 개선, 걷기 속도 1.5배, 토끼 크기 확대
- 바구니 가림·고슴도치 손 중복·떨어질 때 반응 수정 및 넘어지기 추가
- 부엉이·수달·여우 걷기와 여우 기본 표정 수정
- 움직이는 생쥐, 인형 던져 받기, 도토리 함께 흔들기, 자명종 반응
- 벽 책장 사다리 이용, 화분대 기본 70%, 놀이감 치우기·다시 꺼내기
- 프레임 표시 제거, 이동 중 창 갱신 최소화

![벽 책장 사다리 동작](docs/validation/review-20261016/12/ladder-07.png)

## 저장소 구성

- `game/`: 현재 실행 팩에서 추출하고 파일별 해시를 확인한 Godot 프로젝트 리소스
- `docs/validation/`: 실제 화면과 해당 수정의 검수 결과
- `docs/art/`: 기본 이미지 생성 도구로 제작한 원화의 프롬프트 기록
- `snapshot.json`: 실행 파일과 동물 팩의 SHA-256, 소스 스냅샷 정보
- `tools/`: 다운로드한 Windows 실행본에 수정한 소스를 반영하는 도구

개인 플레이 저장 데이터, 개발 계정 정보, 작업용 백업과 과거 버전은 포함하지 않습니다. 배포 용량이 큰 실행 파일과 동물 팩은 Releases에서 받습니다.

## 소스 수정 후 실행하기

프로젝트 리소스는 Godot 4.7.2 실행 팩의 현재 상태입니다. 원본 실행 환경은 Windows이며, 네이티브 클릭 통과와 선택적 타자 감지 보조 프로그램을 사용합니다.

1. 위의 Windows 실행본을 다운로드하고 압축을 풉니다.
2. 게임을 종료하고 `game/`의 소스를 수정합니다.
3. Python 3.11 이상에서 다음을 실행합니다. 외부 패키지는 필요하지 않습니다.

```powershell
python tools/update_runtime.py "C:/games/MalangFriends-v2"
```

변경된 리소스만 실행 팩에 추가합니다. 원본 파일과 게임의 저장 데이터는 삭제하지 않으며, 변경 전 팩 헤더와 길이를 별도 기록합니다. 기본 Godot 에디터 실행은 동물 팩을 실행 파일 옆에서 읽는 배포 구조에 맞춰 별도 경로 설정이 필요합니다.

## 엔진과 검수

Godot 엔진 고지는 [GODOT-LICENSE.txt](GODOT-LICENSE.txt), 외부 구성 요소 정보는 `GODOT-THIRD-PARTY.json`과 `game/addons/`를 참조하세요. `docs/validation/`의 결과는 각 수정 시점의 검수 기록이며, `snapshot.json`은 이번에 업로드한 실행본의 해시입니다.
