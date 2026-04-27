# ML-first 알림 아키텍처 (2026-04 전환)

## 배경

31-심볼 확장 유니버스 재검증 후 아래 패러독스가 드러났다.

| 지표 | 10 심볼 (기존) | 31 심볼 (확장) | 변화 |
|---|---|---|---|
| XGBoost v2 AUC (OOS) | 0.7846 | **0.7964** | +0.0118 (ML 패턴은 더 강해짐) |
| Brier score | 0.1794 | **0.1727** | -0.0067 (보정 개선) |
| 룰 백테스트 PF | 1.145 | 1.016 | 악화 |
| 룰 백테스트 MDD | -38.8% | -55.7% | 악화 |
| 화이트리스트 선정 페어 | 7개 | **1개** (AVAXUSDT_1h) | 붕괴 |

해석: ML 모델이 감지하는 확률적 패턴은 확장 후에도 그대로 유지되지만,
룰 기반 백테스트 성과와 화이트리스트는 기존 10 심볼에 과적합되어 있었다.

## 판단 철학 전환

**룰-first (기존) → ML-first (신규)**

```
기존:  zones → 룰 1차 (strength≥80, signals≥3, emp≥70%) → ML 2차 (p_cal≥0.80) → alert
          ↑ 실제 게이트                                    ↑ 확인용

신규:  zones → 넓은 프리컷 (strength≥60, signals≥2) → ML 1차 (p_cal 티어) → 룰 2차 보정 → alert
          ↑ ML 인퍼런스 낭비 방지용 최소한        ↑ 실제 판단        ↑ 보더라인 보호
```

## 티어 판정 표

| 티어 | ML 조건 | 룰 보정 조건 | 의미 |
|---|---|---|---|
| 🟢 S | p_cal ≥ 0.85 | **AND** strength ≥ 80 | ML + 룰 둘 다 강함 |
| 🔵 A | p_cal ≥ 0.80 | **AND** strength ≥ 70 | ML 강함, 룰 최소 확인 |
| ⚪ B | p_cal ≥ 0.70 | **AND** strength ≥ 70 **AND** signals ≥ 3 | ML 보더라인 — 룰이 확인 |
| ❌ | 위 셋 모두 해당 안 됨 | | drop (알림 안 감) |

> **2026-04-20 튜닝**: 31심볼 + low-vol 시장에서 XGB 과신으로 A 티어 폭증 (103건/런).
> 임계 +0.05 상향 + A 티어에도 strength≥70 룰 확인 추가. 이전 값은 0.65/0.75/0.80 · A 룰 무관.

### 설계 근거

- **S 티어**: XGB AUC 0.796 + Brier 0.173 환경에서 p_cal ≥ 0.80 은
  상위 ~15% 구간. 여기에 룰까지 강하면 가장 확신 높은 셋업.
- **A 티어**: p_cal ≥ 0.75 는 보정된 ML 확률 기준으로 충분히 강해서
  룰이 약해도 신뢰할 수 있다. 확률 자체를 액면 그대로 해석.
- **B 티어**: p_cal 0.65–0.75 구간은 모델도 반신반의 — 이때 룰
  (strength 70+, signals 3+) 이 확인해주면 보조 판단으로 채택.
- **drop**: p_cal < 0.65 이면 모델 관점에서 낮은 확률 — 룰이 아무리
  강해도 알림 안 보냄 (룰-only 백테스트에서 오버피팅 발견됨).

## 동작 모드

### 기본 (ML-first)

```bash
node backtest/scripts/alert_daemon.mjs
```

- 프리컷: strength≥60, signals≥2, empirical≥50%
- ML 1차 판단 활성
- 위 티어표에 따라 판정

### 롤백: 룰-only 폴백 (`--no-ml`)

```bash
node backtest/scripts/alert_daemon.mjs --no-ml
```

- ML 비활성
- 프리컷이 옛 strict (strength≥80, signals≥3, empirical≥70%) 로 전환
- 통과한 존 모두 알림

### 실험: legacy 프리컷 + ML 티어 (`--legacy-rules`)

```bash
node backtest/scripts/alert_daemon.mjs --legacy-rules
```

- 프리컷을 옛 strict 로 두되 ML 티어 판정은 유지
- "룰로 한 번 거르고 ML 로 한 번 더" — 보수적 실험용

### 임계 오버라이드

```bash
node backtest/scripts/alert_daemon.mjs --ml-threshold 0.70    # B 티어 하한만 조정
node backtest/scripts/alert_daemon.mjs --min-strength 70      # 프리컷 strength 만 조정
```

## 화이트리스트의 역할 변경

화이트리스트는 더 이상 차단 필터가 아니다.

- **기본**: `★` 시각 태그로만 사용 (알림 제목에 표시)
- **강제 필터링 원하면**: `--whitelist-only` 플래그 (테스트용)

### 이유

확장 유니버스에서 `whitelist_extended.json` 이 1개 페어 (AVAXUSDT_1h) 만
선정했기 때문. `min_trades_train=8` 임계가 43 후보 페어를 50/50 분할했을 때
너무 빡빡하다 (예: ETH_1h 는 PF=999, winrate=100% 지만 n=6 으로 탈락).

화이트리스트를 차단 필터로 쓰면 사실상 AVAX_1h 만 알림이 오게 되어
ML 모델의 범용성(31 심볼 전체에서 AUC 0.796)을 활용하지 못함.

## CONFIG 키 요약

`alert_daemon.mjs` CONFIG 블록:

```js
// ML-first 1차 판단
mlEnabled: true,
pCalMin: 0.65,        // B 티어 ML 하한
pCalHigh: 0.75,       // A 티어 ML 경계
pCalStrict: 0.80,     // S 티어 ML 경계
strengthStrict: 80,   // S 티어 룰 경계
ruleStrengthMin: 70,  // B 티어 룰 strength 하한
ruleSignalsMin: 3,    // B 티어 룰 signals 하한

// 프리컷 (ML 인퍼런스 전 넓은 필터)
strengthMin: 60,
empiricalMin: 0.50,
signalCountMin: 2,

// 폴백 (--no-ml 또는 --legacy-rules 시)
legacyStrengthMin: 80,
legacyEmpiricalMin: 0.70,
legacySignalCountMin: 3,
```

## 예상 영향

- **알림 빈도**: ML 확률에 달려 있음. AUC 0.796 기준 p_cal ≥ 0.65 는
  보통 존의 ~30–40% 정도. 옛 strict 룰보다 약간 많아질 가능성.
- **품질**: S/A 티어는 더 신뢰성 있는 알림. B 티어는 참고용.
- **범위**: 31 심볼 전체 커버. 옛 10 심볼 + 화이트리스트 7 페어 한계 해제.

## 롤백 절차

문제 발생 시:

1. 즉시 롤백: `--no-ml` 플래그로 launchd plist 수정 → 옛 룰-only 로 복귀
2. 영구 롤백: `CONFIG.mlEnabled = false` 로 설정 변경
3. 부분 조정: `--ml-threshold 0.75` 로 B 티어 제거 (A/S 만 알림)

## 모니터링 포인트

- `backtest/data/alerts/sent.jsonl`: 실제 알림
- `backtest/data/alerts/predictions.jsonl`: ML 스코어된 모든 존 (UI 배지용)
- 티어별 분포 (`verbose` 로그): `pass=X · noMl=X · lowPCal=X · bRuleFail=X`

## 관련 파일

- `backtest/scripts/alert_daemon.mjs` — 메인 구현
- `backtest/scripts/predict_zones.py` — XGBoost v2 호출 (subprocess)
- `backtest/data/ml/xgb_touch100_v2.ubj` — 프로덕션 모델
- `backtest/data/ml/isotonic_calibrator_v2.pkl` — 확률 보정기
- `backtest/data/whitelist_extended.json` — ★ 태그용 페어 목록
- `docs/ARCHITECTURE_MODULAR.md` — 모듈화 장기 계획 (별개)
