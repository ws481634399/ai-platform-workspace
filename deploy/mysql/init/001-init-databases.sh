#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ! "${MYSQL_USER}" =~ ^[A-Za-z0-9_]+$ ]]; then
  echo "MYSQL_USER may contain only letters, digits, and underscores" >&2
  exit 1
fi

export MYSQL_PWD="${MYSQL_ROOT_PASSWORD}"

databases=(
  mall_identity
  mall_member
  mall_product
  mall_cart
  mall_order
  mall_inventory
  mall_search
  mall_system
)

for database in "${databases[@]}"; do
  mysql --protocol=socket -uroot <<SQL
CREATE DATABASE IF NOT EXISTS \`${database}\`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci;
GRANT ALL PRIVILEGES ON \`${database}\`.* TO '${MYSQL_USER}'@'%';
SQL
done

mysql --protocol=socket -uroot -e 'FLUSH PRIVILEGES;'
