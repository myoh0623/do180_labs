#!/bin/bash

# DO180 Lab 18 Cleanup Script
# Red Hat Support를 위한 클러스터 정보 수집 실습 환경 정리

set -e

echo "=== DO180 Lab 18 Cleanup: Red Hat Support를 위한 클러스터 정보 수집 정리 ==="
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
    print_warning "OpenShift에 로그인하지 않았습니다."
    echo "일부 정리 작업은 OpenShift 연결 없이도 수행됩니다."
else
    CURRENT_USER=$(oc whoami)
    print_success "현재 사용자: $CURRENT_USER"
fi

# 홈 디렉터리로 이동
cd ~
echo "작업 디렉터리: $(pwd)"

# must-gather 관련 리소스 정리
print_header "must-gather 관련 리소스 정리"
if oc whoami &> /dev/null; then
    # 실행 중인 must-gather 네임스페이스 확인
    if oc get namespace | grep -q "openshift-must-gather"; then
        print_warning "실행 중인 must-gather 네임스페이스가 있습니다."
        echo "must-gather 네임스페이스 목록:"
        oc get namespace | grep "openshift-must-gather" || echo "  (없음)"
        echo
        
        read -p "실행 중인 must-gather 네임스페이스를 정리하시겠습니까? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "must-gather 네임스페이스 정리 중..."
            oc get namespace -o name | grep "openshift-must-gather" | xargs oc delete --ignore-not-found=true
            print_success "must-gather 네임스페이스가 정리되었습니다."
        else
            print_warning "must-gather 네임스페이스가 유지됩니다."
        fi
    else
        print_success "실행 중인 must-gather 네임스페이스가 없습니다."
    fi
    
    # must-gather clusterrolebinding 정리
    if oc get clusterrolebinding | grep -q "must-gather"; then
        print_warning "must-gather clusterrolebinding이 있습니다."
        echo "must-gather clusterrolebinding 목록:"
        oc get clusterrolebinding | grep "must-gather" || echo "  (없음)"
        echo
        
        read -p "must-gather clusterrolebinding을 정리하시겠습니까? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "must-gather clusterrolebinding 정리 중..."
            oc get clusterrolebinding -o name | grep "must-gather" | xargs oc delete --ignore-not-found=true
            print_success "must-gather clusterrolebinding이 정리되었습니다."
        else
            print_warning "must-gather clusterrolebinding이 유지됩니다."
        fi
    else
        print_success "must-gather clusterrolebinding이 없습니다."
    fi
else
    print_warning "OpenShift 연결이 없어 클러스터 리소스 정리를 건너뜁니다."
fi

# 로컬 must-gather 데이터 정리
print_header "로컬 must-gather 데이터 정리"
if ls must-gather.local.* &> /dev/null; then
    echo "삭제할 must-gather 데이터:"
    ls -lah must-gather.local.* | awk '{print "  - " $9 " (" $5 ")"}'
    echo
    
    # 전체 크기 계산
    TOTAL_SIZE=$(du -sh must-gather.local.* 2>/dev/null | awk '{sum+=$1} END {print sum "B"}' || echo "크기 확인 불가")
    echo "전체 크기: $TOTAL_SIZE"
    echo
    
    read -p "must-gather 데이터를 삭제하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf must-gather.local.*
        print_success "must-gather 데이터가 삭제되었습니다."
    else
        print_warning "must-gather 데이터가 유지됩니다."
    fi
else
    print_success "삭제할 must-gather 데이터가 없습니다."
fi

# 압축 파일 정리
print_header "압축 파일 정리"
if ls ex280-ocp-*.tar.gz &> /dev/null; then
    echo "삭제할 압축 파일:"
    ls -lah ex280-ocp-*.tar.gz | awk '{print "  - " $9 " (" $5 ")"}'
    echo
    
    # 전체 크기 계산
    TOTAL_SIZE=$(du -sh ex280-ocp-*.tar.gz 2>/dev/null | awk '{sum+=$1} END {print sum}' || echo "크기 확인 불가")
    echo "전체 크기: $TOTAL_SIZE"
    echo
    
    read -p "압축 파일을 삭제하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f ex280-ocp-*.tar.gz
        print_success "압축 파일이 삭제되었습니다."
    else
        print_warning "압축 파일이 유지됩니다."
    fi
else
    print_success "삭제할 압축 파일이 없습니다."
fi

# 실습 스크립트 및 참조 파일 정리
print_header "실습 파일 정리"
LAB_FILES=(
    "must-gather-commands.txt"
    "run-must-gather.sh"
    "upload-cluster-data.sh"
    "lab18-scripts"
)

FILES_TO_DELETE=()
for file in "${LAB_FILES[@]}"; do
    if [ -e "$file" ]; then
        FILES_TO_DELETE+=("$file")
    fi
done

if [ ${#FILES_TO_DELETE[@]} -gt 0 ]; then
    echo "삭제할 실습 파일:"
    for file in "${FILES_TO_DELETE[@]}"; do
        if [ -d "$file" ]; then
            echo "  - $file/ (디렉터리)"
        else
            echo "  - $file"
        fi
    done
    echo
    
    read -p "실습 파일을 삭제하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for file in "${FILES_TO_DELETE[@]}"; do
            rm -rf "$file"
        done
        print_success "실습 파일이 삭제되었습니다."
    else
        print_warning "실습 파일이 유지됩니다."
    fi
else
    print_success "삭제할 실습 파일이 없습니다."
fi

# 임시 파일 정리
print_header "임시 파일 정리"
TEMP_PATTERNS=(
    "*.tmp"
    "*must-gather*.log"
    "cluster-data-*"
    ".must-gather-*"
)

TEMP_FILES_FOUND=false
for pattern in "${TEMP_PATTERNS[@]}"; do
    if ls $pattern &> /dev/null; then
        if [ "$TEMP_FILES_FOUND" = false ]; then
            echo "임시 파일 발견:"
            TEMP_FILES_FOUND=true
        fi
        ls -la $pattern | awk '{print "  - " $9}'
    fi
done

if [ "$TEMP_FILES_FOUND" = true ]; then
    echo
    read -p "임시 파일을 삭제하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        for pattern in "${TEMP_PATTERNS[@]}"; do
            rm -f $pattern 2>/dev/null || true
        done
        print_success "임시 파일이 삭제되었습니다."
    else
        print_warning "임시 파일이 유지됩니다."
    fi
else
    print_success "삭제할 임시 파일이 없습니다."
fi

# 정리 완료 상태 확인
print_header "정리 완료 상태 확인"
echo "=== 현재 홈 디렉터리 상태 ==="
echo "위치: $(pwd)"

echo
echo "=== must-gather 관련 파일 ==="
if ls must-gather* ex280-ocp-* *must-gather* &> /dev/null; then
    ls -lah must-gather* ex280-ocp-* *must-gather* 2>/dev/null | head -10
    if [ $(ls must-gather* ex280-ocp-* *must-gather* 2>/dev/null | wc -l) -gt 10 ]; then
        echo "... (더 많은 파일이 있습니다)"
    fi
else
    echo "must-gather 관련 파일 없음"
fi

echo
echo "=== 실습 관련 파일 ==="
if ls run-must-gather.sh must-gather-commands.txt lab18-scripts upload-cluster-data.sh &> /dev/null; then
    ls -lah run-must-gather.sh must-gather-commands.txt lab18-scripts upload-cluster-data.sh 2>/dev/null
else
    echo "실습 관련 파일 없음"
fi

if oc whoami &> /dev/null; then
    echo
    echo "=== OpenShift 클러스터 상태 ==="
    echo "현재 사용자: $(oc whoami)"
    echo "현재 프로젝트: $(oc project -q 2>/dev/null || echo '확인 불가')"
    
    # must-gather 관련 클러스터 리소스 확인
    MUST_GATHER_NS_COUNT=$(oc get namespace 2>/dev/null | grep -c "openshift-must-gather" || echo "0")
    MUST_GATHER_RB_COUNT=$(oc get clusterrolebinding 2>/dev/null | grep -c "must-gather" || echo "0")
    
    echo "must-gather 네임스페이스: $MUST_GATHER_NS_COUNT 개"
    echo "must-gather clusterrolebinding: $MUST_GATHER_RB_COUNT 개"
fi

echo
echo "=== 디스크 사용량 ==="
echo "홈 디렉터리 사용량: $(du -sh ~ 2>/dev/null | cut -f1)"
echo "사용 가능 공간: $(df -h ~ | tail -1 | awk '{print $4}')"

# 최종 안내
print_header "정리 완료"
print_success "Lab 18 환경 정리가 완료되었습니다!"
echo
echo -e "${YELLOW}정리된 항목 (선택적):${NC}"
echo "• must-gather 로컬 데이터 디렉터리"
echo "• 압축된 tar.gz 파일"
echo "• 실습용 스크립트 및 참조 파일"
echo "• OpenShift must-gather 네임스페이스 및 권한"
echo "• 임시 파일"
echo
echo -e "${BLUE}정리되지 않은 항목:${NC}"
echo "• OpenShift 클러스터의 기본 설정"
echo "• 사용자 권한 및 로그인 상태"
echo "• 다른 프로젝트의 리소스"
echo
echo -e "${BLUE}다시 실습하려면:${NC}"
echo "  ./setup-lab.sh"
echo
echo -e "${YELLOW}참고사항:${NC}"
echo "must-gather 데이터는 민감한 클러스터 정보를 포함하므로"
echo "보안을 위해 사용 후 적절히 삭제하는 것이 좋습니다."
echo
echo -e "${GREEN}수고하셨습니다!${NC}"