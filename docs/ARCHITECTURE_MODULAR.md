# CryptoPredictor 모듈화 아키텍처 제안

> 상태: **초안 (Draft)** · 작성: 2026-04-20 · 진행 시점: **미정 (나중 진행)**
>
> 전제: 현재 Phase 1 확장 + Phase 2 XGB v2 튜닝 완료 상태. P1 마감(#129) 이후 착수 권장.

---

## 1. 왜 모듈화를 하나

### 현재 구조의 한계

현재 CryptoPredictor 는 "스크립트가 많이 모여있는 상태"이지 "모듈화된 시스템"은 아니다:

- 신규 기능(LunarCrush 실시간, 뉴스 이벤트, 1D 타임프레임 등) 추가 시 **detection / feature / model 3단계를 모두 수정**해야 함
- `expand_universe.sh` 같은 오케스트레이션 파일이 기능 추가마다 복잡해짐
- 스크립트 하나 고장나면 전체 파이프라인 중단
- Python ↔ Node 혼재로 데이터 주고받기가 암묵적 (파일 경로 합의로 동작)
- 개별 기능 단위 테스트 어려움
- 모델 교체(XGBoost → LightGBM) 같은 실험 비용이 큼

### 모듈화 후 기대 효과

| 작업 | 현재 | 모듈화 후 |
|---|---|---|
| LunarCrush 감정 피처 추가 | detection/feature/model 3군데 수정 | `modules/features/social_aggregates/` 폴더만 만들고 config 한 줄 |
| XGBoost → LightGBM 교체 | tune_xgboost.py 전체 재작성 | `modules/models/lgbm_touch/` 추가 후 config 교체 |
| 1D 타임프레임 추가 | OHLCV 페치부터 detection까지 흩뿌려 수정 | 기존 모듈 TF 인자만 확장 |
| 뉴스 이벤트 연동 | 신규 스크립트 + 호출 포인트 찾아 연결 | `modules/sources/cryptopanic/` + config |
| 모듈 하나 고장 | 전체 파이프라인 멈춤 | 해당 모듈만 skip, 나머지 계속 |
| 단위 테스트 | 힘듦 (통합 필요) | 모듈 단위 가능 |

---

## 2. 제안 구조

```
CryptoPredictor/
├── core/                         # 오케스트레이터 (얇게 유지)
│   ├── orchestrator.py           # DAG 실행 엔진
│   ├── registry.py               # 모듈 로딩/발견
│   ├── contracts.py              # 공통 스키마 정의
│   └── health.py                 # 모듈 상태 체크
│
├── modules/
│   ├── sources/                  # 외부 데이터 수집
│   │   ├── binance_ohlcv/        # (기존 fetch_klines.py 이식)
│   │   ├── lunarcrush_social/    # 신규
│   │   ├── fear_greed/           # 신규 (무료)
│   │   └── cryptopanic_news/     # 신규 (무료)
│   │
│   ├── features/                 # 피처 엔지니어링
│   │   ├── technical_indicators/ # SMA/ATR/RSI (기존 분산 로직 통합)
│   │   ├── zone_detection/       # 컨플루언스 존 (기존 detection.mjs)
│   │   ├── multi_tf_align/       # P1-b 정렬 메타
│   │   └── social_aggregates/    # 신규 (감정 집계)
│   │
│   ├── models/                   # ML/통계 모델
│   │   ├── xgb_touch_v2/         # 존 터치 확률 (현재 프로덕션)
│   │   ├── linear_direction/     # 방향 예측 (기존 predictor/)
│   │   └── ensemble/             # 조합기 (선택)
│   │
│   ├── signals/                  # 결정 로직
│   │   ├── whitelist_filter/     # walk-forward 페어 선별
│   │   ├── regime_filter/        # 월별 레짐
│   │   └── alert_rules/          # 강도·시그널수 필터
│   │
│   └── outputs/                  # 최종 출력
│       ├── desktop_notify/       # macOS 알림
│       ├── markdown_report/      # reports/*.md
│       └── html_dashboard/       # crypto-analyzer.html 갱신
│
├── config/
│   ├── pipeline.yaml             # 어떤 모듈을 어떤 순서로
│   └── modules/                  # 모듈별 세부 설정
│       ├── binance_ohlcv.yaml
│       ├── xgb_touch_v2.yaml
│       └── ...
│
├── data/                         # 모듈 간 공유 저장소 (기존 backtest/data와 통합)
│   ├── raw/
│   ├── features/
│   └── predictions/
│
└── tests/
    ├── contracts/                # 스키마 검증
    └── modules/                  # 모듈별 단위 테스트
```

---

## 3. 모듈 표준 인터페이스

모든 모듈은 동일한 계약을 따른다. 언어별 entry point:

- Python: `modules/<category>/<name>/module.py` → class 상속
- Node: `modules/<category>/<name>/module.mjs` → export default

### 3.1 Python 예시

```python
# modules/sources/binance_ohlcv/module.py
from core.contracts import SourceModule, ModuleManifest

class BinanceOHLCV(SourceModule):
    manifest = ModuleManifest(
        name="binance_ohlcv",
        version="1.0",
        language="python",
        inputs=[],                              # 외부 API
        outputs=["data/raw/{symbol}_{tf}.parquet"],
        dependencies=[],
        config_schema="config/modules/binance_ohlcv.yaml",
    )

    def run(self, config: dict, ctx: RunContext) -> RunResult:
        # 증분 페치 + 저장
        return RunResult(
            status="success",
            artifacts=["data/raw/BTCUSDT_1h.parquet", ...],
            metrics={"rows_fetched": 26280, "duration_s": 12.3},
        )

    def health_check(self) -> HealthStatus:
        # API 응답 체크
        return HealthStatus(ok=True, message="Binance reachable")
```

### 3.2 Node 예시

```javascript
// modules/features/zone_detection/module.mjs
import { FeatureModule } from '../../../core/contracts.mjs';

export default class ZoneDetection extends FeatureModule {
    static manifest = {
        name: "zone_detection",
        version: "2.0",
        language: "node",
        inputs: ["data/raw/{symbol}_{tf}.parquet"],
        outputs: ["data/features/zones_{symbol}_{tf}.parquet"],
        dependencies: ["technical_indicators >= 1.0"],
    };

    async run(config, ctx) {
        // walk-forward zone detection
    }
}
```

### 3.3 공통 계약

각 모듈이 반드시 제공해야 할 것:

| 항목 | 설명 |
|---|---|
| `manifest` | 이름, 버전, I/O, 의존성 선언 |
| `run(config, ctx)` | 메인 실행 로직, RunResult 반환 |
| `health_check()` | 의존 자원 (API, DB) 상태 체크 |
| `schema` | 입출력 데이터의 JSON Schema 또는 Parquet 스키마 |
| `tests/` | 단위 테스트 (최소 smoke test) |

### 3.4 RunResult 구조

```python
@dataclass
class RunResult:
    status: Literal["success", "partial", "failed", "skipped"]
    artifacts: list[str]      # 생성된 파일 경로
    metrics: dict[str, float] # 수행 지표 (실행시간, 행수 등)
    errors: list[str]         # 치명적 에러
    warnings: list[str]       # 비치명적 경고
```

---

## 4. 설정 기반 파이프라인

### 4.1 `config/pipeline.yaml`

```yaml
# 스케줄 (launchd/cron 과 연동)
schedule: "*/15 * * * *"   # 15분마다

# 전역 설정
globals:
  symbols: [BTCUSDT, ETHUSDT, SOLUSDT, ...]   # 31개
  timeframes: [1h, 4h]
  data_root: data/

# 파이프라인 단계
stages:
  - name: ingestion
    parallel: true             # 모듈 간 병렬 실행
    modules:
      - binance_ohlcv
      - lunarcrush_social      # ← 신규 기능 추가 시 이 줄만
      - fear_greed
      - cryptopanic_news

  - name: features
    parallel: false            # 순차 (의존성 있음)
    modules:
      - technical_indicators
      - zone_detection
      - multi_tf_align
      - social_aggregates      # ← 신규

  - name: models
    parallel: true             # 두 모델 병렬
    modules:
      - xgb_touch_v2
      - linear_direction

  - name: signals
    modules:
      - whitelist_filter
      - regime_filter
      - alert_rules

  - name: outputs
    parallel: true
    modules:
      - desktop_notify
      - markdown_report
      - html_dashboard
```

### 4.2 실패 처리 정책

```yaml
# config/pipeline.yaml 에 추가
failure_policy:
  ingestion:
    on_module_fail: continue    # 한 소스 실패해도 나머지 진행
  features:
    on_module_fail: halt        # 피처 실패는 치명적
  models:
    on_module_fail: skip_stage  # 해당 모델만 스킵
  outputs:
    on_module_fail: continue    # 출력 실패 허용
```

---

## 5. 점진적 마이그레이션 (Phase A/B/C)

한 번에 다 바꾸면 현재 돌아가는 시스템이 위험하다. 3단계로 점진 이행:

### Phase A — 계약 정의 (1~2일)

기존 코드는 그대로 두고, **공유 데이터 스키마** 만 명확히:

- `data/raw/*.parquet` 스키마 정의 (time, open, high, low, close, volume, symbol, tf)
- `data/events/*.parquet` 스키마 (zone event 포맷)
- `data/predictions/*.jsonl` 스키마
- 각 스키마 → JSON Schema 문서화 (`docs/schemas/`)

**산출물**:
- `docs/schemas/ohlcv.schema.json`
- `docs/schemas/zone_event.schema.json`
- `docs/schemas/prediction.schema.json`
- `docs/DATA_FLOW.md` (데이터 흐름 다이어그램)

**효과**: 모듈끼리 뭘 주고받는지가 명확해진다. 이것만으로도 유지보수 난이도 크게 떨어짐.

### Phase B — 신규 모듈 2개 추출 (3~5일)

독립성 높은 것부터 패턴 검증:

1. **Fear & Greed 모듈** — API 1개, 완전 새로 만듦
2. **LunarCrush Social 모듈** — 기존 daily_sentiment.json 로직 이식

이걸로 **모듈 패턴이 잘 동작하는지 검증**. 여기서 배운 걸로 표준 인터페이스 확정.

**검증 포인트**:
- RunResult 구조가 충분한가
- config 분리가 깔끔한가
- 단위 테스트 작성 용이한가
- 오케스트레이터에서 호출이 단순한가

### Phase C — 기존 코드 점진 이식 (1~2주, 선택적)

잘 돌아가는 기존 파이프라인(detection, xgboost) 은 급할 것 없음.
- 신규 기능 추가 시 or 리팩토링 자연스러울 때 하나씩 모듈로 이식
- 완전 이식 전까지는 **래퍼 모듈** (기존 스크립트를 subprocess 로 호출하는 thin adapter) 로 임시 처리

이식 우선순위 (종속성 적은 것부터):
1. `technical_indicators` (가장 독립적)
2. `zone_detection` (detection.mjs 래핑)
3. `whitelist_filter` (whitelist_walkforward.py 이식)
4. `xgb_touch_v2` (tune_xgboost + predict_zones 이식)
5. `linear_direction` (predictor/ 이식)

---

## 6. 한계 및 주의사항

### 오버엔지니어링 위험

- 개인 프로젝트 규모에서 과한 추상화는 족쇄가 될 수 있음
- 계약(스키마, 인터페이스) 잘못 잡으면 모든 모듈이 영향받음
- 초기 계약은 **최소한**으로, 필요해지면 확장하는 쪽이 안전

### Python ↔ Node 혼재

- 두 런타임이 섞여 있어 서브프로세스/파이프 설계 필요
- 초기 제안: **파일 기반 IPC** (parquet/JSON) 유지, 메시지 큐 같은 건 당장 도입 안 함
- 오케스트레이터가 각 모듈을 subprocess 로 실행하고 artifacts 경로로 소통

### 테스트 복잡도

- 단위 테스트는 쉬워지지만 **통합 테스트 환경** 구축 필요
- 최소한 `tests/integration/smoke_pipeline.py` 는 있어야 함 (모듈 전체 연결 확인)

### 리팩토링 비용

- 풀 이식 시 **1~2주** 소요 예상
- 그동안 신규 기능 개발 지연 가능

---

## 7. 의사결정 체크포인트

착수 전 다음 질문에 YES 가 3개 이상이면 진행 권장:

- [ ] 앞으로 6개월 내 신규 데이터 소스 2개 이상 추가 예정인가? (LunarCrush 실시간, 뉴스, 온체인 등)
- [ ] 앞으로 모델을 바꾸거나 앙상블할 계획이 있는가?
- [ ] 현재 코드 수정 시 "어디를 고쳐야 하는지" 찾는 데 10분 이상 걸린 적이 있는가?
- [ ] 한 기능 추가가 3개 이상 파일을 동시에 건드리는 일이 자주 있는가?
- [ ] 모듈 단위 테스트의 부재가 디버깅을 느리게 한 적이 있는가?

NO 가 더 많으면 **현재 구조 유지가 합리적**.

---

## 8. 착수 시 최초 작업 (나중 진행용 체크리스트)

Phase A 로 시작하는 경우:

1. [ ] `docs/DATA_FLOW.md` — 현재 데이터 흐름 다이어그램
2. [ ] `docs/schemas/ohlcv.schema.json` — raw parquet 스키마
3. [ ] `docs/schemas/zone_event.schema.json` — events parquet 스키마
4. [ ] `docs/schemas/prediction.schema.json` — predictions JSONL 스키마
5. [ ] `core/contracts.py` 초안 — SourceModule/FeatureModule/ModelModule/SignalModule/OutputModule 추상 클래스
6. [ ] Phase B 착수 여부 결정 (Phase A 완료 후 회고)

---

## 9. 관련 이슈/태스크

- 관련 태스크: #129 (P1 마감 확장 유니버스 재검증) — 선행
- 트리거: 신규 소스 모듈 1개 이상 추가 필요 시점
- 의존: 현재 `expand_universe.sh` 파이프라인 안정화 완료 후

---

**요약**: 지금 시스템은 모듈화 없이도 동작한다. 모듈화는 **"앞으로 기능 추가가 많을 것"** 이 확실해질 때 착수하는 게 합리적이다. 착수 시엔 **Phase A(계약 정의) 만 먼저** 하고 실제 이식은 신규 기능 필요 시점에 자연스럽게.
