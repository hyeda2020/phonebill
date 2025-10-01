# phonebill Jenkins CI/CD 파이프라인 구축 가이드

## 목차
1. [개요](#개요)
2. [사전 준비사항](#사전-준비사항)
3. [Jenkins 서버 환경 구성](#jenkins-서버-환경-구성)
4. [CI/CD 파이프라인 구조](#cicd-파이프라인-구조)
5. [배포 실행 방법](#배포-실행-방법)
6. [롤백 방법](#롤백-방법)
7. [문제 해결](#문제-해결)

---

## 개요

### 프로젝트 정보
- **시스템명**: phonebill
- **서비스 목록**: api-gateway, user-service, bill-service, product-service, kos-mock
- **JDK 버전**: 23
- **빌드 도구**: Gradle
- **컨테이너 레지스트리**: Azure Container Registry (acrdigitalgarage01)
- **쿠버네티스 클러스터**: aks-digitalgarage-01
- **네임스페이스**: phonebill-dg0504

### CI/CD 파이프라인 특징
- **Jenkins + Kustomize** 기반 자동화 배포
- **환경별 매니페스트 관리**: dev/staging/prod
- **SonarQube 코드 품질 분석** 및 Quality Gate 적용
- **Pod 자동 정리**: 파이프라인 완료 시 에이전트 파드 자동 삭제
- **병렬 처리**: 여러 서비스를 동시에 빌드 및 배포

---

## 사전 준비사항

### Azure 리소스 정보
- ACR 이름: `acrdigitalgarage01`
- 리소스 그룹: `rg-digitalgarage-01`
- AKS 클러스터: `aks-digitalgarage-01`
- 네임스페이스: `phonebill-dg0504`

### 필수 도구
- Jenkins (버전 2.x 이상)
- kubectl
- Azure CLI
- Kustomize
- Podman (컨테이너 빌드용)

---

## Jenkins 서버 환경 구성

### 1. 필수 플러그인 설치

Jenkins 관리 > 플러그인 관리에서 다음 플러그인 설치:

```
- Kubernetes
- Pipeline Utility Steps
- Docker Pipeline
- GitHub
- SonarQube Scanner
- Azure Credentials
```

### 2. Credentials 등록

**Jenkins 관리 > Credentials > Add Credentials**

#### Azure Service Principal
```
Kind: Microsoft Azure Service Principal
ID: azure-credentials
Subscription ID: {Azure 구독 ID}
Client ID: {서비스 프린시펄 Client ID}
Client Secret: {서비스 프린시펄 Client Secret}
Tenant ID: {Azure Tenant ID}
Azure Environment: Azure
```

#### ACR Credentials
```
Kind: Username with password
ID: acr-credentials
Username: acrdigitalgarage01
Password: {ACR 액세스 키}
```

**ACR 액세스 키 확인 방법:**
```bash
az acr credential show --name acrdigitalgarage01 --resource-group rg-digitalgarage-01
```

#### Docker Hub Credentials (Rate Limit 해결용)
```
Kind: Username with password
ID: dockerhub-credentials
Username: {Docker Hub 사용자명}
Password: {Docker Hub 패스워드}
```

**참고**: Docker Hub 무료 계정 생성 - https://hub.docker.com

#### SonarQube Token
```
Kind: Secret text
ID: sonarqube-token
Secret: {SonarQube에서 생성한 토큰}
```

**SonarQube 토큰 생성 방법:**
1. SonarQube > My Account > Security > Generate Tokens
2. 토큰 이름 입력 후 생성
3. 생성된 토큰을 Jenkins Credentials에 등록

### 3. SonarQube 서버 설정

**Jenkins 관리 > Configure System > SonarQube servers**

```
Name: SonarQube
Server URL: {SonarQube 서버 URL}
Server authentication token: sonarqube-token (위에서 생성한 Credentials)
```

### 4. Jenkins Pipeline Job 생성

1. **새로운 Item > Pipeline** 선택
2. **General 섹션**
   - 프로젝트명: phonebill-cicd

3. **Build with Parameters 섹션**
   - ENVIRONMENT: Choice Parameter
     - Choices: `dev`, `staging`, `prod`
     - Description: 배포 환경 선택

   - SKIP_SONARQUBE: String Parameter
     - Default Value: `true`
     - Description: SonarQube 분석 건너뛰기 (true/false)

4. **Pipeline 섹션**
   - Definition: Pipeline script from SCM
   - SCM: Git
   - Repository URL: {Git 저장소 URL}
   - Branch: main (또는 develop)
   - Script Path: `deployment/cicd/Jenkinsfile`

5. **저장**

---

## CI/CD 파이프라인 구조

### 디렉토리 구조
```
deployment/cicd/
├── config/
│   ├── deploy_env_vars_dev        # dev 환경 설정
│   ├── deploy_env_vars_staging    # staging 환경 설정
│   └── deploy_env_vars_prod       # prod 환경 설정
├── kustomize/
│   ├── base/                      # Base 매니페스트
│   │   ├── common/
│   │   ├── api-gateway/
│   │   ├── user-service/
│   │   ├── bill-service/
│   │   ├── product-service/
│   │   ├── kos-mock/
│   │   └── kustomization.yaml
│   └── overlays/                  # 환경별 Overlay
│       ├── dev/
│       ├── staging/
│       └── prod/
├── scripts/
│   ├── deploy.sh                  # 수동 배포 스크립트
│   └── validate-cicd-setup.sh     # 리소스 검증 스크립트
├── Jenkinsfile                    # Jenkins 파이프라인
└── jenkins-pipeline-guide.md      # 본 가이드
```

### 파이프라인 단계

1. **Get Source**: Git 저장소에서 소스 코드 체크아웃
2. **Setup AKS**: Azure 로그인 및 AKS 클러스터 인증
3. **Build**: Gradle로 애플리케이션 빌드 (테스트 제외)
4. **SonarQube Analysis & Quality Gate**:
   - 코드 품질 분석 (SKIP_SONARQUBE=false일 때만 실행)
   - 각 서비스별 개별 테스트 및 분석
   - Quality Gate 통과 확인
5. **Build & Push Images**:
   - Podman으로 컨테이너 이미지 빌드
   - ACR에 이미지 푸시 (태그: {환경}-{타임스탬프})
6. **Update Kustomize & Deploy**:
   - Kustomize로 이미지 태그 업데이트
   - Kubernetes에 배포
   - Deployment 준비 상태 확인
7. **Pipeline Complete**: 파이프라인 완료 및 파드 자동 정리

### 환경별 설정 차이

| 설정 | dev | staging | prod |
|------|-----|---------|------|
| Replicas | 1 | 2 | 3 |
| CPU Request | 256m | 512m | 1024m |
| Memory Request | 256Mi | 512Mi | 1024Mi |
| CPU Limit | 1024m | 2048m | 4096m |
| Memory Limit | 1024Mi | 2048Mi | 4096Mi |
| Spring Profile | dev | staging | prod |
| DDL Auto | update | validate | validate |
| JWT Validity | 18000000 (5시간) | 18000000 (5시간) | 3600000 (1시간) |
| SSL Redirect | false | true | true |

---

## 배포 실행 방법

### 1. Jenkins 웹 UI를 통한 배포

1. Jenkins > **phonebill-cicd** 프로젝트 선택
2. **Build with Parameters** 클릭
3. 파라미터 설정:
   - **ENVIRONMENT**: dev/staging/prod 선택
   - **SKIP_SONARQUBE**:
     - `true`: SonarQube 분석 건너뛰기 (빠른 배포)
     - `false`: SonarQube 분석 및 Quality Gate 실행
4. **Build** 클릭
5. 빌드 진행 상황 확인:
   - Console Output에서 실시간 로그 확인
   - Stage View에서 각 단계별 진행 상황 확인

### 2. 수동 배포 스크립트 사용

로컬 환경이나 수동 배포가 필요한 경우:

```bash
# dev 환경에 latest 태그로 배포
./deployment/cicd/scripts/deploy.sh dev latest

# staging 환경에 특정 태그로 배포
./deployment/cicd/scripts/deploy.sh staging 20250101120000

# prod 환경에 특정 태그로 배포
./deployment/cicd/scripts/deploy.sh prod 20250101120000
```

### 3. 배포 상태 확인

```bash
# Pod 상태 확인
kubectl get pods -n phonebill-dg0504

# Service 확인
kubectl get services -n phonebill-dg0504

# Ingress 확인
kubectl get ingress -n phonebill-dg0504

# 특정 서비스 로그 확인
kubectl logs -f deployment/user-service -n phonebill-dg0504

# 배포 이력 확인
kubectl rollout history deployment/user-service -n phonebill-dg0504
```

---

## 롤백 방법

### 1. 이전 버전으로 즉시 롤백

```bash
# 특정 서비스를 이전 버전으로 롤백
kubectl rollout undo deployment/user-service -n phonebill-dg0504

# 특정 리비전으로 롤백
kubectl rollout undo deployment/user-service -n phonebill-dg0504 --to-revision=2

# 롤백 상태 확인
kubectl rollout status deployment/user-service -n phonebill-dg0504
```

### 2. 이미지 태그 기반 롤백

안정적인 이전 버전의 이미지 태그를 알고 있는 경우:

```bash
cd deployment/cicd/kustomize/overlays/dev

# 이전 안정 버전 이미지 태그로 업데이트
kustomize edit set image acrdigitalgarage01.azurecr.io/phonebill/user-service:dev-20250101100000

# 배포 실행
kubectl apply -k .

# 롤백 상태 확인
kubectl rollout status deployment/user-service -n phonebill-dg0504
```

### 3. 전체 서비스 롤백 스크립트

```bash
#!/bin/bash
ENVIRONMENT="dev"
PREVIOUS_TAG="20250101100000"  # 이전 안정 버전 태그

cd deployment/cicd/kustomize/overlays/${ENVIRONMENT}

services="api-gateway user-service bill-service product-service kos-mock"

for service in $services; do
    kustomize edit set image acrdigitalgarage01.azurecr.io/phonebill/$service:${ENVIRONMENT}-${PREVIOUS_TAG}
done

kubectl apply -k .

for service in $services; do
    kubectl rollout status deployment/$service -n phonebill-dg0504
done
```

---

## 문제 해결

### 1. 파이프라인 실패 시 체크리스트

#### Build 단계 실패
```
원인: Gradle 빌드 오류, 컴파일 에러
해결:
1. Console Output에서 에러 메시지 확인
2. 로컬에서 ./gradlew build 실행하여 재현
3. 소스 코드 수정 후 다시 커밋
```

#### SonarQube Analysis 실패
```
원인: 테스트 실패, Quality Gate 미통과
해결:
1. SonarQube 서버에서 프로젝트 확인
2. 실패한 Quality Gate 조건 확인
3. 코드 품질 개선 후 재배포
4. 급한 경우: SKIP_SONARQUBE=true로 배포
```

#### Build & Push Images 단계 실패
```
원인: ACR 인증 실패, 이미지 빌드 오류
해결:
1. ACR Credentials 확인
2. Docker Hub Credentials 확인 (Rate Limit 문제)
3. Dockerfile 문법 확인
4. ACR 접근 권한 확인
```

#### Deploy 단계 실패
```
원인: Kubernetes 리소스 오류, 네임스페이스 미존재
해결:
1. kubectl get pods -n phonebill-dg0504 확인
2. kubectl describe pod <pod-name> -n phonebill-dg0504
3. Kustomize 매니페스트 문법 검증:
   kubectl kustomize deployment/cicd/kustomize/overlays/dev
4. 네임스페이스 생성:
   kubectl create namespace phonebill-dg0504
```

### 2. 리소스 검증

배포 전 Kustomize 리소스 누락 여부 확인:

```bash
./deployment/cicd/scripts/validate-cicd-setup.sh
```

검증 항목:
- Base 디렉토리의 모든 서비스 파일 존재 여부
- kustomization.yaml의 리소스 참조 정확성
- 환경별 overlay 빌드 성공 여부

### 3. Pod 로그 확인

```bash
# 모든 서비스 Pod 상태 확인
kubectl get pods -n phonebill-dg0504

# 특정 서비스 로그 확인 (실시간)
kubectl logs -f deployment/user-service -n phonebill-dg0504

# 여러 개의 Pod 로그 동시 확인
kubectl logs -f -l app=phonebill -n phonebill-dg0504

# 이전 Pod 로그 확인 (Crash 시)
kubectl logs --previous <pod-name> -n phonebill-dg0504
```

### 4. 이미지 태그 확인

```bash
# 현재 배포된 이미지 태그 확인
kubectl get deployment user-service -n phonebill-dg0504 -o jsonpath='{.spec.template.spec.containers[0].image}'

# ACR에 푸시된 이미지 목록 확인
az acr repository show-tags --name acrdigitalgarage01 --repository phonebill/user-service --orderby time_desc --top 10
```

### 5. 네트워크 및 Ingress 문제

```bash
# Ingress 상태 확인
kubectl get ingress -n phonebill-dg0504

# Ingress 상세 정보
kubectl describe ingress phonebill -n phonebill-dg0504

# Service Endpoint 확인
kubectl get endpoints -n phonebill-dg0504

# Service로 직접 접근 테스트
kubectl port-forward service/user-service 8080:80 -n phonebill-dg0504
```

---

## SonarQube 프로젝트 설정

### Quality Gate 설정

각 서비스별 프로젝트에 다음 Quality Gate 적용:

| 메트릭 | 조건 |
|--------|------|
| Coverage | >= 80% |
| Duplicated Lines | <= 3% |
| Maintainability Rating | <= A |
| Reliability Rating | <= A |
| Security Rating | <= A |

### 프로젝트 생성

SonarQube에서 각 서비스별로 프로젝트 생성:
- phonebill-api-gateway-dev
- phonebill-user-service-dev
- phonebill-bill-service-dev
- phonebill-product-service-dev
- phonebill-kos-mock-dev

(staging, prod 환경도 동일하게 생성)

---

## 참고 자료

### Azure CLI 명령어

```bash
# AKS 클러스터 인증 정보 가져오기
az aks get-credentials --resource-group rg-digitalgarage-01 --name aks-digitalgarage-01

# ACR 로그인
az acr login --name acrdigitalgarage01

# Service Principal 생성 (필요 시)
az ad sp create-for-rbac --name jenkins-sp --role Contributor --scopes /subscriptions/{구독ID}
```

### Kustomize 명령어

```bash
# Kustomize 빌드 결과 확인 (배포 전 검증)
kubectl kustomize deployment/cicd/kustomize/overlays/dev

# 특정 환경의 매니페스트 파일로 저장
kubectl kustomize deployment/cicd/kustomize/overlays/dev > manifests-dev.yaml

# 이미지 태그 업데이트
kustomize edit set image acrdigitalgarage01.azurecr.io/phonebill/user-service:dev-20250101120000
```

### Jenkins Pipeline 문법 참고

- [Jenkins Pipeline Syntax](https://www.jenkins.io/doc/book/pipeline/syntax/)
- [Kubernetes Plugin Documentation](https://plugins.jenkins.io/kubernetes/)
- [Azure Credentials Plugin](https://plugins.jenkins.io/azure-credentials/)

---

## 체크리스트

### 배포 전 체크리스트
- [ ] Git 저장소에 최신 코드 푸시 완료
- [ ] Jenkins Credentials 모두 등록 완료
- [ ] SonarQube 서버 연결 확인
- [ ] ACR 접근 권한 확인
- [ ] AKS 클러스터 접근 권한 확인
- [ ] 네임스페이스 존재 확인
- [ ] 리소스 검증 스크립트 실행 완료

### 배포 후 체크리스트
- [ ] Pod 정상 실행 확인 (kubectl get pods)
- [ ] Service Endpoint 확인 (kubectl get svc)
- [ ] Ingress 정상 동작 확인 (kubectl get ingress)
- [ ] 애플리케이션 Health Check 확인 (/actuator/health)
- [ ] 로그 확인 (kubectl logs)
- [ ] SonarQube Quality Gate 통과 확인 (SKIP_SONARQUBE=false인 경우)

---

**작성일**: 2025-10-01
**버전**: 1.0.0
**작성자**: AI DevOps Engineer
