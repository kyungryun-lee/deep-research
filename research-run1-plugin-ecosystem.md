# Claude Code 플러그인 생태계 — 현재 상태, 주요 플러그인, 개발 패턴, 향후 방향

**작성일**: 2026-04-25
**리서치 방법**: 3개 병렬 에이전트 (Ecosystem Surveyor, Development Pattern Analyst, Future Direction Explorer)
**품질 점수**: 82/100 (S/A 소스 18건)
**소스**: 25건 (S: 12, A: 5, B: 8)

---

## 1. 플러그인 생태계 현황

### 공식 플러그인 구성

Claude Code 플러그인 생태계는 2026년 초 공식 출시되어 빠르게 성장 중:

- **LSP 언어 서버** (12개): C/C++, C#, Go, Java, Kotlin, Lua, PHP, Python, Rust, Swift, TypeScript — 각 언어별 코드 인텔리전스
- **외부 통합** (12개): GitHub, GitLab, Atlassian, Asana, Linear, Notion, Figma, Vercel, Firebase, Supabase, Slack, Sentry — MCP 서버 번들
- **워크플로우** (6개): commit-commands, pr-review-toolkit, agent-sdk-dev, plugin-dev 등
- **출력 스타일** (2개): explanatory-output-style, learning-output-style
- **인기 플러그인**: Frontend Design, Context7, Code Review, Playwright, Feature Dev (설치 수 100K-500K+)

**출처**: https://code.claude.com/docs/en/discover-plugins [S], https://claude.com/plugins [S]

### MCP 서버 레지스트리

22개 상업용 MCP 서버 등록, 20/22개가 Claude Code 호환:
Amplitude, Atlassian Rovo, Figma, Linear, Notion, PayPal, Stripe, Supabase, Vercel 등

**출처**: https://api.anthropic.com/mcp-registry/v0/servers [S]

### 커뮤니티 생태계

- **Agent Skills 오픈 표준**: Anthropic이 개발 후 개방, **34개+ AI 도구**가 채택 (GitHub Copilot, Cursor, OpenAI Codex, Gemini CLI, JetBrains Junie 등)
- **커뮤니티 규모**: 4,200+ 스킬, 770+ MCP 서버, awesome-claude-plugins (1.5k stars)
- **디렉토리**: claudemarketplaces.com (월 110K 방문), claudepluginhub.com

**출처**: https://agentskills.io [A], https://github.com/ComposioHQ/awesome-claude-plugins [A]

---

## 2. 플러그인 개발 패턴

### 플러그인 구조

```
Plugin/
├── .claude-plugin/plugin.json    # 매니페스트 (name, version, author)
├── skills/<name>/SKILL.md        # 프론트매터 + 지시사항
├── agents/<name>.md              # 서브에이전트 시스템 프롬프트
├── hooks/hooks.json              # 이벤트 훅 (20+ 이벤트 타입)
├── .mcp.json                     # 번들 MCP 서버
├── .lsp.json                     # LSP 서버
├── monitors/monitors.json        # 백그라운드 모니터
├── bin/                          # PATH 실행 파일
└── settings.json                 # 기본 설정
```

**출처**: https://code.claude.com/docs/en/plugins [S]

### SKILL.md 사양

Agent Skills 오픈 표준 기반, Anthropic 확장:
- **프론트매터**: name, description, when_to_use, allowed-tools, model, effort, context, agent
- **동적 컨텍스트**: `` !`command` `` 셸 명령 전처리
- **네임스페이스**: 플러그인 이름 접두사 (`/plugin-name:skill-name`)
- **자동 압축**: 스킬당 5,000 토큰, 전체 25,000 토큰 예산

**출처**: https://code.claude.com/docs/en/skills [S]

### Hook 시스템

5가지 핸들러: command, http, mcp_tool, prompt, agent
- **PreToolUse**: allow/deny/ask/defer + 입력 변경 가능
- **PostToolUse**: 컨텍스트 주입, MCP 출력 오버라이드
- 20+ 이벤트 타입 (SessionStart~StopFailure)

**출처**: https://code.claude.com/docs/en/hooks [S]

### MCP 통합

3가지 전송: stdio (로컬), http (원격, 권장), sse (폐기 예정)
- OAuth 2.0 지원, 자동 재연결 (HTTP), list_changed 동적 업데이트
- MCP Tool Search: 지연 로딩으로 컨텍스트 사용량 **95% 감소**

**출처**: https://code.claude.com/docs/en/mcp [S]

---

## 3. 경쟁 도구 비교

| 차원 | Claude Code | Cursor | Windsurf |
|------|-----------|--------|----------|
| 확장 체계 | Skills/MCP/Hooks/Plugins | VS Code 확장 (48K) | VS Code 확장 (45K) |
| IDE 지원 | Terminal + VS Code + JetBrains + Desktop + Web + iOS | VS Code only | 40+ IDE |
| 컨텍스트 | 1M 토큰 | 200K | 200K |
| 에이전트 | Dispatch, Remote Control, Ultraplan | 병렬 에이전트 | Cascade |
| 가격 | Max/Team/Enterprise | $20/월 | $20/월 |

**핵심 차별화**: Claude Code는 IDE에 종속되지 않는 프로그래밍 가능한 확장 체계. OpenAI의 codex-plugin-cc가 Claude Code 안에서 동작하는 크로스 벤더 호환 사례 출현.

**출처**: https://builder.io/blog/cursor-vs-claude-code [B], https://nxcode.io [B]

---

## 4. 향후 방향

### 연구 프리뷰 기능 (2026 Q1-Q2)
- **Ultraplan**: CLI에서 클라우드 플랜 작성 → 브라우저 편집 → 원격 실행
- **Computer Use**: 네이티브 앱 열기/클릭/UI 검증 (설정 불필요)
- **Auto Mode**: ML 분류기가 권한 프롬프트 자율 처리
- **Monitor 도구**: 백그라운드 이벤트 스트리밍 (CI/로그)

**출처**: https://code.claude.com/docs/en/whats-new [S]

### 보안 과제
- 커뮤니티 보고: 1,184개 악성 스킬, 36% 프롬프트 인젝션 의심 (미검증 C급)
- 대응: Signet (Ed25519 서명), Sentinel AI (인젝션 스캐너), SkillSafe (네임스페이스 소유권)
- 요청: 공식 마켓플레이스 + 보안 스캐닝 + 코드 서명 (GitHub #30727)

**출처**: https://github.com/anthropics/claude-code/issues/30727 [A]

### 엔터프라이즈 방향
- Desktop Extensions (.mcpb): 원클릭 설치 가능한 MCP 패키지
- MDM/GPO 제어: 사전 설치, 차단 목록, OS 키체인 저장
- Claude Design → Claude Code 핸드오프: 디자인-코드 워크플로우 통합

**출처**: https://anthropic.com/engineering/desktop-extensions [A]

---

## Core Facts 검증

| ID | 주장 | 검증 결과 |
|----|------|----------|
| CF-101 | Claude Code 98.4% 결정론적 인프라 코드 | 확인 — 플러그인 인프라 모두 결정론적 코드로 구현 |
| CF-102 | 프롬프트 캐싱 50%+ 절감 | 확인 — 5분/1시간 TTL, 읽기 0.1x 비용 |
| CF-103 | 모델 라우팅 40% 비용 절감 | 확인 — SKILL.md model 필드 + settings.json modelOverrides |
