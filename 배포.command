#!/bin/bash
# CryptoPredictor 자동 배포 스크립트
# 더블클릭하면 자동으로 git add + commit + push 실행
# 결과: 1~2분 후 https://rlarmsgy1089-ui.github.io/CryptoPredictor/ 업데이트

# 이 스크립트가 있는 폴더로 이동
cd "$(dirname "$0")"

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # 색상 리셋

clear
echo "══════════════════════════════════════════════════"
echo "  🚀 CryptoPredictor 자동 배포"
echo "══════════════════════════════════════════════════"
echo ""

# 변경사항 확인
echo -e "${BLUE}📋 변경사항 확인 중...${NC}"
CHANGES=$(git status --porcelain)

if [ -z "$CHANGES" ]; then
  echo -e "${YELLOW}⚠ 변경된 파일이 없습니다. 배포할 내용이 없어요.${NC}"
  echo ""
  echo "빈 커밋으로 강제 재배포 하시겠습니까? (예: 비번 갱신 후)"
  read -p "[y/N]: " FORCE
  if [[ "$FORCE" =~ ^[Yy]$ ]]; then
    git commit --allow-empty -m "🔄 재배포 트리거 ($(date +'%Y-%m-%d %H:%M'))"
  else
    echo "취소됨."
    echo ""
    read -p "Enter 키 누르면 창이 닫힙니다..." -n1
    exit 0
  fi
else
  echo "변경된 파일:"
  echo "$CHANGES" | head -10
  if [ $(echo "$CHANGES" | wc -l) -gt 10 ]; then
    echo "  (그 외 더 있음)"
  fi
  echo ""

  # 커밋 메시지 입력
  echo -e "${BLUE}💬 커밋 메시지 (Enter 만 누르면 자동 메시지):${NC}"
  read -p "> " MSG
  if [ -z "$MSG" ]; then
    MSG="📝 자동 업데이트 ($(date +'%Y-%m-%d %H:%M'))"
  fi

  # add + commit
  echo ""
  echo -e "${BLUE}📦 커밋 중...${NC}"
  git add .
  git commit -m "$MSG"
fi

# push
echo ""
echo -e "${BLUE}🚀 GitHub 으로 push...${NC}"
if git push; then
  echo ""
  echo "══════════════════════════════════════════════════"
  echo -e "${GREEN}  ✅ Push 성공!${NC}"
  echo "══════════════════════════════════════════════════"
  echo ""
  echo "🔄 GitHub Actions 가 자동 빌드 중 (1~2분 소요)"
  echo ""
  echo "📊 진행 확인: https://github.com/rlarmsgy1089-ui/CryptoPredictor/actions"
  echo "🌐 사이트:    https://rlarmsgy1089-ui.github.io/CryptoPredictor/"
  echo ""
else
  echo ""
  echo "══════════════════════════════════════════════════"
  echo -e "${RED}  ❌ Push 실패${NC}"
  echo "══════════════════════════════════════════════════"
  echo ""
  echo "위 에러 메시지 확인 후 재시도하세요."
  echo ""
fi

echo ""
read -p "Enter 키 누르면 창이 닫힙니다..." -n1
