#!/bin/bash

# DO180 Lab 20: Mount Storage - PV and PVC - 정리 스크립트
# 실습 환경 정리

set -e

echo "=========================================="
echo "DO180 Lab 20 - 실습 환경 정리"
echo "=========================================="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 1. webserver 프로젝트 삭제
echo -e "${YELLOW}[1/3] webserver 프로젝트 삭제 중...${NC}"
oc delete project webserver 2>/dev/null && \
    echo -e "${GREEN}✓ webserver 프로젝트 삭제 완료${NC}" || \
    echo -e "${YELLOW}⚠ webserver 프로젝트가 존재하지 않거나 이미 삭제되었습니다${NC}"
echo ""

# 2. PersistentVolume 삭제
echo -e "${YELLOW}[2/3] PersistentVolume 삭제 중...${NC}"
oc delete pv web-pv 2>/dev/null && \
    echo -e "${GREEN}✓ PersistentVolume 'web-pv' 삭제 완료${NC}" || \
    echo -e "${YELLOW}⚠ PersistentVolume 'web-pv'가 존재하지 않거나 이미 삭제되었습니다${NC}"
echo ""

# 3. NFS 데이터 정리 (선택사항)
echo -e "${YELLOW}[3/3] NFS 데이터 정리 옵션${NC}"
echo -e "${BLUE}NFS 서버의 데이터를 삭제하시겠습니까? (y/N)${NC}"
read -t 10 -r CLEANUP_NFS || CLEANUP_NFS="n"
if [[ $CLEANUP_NFS =~ ^[Yy]$ ]]; then
    NFS_SERVER=$(oc get deployment nfs-client-provisioner -n nfs-client-provisioner -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="NFS_SERVER")].value}' 2>/dev/null || echo "192.168.50.254")
    NFS_BASE_PATH=$(oc get deployment nfs-client-provisioner -n nfs-client-provisioner -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="NFS_PATH")].value}' 2>/dev/null || echo "/exports-ocp4")
    NFS_PATH="${NFS_BASE_PATH}/page"
    echo -e "${YELLOW}  NFS 데이터 삭제 시도 중...${NC}"
    ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@${NFS_SERVER} "rm -rf ${NFS_PATH}/*" 2>/dev/null && \
        echo -e "${GREEN}✓ NFS 데이터 삭제 완료${NC}" || \
        echo -e "${YELLOW}⚠ NFS 데이터를 자동으로 삭제할 수 없습니다. 수동으로 확인하세요.${NC}"
else
    echo -e "${BLUE}  NFS 데이터는 유지됩니다${NC}"
fi
echo ""

# 최종 확인
echo "=========================================="
echo -e "${GREEN}실습 환경 정리 완료!${NC}"
echo "=========================================="
echo ""
echo -e "${BLUE}남은 리소스 확인:${NC}"
echo ""
echo "PersistentVolumes:"
oc get pv | grep web-pv || echo -e "${GREEN}✓ 없음${NC}"
echo ""
echo "Projects:"
oc get project webserver 2>/dev/null || echo -e "${GREEN}✓ webserver 프로젝트 삭제됨${NC}"
echo ""
echo -e "${GREEN}정리가 완료되었습니다.${NC}"
echo "=========================================="
