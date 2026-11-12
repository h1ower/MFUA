#!/usr/bin/env bash
set -Eeuo pipefail

CONTAINER="begin-mysql-1-andrey76546"
cd "$(dirname "$0")"

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

printf 'my_actions.log: %s строк, служебные запросы отфильтрованы.\n' "$(wc -l < my_actions.log)"
