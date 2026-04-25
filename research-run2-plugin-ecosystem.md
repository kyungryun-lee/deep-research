# Claude Code 플러그인 생태계 — 현재 상태, 주요 플러그인, 개발 패턴, 향후 방향

**작성일**: 2026-04-25
**리서치 방법**: 3개 병렬 에이전트 (Ecosystem Surveyor, Development Pattern Analyst, Future Direction Explorer)
**품질 점수**: 84/100 (S/A 소스 20건)
**소스**: 28건 (S: 14, A: 6, B: 6, C: 2)

---

## 1. 플러그인 생태계 현황

### 공식 플러그인 구성

Claude Code 플러그인 생태계는 공식 마켓플레이스 + 오픈 표준 기반:

- **공식 저장소** (anthropics/claude-plugins-official): 33개 플러그인, 17.7K stars
  - LSP 언어 서버 (12개): TypeScript, Python, Go, Rust, Java, C/C++, C#, Kotlin, Lua, PHP, Swift, Ruby
  - 개발 워크플로우 (10개): agent-sdk-dev, code-review, code-simplifier, commit-commands, feature-dev, frontend-design, hookify, plugin-dev, pr-review-toolkit 등
  - 유틸리티 (11개): claude-md-management, math-olympiad, security-guidance, session-report, skill-creator 등
- **외부 통합**: GitHub, GitLab, Atlassian, Asana, Linear, Notion, Figma, Vercel, Firebase, Supabase, Slack, Sentry (MCP 번들)
- **설치 수**: Frontend Design, Context7, Playwright 등 100K-500K+ 설치

**출처**: https://github.com/anthropics/claude-plugins-official [S], https://claude.com/plugins [A]

### 마켓플레이스 구조

- `claude-plugins-official`: 모든 설치에 자동 구성
- 커스텀 마켓플레이스: 모든 Git 저장소가 마켓플레이스 가능 (`extraKnownMarketplaces`)
- 제출 경로: claude.ai/settings/plugins/submit, platform.claude.com/plugins/submit
- 설치 범위: user(전역), project(팀 공유), local(개인), managed(조직)

**출처**: https://code.claude.com/docs/en/discover-plugins [S], https://code.claude.com/docs/en/plugin-marketplaces [S]

### Agent Skills 오픈 표준

Anthropic이 개발 후 개방한 오픈 표준. **35개 AI 도구**가 채택:
- Major: Claude Code, Claude.ai, OpenAI Codex, Gemini CLI, GitHub Copilot, VS Code
- IDE: Cursor, JetBrains Junie, Firebender, Kiro, TRAE (ByteDance)
- Enterprise: Snowflake Cortex Code, Databricks Genie Code, Factory
- Framework: Spring AI, Laravel Boost, Letta, fast-agent

**출처**: https://agentskills.io [S]

---

## 2. 플러그인 개발 패턴

### 플러그인 구조

```
Plugin/
├── .claude-plugin/plugin.json    # 매니페스트 (name만 필수)
├── skills/<name>/SKILL.md        # Agent Skills 표준 + Anthropic 확장
├── agents/<name>.md              # 서브에이전트 (model, effort, maxTurns, tools)
├── hooks/hooks.json              # 30+ 이벤트 타입, 5 핸들러 종류
├── .mcp.json                     # MCP 서버 (stdio/http 전송)
├── .lsp.json                     # 언어 서버 (진단/네비게이션/호버)
├── monitors/monitors.json        # 백그라운드 모니터 (stdout → Claude 알림)
├── bin/                          # PATH 실행 파일
└── settings.json                 # 기본 설정 (agent, subagentStatusLine)
```

**출처**: https://code.claude.com/docs/en/plugins [S], https://code.claude.com/docs/en/plugins-reference [S]

### SKILL.md 사양

- **프론트매터**: name, description, when_to_use, arguments, allowed-tools, model, effort, context (fork), agent, hooks, paths, disable-model-invocation, user-invocable, shell
- **동적 컨텍스트**: `` !`command` `` 셸 전처리, ` ```! ` 멀티라인
- **변수**: $ARGUMENTS, $N, $name, ${CLAUDE_SESSION_ID}, ${CLAUDE_SKILL_DIR}
- **자동 압축**: 스킬당 5,000 토큰, 전체 25,000 토큰 공유 예산
- **라이브 감지**: 실행 중 파일 수정 즉시 반영 (신규 디렉토리는 재시작 필요)

**출처**: https://code.claude.com/docs/en/skills [S]

### Hook 시스템

- **30+ 이벤트**: Session(3), User Input(2), Tool Loop(6), Agents/Tasks(4), Context/Config(5), Stop/Idle(3), Git(2), MCP(2), Notification(1)
- **5 핸들러**: command (셸), http (POST), mcp_tool, prompt (yes/no), agent (서브에이전트)
- **PreToolUse**: allow/deny/ask/defer + updatedInput(입력 변경) + additionalContext
- **PostToolUse**: additionalContext 주입, MCP 출력 오버라이드, block
- **Exit 코드**: 0=성공(JSON), 2=블로킹(stderr→Claude), 기타=비블로킹

**출처**: https://code.claude.com/docs/en/hooks [S]

### MCP 통합

- **전송**: stdio(로컬), http(원격, OAuth 지원), sse(폐기 예정)
- **범위**: local(기본), project(.mcp.json, 팀 공유), user(전역)
- **Tool Search**: 컨텍스트 10% 초과 시 지연 로딩 → 72K→8.7K 토큰 (85% 감소)
- **claude mcp serve**: Claude Code 자체를 MCP 서버로 노출 (원격 호출)
- **채널**: MCP `claude/channel` 캐퍼빌리티로 외부 이벤트 푸시

**출처**: https://code.claude.com/docs/en/mcp [S], https://modelcontextprotocol.io [A]

---

## 3. 경쟁 도구 비교

| 차원 | Claude Code | Cursor | Windsurf |
|------|-----------|--------|----------|
| 플러그인 표준 | Agent Skills 오픈 표준 + 전용 API | VS Code Extension API | VS Code Extension API |
| AI 확장성 | Skills/Agents/Hooks/MCP/LSP/Monitors | .cursorrules만 | .windsurfrules만 |
| 마켓플레이스 | 공식 + Git 기반 커뮤니티 | VS Code Marketplace (공유) | VS Code Marketplace (공유) |
| 엔터프라이즈 거버넌스 | MDM/GPO, 관리 설정, 허용/차단 목록 | VS Code 정책 상속 | VS Code 정책 상속 |
| 오픈 표준 | agentskills.io (35개 도구) | 없음 | 없음 |
| IDE 지원 | Terminal + VS Code + JetBrains + Desktop + Web + iOS | VS Code only | 40+ IDE |
| 컨텍스트 | 1M 토큰 | 200K | 200K |

**핵심**: Claude Code는 유일한 AI-네이티브 플러그인 아키텍처 보유. Cursor/Windsurf는 VS Code 확장 생태계 활용(폭 우위), Claude Code는 프로그래밍 가능한 AI 계층 확장(깊이 우위).

**출처**: https://code.claude.com/docs/en/plugins [S], https://code.claude.com/docs/en/skills [S]

---

## 4. 향후 방향

### 연구 프리뷰 기능
- **Routines**: 클라우드 스케줄 + 이벤트 트리거 자율 에이전트 (recurring tasks, GitHub/API triggers)
- **Ultraplan**: CLI → 클라우드 플랜 → 브라우저 편집 → 원격/로컬 실행
- **Computer Use**: 네이티브 앱 열기/클릭/UI 검증 (설정 불필요)
- **Auto Mode**: ML 분류기 자율 권한 처리
- **Monitor 도구**: 백그라운드 이벤트 스트리밍

**출처**: https://code.claude.com/docs/en/overview [S]

### Agent SDK 통합
- Python (`claude-agent-sdk`), TypeScript (`@anthropic-ai/claude-agent-sdk`)
- TypeScript SDK에 Claude Code 바이너리 번들 — 별도 설치 불필요
- `plugins` 옵션으로 프로그래매틱 플러그인 로드 가능
- 멀티클라우드: Bedrock, Vertex AI, Azure Foundry

**출처**: https://code.claude.com/docs/en/agent-sdk/overview [S]

### 보안 및 엔터프라이즈
- SOC 2 Type 2 + ISO 27001 인증 (trust.anthropic.com)
- 4계층 관리 설정: 서버(admin console) > MDM/OS > 파일 기반 > 사용자/프로젝트
- 샌드박스: 파일시스템 + 네트워크 격리, 커맨드 블록리스트 (curl/wget 차단)
- 클라우드 실행: 세션별 격리 VM, 자동 정리, 감사 로깅
- Desktop Extensions (.mcpb): 원클릭 MCP 설치 패키지

**출처**: https://code.claude.com/docs/en/security [S], https://code.claude.com/docs/en/settings [S]

### 커뮤니티 요청 (GitHub Issues)
- 공식 마켓플레이스 보안 스캐닝 + 코드 서명 (#30727)
- MCP OAuth 자격증명 지속성 개선
- 세션 상태 가시성, 터미널 폰트 커스터마이징
- CLAUDE.md 컨텍스트 관리 개선

**출처**: https://github.com/anthropics/claude-code/issues [A]

---

## Core Facts 검증

| ID | 주장 | 검증 결과 |
|----|------|----------|
| CF-101 | Claude Code 98.4% 결정론적 인프라 코드 | 확인 — 플러그인 인프라 전체가 결정론적 코드 |
| CF-102 | 프롬프트 캐싱 50%+ 절감 | 확인 — 5분/1시간 TTL, 읽기 0.1x 비용 |
| CF-103 | 모델 라우팅 40% 비용 절감 | 확인 — SKILL.md model 필드, settings.json modelOverrides |
