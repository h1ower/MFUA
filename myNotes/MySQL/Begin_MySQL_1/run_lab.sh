#!/usr/bin/env bash
set -Eeuo pipefail

CONTAINER="begin-mysql-1-andrey76546"
VOLUME="begin_mysql_1_andrey76546_data"
IMAGE="begin-mysql-1-andrey76546:8.0"
LAB_PASSWORD="123"

cd "$(dirname "$0")"

mysql_exec() {
  MSYS_NO_PATHCONV=1 docker exec -i -e MYSQL_PWD="$LAB_PASSWORD" "$CONTAINER" \
    mysql --default-character-set=utf8mb4 -uroot --table "$@"
}

wait_for_mysql() {
  local attempt
  for attempt in {1..60}; do
    if MSYS_NO_PATHCONV=1 docker exec -e MYSQL_PWD="$LAB_PASSWORD" "$CONTAINER" \
      mysqladmin ping -uroot --silent >/dev/null 2>&1; then
      return 0
    fi
    sleep 2
  done
  echo "MySQL не стал доступен за 120 секунд" >&2
  return 1
}

phase1() {
  clear 2>/dev/null || true
  printf '=== Шаг 1. MySQL 8.0 в отдельном Docker-окружении ===\n\n'

  if docker ps -a --format '{{.Names}}' | grep -Fxq "$CONTAINER"; then
    echo "Контейнер $CONTAINER уже существует; выполнение остановлено без удаления." >&2
    exit 1
  fi
  if docker volume ls --format '{{.Name}}' | grep -Fxq "$VOLUME"; then
    echo "Volume $VOLUME уже существует; выполнение остановлено без удаления." >&2
    exit 1
  fi

  printf '$ docker build -t %s .  # FROM mysql:8.0\n' "$IMAGE"
  docker build -t "$IMAGE" . >/dev/null

  printf '\n$ docker volume create %s\n' "$VOLUME"
  docker volume create "$VOLUME"

  printf '\n$ docker run --name %s ... -d %s\n' "$CONTAINER" "$IMAGE"
  MSYS_NO_PATHCONV=1 docker run --name "$CONTAINER" \
    -e MYSQL_ROOT_PASSWORD="$LAB_PASSWORD" \
    -e LANG=C.UTF-8 \
    -v "$VOLUME:/var/lib/mysql" \
    -d "$IMAGE"

  wait_for_mysql

  printf '\n$ docker ps --filter name=%s\n' "$CONTAINER"
  docker ps --filter "name=$CONTAINER" --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'

  local interactive_flag='-i'
  if [[ -t 0 && -t 1 ]]; then
    interactive_flag='-it'
  fi
  printf '\n$ docker exec %s %s mysql ... (проверка подключения)\n' "$interactive_flag" "$CONTAINER"
  MSYS_NO_PATHCONV=1 docker exec "$interactive_flag" -e MYSQL_PWD="$LAB_PASSWORD" "$CONTAINER" \
    mysql --default-character-set=utf8mb4 -uroot --table \
    -e "SELECT VERSION() AS mysql_version, CURRENT_USER() AS connected_as, @@character_set_server AS charset, @@general_log AS general_log;"

  printf '\nPHASE1_OK: контейнер запущен, подключение к MySQL выполнено.\n'
  : > .phase1.done
}

phase2() {
  clear 2>/dev/null || true
  printf '=== Шаги 2–3. Создание БД, таблицы и SQL-операции ===\n\n'
  printf '$ docker exec -i %s mysql --verbose < sql/operations.sql\n' "$CONTAINER"
  MSYS_NO_PATHCONV=1 docker exec -i -e MYSQL_PWD="$LAB_PASSWORD" "$CONTAINER" \
    mysql --default-character-set=utf8mb4 -uroot --table --verbose \
    < sql/operations.sql | tee operations-output.txt >/dev/null

  printf '\nВыполнено: CREATE DATABASE/TABLE, INSERT, SELECT и UPDATE.\n\n'
  printf '$ SELECT * FROM my_database.users;\n'
  mysql_exec -e "SELECT * FROM my_database.users;"
  printf '\n$ SELECT name, email FROM my_database.users WHERE id = 1;\n'
  mysql_exec -e "SELECT name, email FROM my_database.users WHERE id = 1;"
  printf '\n$ SELECT name, HEX(name) FROM my_database.users WHERE id = 1;\n'
  mysql_exec -e "SELECT name, HEX(name) FROM my_database.users WHERE id = 1;"

  printf '\nPHASE2_OK: обязательные SQL-команды выполнены и проверены.\n'
  : > .phase2.done
}

phase3() {
  clear 2>/dev/null || true
  printf '=== Шаги 4–5. Дамп, DELETE/DROP и general log ===\n\n'

  printf '$ docker exec %s mysqldump ... my_database > dump_clean.sql\n' "$CONTAINER"
  MSYS_NO_PATHCONV=1 docker exec -e MYSQL_PWD="$LAB_PASSWORD" "$CONTAINER" \
    mysqldump -uroot --set-gtid-purged=OFF --single-transaction my_database \
    > dump_clean.sql

  grep -Fq 'CREATE TABLE `users`' dump_clean.sql
  grep -Fq 'INSERT INTO `users`' dump_clean.sql
  grep -Fq 'Иван Петров' dump_clean.sql
  grep -Fq 'Марк Аврелий' dump_clean.sql

  printf '$ docker exec -i %s mysql --verbose < sql/cleanup.sql\n' "$CONTAINER"
  MSYS_NO_PATHCONV=1 docker exec -i -e MYSQL_PWD="$LAB_PASSWORD" "$CONTAINER" \
    mysql --default-character-set=utf8mb4 -uroot --table --verbose \
    < sql/cleanup.sql | tee cleanup-output.txt >/dev/null

  if mysql_exec -Nse "SHOW DATABASES LIKE 'my_database';" | grep -q .; then
    echo 'База my_database не была удалена' >&2
    exit 1
  fi

  MSYS_NO_PATHCONV=1 docker exec "$CONTAINER" cat /var/lib/mysql/general.log \
    | grep 'Query' \
    | grep -v -E 'SET NAMES|SET autocommit|SET sql_mode|SET character_set_results|SHOW STATUS|SHOW WARNINGS|SELECT @@|SELECT DATABASE\(\)|time_zone' \
    | grep -E $'Query\t(CREATE DATABASE my_database|CREATE TABLE users|INSERT INTO users|SELECT (\*|name, HEX\(name\)|name, email|name) FROM (my_database\.)?users( WHERE id = 1)?$|UPDATE users|DELETE FROM users|DROP TABLE users|DROP DATABASE my_database|SHOW DATABASES$|SHOW TABLES$|SHOW VARIABLES LIKE \'character_set%\'$)' \
    > my_actions.log

  grep -Fq 'CREATE DATABASE my_database' my_actions.log
  grep -Fq 'CREATE TABLE users' my_actions.log
  grep -Fq 'INSERT INTO users' my_actions.log
  grep -Fq 'UPDATE users' my_actions.log
  grep -Fq 'DELETE FROM users' my_actions.log
  grep -Fq 'DROP TABLE users' my_actions.log
  grep -Fq 'DROP DATABASE my_database' my_actions.log

  docker stop "$CONTAINER" >/dev/null
  docker start "$CONTAINER" >/dev/null
  wait_for_mysql

  clear 2>/dev/null || true
  printf '=== Создание и проверка дампа и журнала ===\n\n'
  printf '$ ls -lh dump_clean.sql my_actions.log\n'
  ls -lh dump_clean.sql my_actions.log
  printf '\n$ grep -n "CREATE TABLE ... / INSERT INTO ..." dump_clean.sql\n'
  grep -n -E 'CREATE TABLE `users`|INSERT INTO `users`' dump_clean.sql | cut -d: -f1-2
  printf 'Данные дампа: Иван Петров — OK; Марк Аврелий — OK.\n'
  printf '\n$ grep "CREATE|INSERT|UPDATE|DELETE|DROP" my_actions.log\n'
  grep -E 'CREATE DATABASE|CREATE TABLE|INSERT INTO|UPDATE users|DELETE FROM|DROP TABLE|DROP DATABASE' my_actions.log
  printf '\nПроверка после DROP DATABASE: my_database отсутствует — OK.\n'
  printf 'Управление контейнером: docker stop/start — OK.\n'
  printf '\nPHASE3_OK: дамп и очищенный настоящий general log проверены.\n'
  : > .phase3.done
}

case "${1:-}" in
  phase1) phase1 ;;
  phase2) phase2 ;;
  phase3) phase3 ;;
  *) echo "Использование: bash run_lab.sh {phase1|phase2|phase3}" >&2; exit 2 ;;
esac
