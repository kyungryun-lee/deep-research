"""Shared text utilities for Deep Research bin/ scripts.

Single source of truth for tokenization, cosine similarity, STOPWORDS,
and URL normalization. Callers pass options to preserve their original
semantics (NFC normalize on/off, stopword filter on/off, min length, set/list).

Usage from a heredoc'd Python block:

    python3 - "$PLUGIN_DIR/bin/lib" ... << 'PYEOF'
    import sys, os
    sys.path.insert(0, sys.argv[1])
    from dr_text import tokenize, cosine, STOPWORDS_EN
    # remaining args at sys.argv[2:]
    PYEOF
"""

import math
import re
import unicodedata
from collections import Counter
from urllib.parse import urlparse


KOREAN_TOKEN_PATTERN = r'[a-z0-9가-힣]+'

STOPWORDS_EN = frozenset({
    'the', 'a', 'an', 'is', 'are', 'was', 'were', 'be', 'been', 'being',
    'have', 'has', 'had', 'do', 'does', 'did', 'will', 'would', 'could',
    'should', 'may', 'might', 'can', 'need', 'to', 'of', 'in', 'for',
    'on', 'with', 'at', 'by', 'from', 'as', 'and', 'but', 'or', 'not',
    'so', 'if', 'that', 'this', 'it', 'its', 'i', 'we', 'they', 'what',
    'which', 'who', 'how', 'where', 'when', 'why', 'all', 'each', 'both',
    'some', 'most', 'other', 'about', 'into', 'through', 'during',
    'before', 'after', 'between', 'up', 'down', 'out', 'off', 'over',
    'very', 'just', 'also', 'more', 'only', 'than', 'then', 'too',
})

STOPWORDS_EXTENDED = STOPWORDS_EN | frozenset({
    'shall', 'dare', 'ought', 'used', 'these', 'those', 'them', 'their',
    'our', 'your', 'he', 'she', 'him', 'her', 'whom', 'every', 'few',
    'such', 'no', 'nor', 'above', 'below', 'under', 'again', 'further',
    'once', 'rarely', 'hardly', 'fewer', 'lower',
})

# Negation / polarity tokens (used by dr-contradict for conflict detection)
NEGATION_EN = frozenset({
    'not', 'no', 'never', 'without', 'lack', 'fail', 'cannot', 'dont',
    'doesnt', 'isnt', 'arent', 'wont', 'shouldnt', 'unable', 'impossible',
    'neither', 'nor', 'rarely', 'hardly', 'fewer', 'worse', 'slower',
    'less', 'lower', 'decrease', 'decline', 'drop', 'reduce',
})
NEGATION_KO = frozenset({
    '없', '아닌', '불가', '못', '실패', '부족', '감소', '하락',
    '저하', '약화', '제한', '불가능', '어려', '않',
})
NEGATIONS = NEGATION_EN | NEGATION_KO

COMPARATIVES_POS = frozenset({
    'faster', 'better', 'higher', 'more', 'outperform', 'superior',
    'improve', 'increase', 'exceed', 'surpass',
    '빠른', '우수', '향상',
})
COMPARATIVES_NEG = frozenset({
    'slower', 'worse', 'lower', 'less', 'underperform', 'inferior',
    'decrease', 'decline', 'lag',
    '느린', '열등', '저하',
})


def tokenize(text, *, normalize=True, stopwords=None, min_len=2, as_set=False):
    """Unified tokenizer.

    - normalize=True applies NFC unicode normalization (Korean composed/decomposed).
    - stopwords=None skips stopword filtering; pass a set/frozenset to filter.
    - min_len filters tokens shorter than this (0/1 keeps everything).
    - as_set=True returns a set instead of a list.
    """
    if normalize:
        text = unicodedata.normalize('NFC', text)
    tokens = re.findall(KOREAN_TOKEN_PATTERN, text.lower())
    if stopwords is not None:
        tokens = [t for t in tokens if t not in stopwords and len(t) >= min_len]
    elif min_len > 1:
        tokens = [t for t in tokens if len(t) >= min_len]
    return set(tokens) if as_set else tokens


def cosine(a, b):
    """Cosine similarity for two token iterables (Counter-based)."""
    if not a or not b:
        return 0.0
    ca, cb = Counter(a), Counter(b)
    vocab = set(ca) | set(cb)
    dot = sum(ca.get(w, 0) * cb.get(w, 0) for w in vocab)
    ma = math.sqrt(sum(v ** 2 for v in ca.values()))
    mb = math.sqrt(sum(v ** 2 for v in cb.values()))
    return dot / (ma * mb) if ma and mb else 0.0


def normalize_url(url):
    """URL normalization for dedup comparison (matches dr-dedup cmd_urls semantics)."""
    url = url.rstrip('.,;:)')
    parsed = urlparse(url)
    host = re.sub(r'^www\.', '', parsed.hostname or '')
    path = parsed.path.rstrip('/')
    return f"https://{host}{path}"
