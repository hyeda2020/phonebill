# phonebill GitHub Actions CI/CD 파이프라인 가이드

## 목차
1. [개요](#개요)
2. [사전 준비사항](#사전-준비사항)
3. [GitHub 저장소 환경 구성](#github-저장소-환경-구성)
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
- **GitHub Actions** 기반 자동화 배포
- **환경별 매니페스트 관리**: dev/staging/prod
- **SonarQube 코드 품질 분석** 및 Quality Gate 적용 (선택적)
- **병렬 처리**: 여러 서비스를 동시에 빌드 및 배포
- **자동 트리거**: main/develop 브랜치 push 시 자동 실행
- **수동 실행**: workflow_dispatch로 환경 선택 가능

---

## 사전 준비사항

### Azure 리소스 정보
- ACR 이름: `acrdigitalgarage01`
- 리소스 그룹: `rg-digitalgarage-01`
- AKS 클러스터: `aks-digitalgarage-01`
- 네임스페이스: `phonebill-dg0504`

### 필수 도구
- GitHub 계정 및 저장소
- Azure 구독 및 Service Principal
- Azure Container Registry
- Azure Kubernetes Service
- SonarQube 서버 (선택사항)

---

## GitHub 저장소 환경 구성

### 1. GitHub Secrets 설정

**Settings > Secrets and variables > Actions > Repository secrets**

#### AZURE_CREDENTIALS (필수)
Azure Service Principal 인증 정보를 JSON 형식으로 등록

**Service Principal 생성 방법:**
```bash
az ad sp create-for-rbac --name github-actions-sp --role Contributor --scopes /subscriptions/{구독ID} --sdk-auth
```

**등록 형식:**
```json
{
  "clientId": "5e4b5b41-7208-48b7-b821-d6d5acf50ecf",
  "clientSecret": "ldu8Q~GQEzFYU.dJX7_QsahR7n7C2xqkIM6hqbV8",
  "subscriptionId": "2513dd36-7978-48e3-9a7c-b221d4874f66",
  "tenantId": "4f0a3bfd-1156-4cce-8dc2-a049a13dba23"
}
```

#### ACR_USERNAME / ACR_PASSWORD (필수)
Azure Container Registry 인증 정보

**ACR Credentials 확인:**
```bash
az acr credential show --name acrdigitalgarage01
```

**등록 내용:**
- **ACR_USERNAME**: `acrdigitalgarage01`
- **ACR_PASSWORD**: ACR 관리 키 (username 또는 password 중 하나)

#### DOCKERHUB_USERNAME / DOCKERHUB_PASSWORD (필수)
Docker Hub Rate Limit 방지용

**Docker Hub Personal Access Token 생성:**
1. https://hub.docker.com 로그인
2. 우측 상단 프로필 > Account Settings
3. 좌측 메뉴 > Personal Access Tokens > Generate New Token
4. 토큰 이름 입력 후 생성

**등록 내용:**
- **DOCKERHUB_USERNAME**: Docker Hub 사용자명
- **DOCKERHUB_PASSWORD**: Personal Access Token

#### SONAR_TOKEN / SONAR_HOST_URL (선택사항)
SonarQube 코드 품질 분석용

**SONAR_HOST_URL 확인:**
```bash
kubectl get svc -n sonarqube
# http://{External-IP} 형식으로 등록
# 예: http://20.249.187.69
```

**SONAR_TOKEN 생성:**
1. SonarQube 로그인
2. 우측 상단 Administrator > My Account
3. Security 탭 > Generate Token
4. 토큰 이름 입력 후 생성

**등록 내용:**
- **SONAR_TOKEN**: SonarQube 생성 토큰
- **SONAR_HOST_URL**: SonarQube 서버 URL

### 2. GitHub Secrets 등록 체크리스트

- [ ] AZURE_CREDENTIALS 등록 완료
- [ ] ACR_USERNAME 등록 완료
- [ ] ACR_PASSWORD 등록 완료
- [ ] DOCKERHUB_USERNAME 등록 완료
- [ ] DOCKERHUB_PASSWORD 등록 완료
- [ ] SONAR_TOKEN 등록 완료 (SonarQube 사용 시)
- [ ] SONAR_HOST_URL 등록 완료 (SonarQube 사용 시)

---

## CI/CD 파이프라인 구조

### 디렉토리 구조
```
.github/
├── config/
│   ├── deploy_env_vars_dev        # dev 환경 설정
│   ├── deploy_env_vars_staging    # staging 환경 설정
│   └── deploy_env_vars_prod       # prod 환경 설정
├── scripts/
│   └── deploy-actions.sh          # 수동 배포 스크립트
└── workflows/
    └── backend-cicd.yaml          # GitHub Actions 워크플로우

deployment/cicd/kustomize/         # Kustomize 매니페스트 (Jenkins와 공유)
├── base/                          # Base 매니페스트
└── overlays/                      # 환경별 Overlay
    ├── dev/
    ├── staging/
    └── prod/
```

### 워크플로우 Jobs

#### 1. Build Job
- **소스 체크아웃**: GitHub 저장소에서 코드 다운로드
- **JDK 설정**: Java 23 환경 구성
- **환경 결정**: dev/staging/prod 환경 선택
- **환경 변수 로드**: 환경별 설정 파일 읽기
- **Gradle 빌드**: 테스트를 제외한 애플리케이션 빌드
- **SonarQube 분석**: 코드 품질 분석 (선택적)
- **아티팩트 업로드**: 빌드된 JAR 파일 업로드
- **출력 설정**: 이미지 태그 및 환경 정보 전달

#### 2. Release Job
- **아티팩트 다운로드**: Build Job에서 생성한 JAR 파일 다운로드
- **Docker 로그인**: ACR 및 Docker Hub 인증
- **이미지 빌드**: 각 서비스별 Docker 이미지 빌드
- **이미지 푸시**: ACR에 이미지 업로드

#### 3. Deploy Job
- **Azure 로그인**: Service Principal로 Azure 인증
- **AKS Credentials**: Kubernetes 클러스터 인증 정보 획득
- **네임스페이스 생성**: Kubernetes 네임스페이스 생성
- **Kustomize 설치**: Kustomize CLI 도구 설치
- **이미지 태그 업데이트**: 환경별 매니페스트에 새 이미지 태그 적용
- **배포 실행**: Kubernetes에 리소스 적용
- **배포 대기**: Deployment가 Ready 상태가 될 때까지 대기
- **정보 출력**: Pod, Service, Ingress 정보 표시

### 트리거 조건

```yaml
# 자동 트리거
push:
  branches: [ main, develop ]
  paths:
    - 'api-gateway/**'
    - 'user-service/**'
    - 'bill-service/**'
    - 'product-service/**'
    - 'kos-mock/**'
    - 'common/**'
    - '.github/**'

# PR 트리거
pull_request:
  branches: [ main ]

# 수동 실행
workflow_dispatch:
  inputs:
    ENVIRONMENT: dev/staging/prod 선택
    SKIP_SONARQUBE: true/false 선택
```

---

## 배포 실행 방법

### 1. 자동 배포 (Push 시)

main 또는 develop 브랜치에 코드를 push하면 자동으로 실행됩니다.

```bash
git add .
git commit -m "feat: 새로운 기능 추가"
git push origin main
```

**기본 동작:**
- 환경: **dev** (기본값)
- SonarQube: **Skip** (SKIP_SONARQUBE=true)

### 2. 수동 배포 (Workflow Dispatch)

GitHub 웹 인터페이스에서 수동 실행:

1. **GitHub 저장소** > **Actions** 탭 이동
2. 좌측 목록에서 **"Backend Services CI/CD"** 선택
3. 우측 **"Run workflow"** 버튼 클릭
4. 파라미터 설정:
   - **Branch**: 배포할 브랜치 선택 (main, develop 등)
   - **Environment**: 배포 환경 선택 (dev, staging, prod)
   - **Skip SonarQube Analysis**:
     - `true`: SonarQube 분석 건너뛰기 (빠른 배포)
     - `false`: SonarQube 분석 및 Quality Gate 실행
5. **"Run workflow"** 클릭

### 3. 로컬에서 수동 배포

GitHub Actions를 거치지 않고 직접 배포:

```bash
# dev 환경에 latest 태그로 배포
./.github/scripts/deploy-actions.sh dev latest

# staging 환경에 특정 태그로 배포
./.github/scripts/deploy-actions.sh staging 20250101120000

# prod 환경에 특정 태그로 배포
./.github/scripts/deploy-actions.sh prod 20250101120000
```

### 4. 배포 상태 확인

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

### 1. GitHub Actions에서 이전 버전으로 롤백

1. **GitHub 저장소** > **Actions** 탭 이동
2. 좌측 목록에서 **"Backend Services CI/CD"** 선택
3. 성공한 이전 워크플로우 실행 선택
4. 우측 상단 **"Re-run all jobs"** 클릭

### 2. kubectl을 이용한 롤백

```bash
# 특정 서비스를 이전 버전으로 롤백
kubectl rollout undo deployment/user-service -n phonebill-dg0504

# 특정 리비전으로 롤백
kubectl rollout undo deployment/user-service -n phonebill-dg0504 --to-revision=2

# 롤백 상태 확인
kubectl rollout status deployment/user-service -n phonebill-dg0504
```

### 3. 수동 스크립트를 이용한 롤백

안정적인 이전 버전의 이미지 태그를 알고 있는 경우:

```bash
# 이전 안정 버전 태그로 배포
./.github/scripts/deploy-actions.sh dev 20250101100000
```

### 4. Kustomize를 이용한 롤백

```bash
cd deployment/cicd/kustomize/overlays/dev

# 이전 안정 버전 이미지 태그로 업데이트
kustomize edit set image acrdigitalgarage01.azurecr.io/phonebill/user-service:dev-20250101100000

# 배포 실행
kubectl apply -k .

# 롤백 상태 확인
kubectl rollout status deployment/user-service -n phonebill-dg0504
```

---

## 문제 해결

### 1. 워크플로우 실패 시 체크리스트

#### Build Job 실패
```
원인: Gradle 빌드 오류, 컴파일 에러
해결:
1. GitHub Actions 로그에서 에러 메시지 확인
2. 로컬에서 ./gradlew build 실행하여 재현
3. 소스 코드 수정 후 다시 커밋
```

#### SonarQube Analysis 실패
```
원인: 테스트 실패, Quality Gate 미통과, SonarQube 서버 연결 실패
해결:
1. SonarQube 서버 접근 가능 여부 확인
2. SONAR_TOKEN 및 SONAR_HOST_URL Secrets 확인
3. SonarQube 서버에서 프로젝트 확인
4. 실패한 Quality Gate 조건 확인
5. 급한 경우: SKIP_SONARQUBE=true로 배포
```

#### Release Job 실패
```
원인: ACR 인증 실패, 이미지 빌드 오류, Docker Hub Rate Limit
해결:
1. ACR_USERNAME, ACR_PASSWORD Secrets 확인
2. Docker Hub Credentials 확인
3. Dockerfile 문법 확인
4. ACR 접근 권한 확인
```

#### Deploy Job 실패
```
원인: Azure 인증 실패, AKS 접근 권한 부족, Kubernetes 리소스 오류
해결:
1. AZURE_CREDENTIALS Secret 확인
2. Service Principal 권한 확인
3. kubectl get pods -n phonebill-dg0504 확인
4. Kustomize 매니페스트 문법 검증:
   kubectl kustomize deployment/cicd/kustomize/overlays/dev
```

### 2. GitHub Secrets 확인

```bash
# Service Principal 테스트
az login --service-principal -u {clientId} -p {clientSecret} -t {tenantId}

# ACR 접근 테스트
az acr login --name acrdigitalgarage01

# AKS 접근 테스트
az aks get-credentials --resource-group rg-digitalgarage-01 --name aks-digitalgarage-01
kubectl get nodes
```

### 3. 로컬 테스트

워크플로우를 로컬에서 테스트:

```bash
# 1. 빌드 테스트
./gradlew build -x test

# 2. Docker 이미지 빌드 테스트
docker build \
  --build-arg BUILD_LIB_DIR="user-service/build/libs" \
  --build-arg ARTIFACTORY_FILE="user-service.jar" \
  -f deployment/container/Dockerfile-backend \
  -t test-image:latest .

# 3. Kustomize 빌드 테스트
kubectl kustomize deployment/cicd/kustomize/overlays/dev
```

### 4. 워크플로우 로그 확인

GitHub Actions 로그에서 상세 정보 확인:

1. **GitHub 저장소** > **Actions** 탭
2. 실패한 워크플로우 실행 선택
3. 실패한 Job 선택
4. 실패한 Step의 로그 확인
5. 에러 메시지 분석

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

### GitHub Actions 문법

- [GitHub Actions 공식 문서](https://docs.github.com/en/actions)
- [Workflow 문법](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
- [환경 변수 및 Secrets](https://docs.github.com/en/actions/security-guides/encrypted-secrets)

### Azure CLI 명령어

```bash
# Service Principal 생성
az ad sp create-for-rbac --name github-actions-sp --role Contributor --scopes /subscriptions/{구독ID} --sdk-auth

# ACR 로그인
az acr login --name acrdigitalgarage01

# AKS 클러스터 인증 정보 가져오기
az aks get-credentials --resource-group rg-digitalgarage-01 --name aks-digitalgarage-01
```

### Kustomize 명령어

```bash
# Kustomize 빌드 결과 확인 (배포 전 검증)
kubectl kustomize deployment/cicd/kustomize/overlays/dev

# 이미지 태그 업데이트
kustomize edit set image acrdigitalgarage01.azurecr.io/phonebill/user-service:dev-20250101120000
```

---

## 체크리스트

### 배포 전 체크리스트
- [ ] GitHub Secrets 모두 등록 완료
- [ ] SonarQube 서버 연결 확인 (사용 시)
- [ ] ACR 접근 권한 확인
- [ ] AKS 클러스터 접근 권한 확인
- [ ] 네임스페이스 존재 확인
- [ ] Kustomize 매니페스트 문법 검증 완료

### 배포 후 체크리스트
- [ ] GitHub Actions 워크플로우 성공 확인
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
