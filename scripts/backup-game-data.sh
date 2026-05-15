#!/bin/bash
set -euo pipefail

DATE=$(date +%Y%m%d)
BACKUP_DIR="/data/backups/${DATE}"
SOURCE_DIR="/data/games"

echo "=== ScoutCloud Nightly Backup ==="
echo "Date: ${DATE}"
echo "Source: ${SOURCE_DIR}"
echo "Destination: ${BACKUP_DIR}"
echo ""

if [ -d "${BACKUP_DIR}" ]; then
    echo "Backup already exists for today. Exiting cleanly."
    exit 0
fi

mkdir -p "${BACKUP_DIR}"

CSV_COUNT=0
for file in "${SOURCE_DIR}"/*.csv; do
    if [ -f "$file" ]; then
        cp "$file" "${BACKUP_DIR}/"
        echo "Backed up: $(basename $file)"
        CSV_COUNT=$((CSV_COUNT + 1))
    fi
done

TOTAL_SIZE=$(du -sh "${BACKUP_DIR}" | cut -f1)

echo ""
echo "=== Backup Summary ==="
echo "Files backed up: ${CSV_COUNT}"
echo "Total size: ${TOTAL_SIZE}"
echo "Location: ${BACKUP_DIR}"
echo "Status: SUCCESS"
exit 0
