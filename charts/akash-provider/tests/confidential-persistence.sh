#!/usr/bin/env bash

set -euo pipefail

chart_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
values_file="${chart_dir}/ci/confidential-persistence-values.yaml"

fail() {
  printf 'confidential-persistence chart test failed: %s\n' "$1" >&2
  exit 1
}

default_render=$(helm template provider "${chart_dir}" --namespace akash-services)
if grep -q 'AKASH_CC_PERSISTENCE\|name: confidential-persistence' <<<"${default_render}"; then
  fail "disabled defaults rendered confidential-persistence configuration"
fi

enabled_render=$(helm template provider "${chart_dir}" \
  --namespace akash-services \
  --values "${values_file}")

for expected in \
  'AKASH_CC_PERSISTENCE_KBS_URL: "https://kbs.example.test"' \
  'AKASH_CC_PERSISTENCE_MASTER_KEY_FILE: "/etc/akash-provider/confidential-persistence/master-key"' \
  'AKASH_CC_PERSISTENCE_KBS_ADMIN_TOKEN_FILE: "/etc/akash-provider/confidential-persistence/admin-token"' \
  'AKASH_CC_PERSISTENCE_KBS_CA_FILE: "/etc/akash-provider/confidential-persistence/ca.crt"' \
  'secretName: "provider-confidential-persistence"' \
  'mountPath: /etc/akash-provider/confidential-persistence' \
  'path: master-key' \
  'path: admin-token' \
  'path: ca.crt'; do
  grep -Fq "${expected}" <<<"${enabled_render}" || fail "missing ${expected}"
done

without_ca=$(helm template provider "${chart_dir}" \
  --namespace akash-services \
  --values "${values_file}" \
  --set confidentialPersistence.caCertKey=)
if grep -q 'AKASH_CC_PERSISTENCE_KBS_CA_FILE\|path: ca.crt' <<<"${without_ca}"; then
  fail "empty caCertKey rendered a CA path"
fi

if missing_url=$(helm template provider "${chart_dir}" \
  --set confidentialPersistence.enabled=true \
  --set confidentialPersistence.existingSecret=test-secret 2>&1); then
  fail "enabled configuration without kbsURL rendered successfully"
fi
grep -Fq 'confidentialPersistence.kbsURL is required' <<<"${missing_url}" || \
  fail "missing kbsURL did not return the expected validation error"

if missing_secret=$(helm template provider "${chart_dir}" \
  --set confidentialPersistence.enabled=true \
  --set confidentialPersistence.kbsURL=https://kbs.example.test 2>&1); then
  fail "enabled configuration without existingSecret rendered successfully"
fi
grep -Fq 'confidentialPersistence.existingSecret is required' <<<"${missing_secret}" || \
  fail "missing existingSecret did not return the expected validation error"

printf 'confidential-persistence chart tests passed\n'
