#!/usr/bin/env bash
set -euo pipefail

BASE_URL="${1:-${BASE_URL:-}}"
REQUESTS="${REQUESTS:-50}"   # promijeni npr. REQUESTS=20 ./test_lb_url.sh <url>

if [ -z "${BASE_URL}" ]; then
  echo "❌ Upotreba: $0 <BASE_URL>   (npr. $0 http://127.0.0.1:12155)"
  exit 1
fi

echo "▶️  Testiram LB na: ${BASE_URL}   (broj zahtjeva: ${REQUESTS})"
echo "   Health endpoint: ${BASE_URL}/api/health"
echo

# brzi health check
if ! curl -s "${BASE_URL}/api/health" >/dev/null; then
  echo "❌ Ne mogu da dohvatim ${BASE_URL}/api/health"
  echo "   Provjeri da li je Service izložen i da URL/port odgovaraju."
  exit 1
fi

for i in $(seq 1 "${REQUESTS}"); do
  # Connection: close → izbjegni keep-alive da vidiš ravnomjernije “šaltanje”
  RESP=$(curl -s -H "Connection: close" "${BASE_URL}/api/health")
  echo "#$i  ${RESP}"
done

echo
echo "✅ Gotovo. Po želji povećaj broj replika: kubectl.exe scale deploy/next-supabase-demo --replicas=3"
