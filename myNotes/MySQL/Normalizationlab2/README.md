
# Нормализация данных в MySQL до третьей нормальной формы (3NF) с ведением лога

## Цель работы

Привести ненормализованную таблицу продаж к третьей нормальной форме, разбив её на четыре таблицы; продемонстрировать аномалии обновления, вставки и удаления; перенести данные без потерь и искажений; снять дампы до и после нормализации; освоить ведение и экспорт общего лога действий пользователя MySQL.

## Среда выполнения

- VS Code
- Git Bash (Windows)
- Docker CLI
- Образ `mysql:8.0`
- Контейнер `mysql_norm`
- Volume `mysql_norm_data`
- База данных `sales_norm`

## 1. Подготовка окружения

### 1.1. Удаление старого контейнера (если был)

```bash
docker stop mysql_norm 2>/dev/null
docker rm mysql_norm 2>/dev/null
docker volume rm mysql_norm_data 2>/dev/null
```

### 1.2. Запуск контейнера MySQL с логированием

Настройки логирования передаются напрямую в `docker run`, без использования файла `my.cnf`. Такой подход исключает ситуацию, когда Docker при отсутствии файла конфигурации на хосте создаёт каталог с тем же именем и MySQL не может прочитать настройки.

```bash
MSYS_NO_PATHCONV=1 docker run --name mysql_norm \
  -e MYSQL_ROOT_PASSWORD=123 \
  -e LANG=C.UTF-8 \
  -e MYSQL_INITDB_SKIP_TZINFO=1 \
  -v mysql_norm_data:/var/lib/mysql \
  -d mysql:8.0 \
  --general-log=1 \
  --general-log-file=/var/lib/mysql/general.log \
  --log-output=FILE
```

Префикс `MSYS_NO_PATHCONV=1` отключает автоматическое преобразование Unix-путей в Windows-пути в Git Bash. Без него путь `/var/lib/mysql/general.log` превращается в `C:/Program Files/Git/var/lib/mysql/general.log`, и команды `docker exec`/`docker cp` работают с неверным путём.

### 1.3. Проверка, что контейнер запущен

```bash
docker ps
```

### 1.4. Подключение к MySQL

```bash
MSYS_NO_PATHCONV=1 docker exec -it mysql_norm mysql -uroot -p
```

Пароль: `123`.

### 1.5. Проверка настроек логирования

```sql
SHOW VARIABLES LIKE 'general_log';
SHOW VARIABLES LIKE 'general_log_file';
SHOW VARIABLES LIKE 'log_output';
```

Ожидаемые значения:

- `general_log` — `ON`
- `general_log_file` — `/var/lib/mysql/general.log`
- `log_output` — `FILE`

## 2. Создание базы данных и ненормализованной таблицы

### 2.1. Создание базы данных

```sql
CREATE DATABASE sales_norm
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE sales_norm;
```

### 2.2. Создание таблицы `orders_bad`

```sql
CREATE TABLE orders_bad (
    sale_id       INT,
    sale_date     DATE,
    client_id     INT,
    client_name   VARCHAR(100),
    client_city   VARCHAR(100),
    product_id    INT,
    product_name  VARCHAR(100),
    unit_price    DECIMAL(10,2),
    quantity      INT
);
```

### 2.3. Заполнение таблицы данными

```sql
INSERT INTO orders_bad VALUES
(5001, '2026-11-01', 101, 'Иванов Иван',     'Москва',           201, 'Монитор',    15000.00, 2),
(5001, '2026-11-01', 101, 'Иванов Иван',     'Москва',           202, 'Клавиатура',  2000.00, 1),
(5002, '2026-11-02', 102, 'Петрова Мария',   'Санкт-Петербург', 203, 'Мышь',        1000.00, 3),
(5002, '2026-11-02', 102, 'Петрова Мария',   'Санкт-Петербург', 204, 'Наушники',    3500.00, 1),
(5003, '2026-11-03', 101, 'Иванов Иван',     'Москва',           205, 'Колонки',     2500.00, 2),
(5004, '2026-11-04', 103, 'Сидоров Алексей', 'Казань',           202, 'Клавиатура',  2000.00, 5),
(5004, '2026-11-04', 103, 'Сидоров Алексей', 'Казань',           203, 'Мышь',        1000.00, 2),
(5005, '2026-11-05', 102, 'Петрова Мария',   'Санкт-Петербург', 201, 'Монитор',    15000.00, 1),
(5006, '2026-11-06', 103, 'Сидоров Алексей', 'Казань',           204, 'Наушники',    3500.00, 2),
(5006, '2026-11-06', 103, 'Сидоров Алексей', 'Казань',           205, 'Колонки',     2500.00, 1);
```

### 2.4. Проверка исходных данных

```sql
SELECT COUNT(*) FROM orders_bad;
SELECT * FROM orders_bad ORDER BY sale_id, product_id;
```

Ожидается 10 строк. Контрольная сумма `SUM(unit_price * quantity)` для этих данных равна `80000.00`.

```sql
SELECT SUM(unit_price * quantity) AS total_sum FROM orders_bad;
```

### 2.5. Дамп базы до нормализации

Выполняется в Git Bash, не в клиенте MySQL:

```bash
MSYS_NO_PATHCONV=1 docker exec -e MYSQL_PWD=123 mysql_norm mysqldump -uroot sales_norm > dump_before.sql
```

Проверка, что дамп не пустой:

```bash
grep -c "INSERT INTO" dump_before.sql
```

## 3. Демонстрация аномалий

### 3.1. Аномалия обновления

Город клиента хранится в каждой строке продажи. При смене города нужно обновить все строки клиента; если обновить не все, данные рассогласуются.

Показать, что город клиента 101 дублируется:

```sql
SELECT sale_id, product_id, client_id, client_name, client_city
FROM orders_bad
WHERE client_id = 101;
```

Обновить город только в одной строке (имитация ошибки):

```sql
UPDATE orders_bad
SET client_city = 'Москва (обновлено)'
WHERE client_id = 101 AND product_id = 201;
```

Показать рассогласование:

```sql
SELECT sale_id, product_id, client_id, client_name, client_city
FROM orders_bad
WHERE client_id = 101;
```

У одного и того же `client_id = 101` видны два разных города — это аномалия обновления.

Откат изменения:

```sql
UPDATE orders_bad
SET client_city = 'Москва'
WHERE client_id = 101;
```

Проверка откката:

```sql
SELECT DISTINCT client_id, client_name, client_city
FROM orders_bad
WHERE client_id = 101;
```

### 3.2. Аномалия вставки

Нового клиента или новый товар нельзя добавить, пока у него нет продажи: строка таблицы обязательно содержит `sale_id`, `product_id`, `quantity` и другие поля продажи.

Попытка вставить нового клиента без продажи:

```sql
INSERT INTO orders_bad (client_id, client_name, client_city)
VALUES (104, 'Новиков Пётр', 'Екатеринбург');
```

Поведение зависит от `sql_mode`. При строгом режиме MySQL возвращает ошибку `ERROR 1364 (HY000): Field 'sale_id' doesn't have a default value`. При нестрогом режиме строка вставляется с `NULL` в полях продажи — это тоже демонстрация аномалии: таблица допустила «клиента без продажи», и такая строка не является продажей.

Проверить результат:

```sql
SELECT * FROM orders_bad WHERE client_id = 104;
```

Чтобы показать именно ошибку, можно временно включить строгий режим:

```sql
SET SESSION sql_mode = 'STRICT_TRANS_TABLES,NO_ENGINE_SUBSTITUTION';

INSERT INTO orders_bad (client_id, client_name, client_city)
VALUES (104, 'Новиков Пётр', 'Екатеринбург');
```

После демонстрации удалить возможную строку и вернуть режим:

```sql
DELETE FROM orders_bad WHERE client_id = 104;
SET SESSION sql_mode = DEFAULT;
```

Проверка, что вернулось 10 строк:

```sql
SELECT COUNT(*) FROM orders_bad;
```

### 3.3. Аномалия удаления

Если удалить все продажи клиента, вместе с ними исчезнет и вся информация о клиенте.

Показать данные клиента 103 до удаления:

```sql
SELECT DISTINCT client_id, client_name, client_city
FROM orders_bad
WHERE client_id = 103;

SELECT COUNT(*) AS rows_before
FROM orders_bad
WHERE client_id = 103;
```

Удалить все продажи клиента 103:

```sql
DELETE FROM orders_bad WHERE client_id = 103;
```

Показать, что информация о клиенте исчезла:

```sql
SELECT COUNT(*) AS rows_after FROM orders_bad WHERE client_id = 103;

SELECT DISTINCT client_id, client_name, client_city
FROM orders_bad
WHERE client_id = 103;
```

`rows_after = 0`, и запрос по клиенту 103 не возвращает ни одной строки.

Восстановление данных:

```sql
INSERT INTO orders_bad VALUES
(5004, '2026-11-04', 103, 'Сидоров Алексей', 'Казань', 202, 'Клавиатура', 2000.00, 5),
(5004, '2026-11-04', 103, 'Сидоров Алексей', 'Казань', 203, 'Мышь',       1000.00, 2),
(5006, '2026-11-06', 103, 'Сидоров Алексей', 'Казань', 204, 'Наушники',   3500.00, 2),
(5006, '2026-11-06', 103, 'Сидоров Алексей', 'Казань', 205, 'Колонки',    2500.00, 1);
```

Проверка:

```sql
SELECT COUNT(*) FROM orders_bad;
SELECT DISTINCT client_id, client_name, client_city
FROM orders_bad
WHERE client_id = 103;
```

### 3.4. Итоговая проверка перед нормализацией

```sql
SELECT COUNT(*) AS total_rows FROM orders_bad;
SELECT SUM(unit_price * quantity) AS total_sum FROM orders_bad;
SELECT * FROM orders_bad ORDER BY sale_id, product_id;
```

Ожидается 10 строк и сумма `80000.00`. Если сумма отличается, проверить количество строк и восстановление после аномалии удаления.

## 4. Создание нормализованных таблиц (3NF)

```sql
CREATE TABLE clients (
    client_id   INT PRIMARY KEY,
    client_name VARCHAR(100) NOT NULL,
    client_city VARCHAR(100) NOT NULL
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE products (
    product_id   INT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    unit_price   DECIMAL(10,2) NOT NULL
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE sales (
    sale_id   INT PRIMARY KEY,
    sale_date DATE NOT NULL,
    client_id INT NOT NULL,
    FOREIGN KEY (client_id) REFERENCES clients(client_id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE sale_items (
    sale_id    INT NOT NULL,
    product_id INT NOT NULL,
    quantity   INT NOT NULL,
    PRIMARY KEY (sale_id, product_id),
    FOREIGN KEY (sale_id)    REFERENCES sales(sale_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

## 5. Перенос данных в нормализованные таблицы

```sql
INSERT INTO clients (client_id, client_name, client_city)
SELECT DISTINCT client_id, client_name, client_city
FROM orders_bad;

INSERT INTO products (product_id, product_name, unit_price)
SELECT DISTINCT product_id, product_name, unit_price
FROM orders_bad;

INSERT INTO sales (sale_id, sale_date, client_id)
SELECT DISTINCT sale_id, sale_date, client_id
FROM orders_bad;

INSERT INTO sale_items (sale_id, product_id, quantity)
SELECT sale_id, product_id, quantity
FROM orders_bad;
```

## 6. Проверка целостности перенесённых данных

### 6.1. Сравнение количества строк

```sql
SELECT COUNT(DISTINCT client_id) AS clients_before FROM orders_bad;
SELECT COUNT(*) AS clients_after FROM clients;

SELECT COUNT(DISTINCT product_id) AS products_before FROM orders_bad;
SELECT COUNT(*) AS products_after FROM products;

SELECT COUNT(DISTINCT sale_id) AS sales_before FROM orders_bad;
SELECT COUNT(*) AS sales_after FROM sales;

SELECT COUNT(*) AS items_before FROM orders_bad;
SELECT COUNT(*) AS items_after FROM sale_items;
```

Ожидается: клиентов 3, товаров 5, продаж 6, позиций 10.

### 6.2. Сравнение общей суммы

```sql
SELECT 'before' AS stage, SUM(unit_price * quantity) AS total_sum
FROM orders_bad
UNION ALL
SELECT 'after',
       (SELECT SUM(p.unit_price * si.quantity)
        FROM sale_items si
        JOIN products p ON p.product_id = si.product_id);
```

Оба значения `total_sum` должны равняться `80000.00`.

## 7. Тестовые запросы на нормализованной схеме

### 7.1. Сколько потратил клиент 101

```sql
SELECT c.client_name, SUM(p.unit_price * si.quantity) AS total_spent
FROM clients c
JOIN sales s ON s.client_id = c.client_id
JOIN sale_items si ON si.sale_id = s.sale_id
JOIN products p ON p.product_id = si.product_id
WHERE c.client_id = 101
GROUP BY c.client_id, c.client_name;
```

Ожидается `37000.00`.

### 7.2. Все продажи с позициями

```sql
SELECT s.sale_id, s.sale_date, c.client_name, p.product_name, si.quantity
FROM sales s
JOIN clients c ON c.client_id = s.client_id
JOIN sale_items si ON si.sale_id = s.sale_id
JOIN products p ON p.product_id = si.product_id
ORDER BY s.sale_id, p.product_id;
```

## 8. Переименование исходной таблицы

После успешной проверки исходная таблица переименована:

```sql
RENAME TABLE orders_bad TO orders_bad_backup;
```

## 9. Дамп базы после нормализации

Выполняется в Git Bash:

```bash
MSYS_NO_PATHCONV=1 docker exec -e MYSQL_PWD=123 mysql_norm mysqldump -uroot \
  --set-gtid-purged=OFF \
  --single-transaction \
  sales_norm > dump_after.sql
```

Проверка, что дамп не пустой:

```bash
grep -c "INSERT INTO" dump_after.sql
```

## 10. Ведение и экспорт лога действий пользователя

### 10.1. Проверка, что лог пишется

```bash
MSYS_NO_PATHCONV=1 docker exec mysql_norm ls -la /var/lib/mysql/general.log
```

Файл должен иметь размер больше 0 и принадлежать пользователю `mysql`.

### 10.2. Просмотр последних строк лога

```bash
MSYS_NO_PATHCONV=1 docker exec mysql_norm tail -n 30 /var/lib/mysql/general.log
```

### 10.3. Фильтрация только своих действий

```bash
MSYS_NO_PATHCONV=1 docker exec mysql_norm cat /var/lib/mysql/general.log \
  | grep -E "Query[[:space:]]+(CREATE|INSERT|SELECT|UPDATE|DELETE|ALTER|DROP|RENAME|SHOW DATABASES|SHOW TABLES|SHOW FULL TABLES|SHOW CREATE|SHOW VARIABLES LIKE)" \
  | grep -v -E "INSERT INTO help_|INSERT INTO time_zone|INSERT INTO mysql\.|SELECT \* FROM mysql\.general_log" \
  > my_actions.log
```

Проверка результата:

```bash
wc -l my_actions.log
cat my_actions.log
```

В файле должны остаться только осмысленные SQL-команды, выполненные в ходе работы.

### 10.4. Копирование лога на хост

```bash
MSYS_NO_PATHCONV=1 docker cp mysql_norm:/var/lib/mysql/general.log ./general.log
ls -la general.log
```

Размер скопированного файла должен быть больше 0.

### 10.5. Очистка лога

Выполняется после копирования лога и снятия скриншотов:

```bash
MSYS_NO_PATHCONV=1 docker exec -u mysql mysql_norm sh -c ': > /var/lib/mysql/general.log'
```

## 11. Состав файлов в репозитории

```
normalization_lab/
├── README.md
├── general.log
├── my_actions.log
├── dump_before.sql
└── dump_after.sql
```

## Скриншоты

![alt](<screenshots/1.png>)

![alt](<screenshots/2.png>)

![alt](<screenshots/3.png>)

![alt](<screenshots/4.png>)

![alt](<screenshots/5.png>)

![alt](<screenshots/6.png>)

![alt](<screenshots/7.png>)
