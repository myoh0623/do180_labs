#!/bin/bash

# DO180 Lab 9: Kubernetes Secret 생성 정리 스크립트
# 실습 후 리소스 정리 (Lab 10에서 재사용하므로 주의)

set -e

# 스크립트 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "DO180 Lab 9 - 실습 환경 정리"
echo "=========================================="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 사전 조건 확인
echo -e "${YELLOW}[1/4] 사전 조건 확인 중...${NC}"

if ! oc whoami &>/dev/null; then
    echo -e "${RED}✗ OpenShift 클러스터에 로그인되어 있지 않습니다.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ 현재 사용자: $(oc whoami)${NC}"
echo ""

# 사용자 확인
echo -e "${BLUE}이 스크립트는 다음 리소스를 삭제합니다:${NC}"
echo "  - moon 프로젝트 및 모든 리소스"
echo "  - moon-secret (있는 경우)"
echo "  - 관련된 모든 Secrets, ConfigMaps, Pods"
echo ""
echo -e "${YELLOW}⚠ 주의: Lab 10에서 moon-secret을 사용합니다.${NC}"
echo -e "${YELLOW}   Lab 10을 수행할 예정이면 정리하지 마세요!${NC}"
echo ""

read -p "계속하시겠습니까? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "정리가 취소되었습니다."
    exit 0
fi

echo ""

# 1. 현재 상태 확인
echo -e "${YELLOW}[2/4] 현재 상태 확인 중...${NC}"

if oc get project moon &>/dev/null; then
    echo -e "${GREEN}✓ moon 프로젝트 존재함${NC}"
    
    # moon 프로젝트로 전환
    oc project moon &>/dev/null
    
    # 현재 리소스 목록 표시
    echo ""
    echo "  현재 moon 프로젝트의 리소스:"
    
    # Secrets 확인
    SECRETS=$(oc get secrets --no-headers 2>/dev/null | grep -v "default-token\|builder-token\|deployer-token" | wc -l)
    if [ "$SECRETS" -gt 0 ]; then
        echo "    Secrets: $SECRETS개"
        oc get secrets --no-headers | grep -v "default-token\|builder-token\|deployer-token" | sed 's/^/      /'
        
        # moon-secret 확인
        if oc get secret moon-secret &>/dev/null; then
            echo "    🔍 moon-secret 발견:"
            echo "      - 키 개수: $(oc get secret moon-secret -o jsonpath='{.data}' | jq -r 'keys | length' 2>/dev/null || echo '확인 불가')"
            if oc get secret moon-secret -o jsonpath='{.data.moon-key}' &>/dev/null; then
                DECODED_VALUE=$(oc get secret moon-secret -o jsonpath='{.data.moon-key}' | base64 -d 2>/dev/null || echo "디코딩 실패")
                echo "      - moon-key 값: '$DECODED_VALUE'"
            fi
        fi
    fi
    
    # ConfigMaps 확인
    CONFIGMAPS=$(oc get configmaps --no-headers 2>/dev/null | wc -l)
    if [ "$CONFIGMAPS" -gt 0 ]; then
        echo "    ConfigMaps: $CONFIGMAPS개"
        oc get configmaps --no-headers | sed 's/^/      /'
    fi
    
    # Pods 확인
    PODS=$(oc get pods --no-headers 2>/dev/null | wc -l)
    if [ "$PODS" -gt 0 ]; then
        echo "    Pods: $PODS개"
        oc get pods --no-headers | sed 's/^/      /'
    fi
    
    # Deployments 확인
    DEPLOYMENTS=$(oc get deployments --no-headers 2>/dev/null | wc -l)
    if [ "$DEPLOYMENTS" -gt 0 ]; then
        echo "    Deployments: $DEPLOYMENTS개"
        oc get deployments --no-headers | sed 's/^/      /'
    fi
    
else
    echo -e "${YELLOW}⚠ moon 프로젝트를 찾을 수 없습니다.${NC}"
    echo "이미 정리되었거나 생성되지 않았을 수 있습니다."
fi

echo ""

# 2. moon-secret 개별 삭제 (선택적)
echo -e "${YELLOW}[3/4] moon-secret 개별 삭제 중...${NC}"

if oc get project moon &>/dev/null; then
    oc project moon &>/dev/null
    
    # moon-secret 삭제
    if oc get secret moon-secret &>/dev/null; then
        echo "  - moon-secret 삭제 중..."
        oc delete secret moon-secret --ignore-not-found=true
        echo -e "${GREEN}  ✓ moon-secret 삭제됨${NC}"
    else
        echo -e "${YELLOW}  ⚠ moon-secret를 찾을 수 없습니다.${NC}"
    fi
    
    # 다른 사용자 정의 secrets 확인
    OTHER_SECRETS=$(oc get secrets --no-headers 2>/dev/null | grep -v "default-token\|builder-token\|deployer-token" | wc -l)
    if [ "$OTHER_SECRETS" -gt 0 ]; then
        echo "  - 기타 사용자 정의 secrets 삭제 중..."
        oc get secrets --no-headers | grep -v "default-token\|builder-token\|deployer-token" | awk '{print $1}' | xargs -r oc delete secret
        echo -e "${GREEN}  ✓ 사용자 정의 secrets 정리됨${NC}"
    fi
    
else
    echo -e "${YELLOW}  ⚠ moon 프로젝트가 없으므로 건너뜁니다.${NC}"
fi

echo ""

# 3. moon 프로젝트 삭제
echo -e "${YELLOW}[4/4] moon 프로젝트 삭제 중...${NC}"

if oc get project moon &>/dev/null; then
    echo "  - moon 프로젝트 및 모든 리소스 삭제 중..."
    oc delete project moon
    
    # 프로젝트 삭제 완료 대기
    echo "  - 프로젝트 삭제 완료 대기 중..."
    while oc get project moon &>/dev/null; do
        echo -n "."
        sleep 2
    done
    echo ""
    echo -e "${GREEN}  ✓ moon 프로젝트 삭제 완료${NC}"
else
    echo -e "${YELLOW}  ⚠ moon 프로젝트가 이미 존재하지 않습니다.${NC}"
fi

echo ""

# 정리 완료 확인
echo -e "${BLUE}=========================================="
echo "정리 완료"
echo "=========================================="
echo ""

# 최종 상태 확인
echo -e "${GREEN}✓ 실습 환경이 성공적으로 정리되었습니다.${NC}"
echo ""
echo "정리된 리소스:"
echo "  - moon 프로젝트"
echo "  - moon-secret 및 모든 사용자 정의 secrets"
echo "  - 모든 pods, deployments, services"
echo "  - 모든 configmaps 및 기타 리소스"
echo ""
echo -e "${BLUE}실습을 다시 수행하려면 다음 명령어를 실행하세요:${NC}"
echo "  ./settings/setup-lab.sh"
echo ""
echo -e "${YELLOW}참고: Base64 인코딩/디코딩 명령어${NC}"
echo "  인코딩: echo -n 'moon-password' | base64"
echo "  디코딩: echo 'bW9vbi1wYXNzd29yZAo=' | base64 -d"
echo ""

# 기본 프로젝트로 전환
if oc get project default &>/dev/null; then
    oc project default &>/dev/null
    echo -e "${YELLOW}현재 프로젝트가 'default'로 전환되었습니다.${NC}"
fi

echo -e "${NC}"