#!/bin/bash
set -e

CODEARTIFACT_URL="https://widergydev-325736894961.d.codeartifact.us-east-1.amazonaws.com/ruby/gems/"

bash "$(dirname "$0")/codeartifact-login.sh"

for ARG in "$@"; do
  GEM_NAME=$(echo "$ARG" | sed 's/[[:space:]]*[~><=].*//')
  VERSION_SPEC=$(echo "$ARG" | sed "s/^$GEM_NAME//" | xargs)

  echo "[add] Buscando '$GEM_NAME' en CodeArtifact..."

  DESCRIBE_OUTPUT=$(aws codeartifact describe-package \
    --profile widergyapp \
    --domain widergydev \
    --domain-owner 325736894961 \
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
