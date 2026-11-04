import 'package:get/get.dart';

// Korean is the source language of the UI. Every user-visible Korean string
// goes through t() (looked up here) or l10n(korean, english) for interpolated
// text. Keys are the exact Korean source strings.
const Map<String, String> _englishText = <String, String>{
  // ── Navigation / common actions ────────────────────────────────────────────
  '대시보드': 'Dashboard',
  '장치 관리': 'Device Management',
  '활동': 'Activity',
  '설정': 'Settings',
  '확인': 'Confirm',
  '저장': 'Save',
  '취소': 'Cancel',
  '예': 'Yes',
  '아니오': 'No',
  '적용': 'Apply',
  '삭제': 'Delete',
  '편집': 'Edit',
  '등록': 'Register',
  '검색': 'Search',
  '새로고침': 'Refresh',
  '숨기기': 'Hide',
  '알림': 'Notifications',
  '완료': 'Done',
  '오류': 'Error',
  '불러오는 중...': 'Loading...',
  '저장되었습니다.': 'Saved.',
  '저장에 실패했습니다.': 'Failed to save.',
  '삭제에 실패했습니다.': 'Failed to delete.',
  '예기치 않은 UI 오류': 'Unexpected UI error',

  // ── Auth / pre-login pages ─────────────────────────────────────────────────
  '로그인': 'Login',
  '로그아웃': 'Log out',
  '내 계정': 'My account',
  '회원가입': 'Sign Up',
  '회원 가입': 'Sign Up',
  '아이디 찾기': 'Find ID',
  '비밀번호 찾기': 'Find Password',
  '비밀번호 재설정': 'Reset Password',
  '비밀번호 재설정이 완료되었습니다.': 'Password reset is complete.',
  '계정 정보를 입력하여 회원가입을 완료하세요.': 'Complete sign up by entering your account information.',
  '이름과 메일로 본인 확인을 진행하세요.': 'Verify your identity with your name and email.',
  '이름과 메일로 아이디를 찾아보세요.': 'Find your ID using your name and email.',
  '아이디와 메일로 비밀번호를 재설정하세요.': 'Reset your password using your ID and email.',
  '이름': 'Name',
  '아이디': 'ID',
  '비밀번호': 'Password',
  '메일': 'Email',
  '연락처': 'Phone',
  '이름을 입력하세요.': 'Enter your name.',
  '이름을 입력해주세요.': 'Enter your name.',
  '메일을 입력하세요.': 'Enter your email.',
  '메일을 입력해주세요.': 'Enter your email.',
  '가입에 사용할 메일을 입력하세요.': 'Enter the email to use for sign up.',
  '가입에 사용한 메일을 입력하세요.': 'Enter the email used for sign up.',
  '인증메일 보내기': 'Send Verification Email',
  '인증번호': 'Verification Code',
  '인증번호를 입력해 주세요.': 'Enter the verification code.',
  '인증번호를 입력해주세요.': 'Enter the verification code.',
  '인증번호를 입력하세요.': 'Enter the verification code.',
  '인증번호가 유효하지 않습니다.': 'The verification code is invalid.',
  '인증번호가 일치하지 않습니다.': 'The verification code does not match.',
  '인증번호가 올바르지 않습니다.': 'The verification code is incorrect.',
  '인증번호 확인 성공! 다음 단계로 이동하세요.': 'Verification succeeded. Move to the next step.',
  '인증메일을 보냈습니다. 메일을 확인해주세요.': 'Verification email sent. Please check your inbox.',
  '인증번호가 발송되었습니다. 이메일 확인해주세요.': 'Verification code sent. Please check your email.',
  '이름과 메일을 입력하세요.': 'Enter your name and email.',
  '아이디와 메일을 입력하세요.': 'Enter your ID and email.',
  '메일 전송에 실패했습니다.': 'Failed to send the email.',
  '서버 에러 혹은 메일주소가 잘못됨.': 'Server error or invalid email address.',
  '서버 오류가 발생했습니다.': 'A server error occurred.',
  '서버 요청 오류 (reqPasswordComplete null).': 'Server request error (reqPasswordComplete null).',
  '인증되었습니다! 비밀번호를 재설정하세요.': 'Verified. Reset your password.',
  '비밀번호를 입력하세요.': 'Enter your password.',
  '비밀번호를 다시 입력하세요.': 'Enter your password again.',
  '비밀번호를 한 번 더 입력하세요.': 'Enter your password again.',
  '비밀번호가 서로 일치하지 않습니다.': 'Passwords do not match.',
  '비밀번호가 일치하지 않습니다.': 'Passwords do not match.',
  '비밀번호는 영문, 숫자, 특수문자를 포함해 8~16자로 입력해주세요.': 'Use 8-16 characters including letters, numbers, and symbols.',
  '비밀번호가 변경되었습니다!': 'Password changed.',
  '새 비밀번호': 'New Password',
  '비밀번호 확인': 'Confirm Password',
  '확인 비밀번호를 입력하세요.': 'Enter the confirmation password.',
  '영문, 숫자, 특수문자를 함께 사용하면 (8~16자) 보다 안전합니다.': 'Using letters, numbers, and symbols together is safer (8-16 characters).',
  '← 로그인으로 돌아가기': '← Back to Login',
  '회원가입이 완료되었습니다.': 'Sign up is complete.',
  '가입이 완료되었습니다!\n로그인 후 서비스를 이용해보세요.': 'Sign up is complete.\nLog in to start using the service.',
  '비밀번호가 성공적으로 변경되었습니다!\n새 비밀번호로 로그인하세요.': 'Your password has been changed successfully.\nLog in with the new password.',
  '아이디를 입력하세요.': 'Enter your ID.',
  '아이디를 입력하세요': 'Enter your ID',
  '연락처를 입력해주세요.': 'Enter your phone number.',
  '사용이 불가능한 아이디입니다.': 'This ID is not available.',
  '사용이 불가능한 비밀번호입니다.': 'This password is not allowed.',
  '비밀번호를 확인해주세요.': 'Please confirm your password.',
  '회원가입 실패: ID/EMAIL 중복이거나 서버 오류': 'Sign up failed: duplicate ID/email or server error.',
  '회원가입 성공!': 'Sign up completed.',

  // ── Password reset dialogs ─────────────────────────────────────────────────
  '비밀번호 설정': 'Set Password',
  '인증 코드': 'Code',
  '코드 4자리를 입력하세요': 'Enter the 4-digit code',
  '이메일을 입력하세요': 'Enter your email',
  '메일을 입력하세요. 등록된 메일이면 4자리 코드를 보내드립니다.': 'Enter your email. If it exists, we will send a 4-digit code.',
  '🔐 4자리 코드 입력': '🔐 Enter 4-digit code',
  '🔐 비밀번호 재설정': '🔐 Reset Password',
  '🔐 새 비밀번호 설정': '🔐 Set New Password',

  // ── Settings: profile / members ────────────────────────────────────────────
  '프로필 설정': 'Profile Settings',
  '맴버 관리': 'Member Management',
  '멤버 관리': 'Member Management',
  '승인 대기 멤버': 'Pending Members',
  '멤버등급': 'Role',
  '승인요청일자': 'Requested At',
  '승인여부선택': 'Approval',
  '승인 대기 멤버가 없습니다. 😎': 'No pending members. 😎',
  '멤버가 없습니다. 😎': 'No members found. 😎',
  '관리자': 'Admin',
  '일반': 'User',
  '변경되었습니다.': 'Updated.',
  '승인': 'Approve',
  '거절': 'Reject',
  '승인되었습니다.': 'Approved.',
  '삭제되었습니다.': 'Deleted.',
  '거절되었습니다.': 'Rejected.',
  '핸드폰': 'Mobile',
  '핸드폰 번호를 입력해주세요.': 'Enter your mobile number.',
  '연락처 변경': 'Change Phone',
  '개인 정보가 변경되었습니다.': 'Profile updated.',
  '연락처 정보가 변경되었습니다.': 'Phone number updated.',
  '비밀번호 변경': 'Change Password',
  '현재 비밀번호': 'Current Password',
  '변경할 비밀번호': 'New Password',
  '사진 변경': 'Change Photo',
  '사진 추가': 'Add Photo',
  '사진 삭제': 'Delete Photo',
  '이미지 업로드에 실패했습니다.': 'Failed to upload the image.',
  '프로필 이미지가 변경되었습니다.': 'Profile image updated.',

  // ── Device management ──────────────────────────────────────────────────────
  'DEVICE 관리': 'Device Management',
  '장치 이름': 'Device Name',
  '메모 (선택)': 'Memo (Optional)',
  '메모를 입력하세요': 'Enter a memo',
  '차량 및 인프라 장치를 등록하고 관리합니다.': 'Register and manage vehicles and infrastructure devices.',
  '수동': 'Manual',
  '차량': 'Vehicle',
  '인프라': 'Infrastructure',
  '온라인': 'Online',
  '오프라인': 'Offline',
  '등록된 위치 없음': 'No registered location',
  '등록된 디바이스가 없습니다.': 'No registered devices.',
  '차량 관리': 'Vehicle Management',
  '인프라 관리': 'Infrastructure Management',
  '등록된 차량 없음': 'No registered vehicles',
  '등록된 인프라 없음': 'No registered infrastructure',
  '이름 / 번호': 'Name / ID',
  '위치': 'Location',
  '마지막 수신': 'Last Seen',
  '직접 입력': 'Manual Input',
  '위도': 'Latitude',
  '경도': 'Longitude',
  '스테이션': 'Station',
  '스테이션을 선택하세요': 'Select a station',
  '지도에서 위치 선택': 'Pick Location on Map',
  '지도를 드래그하면 중앙 핀 위치가 실시간으로 업데이트됩니다.': 'Drag the map to update the center pin position in real time.',
  '핀 제거': 'Remove Pin',
  '레지스트리 정보가 영구 삭제됩니다.\n계속하시겠습니까?': 'The registry info will be permanently deleted.\nDo you want to continue?',
  '레지스트리 정보 및 모든 텔레메트리 데이터(이력 포함)가 영구 삭제됩니다.\n계속하시겠습니까?': 'The registry info and all telemetry history will be permanently deleted.\nDo you want to continue?',
  // Legacy vehicle/infra settings tab
  '홈 위치': 'Home Location',
  '홈 스테이션': 'Home Station',
  '고정 주소': 'Fixed Address',
  '레코드 수': 'Records',
  '주소': 'Address',
  '주소 검색': 'Search Address',
  '주소를 찾을 수 없습니다.': 'Address not found.',

  // ── Dashboard ──────────────────────────────────────────────────────────────
  '데이터 다운로드': 'Download Data',
  '내보내는 중...': 'Exporting...',
  '날짜 선택': 'Select Date',
  '먼저 다운로드할 날짜를 선택해 주세요.': 'Select a date to download first.',
  // 2026-08-10: 빈 기간 내려받기 방지 안내
  '선택한 기간에 데이터가 없습니다. 다른 날짜를 선택해 주세요.':
      'No data for the selected period. Please choose another date.',
  '내보내기에 실패했습니다. 다시 시도해 주세요.': 'Export failed. Please try again.',
  '지도': 'Map',
  '지도 열기': 'Open Map',
  '지도 닫기': 'Close Map',
  '지도 오른쪽': 'Map on Right',
  '지도 아래': 'Map Below',
  '지도 왼쪽': 'Map on Left',
  '왼쪽': 'Left',
  '오른쪽': 'Right',
  '아래': 'Bottom',
  '컬럼': 'Columns',
  '컬럼 선택': 'Select Columns',
  '전체 선택': 'Select All',
  '전체 해제': 'Deselect All',
  '최소 선택': 'Minimum',
  '최소': 'Min',
  '프리셋:': 'Presets:',
  '기본': 'Basic',
  '내비게이션': 'Navigation',
  '제어': 'Control',
  '전체': 'All',
  '객체 현황 표시': 'Show Object Status',
  '객체 현황 닫기': 'Hide Object Status',
  '차량 이력': 'Vehicle History',
  '인프라 이력': 'Infrastructure History',
  '이력': 'HISTORY',
  '고정 위치': 'Fixed Location',
  '정지': 'Stopped',
  '차량 ID': 'Vehicle ID',
  '인프라 ID': 'Infra ID',
  '식별': 'Identifiers',
  '속도/IMU': 'Speed/IMU',
  '기타': 'Other',
  '감지 객체': 'Detected Objects',
  '감지된 객체': 'Detected Objects',
  '감지된 객체가 없습니다.': 'No detected objects.',
  '# 검색': '# Search',
  // Grid column filter types
  '일치': 'Equals',
  '시작': 'Starts with',
  '끝': 'Ends with',

  // ── Object status panel / object types ─────────────────────────────────────
  '객체 현황': 'Object Status',
  '타입': 'Type',
  '분류': 'Class',
  '객체 ID': 'Object ID',
  '소스': 'Source',
  '소유 장치': 'Owner Device',
  '신뢰도': 'Confidence',
  '폭(mm)': 'Width (mm)',
  '높이(mm)': 'Height (mm)',
  '깊이(mm)': 'Depth (mm)',
  '행을 클릭하면 해당 패킷의\n감지 객체가 표시됩니다.': 'Click a row to show the\ndetected objects in that packet.',
  '미확인': 'Unknown',
  '승용차': 'Car',
  '트럭': 'Truck',
  '버스': 'Bus',
  '보행자': 'Pedestrian',
  '이륜차': 'Two-wheeler',

  // ── Map ────────────────────────────────────────────────────────────────────
  '데이터 수신 중...': 'Receiving data...',
  '차량 없음': 'No vehicles',
  '등록된 인프라가 없습니다': 'No registered infrastructure',
  '위치 정보 없음': 'No location info',
  '위치 미등록': 'Location not registered',
  '패널 펼치기': 'Expand Panel',
  '패널 숨기기': 'Hide Panel',
  '실시간 추적': 'Live Tracking',
  '추적 닫기': 'Close Tracking',
  '속도': 'Speed',
  '다음 ETA': 'Next ETA',
  '실시간 객체': 'Live Objects',
  '세션 누적': 'Session Total',
  '실시간 위치': 'Live Location',
  '출발': 'Departure',
  '현재': 'Current',
  '예상 경로': 'Expected Route',
  '남은 거리': 'Remaining Distance',
  '예상 시간': 'Estimated Time',
  '방향': 'Heading',
  '이동 중': 'Moving',
  '대기 중': 'Idle',
  '최근 패킷에 감지된 객체가 없습니다.': 'No objects detected in the latest packet.',
  '팔로우 ON': 'Follow ON',
  '팔로우 OFF': 'Follow OFF',
  '객체 ON': 'Objects ON',
  '객체 OFF': 'Objects OFF',
  // Compass directions
  '북': 'N',
  '북동': 'NE',
  '동': 'E',
  '남동': 'SE',
  '남': 'S',
  '남서': 'SW',
  '서': 'W',
  '북서': 'NW',

  // ── Activity ───────────────────────────────────────────────────────────────
  '주행 거리': 'Distance Driven',
  '이벤트': 'Events',
  '이동 시간': 'Moving Time',
  '현재 속도': 'Current Speed',
  '연결 상태': 'Connection',
  '경고': 'Warning',
  '누적 주행 거리': 'Cumulative Distance',
  '이동 거리 이력 없음': 'No distance history',
  '일별 이동 시간': 'Daily Moving Time',
  '총 이동': 'total',
  '이동 기록 없음': 'No moving records',
  '거리': 'Distance',
  '시간': 'Time',
  '선택 대기 중': 'Ready for selection',
  '왼쪽 목록에서 장치를 선택하세요': 'Select a unit from the rail',
  '차량 또는 인프라 노드를 선택하면 실시간 상태, 이동 패턴, 날씨 정보, 이벤트 타임라인을 한 화면에서 확인할 수 있습니다.':
      'Pick any vehicle or infrastructure node to open live health, motion pattern, weather context, and a readable event timeline in one operational screen.',
  '전체 장치': 'Fleet inventory',
  '전체 이벤트': 'Global feed',
  '이 화면에서 볼 수 있는 정보': 'What this deck shows',
  '단순 로그가 아닌 운영 상황 중심 정보': 'Operational context, not just raw feed lines',
  '실시간 상태 프로필': 'Live status profile',
  '연결 상태, 최근 활동, 객체 수, 좌표, 실시간 이동 요약을 보여줍니다.':
      'Connection state, last activity, object count, coordinates, and live motion summary.',
  '읽기 쉬운 타임라인': 'Readable timeline',
  '경고와 이벤트 유형을 카드로 묶어 원시 백엔드 로그보다 한눈에 파악하기 쉽습니다.':
      'Warnings and event types are grouped into cards that are easier to scan than raw backend logs.',
  '활동 추이': 'Behavior trend',
  '이동 거리 이력 또는 이벤트 활동 차트를 날씨 및 월간 정보와 함께 보여줍니다.':
      'Distance history or event activity chart stays visible next to weather and monthly context.',

  // ── Dialogs ────────────────────────────────────────────────────────────────
  '조회기간': 'Search Period',
  '조회': 'Search',
  '1일': '1 Day',
  '1주일': '1 Week',
  '1개월': '1 Month',
  '직접설정': 'Custom',
  '메시지': 'Message',
  '메시지 ID': 'Message ID',
  '타임스탬프': 'Timestamp',
  '차량 메시지': 'Vehicle Message',
  '인프라 메시지': 'Infra Message',
  '다운로드 가능한 XLS 로그 파일이 없습니다.': 'No XLS log files are available to download.',
  '로그 파일 다운로드를 시작했습니다.': 'Log file download started.',
  '로그 다운로드 중 문제가 발생했습니다.': 'A problem occurred while downloading the log.',

  // ── Stations (proper nouns, romanized; data values stay Korean) ───────────
  '대구역': 'Daegu Station',
  '동대구역': 'Dongdaegu Station',
  '수성구': 'Suseong-gu',
  '범어역': 'Beomeo Station',
  '칠성시장': 'Chilseong Market',
  '동대구': 'Dongdaegu',
  '칠성': 'Chilseong',

  // ── Server messages (backend activity worker event subtitles) ──────────────
  '텔레메트리 수신 재개': 'Telemetry resumed',
  '텔레메트리 수신 중단': 'Telemetry stopped',
  '목적지 도착': 'Arrived at destination',
  '인프라 디바이스 수신 재개': 'Infra device data resumed',
};

// Dynamic Korean server messages (backend activity worker event titles and
// subtitles). Tried by t() when there is no exact dictionary match.
final List<(RegExp, String Function(Match))> _serverPatterns =
    <(RegExp, String Function(Match))>[
  (RegExp(r'^차량 (\d+) 온라인 복귀$'), (Match m) => 'Vehicle ${m[1]} back online'),
  (RegExp(r'^차량 (\d+) 출발$'), (Match m) => 'Vehicle ${m[1]} departed'),
  (
    RegExp(r'^차량 (\d+) → (.+) 도착$'),
    (Match m) => 'Vehicle ${m[1]} arrived at ${t(m[2]!)}',
  ),
  (RegExp(r'^차량 (\d+) 과속 감지$'), (Match m) => 'Vehicle ${m[1]}: speeding detected'),
  (
    RegExp(r'^차량 (\d+) 급정거 감지$'),
    (Match m) => 'Vehicle ${m[1]}: hard braking detected',
  ),
  (RegExp(r'^차량 (\d+) 오프라인$'), (Match m) => 'Vehicle ${m[1]} offline'),
  (RegExp(r'^인프라 (\d+) 온라인 복귀$'), (Match m) => 'Infra ${m[1]} back online'),
  (RegExp(r'^인프라 (\d+) 오프라인$'), (Match m) => 'Infra ${m[1]} offline'),
  (RegExp(r'^속도 ([\d.]+) km/h$'), (Match m) => 'Speed ${m[1]} km/h'),
  (RegExp(r'^감속도 ([\d.]+) m/s²$'), (Match m) => 'Deceleration ${m[1]} m/s²'),
];

// Known English backend messages (password reset API) shown in Korean mode.
const Map<String, String> _koreanServerText = <String, String>{
  'Email is required': '메일을 입력하세요.',
  'Email not registered': '등록되지 않은 메일입니다.',
  'Fields missing': '필수 입력 항목이 누락되었습니다.',
  'No reset code for this email': '이 메일로 발급된 인증번호가 없습니다.',
  'Invalid code': '인증번호가 올바르지 않습니다.',
  'Code expired': '인증번호가 만료되었습니다.',
  'Invalid verify token': '인증 정보가 유효하지 않습니다. 인증을 다시 진행하세요.',
  'Failed to update password': '비밀번호 변경에 실패했습니다.',
  'exception occurred': '서버 오류가 발생했습니다.',
};

/// Read-only view of the Korean → English dictionary (used by the i18n
/// coverage test to verify that every t('…') key has a translation).
Map<String, String> get englishDictionary => _englishText;

/// Inline translation for interpolated or one-off text.
String l10n(String korean, String english) {
  return Get.locale?.languageCode == 'en' ? english : korean;
}

/// Translates a Korean source string for the current locale. Unknown strings
/// (user data, addresses) come back unchanged; known dynamic server messages
/// are translated by pattern.
String t(String korean) {
  if (!isEnglishLocale) return korean;
  final String? exact = _englishText[korean];
  if (exact != null) return exact;
  for (final (RegExp pattern, String Function(Match) build) in _serverPatterns) {
    final Match? match = pattern.firstMatch(korean);
    if (match != null) return build(match);
  }
  return korean;
}

/// Marks a Korean source string as a translation key without translating it.
/// Store the result (e.g. a validation message in a State field) and pass it
/// through t() when rendering, so the text follows later locale changes.
String tKey(String korean) => korean;

/// Server-provided message for display: Korean backend texts go through t(),
/// known English backend error texts are shown in Korean in Korean mode.
String serverText(String? message) {
  final String text = message?.trim() ?? '';
  if (text.isEmpty) return '';
  if (isEnglishLocale) return t(text);
  return _koreanServerText[text] ?? text;
}

bool get isEnglishLocale => Get.locale?.languageCode == 'en';
