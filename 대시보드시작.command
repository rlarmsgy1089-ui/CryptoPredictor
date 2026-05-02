#!/bin/bash
# CryptoPredictor 로컬 대시보드 자동 실행
# 더블클릭 → Python HTTP 서버 시작 + 브라우저 자동 오픈
# 종료: 이 터미널 창 닫기 (또는 Ctrl+C)

cd "$(dirname "$0")"

# 색상
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

PORT=8000
URL="http://localhost:${PORT}/crypto-analyzer.html"

clear
echo "══════════════════════════════════════════════════"
echo "  📊 CryptoPredictor 로컬 대시보드"
echo "══════════════════════════════════════════════════"
echo ""

# Python 확인
if ! command -v python3 &> /dev/null; then
  echo -e "${RED}❌ python3 가 설치되어 있지 않습니다.${NC}"
  echo ""
  echo "해결 방법:"
  echo "  1) macOS 기본 Python — 보통 /usr/bin/python3 에 있음"
  echo "  2) 없으면 Homebrew 로: brew install python"
  echo ""
  read -p "Enter 키 누르면 창이 닫힙니다..." -n1
  exit 1
fi

# 포트 사용 중 확인
if lsof -i :${PORT} > /dev/null 2>&1; then
  echo -e "${YELLOW}⚠ 포트 ${PORT} 이미 사용 중${NC}"
  echo ""
  echo "이미 다른 서버가 실행 중일 수 있어요."
  echo "옵션:"
  echo "  1) 기존 서버 사용 → 그냥 브라우저에서 ${URL} 열기"
  echo "  2) 기존 서버 종료 후 다시 실행"
  echo ""
  read -p "기존 서버를 종료할까요? [y/N]: " KILL
  if [[ "$KILL" =~ ^[Yy]$ ]]; then
    lsof -ti :${PORT} | xargs kill -9 2>/dev/null
    echo -e "${GREEN}✓ 기존 서버 종료${NC}"
    sleep 1
  else
    echo -e "${BLUE}브라우저만 열고 종료합니다...${NC}"
    open "${URL}"
    sleep 1
    exit 0
  fi
fi

echo -e "${BLUE}🌐 Python HTTP 서버 시작 (포트 ${PORT})...${NC}"
echo ""
echo "──────────────────────────────────────────────────"
echo -e "  📍 대시보드 주소: ${CYAN}${URL}${NC}"
echo "──────────────────────────────────────────────────"
echo ""
echo -e "${YELLOW}💡 종료: 이 터미널 창을 닫거나 Ctrl+C${NC}"
echo ""

# 1초 후 브라우저 자동 오픈 (서버가 startup 할 시간 주기)
(sleep 1.2 && open "${URL}") &

# 서버 실행 (foreground — 창 열려있는 동안 계속 실행)
python3 -m http.server ${PORT}
