#!/bin/sh
# =============================================================================
# Genera .env.production a partir de AWS Systems Manager Parameter Store.
# Se ejecuta EN LA INSTANCIA EC2 (usa el rol de la instancia, sin claves en disco).
#
# Parámetros que hay que crear antes (tipo SecureString los secretos):
#   /moderniza/<ALUMNO>/prod/APP_KEY       (SecureString)  base64:...
#   /moderniza/<ALUMNO>/prod/APP_URL       (String)        https://<dominio>
#   /moderniza/<ALUMNO>/prod/DB_HOST       (String)        endpoint de RDS
#   /moderniza/<ALUMNO>/prod/DB_USERNAME   (String)        moderniza_app
#   /moderniza/<ALUMNO>/prod/DB_PASSWORD   (SecureString)
#
# Uso:  sh generar-env.sh <ALUMNO> [region]
# =============================================================================
set -eu
ALUMNO="${1:?Uso: sh generar-env.sh <ALUMNO> [region]}"
REGION="${2:-us-east-1}"
RUTA="/moderniza/${ALUMNO}/prod/"
DESTINO=".env.production"

# Valores fijos (no secretos) a partir del ejemplo, sin las líneas que vienen de Parameter Store
grep -v -E '^(APP_KEY|APP_URL|DB_HOST|DB_USERNAME|DB_PASSWORD)=' .env.production.example \
  | grep -v '^#' | grep -v '^$' > "$DESTINO.tmp"

# Parámetros del alumno: NOMBRE=valor (descifrados)
aws ssm get-parameters-by-path \
  --region "$REGION" \
  --path "$RUTA" \
  --with-decryption \
  --query 'Parameters[*].[Name,Value]' \
  --output text \
| while IFS="$(printf '\t')" read -r NOMBRE VALOR; do
    printf '%s=%s\n' "${NOMBRE##*/}" "$VALOR"
  done >> "$DESTINO.tmp"

for VAR in APP_KEY APP_URL DB_HOST DB_USERNAME DB_PASSWORD; do
  grep -q "^${VAR}=" "$DESTINO.tmp" || { echo "ERROR: falta ${RUTA}${VAR} en Parameter Store" >&2; rm -f "$DESTINO.tmp"; exit 1; }
done

umask 077
mv "$DESTINO.tmp" "$DESTINO"
chmod 600 "$DESTINO"
echo "OK: $DESTINO generado con $(wc -l < "$DESTINO") variables (no se muestran los valores)."
