#!/usr/bin/env bash
# Pokreće minikube, opcionalno build-a Docker sliku u minikube,
# kreira/azurira Secret iz .env, primjenjuje postojeće k8s manifeste
# i postavlja image tag + broj replika bez mijenjanja yaml fajlova.

set -euo pipefail

# ── Podesivo: možeš prebaciti preko env varijabli pri pozivu ────────────────
IMAGE_NAME="${IMAGE_NAME:-next-supabase-demo}"    # ime Docker slike
IMAGE_TAG="${IMAGE_TAG:-1.0.3}"                   # tag slike
DEPLOY_NAME="${DEPLOY_NAME:-next-supabase-demo}"  # ime Deployment-a
CONTAINER_NAME="${CONTAINER_NAME:-web}"           # ime container-a u Deploymentu
SERVICE_NAME="${SERVICE_NAME:-next-supabase-svc}" # ime Service-a
NS="${NS:-default}"                               
REPLICAS="${REPLICAS:-2}"
BUILD_IMAGE="${BUILD_IMAGE:-true}"                # true|false → da li da buildamo u minikube

# ── Preflight ───────────────────────────────────────────────────────────────
need() { command -v "$1" >/dev/null 2>&1 || { echo "❌ '$1' nije u PATH-u"; exit 1; }; }
need kubectl.exe
need minikube.exe
need docker
echo "✅ Alati: kubectl.exe, minikube.exe, docker"

# ── 1) Start minikube ───────────────────────────────────────────────────────
echo "▶️  Pokrećem minikube (ako nije pokrenut)..."
minikube.exe start --driver=docker --cpus=2 --memory=4096 --disk-size=20g >/dev/null || true
kubectl.exe get nodes

# ── 2) (Opcionalno) build Docker slike U minikube ──────────────────────────
if [ "${BUILD_IMAGE}" = "true" ]; then
  echo "▶️  Prebacujem Docker CLI na minikube engine i gradim sliku..."
  eval "$(minikube.exe docker-env)"
  docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" .
  # Vrati okruženje ako želiš: eval "$(minikube.exe docker-env -u)"
else
  echo "ℹ️  Preskačem build (BUILD_IMAGE=false). Pretpostavljam da je slika dostupna klasteru/registry-ju."
fi

# ── 3) Secret iz .env (SUPABASE_* obavezni) ─────────────────────────────────
if [ -f .env ]; then
  echo "▶️  Učitavam .env"
  set -a; . ./.env; set +a
fi

req_vars=(SUPABASE_A_URL SUPABASE_A_API_KEY SUPABASE_B_URL SUPABASE_B_API_KEY)
for v in "${req_vars[@]}"; do
  if [ -z "${!v:-}" ]; then
    echo "❌ Nedostaje env varijabla: $v  (dodaj u .env ili exportuj u terminalu)"
    exit 1
  fi
done

echo "▶️  Kreiram/azuriram Secret 'supabase-secrets' (ns=${NS})"
kubectl.exe create secret generic supabase-secrets \
  -n "${NS}" \
  --from-literal=SUPABASE_A_URL="${SUPABASE_A_URL}" \
  --from-literal=SUPABASE_A_API_KEY="${SUPABASE_A_API_KEY}" \
  --from-literal=SUPABASE_B_URL="${SUPABASE_B_URL}" \
  --from-literal=SUPABASE_B_API_KEY="${SUPABASE_B_API_KEY}" \
  --dry-run=client -o yaml | kubectl.exe apply -f -

# ── 4) Primijeni tvoje POSTOJEĆE manifeste ─────────────────────────────────
echo "▶️  Primjenjujem k8s/ (deployment.yaml, service.yaml)"
kubectl.exe apply -f k8s/ -n "${NS}"

# ── 5) Postavi image tag i broj replika BEZ mijenjanja yaml fajlova ────────
echo "▶️  Postavljam image na ${IMAGE_NAME}:${IMAGE_TAG}"
kubectl.exe set image deploy/"${DEPLOY_NAME}" -n "${NS}" \
  "${CONTAINER_NAME}=${IMAGE_NAME}:${IMAGE_TAG}" --record=true

echo "▶️  Skaliram na ${REPLICAS} replika"
kubectl.exe scale deploy/"${DEPLOY_NAME}" -n "${NS}" --replicas="${REPLICAS}"

# ── 6) Sačekaj rollout i prikaži stanje ─────────────────────────────────────
echo "▶️  Čekam rollout..."
kubectl.exe rollout status deploy/"${DEPLOY_NAME}" -n "${NS}"

echo "✅ Gotovo."
echo "ℹ️  Pods:"
kubectl.exe get pods -l app="${DEPLOY_NAME}" -o wide -n "${NS}"
echo "ℹ️  Service:"
kubectl.exe get svc "${SERVICE_NAME}" -n "${NS}"

echo
echo "👉 Lokalni pristup (izaberi jedno):"
echo "   1) minikube.exe service ${SERVICE_NAME} --url"
echo "   2) kubectl.exe port-forward service/${SERVICE_NAME} 8080:80"
