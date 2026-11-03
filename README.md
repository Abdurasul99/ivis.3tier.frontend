# ivis.3tier.frontend
Dasboard to monitor vechicle data
Here's the website url
http://<SERVER_DOMAIN>/#/login
for frontend view only 

차량·인프라 텔레메트리를 실시간으로 보여주는 IVIS 3Tier 대시보드(Flutter Web)입니다.

요구 사항
- Flutter 3.27.2 (stable, Dart 3.6 포함) — `flutter --version` 으로 확인
- Git
- Chrome (개발 실행용)
- 실행 중인 IVIS 3Tier 백엔드 (REST API, MQTT WebSocket)

설치
bash
git clone <저장소 URL>
cd ivis.3tier.frontend
git checkout test        # 개발 브랜치 (main 은 PR 승인 후 병합되는 브랜치)
flutter pub get

`packages/pluto_grid` 는 저장소에 포함된 로컬 패키지라 따로 설치할 필요가 없습니다.

 서버 주소 설정
`lib/constants/constants.dart` 에 백엔드가 실행 중인 PC(서버)의 IP 주소를 입력합니다.
dart
const String kApiServer = "<내 IP 주소>:4090";        // REST API (기본 포트 4090)
const String kMqttServer = "ws://<내 IP 주소>:9001";  // MQTT over WebSocket (기본 포트 9001)

- 백엔드를 같은 PC에서 실행하면 `localhost` 를 써도 됩니다.
- 내 IP 확인: Windows `ipconfig` → IPv4 주소, macOS / Linux `ip a`
- 값을 바꾼 뒤에는 다시 실행(빌드)합니다.

 개발 실행
bash
flutter run -d chrome
# 또는 고정 포트로 실행
flutter run -d web-server --web-port 8080   # http://localhost:8080/#/login

등록된 계정으로 로그인합니다.
 빌드 / 배포
bash
flutter build web --release      # 결과물: build/web/

- `build/web/` 의 파일을 웹 서버(nginx 등) 루트에 복사합니다.
- 배포 후 이전 화면이 보이면 Ctrl+F5 로 새로고침합니다.

테스트 / 정적 분석
bash
flutter test
flutter analyze lib test

프로젝트 전체를 analyze 하면 `packages/pluto_grid/packages/pluto_grid_export`(앱에서 쓰지 않는 하위 패키지)에서 오류가 표시되지만 빌드와는 무관합니다.

 폴더 구조

lib/
  constants/      서버 주소, 색상, 화면 크기
  model/          API 응답 모델 (차량·인프라·객체)
  view/           페이지, 탭, 컴포넌트 (지도 포함)
  viewmodel/
    controller/   GetX 컨트롤러 (GetBuilder + update())
    repository/   REST API 호출
  i18n/           한국어 / 영어 문자열
  utils/          UTM 52N 좌표·방위 변환
packages/pluto_grid/   그리드 라이브러리 (로컬 패키지)
test/                  단위·위젯 테스트
web/                   index.html

### Google Maps API 키
`web/maps_key.js` 에 Google Maps API 키를 붙여 넣습니다.

1. `web/maps_key.example.js` 를 `web/maps_key.js` 로 복사합니다.
2. `YOUR_GOOGLE_MAPS_API_KEY` 를 본인 키로 바꿉니다:
   `window.GOOGLE_MAPS_API_KEY = 'your-key-here';`
3. 앱을 다시 실행(빌드)합니다.

`web/maps_key.js` 는 git 에 올라가지 않습니다. 키를 커밋하지 마세요.


 보안
- 실제 서버 IP, 도메인, 계정, 비밀번호, 키는 README·이슈·커밋 메시지에 적지 않습니다.
- `constants.dart` 에 넣은 내 IP 는 개인 환경용입니다. 공용 브랜치에 커밋하기 전에 팀과 확인합니다.
- 운영 환경에서는 HTTPS / WSS 를 사용하고, 서버 포트는 허용된 IP 에서만 접속되도록 방화벽(보안 그룹)으로 제한합니다.

 참고
- 데이터는 프로토콜 명세 260427 기준입니다. 장치 번호 0 도 실제 장치입니다.
- 속도는 `velocity_kph`(= mps × 3.6)를 사용합니다. 7번 필드는 이벤트 코드(0~9)이며 속도가 아닙니다.
- 화면 언어: 기본 한국어, 영어 지원.



## English

IVIS 3Tier dashboard (Flutter Web) that shows vehicle and infrastructure telemetry in real time.

### Requirements
- Flutter 3.27.2 (stable, includes Dart 3.6) — check with `flutter --version`
- Git
- Chrome (for development runs)
- A running IVIS 3Tier backend (REST API, MQTT over WebSocket)

Installation
bash
git clone <REPOSITORY_URL>
cd ivis.3tier.frontend
git checkout test        # development branch (main receives approved pull requests)
flutter pub get

packages/pluto_grid` is a local package inside the repository; it needs no separate install.

 Server address
In `lib/constants/constants.dart`, enter the IP address of the PC (server) where the backend runs.
dart
const String kApiServer = "<YOUR_IP>:4090";        // REST API (default port 4090)
const String kMqttServer = "ws://<YOUR_IP>:9001";  // MQTT over WebSocket (default port 9001)

- If the backend runs on the same PC, `localhost` also works.
- Find your IP: Windows `ipconfig` → IPv4 Address, macOS / Linux `ip a`
- Run (or build) again after changing the values.

 Run for development
bash
- flutter run -d chrome
 or on a fixed port
- flutter run -d web-server --web-port 8080   # http://localhost:8080/#/login

Sign in with a registered account.

 Build / deploy
bash
- flutter build web --release      # output: build/web/

- Copy the contents of `build/web/` to the web server (nginx or similar) root.
- If the browser still shows the old version after a deploy, press Ctrl+F5.

 Tests / static analysis

bash
- flutter test
- flutter analyze lib test

Analyzing the whole project also reports errors in `packages/pluto_grid/packages/pluto_grid_export`, a sub-package the app does not use; they do not affect the build.

 Project structure

lib/
  constants/      server addresses, colors, screen sizes
  model/          API response models (vehicle, infra, objects)
  view/           pages, tabs, components (including the map)
  viewmodel/
    controller/   GetX controllers (GetBuilder + update())
    repository/   REST API calls
  i18n/           Korean / English strings
  utils/          UTM 52N coordinates and heading conversion
packages/pluto_grid/   grid library (local package)
test/                  unit and widget tests
web/                   index.html


### Google Maps API key
Paste your Google Maps API key into `web/maps_key.js`:

1. Copy `web/maps_key.example.js` to `web/maps_key.js`.
2. Replace `YOUR_GOOGLE_MAPS_API_KEY` with your key:
   `window.GOOGLE_MAPS_API_KEY = 'your-key-here';`
3. Run or build the app again.

`web/maps_key.js` is git-ignored. Never commit the key.


Security
- Never put real server IPs, domains, accounts, passwords or keys in the README, issues or commit messages.
- The IP you put in `constants.dart` is for your own environment. Check with the team before committing it to a shared branch.
- In production use HTTPS / WSS, and restrict the server ports to allowed IPs with a firewall (security group).

Notes
- Data follows protocol spec 260427. Device number 0 is a real device.
- Speed comes from `velocity_kph` (= mps × 3.6). Field 7 is an event code (0–9), not a speed.
- UI language: Korean by default, English supported.
