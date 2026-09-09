#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

CONTAINER_NAME="${CONTAINER_NAME:-hotel-booking-postgres}"
DB_USER="${POSTGRES_USER:-postgres}"
DB_NAME="${POSTGRES_DB:-hotel_booking}"

TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
BACKUP_FILENAME="hotel_booking_backup_${TIMESTAMP}.dump"
BACKUP_PATH="${SCRIPT_DIR}/${BACKUP_FILENAME}"

echo "==> Backing up '${DB_NAME}' from container '${CONTAINER_NAME}'"


docker exec -t "${CONTAINER_NAME}" \
    pg_dump -U "${DB_USER}" -d "${DB_NAME}" -F c -f "/tmp/${BACKUP_FILENAME}"

docker cp "${CONTAINER_NAME}:/tmp/${BACKUP_FILENAME}" "${BACKUP_PATH}"
docker exec "${CONTAINER_NAME}" rm -f "/tmp/${BACKUP_FILENAME}"

echo "==> Backup complete: ${BACKUP_PATH}"
ls -lh "${BACKUP_PATH}"
