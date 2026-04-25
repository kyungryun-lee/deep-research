---
name: setup
description: >
  Deep Research 플러그인 환경 설정 도우미. 설치 후 최초 실행 시 필요한 환경을 
  자동 점검하고, 권한/설정/디렉토리를 안내합니다.
  "설정", "setup", "초기 설정", "환경 확인" 등의 요청 시 자동 호출.
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Glob
argument-hint: "[check | configure | reset]"
---

# Deep Research Setup Assistant

사용자의 환경을 점검하고 플러그인 사용을 위한 설정을 안내합니다.

## 명령어

- `/deep-research:setup` 또는 `/deep-research:setup check` — 환경 점검
- `/deep-research:setup configure` — 대화형 설정
- `/deep-research:setup reset` — 설정 초기화

---

## check (기본)

아래 항목을 순서대로 점검하고 결과를 표로 출력합니다.

### 0. 자동 의존성 점검 (신규)

아래 명령을 **자동으로 실행**하여 필수 의존성을 점검합니다:

```bash
# Python3 버전 및 필수 모듈
python3 --version 2>/dev/null && python3 -c "import json, re, math, collections, hashlib" 2>/dev/null && echo "PYTHON_OK" || echo "PYTHON_FAIL"

# md5sum (캐시 해시에 사용)
md5sum --version >/dev/null 2>&1 && echo "MD5_OK" || md5sum /dev/null >/dev/null 2>&1 && echo "MD5_OK" || echo "MD5_FAIL"

# bin/ 스크립트 실행 권한
for BIN in dr-tokens dr-cache dr-classify dr-normalize dr-score dr-verify dr-knowledge; do
  [ -x "${CLAUDE_PLUGIN_DIR:-$(cd "$(dirname "$0")/../.." && pwd)}/bin/$BIN" ] && echo "$BIN: OK" || echo "$BIN: NOT EXECUTABLE"
done
```

점검 결과 처리:
- `PYTHON_FAIL`: FAIL + `brew install python3` 또는 `apt install python3` 안내
- `MD5_FAIL`: WARN + macOS에서 `md5 -r` 대안 안내 (md5sum은 GNU coreutils 필요)
- `NOT EXECUTABLE`: FAIL + `chmod +x bin/{name}` 명령 안내

### 1. Claude Code 버전 확인
```bash
claude --version
```
- v2.1.30 이상이면 PASS
- 미만이면 WARN + 업그레이드 안내

### 2. 플러그인 로드 확인
현재 세션에서 deep-research 플러그인이 로드되었는지 확인합니다.
- `/deep-research:research` 명령이 인식되면 PASS
- 안 되면 FAIL + 설치 방법 안내

### 3. 메모리 디렉토리 확인
```bash
ls -la "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/deep-research}/memory/" 2>/dev/null
```
- 디렉토리 존재하면 PASS
- 없으면 자동 생성 안내 (첫 실행 시 자동 생성됨)

### 4. 도구 권한 확인
필요한 도구: WebSearch, WebFetch, Agent, Read, Write
- 사용자에게 필요한 권한 목록을 안내합니다
- 자동 승인 설정 방법을 안내합니다

### 5. 기존 세션 데이터 확인
```bash
wc -l "${CLAUDE_PLUGIN_DATA:-$HOME/.claude/plugins/data/deep-research}/memory/sessions.jsonl" 2>/dev/null
```
- 파일이 있으면 기존 학습 데이터 건수 표시
- 없으면 "첫 실행 — 학습 데이터가 축적되면 점점 좋아집니다" 안내

### 출력 형식
```
[Deep Research Setup Check]

| 항목 | 상태 | 상세 |
|------|------|------|
| Claude Code 버전 | ✅ PASS | v2.1.97 |
| 플러그인 로드 | ✅ PASS | deep-research v1.0.0 |
| 메모리 디렉토리 | ✅ PASS | ~/.claude/plugins/data/deep-research/memory/ |
| 도구 권한 | ⚠️ INFO | WebSearch, WebFetch 권한 필요 (첫 실행 시 승인) |
| 학습 데이터 | ℹ️ | 0건 (첫 실행) |

모든 항목이 정상입니다. /deep-research:research "질문" 으로 시작하세요!
```

문제가 있는 항목이 있으면 해결 방법을 구체적으로 안내합니다.

---

## configure

대화형으로 사용자 설정을 구성합니다.

### 설정 항목

1. **기본 리서치 깊이** (surface / standard / deep)
   - "빠른 조회가 많으면 surface, 심층 조사가 많으면 deep을 추천합니다"

2. **기본 평가 기준** (default / academic / practical / trend)
   - "학술 논문 조사가 주 업무면 academic"
   - "구현 방법 조사가 주 업무면 practical"
   - "시장/기술 동향 파악이 주 업무면 trend"

3. **최대 반복 횟수** (1-5)
   - "1: 빠르지만 품질 보증 없음"
   - "3: 권장 (품질-비용 균형)"
   - "5: 최고 품질, 시간 소요 많음"

4. **보고서 기본 저장 경로**
   - 기본값: 현재 디렉토리
   - 프로젝트별 고정 경로 설정 가능

### 설정 저장
사용자의 선택을 확인한 후, 설정을 안내합니다:

```
설정이 완료되었습니다. 다음 내용을 settings.json에 추가하세요:

[개인 설정] ~/.claude/settings.json:
{
  "plugins": {
    "deep-research": {
      "config": {
        "default_depth": "standard",
        "default_rubric": "practical",
        "max_iterations": "3",
        "output_dir": "./research-reports"
      }
    }
  }
}
```

---

## reset

메모리와 설정을 초기화합니다.

1. 사용자에게 확인: "학습 데이터(N건)와 설정을 초기화합니다. 계속할까요?"
2. 확인 시:
   - `${CLAUDE_PLUGIN_DATA}/memory/sessions.jsonl` 삭제
   - 설정 초기화 안내
3. "초기화 완료. 다음 리서치부터 새로 학습을 시작합니다."
