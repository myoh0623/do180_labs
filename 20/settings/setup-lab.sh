#!/bin/bash

# DO180 Lab 20: Mount Storage - PV and PVC - 자동 설정 스크립트
# NFS 기반 스토리지 실습 환경 구성

set -e

# 스크립트 디렉토리 확인
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "DO180 Lab 20 - Mount Storage PV/PVC 실습 환경 구성"
echo "=========================================="
echo ""

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 1. NFS 서버 확인 또는 설정
echo -e "${YELLOW}[2/7] NFS 서버 정보 확인 중...${NC}"
# NFS Storage Class에서 서버 정보 자동 감지
NFS_SERVER=$(oc get deployment nfs-client-provisioner -n nfs-client-provisioner -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="NFS_SERVER")].value}' 2>/dev/null || echo "192.168.50.254")
NFS_BASE_PATH=$(oc get deployment nfs-client-provisioner -n nfs-client-provisioner -o jsonpath='{.spec.template.spec.containers[0].env[?(@.name=="NFS_PATH")].value}' 2>/dev/null || echo "/exports-ocp4")
NFS_PATH="${NFS_BASE_PATH}/page"

echo -e "${BLUE}  NFS Server: $NFS_SERVER${NC}"
echo -e "${BLUE}  NFS Path: $NFS_PATH${NC}"

# NFS 디렉토리 생성 시도 (권한이 있는 경우)
echo -e "${YELLOW}  NFS 디렉토리 준비 시도 중...${NC}"
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@${NFS_SERVER} "mkdir -p ${NFS_PATH} && chmod 755 ${NFS_PATH}" 2>/dev/null && \
    echo -e "${GREEN}✓ NFS 디렉토리 생성 완료${NC}" || \
    echo -e "${YELLOW}⚠ NFS 디렉토리를 자동으로 생성할 수 없습니다. 수동으로 확인하세요.${NC}"

# 샘플 HTML 파일 생성 시도
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 root@${NFS_SERVER} "cat > ${NFS_PATH}/index.html <<'HTMLEOF'
<!DOCTYPE html>
<html lang=\"en\">
<head>
    <meta charset=\"UTF-8\">
    <meta name=\"viewport\" content=\"width=device-width, initial-scale=1.0\">
    <title>Exoplanets - DO180 Lab 20</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-align: center;
            padding: 50px;
        }
        h1 { font-size: 3em; margin-bottom: 20px; }
        p { font-size: 1.5em; }
        .info { background: rgba(255,255,255,0.1); padding: 20px; border-radius: 10px; margin: 20px auto; max-width: 600px; }
    </style>
</head>
<body>
    <h1>🪐 Exoplanets Discovery Portal</h1>
    <p>Welcome to the Declarative Manifests Project</p>
    <div class=\"info\">
        <h2>Storage Information</h2>
        <p><strong>Storage Type:</strong> NFS-backed Persistent Volume</p>
        <p><strong>Access Mode:</strong> ReadOnlyMany (ROX)</p>
        <p><strong>Capacity:</strong> 1Gi</p>
        <p><strong>Replicas:</strong> 3 Pods sharing the same storage</p>
    </div>
    <p>Lab 20: Mount Storage - PV and PVC</p>
</body>
</html>
HTMLEOF
chmod 644 ${NFS_PATH}/index.html" 2>/dev/null && \
    echo -e "${GREEN}✓ 샘플 HTML 파일 생성 완료${NC}" || \
    echo -e "${YELLOW}⚠ 샘플 HTML 파일을 자동으로 생성할 수 없습니다.${NC}"
echo ""

# 최종 상태 확인
echo "=========================================="
echo -e "${GREEN}실습 환경 구성 완료!${NC}"
echo "=========================================="
