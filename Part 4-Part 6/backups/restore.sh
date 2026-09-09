#!/usr/bin/env bash
set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <path-to-backup-file>"
    exit 1
fi

BACKUP_FILE="$1"
if [ ! -f "${BACKUP_FILE}" ]; then
    echo "Backup file not found: ${BACKUP_FILE}"
    exit 1
fi

CONTAINER_NAME="${CONTAINER_NAME:-hotel-booking-postgres}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_NAME="${POSTGRES_DB:-hotel_booking}"
RESTORE_DB_NAME="${RESTORE_DB_NAME:-${DB_NAME}_restore_test}"

BACKUP_FILENAME="$(basename "${BACKUP_FILE}")"

echo "==> Copying backup into container"
docker cp "${BACKUP_FILE}" "${CONTAINER_NAME}:/tmp/${BACKUP_FILENAME}"

echo "==> Creating fresh database: ${RESTORE_DB_NAME}"
docker exec -t "${CONTAINER_NAME}" \
    psql -U "${DB_USER}" -d postgres -v ON_ERROR_STOP=1 \
    -c "DROP DATABASE IF EXISTS ${RESTORE_DB_NAME};"
docker exec -t "${CONTAINER_NAME}" \
    psql -U "${DB_USER}" -d postgres -v ON_ERROR_STOP=1 \
    -c "CREATE DATABASE ${RESTORE_DB_NAME};"

echo "==> Restoring dump into ${RESTORE_DB_NAME}"
docker exec -t "${CONTAINER_NAME}" \
    pg_restore -U "${DB_USER}" -d "${RESTORE_DB_NAME}" \
    --no-owner --no-privileges "/tmp/${BACKUP_FILENAME}"

docker exec "${CONTAINER_NAME}" rm -f "/tmp/${BACKUP_FILENAME}"

echo "==> Restore complete into database: ${RESTORE_DB_NAME}"
echo "==> Verify with:"
echo "    docker exec -i ${CONTAINER_NAME} psql -U ${DB_USER} -d ${RESTORE_DB_NAME} -f - < scripts/verify.sql"
