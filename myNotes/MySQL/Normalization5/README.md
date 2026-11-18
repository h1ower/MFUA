
# Лабораторная работа №5. Нормализация данных в БД (с ведением лога)

## Цель работы

Привести ненормализованную таблицу заказов к третьей нормальной форме, разбив её на таблицы-справочники и таблицу фактов; обеспечить связь «клиент — заказ» и классификацию товаров по коду товарной классификации; перенести данные без потерь и искажений; снять дампы до и после нормализации; освоить ведение и экспорт общего лога действий пользователя MySQL.

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

### 1.4. Очистка лога перед началом работы

Выполняется сразу после запуска контейнера, чтобы в лог не попали служебные записи инициализации MySQL и размер файла оставался разумным для просмотра на GitHub:

```bash
MSYS_NO_PATHCONV=1 docker exec -u mysql mysql_norm sh -c ': > /var/lib/mysql/general.log'
```

Флаг `-u mysql` важен: файл должен принадлежать пользователю `mysql`, иначе MySQL не сможет в него писать.

### 1.5. Подключение к MySQL

```bash
MSYS_NO_PATHCONV=1 docker exec -it mysql_norm mysql -uroot -p
```

Пароль: `123`.

### 1.6. Проверка настроек логирования

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

Исходная таблица содержит повторяющиеся группы: для одного заказа перечислены несколько товаров, при этом данные клиента и даты дублируются в каждой строке. Каждый товар относится к товарной классификации, название которой также дублируется.

```sql
CREATE TABLE orders_bad (
    order_id        INT,
    order_date      DATE,
    client_id       INT,
    client_name     VARCHAR(100),
    product_id      INT,
    product_name    VARCHAR(100),
    price           DECIMAL(10,2),
    category_id     INT,
    category_name   VARCHAR(100),
    quantity        INT
);
```

### 2.3. Заполнение таблицы данными

```sql
INSERT INTO orders_bad VALUES
(7001, '2026-11-01', 101, 'Иванов Иван',     201, 'Монитор',    15000.00, 10, 'Периферия',  2),
(7001, '2026-11-01', 101, 'Иванов Иван',     202, 'Клавиатура',  2000.00, 10, 'Периферия',  1),
(7002, '2026-11-02', 102, 'Петрова Мария',   203, 'Мышь',        1000.00, 10, 'Периферия',  3),
(7002, '2026-11-02', 102, 'Петрова Мария',   204, 'Наушники',    3500.00, 20, 'Аудио',      1),
(7003, '2026-11-03', 101, 'Иванов Иван',     205, 'Колонки',     2500.00, 20, 'Аудио',      2),
(7004, '2026-11-04', 103, 'Сидоров Алексей', 202, 'Клавиатура',  2000.00, 10, 'Периферия',  5),
(7004, '2026-11-04', 103, 'Сидоров Алексей', 203, 'Мышь',        1000.00, 10, 'Периферия',  2),
(7005, '2026-11-05', 102, 'Петрова Мария',   201, 'Монитор',    15000.00, 10, 'Периферия',  1),
(7006, '2026-11-06', 103, 'Сидоров Алексей', 204, 'Наушники',    3500.00, 20, 'Аудио',      2),
(7006, '2026-11-06', 103, 'Сидоров Алексей', 205, 'Колонки',     2500.00, 20, 'Аудио',      1);
```

### 2.4. Проверка исходных данных

```sql
SELECT COUNT(*) FROM orders_bad;
SELECT * FROM orders_bad ORDER BY order_id, product_id;
```

Ожидается 10 строк. Контрольная сумма `SUM(price * quantity)` для этих данных равна `80000.00`.

```sql
SELECT SUM(price * quantity) AS total_sum FROM orders_bad;
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

## 3. Создание нормализованных таблиц (3NF)

Ненормализованная таблица содержит частичные и транзитивные зависимости: имя клиента зависит только от `client_id`, название и цена товара — только от `product_id`, название классификации — только от `category_id`. Для приведения к 3NF создаются справочники `clients`, `categories`, `products` и таблица фактов `orders` / `order_items`.

Связь «клиент — заказ» обеспечивается хранением `client_id` в таблице `orders` (шапка заказа). Классификация товаров обеспечивается связью `products.category_id → categories.category_id`.

```sql
CREATE TABLE clients (
    client_id   INT PRIMARY KEY,
    client_name VARCHAR(100) NOT NULL
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE categories (
    category_id   INT PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE products (
    product_id   INT PRIMARY KEY,
    product_name VARCHAR(100) NOT NULL,
    price        DECIMAL(10,2) NOT NULL,
    category_id  INT NOT NULL,
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE orders (
    order_id   INT PRIMARY KEY,
    order_date DATE NOT NULL,
    client_id  INT NOT NULL,
    FOREIGN KEY (client_id) REFERENCES clients(client_id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE order_items (
    order_id   INT NOT NULL,
    product_id INT NOT NULL,
    quantity   INT NOT NULL,
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (order_id)   REFERENCES orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

## 4. Перенос данных в нормализованные таблицы

```sql
INSERT INTO clients (client_id, client_name)
SELECT DISTINCT client_id, client_name
FROM orders_bad;

INSERT INTO categories (category_id, category_name)
SELECT DISTINCT category_id, category_name
FROM orders_bad;

INSERT INTO products (product_id, product_name, price, category_id)
SELECT DISTINCT product_id, product_name, price, category_id
FROM orders_bad;

INSERT INTO orders (order_id, order_date, client_id)
SELECT DISTINCT order_id, order_date, client_id
FROM orders_bad;

INSERT INTO order_items (order_id, product_id, quantity)
SELECT order_id, product_id, quantity
FROM orders_bad;
```

## 5. Проверка целостности перенесённых данных

### 5.1. Сравнение количества строк

```sql
SELECT COUNT(DISTINCT client_id) AS clients_before FROM orders_bad;
SELECT COUNT(*) AS clients_after FROM clients;

SELECT COUNT(DISTINCT category_id) AS categories_before FROM orders_bad;
SELECT COUNT(*) AS categories_after FROM categories;

SELECT COUNT(DISTINCT product_id) AS products_before FROM orders_bad;
SELECT COUNT(*) AS products_after FROM products;

SELECT COUNT(DISTINCT order_id) AS orders_before FROM orders_bad;
SELECT COUNT(*) AS orders_after FROM orders;

SELECT COUNT(*) AS items_before FROM orders_bad;
SELECT COUNT(*) AS items_after FROM order_items;
```

Ожидается: клиентов 3, классификаций 2, товаров 5, заказов 6, позиций 10.

### 5.2. Сравнение общей суммы

```sql
SELECT 'before' AS stage, SUM(price * quantity) AS total_sum
FROM orders_bad
UNION ALL
SELECT 'after',
       (SELECT SUM(p.price * oi.quantity)
        FROM order_items oi
        JOIN products p ON p.product_id = oi.product_id);
```

Оба значения `total_sum` должны равняться `80000.00`.

### 5.3. Проверка связи «клиент — заказ»

```sql
SELECT order_id, COUNT(DISTINCT client_id) AS clients_per_order
FROM orders
GROUP BY order_id
HAVING clients_per_order > 1;
```

Запрос должен вернуть пустой результат: у каждого заказа ровно один клиент.

### 5.4. Проверка классификации товаров

```sql
SELECT p.product_name, c.category_name
FROM products p
JOIN categories c ON c.category_id = p.category_id
ORDER BY p.product_id;
```

Каждый товар должен быть связан ровно с одной классификацией.

## 6. Тестовые запросы на нормализованной схеме

### 6.1. Сумма продаж по товарным классификациям

```sql
SELECT c.category_name, SUM(p.price * oi.quantity) AS total_sales
FROM categories c
JOIN products p     ON p.category_id = c.category_id
JOIN order_items oi ON oi.product_id = p.product_id
GROUP BY c.category_id, c.category_name
ORDER BY total_sales DESC;
```

### 6.2. Все заказы с расшифровкой

```sql
SELECT o.order_id, o.order_date, cl.client_name,
       p.product_name, cat.category_name, oi.quantity, p.price
FROM orders o
JOIN clients cl     ON cl.client_id = o.client_id
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
JOIN categories cat ON cat.category_id = p.category_id
ORDER BY o.order_id, p.product_id;
```

### 6.3. Сумма заказа 7001

```sql
SELECT o.order_id, SUM(p.price * oi.quantity) AS order_total
FROM orders o
JOIN order_items oi ON oi.order_id = o.order_id
JOIN products p     ON p.product_id = oi.product_id
WHERE o.order_id = 7001
GROUP BY o.order_id;
```

## 7. Переименование исходной таблицы

После успешной проверки исходная таблица переименована:

```sql
RENAME TABLE orders_bad TO orders_bad_backup;
```

## 8. Дамп базы после нормализации

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

## 9. Ведение и экспорт лога действий пользователя

### 9.1. Проверка, что лог пишется

```bash
MSYS_NO_PATHCONV=1 docker exec mysql_norm ls -la /var/lib/mysql/general.log
```

Файл должен иметь размер больше 0 и принадлежать пользователю `mysql`.

### 9.2. Просмотр последних строк лога

```bash
MSYS_NO_PATHCONV=1 docker exec mysql_norm tail -n 30 /var/lib/mysql/general.log
```

### 9.3. Фильтрация только своих действий

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

### 9.4. Копирование лога на хост

```bash
MSYS_NO_PATHCONV=1 docker cp mysql_norm:/var/lib/mysql/general.log ./general.log
ls -la general.log
```

Размер скопированного файла должен быть больше 0.

### 9.5. Очистка лога

Выполняется после копирования лога и снятия скриншотов:

```bash
MSYS_NO_PATHCONV=1 docker exec -u mysql mysql_norm sh -c ': > /var/lib/mysql/general.log'
```

## 10. Состав файлов в репозитории

```
normalization_lab/
├── README.md
├── general.log
├── my_actions.log
├── dump_before.sql
└── dump_after.sql
```


## Скриншоты о выполнении работы

![alt text](<screen/Снимок экрана 2026-11-13 131405.png>)

![alt text](<screen/Снимок экрана 2026-11-13 131414.png>)

![alt text](<screen/Снимок экрана 2026-11-13 131528.png>)

![alt text](<screen/Снимок экрана 2026-11-13 131536.png>)

![alt text](<screen/Снимок экрана 2026-11-13 131546.png>)

![alt text](<screen/Снимок экрана 2026-11-13 131552.png>)

![alt text](<screen/Снимок экрана 2026-11-13 131629.png>)

![alt text](<screen/Снимок экрана 2026-11-13 131638.png>)