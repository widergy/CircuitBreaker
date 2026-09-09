#!/bin/bash
set -e

if [ -n "$CI" ]; then
  echo "[codeartifact-login] Entorno CI detectado, el pipeline se encarga del auth. Saliendo."
  exit 0
fi

if ! aws configure list-profiles 2>/dev/null | grep -q "^widergyapp$"; then
  echo "[codeartifact-login] ERROR: El perfil 'widergyapp' no existe. Crealo con:"
  echo "  aws configure --profile widergyapp"
  exit 1
fi

CODEARTIFACT_URL="https://widergydev-325736894961.d.codeartifact.us-east-1.amazonaws.com"

echo "[codeartifact-login] Obteniendo token de CodeArtifact..."

CODEARTIFACT_TOKEN=$(aws codeartifact get-authorization-token \
  --profile widergyapp \
  --domain widergydev \
  --domain-owner 325736894961 \
  --region us-east-1 \
  --query authorizationToken \
  --output text) || {
  echo "[codeartifact-login] ERROR: No se pudo obtener el token. Verificá que el perfil 'widergyapp' esté configurado con 'aws configure --profile widergyapp'."
  exit 1
}

CODEARTIFACT_HOST="${CODEARTIFACT_URL#https://}"

# Bundler
bundle config "${CODEARTIFACT_URL}/ruby/gems/" "aws:${CODEARTIFACT_TOKEN}"
echo "[codeartifact-login] Bundler configurado para CodeArtifact."

# npm/yarn
printf "@widergy:registry=%s/npm/npm/\n//%s/npm/npm/:_authToken=%s\n" \
  "$CODEARTIFACT_URL" "$CODEARTIFACT_HOST" "$CODEARTIFACT_TOKEN" \
  > .npmrc
echo "[codeartifact-login] .npmrc configurado para CodeArtifact."
