#!/bin/bash

# DO180 Lab 18 Setup Script
# Red Hat Support를 위한 클러스터 정보 수집 실습 환경 구성

set -e

echo "=== DO180 Lab 18 Setup: Red Hat Support를 위한 클러스터 정보 수집 ==="
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

# cluster-admin 권한 확인
print_header "권한 확인"
if oc auth can-i create pods --all-namespaces &> /dev/null; then
    print_success "cluster-admin 권한이 있습니다."
else
    print_warning "cluster-admin 권한이 없을 수 있습니다."
    echo "must-gather를 실행하려면 cluster-admin 권한이 필요합니다."
    echo
    echo "권한 확인 방법:"
    echo "  oc auth can-i create pods --all-namespaces"
    echo "  oc auth can-i create clusterrolebindings"
    echo
    echo "권한이 없다면 관리자에게 다음을 요청하세요:"
    echo "  oc adm policy add-cluster-role-to-user cluster-admin $CURRENT_USER"
fi

# 클러스터 정보 확인
print_header "클러스터 정보 확인"
echo "현재 사용자: $(oc whoami)"
echo "클러스터 콘솔: $(oc whoami --show-console 2>/dev/null || echo '확인 불가')"
echo "클러스터 서버: $(oc whoami --show-server 2>/dev/null || echo '확인 불가')"

# 클러스터 ID 확인
if CLUSTER_ID=$(oc get clusterversion version -o jsonpath='{.spec.clusterID}' 2>/dev/null); then
    echo "클러스터 ID: $CLUSTER_ID"
    print_success "클러스터 ID가 확인되었습니다."
else
    print_warning "클러스터 ID를 가져올 수 없습니다. 권한을 확인하세요."
fi

# 클러스터 버전 확인
if CLUSTER_VERSION=$(oc get clusterversion version -o jsonpath='{.status.desired.version}' 2>/dev/null); then
    echo "클러스터 버전: $CLUSTER_VERSION"
else
    print_warning "클러스터 버전을 가져올 수 없습니다."
fi

# 디스크 공간 확인
print_header "디스크 공간 확인"
HOME_SPACE=$(df -h ~ | tail -1 | awk '{print $4}')
echo "홈 디렉터리 사용 가능 공간: $HOME_SPACE"

# 공간이 부족한지 확인 (단순화된 체크)
AVAILABLE_KB=$(df ~ | tail -1 | awk '{print $4}')
if [ "$AVAILABLE_KB" -lt 2097152 ]; then  # 2GB = 2097152 KB
    print_warning "디스크 공간이 부족할 수 있습니다 (2GB 미만)."
    echo "must-gather 데이터는 보통 100MB-1GB 정도입니다."
else
    print_success "충분한 디스크 공간이 있습니다."
fi

# 업로드 스크립트 확인
print_header "업로드 스크립트 확인"
UPLOAD_SCRIPT="/usr/local/bin/upload-cluster-data.sh"
if [ -f "$UPLOAD_SCRIPT" ]; then
    print_success "업로드 스크립트가 존재합니다: $UPLOAD_SCRIPT"
    
    # 스크립트 권한 확인
    if [ -x "$UPLOAD_SCRIPT" ]; then
        print_success "스크립트에 실행 권한이 있습니다."
    else
        print_warning "스크립트에 실행 권한이 없습니다."
        echo "다음 명령으로 권한을 부여하세요:"
        echo "sudo chmod +x $UPLOAD_SCRIPT"
    fi
else
    print_error "업로드 스크립트가 존재하지 않습니다: $UPLOAD_SCRIPT"
    echo "실습 환경에서 스크립트를 생성합니다."
    
    # 실습용 더미 업로드 스크립트 생성
    mkdir -p ~/lab18-scripts
    cat > ~/lab18-scripts/upload-cluster-data.sh << 'EOF'
#!/bin/bash

# 실습용 더미 업로드 스크립트
# 실제 환경에서는 /usr/local/bin/upload-cluster-data.sh를 사용하세요

if [ $# -ne 1 ]; then
    echo "사용법: $0 <파일명>"
    echo "예시: $0 ex280-ocp-cluster123.tar.gz"
    exit 1
fi

FILENAME="$1"

if [ ! -f "$FILENAME" ]; then
    echo "오류: 파일 '$FILENAME'을 찾을 수 없습니다."
    exit 1
fi

echo "=== 실습용 업로드 시뮬레이션 ==="
echo "파일명: $FILENAME"
echo "파일 크기: $(du -sh "$FILENAME" | cut -f1)"
echo "업로드 시뮬레이션 중..."

# 실습용 딜레이
sleep 2

echo "Upload successful (시뮬레이션)"
echo "실제 환경에서는 /usr/local/bin/upload-cluster-data.sh를 사용하세요."
EOF
    
    chmod +x ~/lab18-scripts/upload-cluster-data.sh
    print_success "실습용 업로드 스크립트가 생성되었습니다: ~/lab18-scripts/upload-cluster-data.sh"
fi

# 작업 디렉터리 설정
print_header "작업 디렉터리 설정"
cd ~
echo "작업 디렉터리: $(pwd)"

# 기존 must-gather 데이터 정리 (선택적)
if ls must-gather.local.* &> /dev/null; then
    print_warning "기존 must-gather 데이터가 존재합니다."
    echo "기존 데이터 목록:"
    ls -lah must-gather.local.*
    echo
    
    read -p "기존 must-gather 데이터를 정리하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -rf must-gather.local.*
        print_success "기존 must-gather 데이터가 정리되었습니다."
    else
        print_warning "기존 데이터가 유지됩니다."
    fi
fi

# 기존 압축 파일 정리 (선택적)
if ls ex280-ocp-*.tar.gz &> /dev/null; then
    print_warning "기존 압축 파일이 존재합니다."
    echo "기존 압축 파일 목록:"
    ls -lah ex280-ocp-*.tar.gz
    echo
    
    read -p "기존 압축 파일을 정리하시겠습니까? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        rm -f ex280-ocp-*.tar.gz
        print_success "기존 압축 파일이 정리되었습니다."
    else
        print_warning "기존 압축 파일이 유지됩니다."
    fi
fi

# 실습 참조 파일 생성
print_header "실습 참조 파일 생성"

# 명령어 참조 파일 생성
cat > ~/must-gather-commands.txt << 'EOF'
=== DO180 Lab 18: must-gather 실습 명령어 참조 ===

1. 클러스터 ID 확인:
   oc get clusterversion version -o jsonpath='{.spec.clusterID}'

2. 기본 must-gather 실행:
   oc adm must-gather

3. 생성된 디렉터리 확인:
   ls -la must-gather.local.*
   du -sh must-gather.local.*

4. 클러스터 ID 변수 저장:
   CLUSTER_ID=$(oc get clusterversion version -o jsonpath='{.spec.clusterID}')

5. 압축 파일 생성:
   tar -czf "ex280-ocp-${CLUSTER_ID}.tar.gz" must-gather.local.*

6. 압축 파일 확인:
   ls -lh ex280-ocp-*.tar.gz
   du -sh ex280-ocp-*.tar.gz

7. 업로드 (실제 환경):
   /usr/local/bin/upload-cluster-data.sh "ex280-ocp-${CLUSTER_ID}.tar.gz"

8. 업로드 (실습 환경):
   ~/lab18-scripts/upload-cluster-data.sh "ex280-ocp-${CLUSTER_ID}.tar.gz"

=== 고급 must-gather 명령어 ===

네트워킹 정보 수집:
oc adm must-gather --image=registry.redhat.io/openshift4/ose-cluster-network-operator-must-gather

스토리지 정보 수집:
oc adm must-gather --image=registry.redhat.io/ocs4/ocs-must-gather-rhel8

로깅 정보 수집:
oc adm must-gather --image=registry.redhat.io/openshift-logging/cluster-logging-operator-must-gather

특정 노드에서만 수집:
oc adm must-gather --node-name=<node-name>

사용자 정의 출력 디렉터리:
oc adm must-gather --dest-dir=./custom-gather-data
EOF

print_success "명령어 참조 파일이 생성되었습니다: ~/must-gather-commands.txt"

# 자동 실행 스크립트 생성
cat > ~/run-must-gather.sh << 'EOF'
#!/bin/bash

# DO180 Lab 18 자동 실행 스크립트
# must-gather 데이터 수집, 압축, 업로드를 자동으로 수행

set -e

echo "=== DO180 Lab 18: must-gather 자동 실행 ==="
echo

# 색상 정의
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_step() {
    echo -e "${BLUE}단계 $1: $2${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

# 홈 디렉터리로 이동
cd ~

print_step "1" "클러스터 정보 확인"
echo "현재 사용자: $(oc whoami)"
echo "클러스터 콘솔: $(oc whoami --show-console 2>/dev/null || echo '확인 불가')"

# 클러스터 ID 확인
CLUSTER_ID=$(oc get clusterversion version -o jsonpath='{.spec.clusterID}' 2>/dev/null || echo 'unknown')
echo "클러스터 ID: $CLUSTER_ID"

if [ "$CLUSTER_ID" = "unknown" ]; then
    print_warning "클러스터 ID를 가져올 수 없습니다."
    CLUSTER_ID="test-cluster-$(date +%s)"
    echo "임시 클러스터 ID 사용: $CLUSTER_ID"
fi

print_step "2" "기존 데이터 정리"
if ls must-gather.local.* &> /dev/null; then
    print_warning "기존 must-gather 데이터 정리 중..."
    rm -rf must-gather.local.*
fi

if ls ex280-ocp-*.tar.gz &> /dev/null; then
    print_warning "기존 압축 파일 정리 중..."
    rm -f ex280-ocp-*.tar.gz
fi

print_step "3" "must-gather 데이터 수집"
echo "데이터 수집을 시작합니다... (몇 분 소요될 수 있습니다)"
oc adm must-gather

print_step "4" "수집된 데이터 확인"
MUST_GATHER_DIR=$(ls -d must-gather.local.* | head -1)
echo "수집된 디렉터리: $MUST_GATHER_DIR"
echo "데이터 크기: $(du -sh "$MUST_GATHER_DIR" | cut -f1)"

print_step "5" "데이터 압축"
ARCHIVE_NAME="ex280-ocp-${CLUSTER_ID}.tar.gz"
echo "압축 파일명: $ARCHIVE_NAME"
tar -czf "$ARCHIVE_NAME" "$MUST_GATHER_DIR"

print_step "6" "압축 결과 확인"
echo "압축 파일 크기: $(du -sh "$ARCHIVE_NAME" | cut -f1)"
echo "압축 파일 상세 정보:"
ls -lh "$ARCHIVE_NAME"

print_step "7" "업로드 시뮬레이션"
if [ -f "/usr/local/bin/upload-cluster-data.sh" ]; then
    echo "실제 업로드 스크립트 사용..."
    /usr/local/bin/upload-cluster-data.sh "$ARCHIVE_NAME"
elif [ -f "~/lab18-scripts/upload-cluster-data.sh" ]; then
    echo "실습용 업로드 스크립트 사용..."
    ~/lab18-scripts/upload-cluster-data.sh "$ARCHIVE_NAME"
else
    echo "업로드 스크립트를 찾을 수 없습니다."
    echo "수동으로 다음 명령을 실행하세요:"
    echo "/usr/local/bin/upload-cluster-data.sh $ARCHIVE_NAME"
fi

print_success "Lab 18 must-gather 실습이 완료되었습니다!"
echo
echo "=== 결과 요약 ==="
echo "• 클러스터 ID: $CLUSTER_ID"
echo "• 원본 데이터: $MUST_GATHER_DIR ($(du -sh "$MUST_GATHER_DIR" | cut -f1))"
echo "• 압축 파일: $ARCHIVE_NAME ($(du -sh "$ARCHIVE_NAME" | cut -f1))"
echo
echo "=== 추가 명령어 ==="
echo "• 압축 파일 내용 확인: tar -tzf $ARCHIVE_NAME | head -20"
echo "• 데이터 정리: rm -rf must-gather.local.* ex280-ocp-*.tar.gz"
EOF

chmod +x ~/run-must-gather.sh
print_success "자동 실행 스크립트가 생성되었습니다: ~/run-must-gather.sh"

# 현재 상태 표시
print_header "실습 환경 상태 확인"
echo "=== 현재 디렉터리 ==="
pwd

echo
echo "=== 홈 디렉터리 주요 파일 ==="
ls -la ~ | grep -E "(must-gather|ex280-ocp|upload|run-must-gather|lab18)" || echo "관련 파일 없음"

echo
echo "=== 클러스터 연결 상태 ==="
echo "사용자: $(oc whoami 2>/dev/null || echo '로그인 필요')"
echo "프로젝트: $(oc project -q 2>/dev/null || echo '확인 불가')"

# 실습 준비 완료 안내
print_header "실습 준비 완료"
print_success "Lab 18 환경 구성이 완료되었습니다!"
echo
echo -e "${YELLOW}실습 시작 방법:${NC}"
echo "1. 수동 실습: README.md 파일의 단계별 가이드를 따라하세요"
echo "2. 자동 실습: ~/run-must-gather.sh 스크립트를 실행하세요"
echo "3. 명령어 참조: ~/must-gather-commands.txt 파일을 확인하세요"
echo
echo -e "${YELLOW}주요 명령어:${NC}"
echo "• 클러스터 ID 확인: oc get clusterversion version -o jsonpath='{.spec.clusterID}'"
echo "• must-gather 실행: oc adm must-gather"
echo "• 데이터 압축: tar -czf ex280-ocp-<클러스터ID>.tar.gz must-gather.local.*"
echo
if [ -f "/usr/local/bin/upload-cluster-data.sh" ]; then
    echo -e "${YELLOW}업로드 명령:${NC} /usr/local/bin/upload-cluster-data.sh <파일명>"
else
    echo -e "${YELLOW}업로드 명령 (실습용):${NC} ~/lab18-scripts/upload-cluster-data.sh <파일명>"
fi
echo
echo -e "${BLUE}실습 가이드:${NC} README.md 파일을 참조하세요."
echo -e "${BLUE}정리 명령:${NC} ./cleanup-lab.sh"
echo

print_success "Lab 18 실습을 시작하세요!"