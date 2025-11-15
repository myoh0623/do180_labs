#!/bin/bash

# DO180 Lab 9: Kubernetes Secret 생성 실습 환경 구성 스크립트
# moon 프로젝트 생성 및 실습 환경 준비

set -e

# 스크립트 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "DO180 Lab 9 - Kubernetes Secret 생성 실습 환경 구성"
echo "=========================================="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 사전 조건 확인
echo -e "${YELLOW}[1/3] 사전 조건 확인 중...${NC}"

if ! oc whoami &>/dev/null; then
    echo -e "${RED}✗ OpenShift 클러스터에 로그인되어 있지 않습니다.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 사전 조건 확인 완료${NC}"
echo "  - 현재 사용자: $(oc whoami)"
echo ""

# 1. moon 프로젝트 생성
echo -e "${YELLOW}[2/3] moon 프로젝트 생성 중...${NC}"

if oc get project moon &>/dev/null; then
    echo "  ⚠ moon 프로젝트가 이미 존재합니다."
    oc project moon
else
    if oc auth can-i create projects &>/dev/null; then
        oc new-project moon --display-name="Moon Base Control" --description="DO180 Lab 9 - Kubernetes Secret Creation"
        echo "  ✓ moon 프로젝트 생성됨"
    else
        echo -e "${RED}  ✗ 프로젝트 생성 권한이 없습니다.${NC}"
        echo "  관리자에게 moon 프로젝트 생성을 요청하거나 self-provisioner 권한을 요청하세요."
        exit 1
    fi
fi

echo -e "${GREEN}✓ moon 프로젝트 설정 완료${NC}"
echo ""

# 2. Base64 값 확인 및 실습 안내
echo -e "${YELLOW}[3/3] 실습 환경 준비 완료${NC}"

echo ""
echo "  - Base64 값 검증:"
echo "    주어진 값: bW9vbi1wYXNzd29yZAo="

# Base64 디코딩 결과 표시
DECODED_VALUE=$(echo "bW9vbi1wYXNzd29yZAo=" | base64 -d 2>/dev/null || echo "디코딩 실패")
echo "    디코딩 결과: '$DECODED_VALUE'"

echo ""
echo -e "${GREEN}✓ 실습 환경 준비 완료${NC}"
echo ""

# 완료 메시지
echo -e "${BLUE}=========================================="
echo "Kubernetes Secret 생성 실습 환경 구성 완료!"
echo "=========================================="
echo ""
echo "생성된 리소스:"
echo "✓ moon 프로젝트"
echo ""
echo "실습 과제:"
echo "🎯 moon 프로젝트에 다음 요구사항으로 Secret을 생성하세요:"
echo "   - Secret 이름: moon-secret"
echo "   - 키 이름: moon-key"
echo "   - 키 값: bW9vbi1wYXNzd29yZAo= (Base64 인코딩된 값)"
echo ""
echo "Secret 생성 방법:"
echo "1. CLI 방법:"
echo "   oc create secret generic moon-secret --from-literal=moon-key=bW9vbi1wYXNzd29yZAo="
echo ""
echo "2. Web Console 방법:"
echo "   - Developer View → Secrets → Create → Key/Value Secret"
echo "   - Secret Name: moon-secret"
echo "   - Key: moon-key, Value: bW9vbi1wYXNzd29yZAo="
echo ""
echo "3. YAML 방법:"
echo "   cat <<EOF | oc apply -f -"
echo "   apiVersion: v1"
echo "   kind: Secret"
echo "   metadata:"
echo "     name: moon-secret"
echo "     namespace: moon"
echo "   type: Opaque"
echo "   data:"
echo "     moon-key: bW9vbi1wYXNzd29yZAo="
echo "   EOF"
echo ""
echo "Secret 확인:"
echo "   oc get secrets"
echo "   oc describe secret moon-secret"
echo "   oc get secret moon-secret -o jsonpath='{.data.moon-key}' | base64 -d"
echo ""
echo "Base64 인코딩/디코딩 실습:"
echo "   echo -n 'moon-password' | base64     # 인코딩"
echo "   echo 'bW9vbi1wYXNzd29yZAo=' | base64 -d  # 디코딩"
echo ""
echo "정리: ./settings/cleanup-lab.sh"
echo -e "${NC}"