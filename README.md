# Crypto Analyzer Pro

암호화폐 실시간 차트 분석 + AI 방향 예측 도구. 두 구성요소로 이루어져 있습니다.

## 파일 구조

```
차트 분석/
├─ crypto-analyzer.html          ← 메인 대시보드 (브라우저에서 더블클릭)
└─ predictor/                    ← AI 예측 엔진 (선택 설치)
   ├─ predictor.py               ← XGBoost 학습·추론 스크립트
   ├─ requirements.txt
   ├─ run_windows.bat            ← Windows 원클릭 실행
   ├─ run_mac.command            ← macOS 원클릭 실행
   ├─ SETUP_가이드.md            ← 상세 설치 가이드
   └─ predictions.json           ← 실행 후 생성됨 (HTML이 읽음)
```

## 빠른 시작

### 1. 대시보드만 쓰기 (설치 0초)
`crypto-analyzer.html` 을 더블클릭하면 브라우저에서 바로 실행.
- 실시간 캔들 차트 (Binance / 업비트)
- 기술적 지표 7종 (RSI, MACD, 볼린저, MA 3종, Stoch, ATR)
- 자동 패턴 인식 (이중 천장/바닥, 헤드앤숄더, 다이버전스, 정/역배열)
- 자동 지지·저항선
- 5가지 전략 백테스팅
- 온체인 지표 (CoinGecko)
- 기본 AI 예측 (선형회귀)

### 2. PRO 예측기 활성화 (선택, 더 정확한 확률 예측)
`predictor/SETUP_가이드.md` 의 순서대로 Python 설치 → `run_windows.bat` 또는 `run_mac.command` 더블클릭.

처음 한 번 5분 정도 걸리고, 이후로는 **15분마다 자동으로 상승/하락 확률을 갱신** 합니다:
- 15분 / 1시간 / 4시간 후 방향 예측
- "상승 확률 62.3% — UP" 형태의 직관적 결과
- 백테스트 정확도·Brier 스코어 등 신뢰도 지표
- 상위 기여 피처 (어떤 지표가 예측에 영향을 줬는지)

**데이터 소스**: Binance Spot OHLCV + 선물 퍼딩비/미결제약정/롱숏비율/테이커 매수비율 + Alternative.me 공포탐욕 지수 + (알트코인의 경우) BTC 크로스 비율.

**모델**: XGBoost 2진 분류 × 3 호라이즌, isotonic calibration으로 확률 보정.

## 주의사항

암호화폐 단기 예측은 본질적으로 어렵습니다. 본 도구의 예측은 **참고 자료**이며, 60% 정확도도 시장 평균 이상입니다. 실거래 시 항상 손절 관리 병행하세요.
