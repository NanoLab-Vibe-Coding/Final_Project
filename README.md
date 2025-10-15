# Ask Eye (gaze_tts_app)
전면 카메라의 시선 추정을 활용해 버튼을 응시하여 문장을 발화(TTS)하거나 긴급(SOS) 동작을 수행하는 접근성 보조 앱입니다. 웹/권한 거부/에뮬레이터 환경에서는 터치 제스처로 시선을 모의 입력(Mock)할 수 있습니다.

본 README는 저장소 전체 구조와 실제 코드 기준으로 작성되었습니다. `.gitignore`는 Flutter 표준을 따르며 빌드/툴 산출물은 VCS에 포함하지 않습니다.

– 프로젝트 루트: Flutter 애플리케이션(안드로이드/iOS/웹/데스크톱 타겟)
– 앱 이름: Ask Eye


**목차**
- 개요
- 개발 동기
- 핵심 기능
- 기술 스택
- 프로젝트 구조
- 설치 및 실행
- 권한/플랫폼 동작
- 사용 방법
- 데이터/저장 방식
- 개발 과정 메모
- 테스트/빌드
- 문제 해결/알려진 한계


**개요**
- 목적: 손 사용이 어려운 사용자가 카메라 기반 시선 추정 + 응시(Dwell)로 보드의 카드를 선택해 음성 합성(TTS)으로 의사 표현을 돕고, 필요 시 전화/문자 등 긴급 호출 기능을 제공합니다.
- 특징: 화면을 카메라 프리뷰가 가리지 않도록 “숨김 프리뷰(1x1 Offstage)”를 사용하며, 시선 좌표는 스무딩 및 보정(3x3)으로 안정화합니다.


**개발 동기**
- 청각·언어 장애로 인해 발성이나 대면 의사표현이 어려운 사용자가, 주변 도움 없이도 스스로 빠르게 의사 표시를 할 수 있는 도구가 필요했습니다. 기존 키보드/터치 기반 앱은 손 사용의 부담이 크고, 발화가 지연되거나 상황(이동 중·누워 있음·한 손 사용)에 따라 사용성이 급격히 떨어집니다.
- 전면 카메라로 얼굴/눈을 감지해 ‘응시(Dwell)’만으로 카드를 선택하고 즉시 음성(TTS)으로 발화하면, 다음과 같은 불편을 줄일 수 있습니다.
  - 반복되는 일상 표현(물·화장실·도움 요청 등)을 빠르게 전달 → 반응 시간 단축과 피로도 감소
  - 보호자/도우미 부재 상황에서도 기본적 의사 표현과 긴급 호출(SOS) 가능 → 안전성·자립성 향상
  - 보드 편집으로 개인 맞춤 어휘를 손쉽게 구성 → 학습/재활 과정에 맞춘 점진적 사용 확대
- 개인정보와 안정성을 고려해 on‑device 추론(안드로이드)과 최소 로그(개인식별정보 미수집)를 우선하며, 권한이 없거나 미지원 플랫폼에서는 모의 시선을 제공해 학습·테스트 장벽을 낮췄습니다.


**핵심 기능**
- 시선 추정/입력
  - 안드로이드(우선): Google ML Kit 얼굴 검출 기반의 간단한 시선 포인트 추정.
  - 기타 플랫폼/권한 거부: Mock Gaze(화면 탭/드래그로 시선 좌표 입력).
  - 이동 평균 + 점프 클램프 스무딩, 60fps 렌더 스로틀, 데드존 처리.
- 보정(Calibration)
  - 3x3 타깃을 순차 응시해 원시 좌표 → 화면 좌표로 보정 행렬을 계산/적용.
- Dwell 선택
  - 일정 시간 응시 시 카드 트리거. 진행률 링과 진동/플래시로 피드백.
- 음성 합성(TTS)
  - 한국어/영어, 속도/피치/음성(선택)에 따른 발화.
  - 실시간 시선 읽어주기(가리키는 카드 또는 좌표 주기적 안내) 옵션.
- SOS
  - 112/119 또는 사용자 번호로 통화/문자, 또는 둘 다. 진동 패턴 + TTS 안내.
- 보드 편집
  - 앱 내 간단한 보드/카드 편집기. SharedPreferences에 JSON 저장.
- 접근성
  - 고대비, 폰트 스케일, 다크 모드, 큰 터치 타깃, 시각 피드백 강화.
- 로깅
  - 동작 로그를 `sqflite` DB에 저장(웹은 메모리 대체). CSV 내보내기 유틸 포함.


**기술 스택**
- Flutter(Dart), Material 3
- 카메라/ML
  - `camera`, `google_mlkit_face_detection` (웹/미지원 시 스텁)
- 음성/디바이스
  - `flutter_tts`, `vibration`, `url_launcher`, `permission_handler`
- 저장/상태
  - `shared_preferences`, `sqflite`, `path`
- 국제화/유틸
  - `intl`

참고: `tflite_flutter` 의존성이 포함되어 있으나 현 버전 코드에서는 ML Kit 경로를 사용합니다(향후 on‑device 커스텀 모델로의 확장 여지).


**개발 환경**
- 에디터/IDE: Visual Studio Code
- 테스트: Android Studio Emulator (Pixel 9) 기반 실행/검증


**프로젝트 구조**
```
final/
├─ lib/
│  ├─ main.dart                 # 엔트리, AppRoot 구동
│  ├─ app.dart                  # 부트스트랩(TTS/DB/권한/가제트), 라우팅/테마
│  ├─ core/                     # 테마/접근성/로거
│  ├─ data/                     # prefs 저장/로그 DB
│  ├─ domain/
│  │  ├─ gaze/                  # 시선 Repo/어댑터/보정/FSM/Mock
│  │  ├─ tts/                   # TTS 서비스
│  │  ├─ sos/                   # SOS 서비스
│  │  └─ models/                # Settings/Board/Card 모델
│  ├─ platform/                 # Android 채널 기반 Gaze(안전 폴백)
│  └─ ui/
│     ├─ screens/               # Camera/Settings/Calibration/Editor/SOS/EyeDebug
│     └─ widgets/               # Gaze 커서/카드 그리드 등
├─ assets/
│  └─ boards/cards_default.json # 기본 보드
├─ l10n/                        # 간단 ARB 텍스트(ko/en)
├─ android/ ios/ web/ ...       # 각 플랫폼 타겟
├─ pubspec.yaml                 # 의존성/에셋 선언
└─ .gitignore                   # 빌드/도구 산출물 제외
```


**설치 및 실행**
- 요구 사항: Flutter SDK 3.x, Android SDK(or Xcode), 실제 기기 권장(안드로이드는 전면 카메라/권한 필요)

1) 의존성 설치
```
flutter pub get
```
2) 실행
```
# Android 실제 기기(권장)
flutter run -d android

# iOS (시뮬레이터/실기기). ML Kit 설정/권한 필요
flutter run -d ios

# Web/데스크톱(모의 시선 사용)
flutter run -d chrome   # 또는 macos/windows/linux
```
3) 빌드
```
flutter build apk   # 또는 ios / web / macos / windows / linux
```


**권한/플랫폼 동작**
- 권한: 카메라, 전화(CALL_PHONE), 진동
  - AndroidManifest에 선언됨. 런타임에 `permission_handler`로 요청합니다.
- 안드로이드: ML Kit + `camera` 이미지 스트림으로 on‑device 추정 동작.
- iOS: ML Kit Face Detection 사용 가능(권한/설정 필요). 미설정 시 Mock fallback.
- Web/데스크톱/권한 거부/에뮬레이터: 5초 동안 시선 이벤트가 없으면 자동으로 Mock Gaze로 전환(화면 탭/드래그로 이동).
- 프리뷰 숨김: `GazeHiddenPreview` 위젯이 1x1 오프스테이지 `CameraPreview`를 렌더해 실제 화면을 가리지 않습니다.


**사용 방법**
- 첫 실행
  - 권한 요청을 허용하세요(카메라/전화). 거부 시 Mock Gaze로 안내 음성이 출력됩니다.
- 보정(Calibration)
  - 메뉴의 보정 화면에서 3x3 점을 차례로 응시합니다. 계산된 보정은 `SharedPreferences`에 저장됩니다.
- 메인(카메라/보드)
  - 시선 커서가 카드 위에 머물면 진행 링이 차오르고, 완료 시 카드가 발화됩니다. SOS 카드는 상세 화면으로 이동합니다.
- SOS 상세
  - 112/119/사용자 지정 버튼이 크게 표시됩니다. 응시로 선택 시 진동+TTS 후 통화/문자 동작을 시도합니다.
- 설정(Settings)
  - Dwell 시간, 커서 크기/색, 고대비/다크모드, 글자 크기, TTS 속도/피치, Mock Gaze 사용, 실시간 시선 읽어주기 등을 조정할 수 있습니다.
- 보드 편집(Editor)
  - 카드 추가/수정/삭제가 가능하며 결과 JSON은 `SharedPreferences`의 `boardJson` 키에 저장됩니다. 기본 템플릿은 `assets/boards/cards_default.json`.


**데이터/저장 방식**
- 사용자 설정: `SharedPreferences`(`lib/data/prefs.dart`)
- 보정/보드: `SharedPreferences` JSON 문자열
- 로그: `sqflite` DB(웹은 메모리 대체) → CSV 내보내기 지원(`lib/data/db.dart`)
- 민감정보: 전화번호 등은 저장하지 않으며, 로그에는 개인식별정보를 남기지 않습니다.


**개발 과정 메모(요약)**
- 단계적 구현
  - Mock Gaze → Dwell FSM → 카드 그리드/포커스 링 → TTS → SOS → ML Kit 연동 → 숨김 프리뷰 → 보정/접근성/성능 최적화.
- 성능/안정성
  - 60fps 스로틀, 이동평균 + 점프 클램프 스무딩, 데드존, 이벤트 없는 경우 Mock 자동 전환.
- 접근성
  - 큰 터치 타깃, 고대비 테마, 폰트 스케일, 실시간 읽어주기 옵션으로 가이드 강화.


**테스트/빌드**
- 단위/위젯 테스트: `flutter test`
  - 초기 템플릿 테스트는 현재 앱 구조(`AppRoot`)와 다를 수 있습니다. 필요 시 최신 구조에 맞게 테스트를 보강하세요.
- 형상/포맷: Flutter 공식 lints(`flutter_lints`) 적용, IDE/`dart format` 권장.


**문제 해결/알려진 한계**
- 웹/데스크톱은 카메라+ML Kit 경로가 제한되어 Mock Gaze만 실용적입니다.
- 단말/조명/각도에 따라 시선 포인트 안정성은 달라질 수 있습니다(보정으로 완화).
- iOS는 권한/설정에 따라 동작이 상이할 수 있으며 실제 기기 테스트가 필요합니다.


**.gitignore 참고**
- 본 저장소의 `.gitignore`는 Flutter 표준으로 설정되어 있으며 다음을 버전 관리에서 제외합니다.
  - 빌드 산출물: `/build/`, `**/ios/Flutter/.last_build_id`, Android 빌드 변형 디렉터리 등
  - 도구/캐시: `.dart_tool/`, `.pub-cache/`, `.pub/`, `**/doc/api/`
  - IDE 메타: `.idea/`, `*.iml`, `.DS_Store` 등
- 추가 비밀 키/환경 파일은 사용하지 않으며(본 프로젝트는 외부 API 키를 다루지 않음), 필요한 경우 `.gitignore`에 포함하세요.


**라이선스**
- 별도 명시가 없는 한 교육/데모 목적의 코드입니다. 외부 패키지는 각 라이선스를 따릅니다.
