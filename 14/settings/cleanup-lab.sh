#!/bin/bash

# DO180 Lab 14 Cleanup Script
# ConfigMap을 사용한 Deployment 구성 실습 환경 정리

set -e

echo "=== DO180 Lab 14 Cleanup: ConfigMap을 사용한 Deployment 구성 정리 ==="
echo

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 헬퍼 함수들
print_header() {
    echo -e "${BLUE}==== $1 ====${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# OpenShift 로그인 상태 확인
print_header "OpenShift 로그인 상태 확인"
if ! oc whoami &> /dev/null; then
    print_error "OpenShift에 로그인하지 않았습니다."
    echo "다음 명령으로 로그인하세요:"
    echo "oc login -u <username> -p <password> <cluster-url>"
    exit 1
fi

CURRENT_USER=$(oc whoami)
print_success "현재 사용자: $CURRENT_USER"

# publish 프로젝트 존재 확인 및 정리
print_header "publish 프로젝트 정리"
if oc get project publish &> /dev/null; then
    echo "publish 프로젝트에서 생성된 리소스들을 정리합니다..."
    
    # 프로젝트로 전환
    oc project publish 2>/dev/null || true
    
    # 현재 리소스 상태 표시
    echo
    echo "=== 삭제할 리소스 목록 ==="
    
    echo "Deployments:"
    oc get deployments --no-headers 2>/dev/null | awk '{print "  - " $1}' || echo "  (없음)"
    
    echo "Services:"
    oc get services --no-headers 2>/dev/null | grep -v kubernetes | awk '{print "  - " $1}' || echo "  (없음)"
    
    echo "ConfigMaps:"
    oc get configmaps --no-headers 2>/dev/null | awk '{print "  - " $1}' || echo "  (없음)"
    
    echo "Pods:"
    oc get pods --no-headers 2>/dev/null | awk '{print "  - " $1}' || echo "  (없음)"
    
    echo
    
    # 사용자 확인
    read -p "위 리소스들을 모두 삭제하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # 개별 리소스 삭제 (더 안전한 방법)
        print_header "개별 리소스 삭제"
        
        # ConfigMaps 삭제
        if oc get configmaps -o name 2>/dev/null | grep -q .; then
            echo "ConfigMaps 삭제 중..."
            oc delete configmaps --all --ignore-not-found=true
            print_success "ConfigMaps가 삭제되었습니다."
        fi
        
        # Services 삭제 (kubernetes 서비스 제외)
        SERVICES=$(oc get services -o name 2>/dev/null | grep -v "service/kubernetes" || true)
        if [ -n "$SERVICES" ]; then
            echo "Services 삭제 중..."
            echo "$SERVICES" | xargs oc delete --ignore-not-found=true
            print_success "Services가 삭제되었습니다."
        fi
        
        # Deployments 삭제
        if oc get deployments -o name 2>/dev/null | grep -q .; then
            echo "Deployments 삭제 중..."
            oc delete deployments --all --ignore-not-found=true
            print_success "Deployments가 삭제되었습니다."
        fi
        
        # Pod 종료 대기
        echo "Pod 종료 대기 중..."
        for i in {1..30}; do
            if ! oc get pods --no-headers 2>/dev/null | grep -q .; then
                print_success "모든 Pod가 종료되었습니다."
                break
            fi
            echo -n "."
            sleep 2
        done
        echo
        
        # 전체 프로젝트 삭제 여부 확인
        echo
        read -p "publish 프로젝트 전체를 삭제하시겠습니까? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            print_header "프로젝트 삭제"
            oc delete project publish --ignore-not-found=true
            
            # 프로젝트 삭제 완료 대기
            echo "프로젝트 삭제 완료 대기 중..."
            for i in {1..60}; do
                if ! oc get project publish &> /dev/null; then
                    print_success "publish 프로젝트가 완전히 삭제되었습니다."
                    break
                fi
                echo -n "."
                sleep 1
            done
            echo
        else
            print_warning "프로젝트는 유지되고 내부 리소스만 정리되었습니다."
        fi
    else
        print_warning "리소스 정리를 취소했습니다."
    fi
else
    print_warning "publish 프로젝트가 존재하지 않습니다."
fi

# 소스 파일 정리
print_header "소스 파일 정리"
WEB_DIR="/home/student/web"
if [ -d "$WEB_DIR" ]; then
    echo "소스 파일 디렉터리 정리: $WEB_DIR"
    
    # 디렉터리 내용 확인
    if [ "$(ls -A $WEB_DIR 2>/dev/null)" ]; then
        echo "삭제될 파일:"
        ls -la "$WEB_DIR" | grep -v "^total" | awk '{print "  - " $9}'
        echo
        
        read -p "소스 파일 디렉터리를 삭제하시겠습니까? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -rf "$WEB_DIR"
            print_success "소스 파일 디렉터리가 삭제되었습니다."
        else
            print_warning "소스 파일 디렉터리가 유지되었습니다."
        fi
    else
        print_warning "소스 파일 디렉터리가 비어있습니다."
    fi
else
    print_warning "소스 파일 디렉터리가 존재하지 않습니다."
fi

# 기본 프로젝트로 전환
print_header "기본 프로젝트로 전환"
if oc get project default &> /dev/null; then
    oc project default
    print_success "default 프로젝트로 전환했습니다."
else
    # default 프로젝트가 없는 경우 첫 번째 접근 가능한 프로젝트로 전환
    FIRST_PROJECT=$(oc get projects -o name 2>/dev/null | head -n 1 | cut -d'/' -f2)
    if [ -n "$FIRST_PROJECT" ]; then
        oc project "$FIRST_PROJECT"
        print_success "$FIRST_PROJECT 프로젝트로 전환했습니다."
    else
        print_warning "전환할 수 있는 프로젝트가 없습니다."
    fi
fi

# 정리 완료 상태 확인
print_header "정리 완료 상태 확인"
echo "=== 현재 프로젝트 목록 ==="
oc get projects | grep -E "(NAME|publish)" || echo "publish 프로젝트가 없습니다."

echo
echo "=== 현재 작업 프로젝트 ==="
CURRENT_PROJECT=$(oc project -q 2>/dev/null || echo "없음")
echo "현재 프로젝트: $CURRENT_PROJECT"

echo
echo "=== 소스 파일 상태 ==="
if [ -d "$WEB_DIR" ]; then
    echo "소스 디렉터리: $WEB_DIR (유지됨)"
    ls -la "$WEB_DIR" 2>/dev/null || echo "디렉터리 접근 불가"
else
    echo "소스 디렉터리: 삭제됨"
fi

# 최종 안내
print_header "정리 완료"
print_success "Lab 14 환경 정리가 완료되었습니다!"
echo
echo -e "${YELLOW}정리된 항목:${NC}"
echo "• OpenShift 리소스 (Deployments, Services, ConfigMaps, Pods)"
echo "• publish 프로젝트 (선택적)"
echo "• 소스 파일 디렉터리 (선택적)"
echo
echo -e "${BLUE}다시 실습하려면:${NC}"
echo "  ./setup-lab.sh"
echo
echo -e "${GREEN}수고하셨습니다!${NC}"