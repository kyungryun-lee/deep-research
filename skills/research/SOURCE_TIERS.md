# 소스 등급 기준 (Single Source of Truth)

모든 에이전트(Worker, Evaluator)와 rubric이 참조하는 단일 등급 정의입니다.

| 등급 | 기준 | 예시 |
|------|------|------|
| **S** | 공식 문서 + 프로덕션 검증 GitHub (v1.0+, 활발한 유지보수). peer-reviewed 학술지 (NeurIPS/ICML/ICLR/ACL) | Anthropic docs, Python docs, React docs |
| **A** | 기업 엔지니어링 블로그 (실적용 사례) + 코드 동반 arXiv 프리프린트 + 벤치마크 분석 | Cloudflare Engineering, arXiv 2025+ with code |
| **B** | 개발자 블로그 (개인), 커뮤니티 토론, 산업 보고서, 코드 미동반 arXiv | HackerNews, Medium (개인), Stack Overflow |
| **C** | 일반 블로그, 마케팅 자료, 비검증 통계, SEO 콘텐츠 | 제품 비교 사이트, 광고성 콘텐츠 |

**주의**: arXiv 프리프린트는 최대 A등급. S등급은 peer-reviewed 학술지와 공식 문서만 해당.
