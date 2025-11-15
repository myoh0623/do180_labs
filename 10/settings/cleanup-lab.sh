#!/bin/bash

# DO180 Lab 10: Secret을 사용하는 애플리케이션 구성 정리 스크립트
# satellite 애플리케이션 삭제 (moon-secret은 유지)

set -e

# 스크립트 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "DO180 Lab 10 - 실습 환경 정리"
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
echo "  - satellite deployment"
echo "  - satellite service"
echo "  - satellite route"
echo "  - satellite 관련 pods"
echo ""
echo -e "${GREEN}다음 리소스는 유지됩니다:${NC}"
echo "  - moon 프로젝트"
echo "  - moon-secret (Lab 9에서 생성)"
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
    echo "  현재 moon 프로젝트의 satellite 관련 리소스:"
    
    # satellite deployment 확인
    if oc get deployment satellite &>/dev/null; then
        echo "    ✓ satellite deployment 존재"
        CURRENT_REPLICAS=$(oc get deployment satellite -o jsonpath='{.spec.replicas}')
        READY_REPLICAS=$(oc get deployment satellite -o jsonpath='{.status.readyReplicas}' 2>/dev/null || echo "0")
        echo "      - 레플리카: $CURRENT_REPLICAS (Ready: $READY_REPLICAS)"
        
        # 환경 변수 확인
        if oc get deployment satellite -o jsonpath='{.spec.template.spec.containers[0].env}' | grep -q MOON_KEY; then
            echo "      - MOON_KEY 환경 변수: 설정됨 ✓"
        else
            echo "      - MOON_KEY 환경 변수: 설정되지 않음 ❌"
        fi
    else
        echo "    ⚠ satellite deployment를 찾을 수 없습니다."
    fi
    
    # satellite pod 확인
    SATELLITE_PODS=$(oc get pods --no-headers 2>/dev/null | grep satellite | wc -l)
    if [ "$SATELLITE_PODS" -gt 0 ]; then
        echo "    ✓ satellite pods: $SATELLITE_PODS개"
        oc get pods --no-headers | grep satellite | sed 's/^/      /'
    fi
    
    # satellite service 확인
    if oc get service satellite &>/dev/null; then
        echo "    ✓ satellite service 존재"
    fi
    
    # satellite route 확인
    if oc get route satellite &>/dev/null; then
        echo "    ✓ satellite route 존재"
        ROUTE_URL=$(oc get route satellite -o jsonpath='{.spec.host}')
        echo "      - URL: http://$ROUTE_URL"
    fi
    
    # moon-secret 확인 (유지되어야 함)
    if oc get secret moon-secret &>/dev/null; then
        echo "    ✓ moon-secret 존재 (유지됨)"
        DECODED_VALUE=$(oc get secret moon-secret -o jsonpath='{.data.moon-key}' | base64 -d 2>/dev/null || echo "디코딩 실패")
        echo "      - moon-key 값: '$DECODED_VALUE'"
    else
        echo "    ⚠ moon-secret이 존재하지 않습니다."
    fi
    
else
    echo -e "${YELLOW}⚠ moon 프로젝트를 찾을 수 없습니다.${NC}"
    echo "이미 정리되었거나 생성되지 않았을 수 있습니다."
fi

echo ""

# 2. satellite 리소스 개별 삭제
echo -e "${YELLOW}[3/4] satellite 애플리케이션 리소스 삭제 중...${NC}"

if oc get project moon &>/dev/null; then
    oc project moon &>/dev/null
    
    # satellite deployment 삭제
    if oc get deployment satellite &>/dev/null; then
        echo "  - satellite deployment 삭제 중..."
        oc delete deployment satellite --ignore-not-found=true
        echo -e "${GREEN}  ✓ satellite deployment 삭제됨${NC}"
        
        # Pod 삭제 대기
        echo "  - satellite pod 종료 대기 중..."
        oc wait --for=delete pod -l app=satellite --timeout=60s 2>/dev/null || true
        echo -e "${GREEN}  ✓ satellite pod 정리됨${NC}"
    else
        echo -e "${YELLOW}  ⚠ satellite deployment를 찾을 수 없습니다.${NC}"
    fi
    
    # satellite service 삭제
    if oc get service satellite &>/dev/null; then
        echo "  - satellite service 삭제 중..."
        oc delete service satellite --ignore-not-found=true
        echo -e "${GREEN}  ✓ satellite service 삭제됨${NC}"
    else
        echo -e "${YELLOW}  ⚠ satellite service를 찾을 수 없습니다.${NC}"
    fi
    
    # satellite route 삭제
    if oc get route satellite &>/dev/null; then
        echo "  - satellite route 삭제 중..."
        oc delete route satellite --ignore-not-found=true
        echo -e "${GREEN}  ✓ satellite route 삭제됨${NC}"
    else
        echo -e "${YELLOW}  ⚠ satellite route를 찾을 수 없습니다.${NC}"
    fi
    
else
    echo -e "${YELLOW}  ⚠ moon 프로젝트가 없으므로 건너뜁니다.${NC}"
fi

echo ""

# 3. 정리 결과 확인
echo -e "${YELLOW}[4/4] 정리 결과 확인 중...${NC}"

if oc get project moon &>/dev/null; then
    oc project moon &>/dev/null
    echo "  - 남은 리소스 확인:"
    
    # moon-secret이 여전히 존재하는지 확인
    if oc get secret moon-secret &>/dev/null; then
        echo -e "${GREEN}    ✓ moon-secret 유지됨${NC}"
    else
        echo -e "${YELLOW}    ⚠ moon-secret이 없습니다 (Lab 9 재실행 필요할 수 있음)${NC}"
    fi
    
    # satellite 리소스가 모두 삭제되었는지 확인
    REMAINING_SATELLITE=$(oc get all -l app=satellite --no-headers 2>/dev/null | wc -l)
    if [ "$REMAINING_SATELLITE" -eq 0 ]; then
        echo -e "${GREEN}    ✓ satellite 관련 리소스 모두 삭제됨${NC}"
    else
        echo -e "${YELLOW}    ⚠ 일부 satellite 리소스가 남아있을 수 있습니다${NC}"
        oc get all -l app=satellite --no-headers 2>/dev/null | sed 's/^/      /'
    fi
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
echo "삭제된 리소스:"
echo "  - satellite deployment"
echo "  - satellite service"
echo "  - satellite route"
echo "  - satellite pods"
echo ""
echo "유지된 리소스:"
echo "  - moon 프로젝트"
echo "  - moon-secret (Lab 9에서 생성)"
echo ""
echo -e "${BLUE}실습을 다시 수행하려면:${NC}"
echo "  ./settings/setup-lab.sh"
echo ""
echo -e "${BLUE}Lab 9부터 다시 시작하려면:${NC}"
echo "  cd ../9"
echo "  ./settings/cleanup-lab.sh  # moon 프로젝트 전체 삭제"
echo "  ./settings/setup-lab.sh    # moon 프로젝트 및 moon-secret 재생성"
echo ""

echo -e "${NC}"