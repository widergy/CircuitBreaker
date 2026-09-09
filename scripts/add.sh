#!/bin/bash
set -e

CODEARTIFACT_DOMAIN="widergydev"

DOMAIN_OWNER=$(aws sts get-caller-identity \
  --profile widergyapp \
  --query Account \
  --output text) || {
  echo "[add] ERROR: No se pudo obtener el ID de cuenta. Verificá que el perfil 'widergyapp' esté configurado correctamente."
  exit 1
}

CODEARTIFACT_URL="https://${CODEARTIFACT_DOMAIN}-${DOMAIN_OWNER}.d.codeartifact.us-east-1.amazonaws.com/ruby/gems/"

bash "$(dirname "$0")/codeartifact-login.sh"

for ARG in "$@"; do
  GEM_NAME=$(echo "$ARG" | sed 's/[[:space:]]*[~><=].*//')
  VERSION_SPEC=$(echo "$ARG" | sed "s/^$GEM_NAME//" | xargs)

  echo "[add] Buscando '$GEM_NAME' en CodeArtifact..."

  DESCRIBE_OUTPUT=$(aws codeartifact describe-package \
    --profile widergyapp \
    --domain "$CODEARTIFACT_DOMAIN" \
    --domain-owner "$DOMAIN_OWNER" \
    --repository gems \
    --format ruby \
    --package "$GEM_NAME" \
    --region us-east-1 2>&1)
  DESCRIBE_EXIT=$?

  if [ $DESCRIBE_EXIT -eq 0 ]; then
    echo "[add] '$GEM_NAME' encontrada en CodeArtifact, agregando con source interno..."
    bundle add "$GEM_NAME" ${VERSION_SPEC:+--version "$VERSION_SPEC"} --source "$CODEARTIFACT_URL"
  elif echo "$DESCRIBE_OUTPUT" | grep -q "ResourceNotFoundException"; then
    echo "[add] '$GEM_NAME' no encontrada en CodeArtifact, agregando desde RubyGems..."
    bundle add "$GEM_NAME" ${VERSION_SPEC:+--version "$VERSION_SPEC"}
  else
    echo "[add] ERROR: No se pudo consultar CodeArtifact para '$GEM_NAME'."
    echo "  Detalle: $DESCRIBE_OUTPUT"
    echo "  Verificá tu conexión a internet o que el perfil 'widergyapp' esté configurado correctamente."
    exit 1
  fi
done
