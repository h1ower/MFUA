## Интерактивная работа с MySQL в изолированном окружении Docker.

InnoDB

Навигация:
- [Docker + MySQL + кириллица](#docker)
- [Создание БД и таблиц](#create-db)
- [CRUD-операции](#crud)
- [Фильтрация, сортировка, ограничение](#filter)
- [Агрегация и группировка](#aggregate)
- [Все основные типы JOIN](#join)
- [Подзапросы и UNION](#subqueries)
- [Изменение структуры](#alter)
- [Создание дампа БД](#dump)
- [Удаление объектов](#drop)
- [Направления для дальнейшего изучения](#next)

Задачи:
- запустить «чистый» контейнер
- подключиться к нему
- выполнять основные операции с базами данных
- сделать дамп базы данных

<a id="docker"></a>
### 🚀 Шаг 1: Запуск контейнера MySQL

- Создайте отдельный каталог `my-mysql` и перейдите в него.
- Создайте в каталоге `my-mysql` файл `my.cnf` с содержимым:
```shell
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci

[client]
default-character-set = utf8mb4

[mysql]
default-character-set = utf8mb4
```
Контейнер с официального образа **MySQL**:
```bash
docker run --name my-mysql \
  -e MYSQL_ROOT_PASSWORD=123 \
  -e LANG=C.UTF-8 \
  -v mysql_data:/var/lib/mysql \
  -v $(pwd)/my.cnf:/etc/mysql/conf.d/my.cnf \
  -d mysql:latest
```

Разберем, что делает эта команда:
*   `--name my-mysql`: Присваивает контейнеру понятное имя `my-mysql`, чтобы не использовать его ID.
*   `-e MYSQL_ROOT_PASSWORD=123`: Устанавливает пароль для пользователя root. В учебном примере — 123, в реальных проектах используйте надёжный пароль.
*   `-d`: Запускает контейнер в фоновом режиме (detached mode).
*   `mysql:latest`: Указывает, что нужно использовать последнюю версию официального образа MySQL.

Чтобы убедиться, что контейнер успешно запущен, выполните:
```bash
docker ps
```
Вы должны увидеть свой контейнер `my-mysql` в списке работающих.

Где "физически" зранятся файлы новой базы данных?

Увидеть физические файлы базы в вашем Docker-контейнере:
```shell
docker exec -it my-mysql ls -la /var/lib/mysql
```
Вы увидите примерно такую картину:
```shell
drwxr-xr-x  mysql mysql  ibdata1
drwxr-xr-x  mysql mysql  ib_logfile0
drwxr-xr-x  mysql mysql  ib_logfile1
drwxr-xr-x  mysql mysql  #innodb_temp
drwxr-xr-x  mysql mysql  mysql/
drwxr-xr-x  mysql mysql  performance_schema/
drwxr-xr-x  mysql mysql  sys/
drwxr-xr-x  mysql mysql  sql_practice/
```

### 🔌 Шаг 2: Подключение к MySQL в интерактивном режиме

Теперь, когда контейнер работает, к нему нужно подключиться. Для этого используется команда `docker exec`, которая позволяет выполнить команду внутри работающего контейнера.

Выполните следующую команду, чтобы открыть интерактивную оболочку **MySQL**:

```bash
docker exec -it my-mysql mysql --default-character-set=utf8mb4 -uroot -p
```
*   `-it`: Флаги `-i` (interactive) и `-t` (tty) вместе создают интерактивный терминал.
*   `mysql -uroot -p`: Запускает клиент MySQL от имени пользователя `root` и запрашивает пароль.

После ввода пароля вы увидите приглашение `mysql>`. Теперь вы находитесь в интерактивной оболочке и можете выполнять любые SQL-команды.

### 🛠️ Шаг 3: Основные операции с базами данных и таблицами

Внутри оболочки **MySQL** вы можете выполнять все стандартные SQL-команды.

Проверить кодировку сразу после подключения:
```sql
SHOW VARIABLES LIKE 'character_set%';
```
Если `character_set_client`, `character_set_connection` и `character_set_results` равны `utf8mb4` — всё в порядке.

**1. Просмотр существующих баз данных**
```sql
SHOW DATABASES;
```
Эта команда покажет список всех баз данных, включая системные (`information_schema`, `mysql`, `performance_schema`, `sys`).

**2. Создание новой базы данных и таблицы в ней**

Получить краткую справку по командам СУБД **MySQL**
```sql
help
```

Создадим базу данных с именем `my_database` с таблицей `users`. Рекомендуется сразу указывать кодировку:
```sql
CREATE DATABASE my_database
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE my_database;

CREATE TABLE users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

INSERT INTO users (name, email) VALUES
  ('Иван Иванов', 'ivan@example.com'),
  ('Пётр Петров', 'petr@example.com'),
  ('Мария Сидорова', 'maria@example.com');

SELECT * FROM users;
```
Это инструкции, которые указывают СУБД: «создай базу», «создай таблицу», «вставь строку»

Получить существующие БД
```sql
SHOW DATABASES;
```

**3. Выбор базы данных для работы**
```sql
USE my_database;
```
Теперь все последующие команды будут применяться к этой базе данных!

Получить существующие таблицы
```sql
SHOW TABLES;
```

**4. Вставка данных**

Сначала получим текущие данные указанной таблицы
```sql
SELECT * FROM users;
```
затем добавим новые:
```sql
INSERT INTO users (name, email) VALUES ('Павел Иванов', 'pavel@example.com');
INSERT INTO users (name, email) VALUES ('Марк Аврелий', 'mark@example.com');
```
Проверка кодировки после вставки (опционально):
```sql
SELECT name, HEX(name) FROM users WHERE id = 1;
```

**5. Просмотр данных**
```sql
SELECT * FROM users;
```

**6. Обновление данных**
```sql
UPDATE users SET name = 'Иван Петров' WHERE id = 1;
```
просто меняем **id** в указанной записи

или
```sql
UPDATE users SET name = 'Vasya' WHERE id = 1;
```
Посмотреть все строки таблицы
```sql
SELECT * FROM users;
```
Посмотреть одну конкретную запись (строку)
```sql
SELECT * FROM users WHERE id = 1;
```
Получить указанные поля
```sql
SELECT name, email FROM users;
```
или получить указанное поле
```sql
SELECT name FROM users;
```
Посмотреть только нужные поля (столбцы)
```sql
SELECT name, email FROM users WHERE id = 1;
```
Удобный вертикальный вывод
```sql
SELECT * FROM users WHERE id = 1\G
```
`\G` заменяет точку с запятой и не требует `;` в конце

**7. Удаление данных**

Сначала получим содержимое таблицы для последующего сравнения
```sql
SELECT * FROM users;
```
затем удалим указанную запись
```sql
DELETE FROM users WHERE id = 2;
```
Если удалить `WHERE`, удалятся все строки

**8. Удаление таблицы**
```sql
DROP TABLE users;
```
Получить существующие таблицы
```sql
SHOW TABLES;
```

**9. Удаление базы данных**
```sql
DROP DATABASE my_database;
```
Просмотр существующих баз данных
```sql
SHOW DATABASES;
```
```sql
exit
```
или
```sql
quit
```
ещё
```sql
\q
```

### 🧹 Шаг 4: Управление контейнером

*   **Остановка контейнера:**
    ```bash
    docker stop my-mysql
    ```
*   **Запуск ранее остановленного контейнера:**
    ```bash
    docker start my-mysql
    ```
*   **Просмотр логов (может пригодиться для отладки):**
    ```bash
    docker logs my-mysql
    ```

Если нужно пересоздать контейнер с сохранением данных:
```shell
docker stop my-mysql
docker rm my-mysql
docker run --name my-mysql \
  -e MYSQL_ROOT_PASSWORD=123 \
  -e LANG=C.UTF-8 \
  -v mysql_data:/var/lib/mysql \
  -v $(pwd)/my.cnf:/etc/mysql/conf.d/my.cnf \
  -d mysql:latest
```

***

## Практическое руководство по основам SQL

---

## 🔌 Подключение к контейнеру

Если контейнер ещё не запущен, запустите его:
```bash
docker start my-mysql
```
Подключитесь к MySQL:
```bash
docker exec -it my-mysql mysql --default-character-set=utf8mb4 -uroot -p
```
Введите пароль `123`. Вы увидите приглашение `mysql>`.

---

<a id="create-db"></a>
## 🗄️ Шаг 1: Создание учебной базы данных

```sql
CREATE DATABASE sql_practice
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE sql_practice;
```
Проверить, что база создана:
```sql
SHOW DATABASES;
```

---

## 📋 Шаг 2: Создание таблиц

Создадим две связанные таблицы: `customers` (клиенты) и `orders` (заказы):
```sql
CREATE TABLE customers (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) NOT NULL UNIQUE,
    city VARCHAR(100),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE orders (
    id INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date DATE NOT NULL,
    amount DECIMAL(10, 2) NOT NULL,
    status VARCHAR(20) DEFAULT 'new',
    FOREIGN KEY (customer_id) REFERENCES customers(id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```
Получить существующие таблицы
```sql
SHOW TABLES;
```
Проверить структуру таблицы:
```sql
DESCRIBE customers;
DESCRIBE orders;
```
Команда `CREATE TABLE customers` Создаёт файл customers.ibd и т.п.
```sql
exit
```
Внутри каталога sql_practice/ можно увидеть файлы
```shell
docker exec -it my-mysql ls -la /var/lib/mysql/sql_practice
```
Вы увидите:
```shell
customers.ibd
orders.ibd
```

---

<a id="crud"></a>
## ✍️ Шаг 3: Вставка данных (INSERT)

Вернуться в базу данных
```sql
docker exec -it my-mysql mysql --default-character-set=utf8mb4 -uroot -p
```
Использовать указанную БД
```sql
USE sql_practice;
```
Показать таблицы
```sql
SHOW TABLES;
```
Показать содержимое таблиц:
```sql
SELECT * FROM customers;
SELECT * FROM orders;
```

и вставить эту инструкцию
```sql
INSERT INTO customers (name, email, city) VALUES
  ('Иван Иванов', 'ivan@example.com', 'Москва'),
  ('Пётр Петров', 'petr@example.com', 'Санкт-Петербург'),
  ('Мария Сидорова', 'maria@example.com', 'Москва'),
  ('Алексей Смирнов', 'alex@example.com', 'Казань'),
  ('Ольга Кузнецова', 'olga@example.com', 'Новосибирск');

INSERT INTO orders (customer_id, order_date, amount, status) VALUES
  (1, '2026-10-01', 1500.00, 'paid'),
  (1, '2026-10-05', 2300.50, 'paid'),
  (2, '2026-10-03', 800.00, 'new'),
  (3, '2026-10-07', 4200.00, 'paid'),
  (3, '2026-10-10', 1100.00, 'cancelled'),
  (4, '2026-10-12', 950.00, 'new');
```
`customers` — клиенты, `paid` — оплачено

Проверить, что данные вставились:
```sql
SHOW TABLES;
```
и
```sql
SELECT * FROM customers;
SELECT * FROM orders;
```

---

<a id="filter"></a>
## 🔍 Шаг 4: Выборка данных (SELECT)

### 4.1. Все столбцы и все строки
```sql
SELECT * FROM customers;
```
### 4.2. Только нужные столбцы
```sql
SELECT name, city FROM customers;
```
### 4.3. Условие `WHERE` (ГДЕ)
```sql
SELECT * FROM customers WHERE city = 'Москва';
SELECT * FROM orders WHERE amount > 1000;
SELECT * FROM orders WHERE status = 'paid' AND amount > 1500;
SELECT * FROM orders WHERE status = 'new' OR status = 'cancelled';
```
`amount` — количество, сумма

### 4.4. Сортировка `ORDER BY`
```sql
SELECT * FROM customers ORDER BY name;
SELECT * FROM orders ORDER BY amount DESC;
SELECT * FROM orders ORDER BY order_date DESC, amount ASC;
```
Сортировка заказов по сумме (от большей к меньшей)

### 4.5. Ограничение количества строк `LIMIT`
```sql
SELECT * FROM orders ORDER BY amount DESC LIMIT 3;
```
### 4.6. Поиск по шаблону `LIKE`
```sql
SELECT * FROM customers WHERE name LIKE 'И%';      -- начинается на И
SELECT * FROM customers WHERE email LIKE '%@example.com';
```
### 4.7. Диапазон `BETWEEN`, список `IN`
```sql
SELECT * FROM orders WHERE amount BETWEEN 1000 AND 3000;
SELECT * FROM customers WHERE city IN ('Москва', 'Казань');
```
Оператор **IN** — это логический оператор, который проверяет, входит ли значение в заданный список. Он является сокращённой формой цепочки OR (ИЛИ, дизъюнкция).

Это то же самое, что:
```sql
SELECT * FROM customers WHERE city = 'Москва' OR city = 'Казань';
```
Результат одинаковый — обе строки вернут клиентов из Москвы и Казани. Но **IN** короче, читабельнее и удобнее, особенно если значений много.

### 4.8. Пустые значения `IS NULL`
```sql
SELECT * FROM customers WHERE city IS NULL;
```

---

<a id="aggregate"></a>
## 📊 Шаг 5: Агрегатные функции

Всего заказов
```sql
SELECT COUNT(*) AS total_orders FROM orders;
```
Общая сумма
```sql
SELECT SUM(amount) AS total_sum FROM orders;
```
Среднее
```sql
SELECT AVG(amount) AS avg_amount FROM orders;
```
Минимальная и максимальная сумма
```sql
SELECT MIN(amount) AS min_amount, MAX(amount) AS max_amount FROM orders;
```

---

## 📈 Шаг 6: Группировка `GROUP BY` и `HAVING`

### 6.1. Количество заказов по каждому клиенту
```sql
SELECT customer_id, COUNT(*) AS order_count, SUM(amount) AS total_amount
FROM orders
GROUP BY customer_id;
```

### 6.2. Соединение с именами клиентов
```sql
SELECT c.name, COUNT(o.id) AS order_count, SUM(o.amount) AS total_amount
FROM customers c
JOIN orders o ON c.id = o.customer_id
GROUP BY c.id, c.name
ORDER BY total_amount DESC;
```
Алиасы c и o — см. раздел 7.1.

### 6.3. Фильтрация групп HAVING
```sql
SELECT customer_id, SUM(amount) AS total_amount
FROM orders
GROUP BY customer_id
HAVING SUM(amount) > 2000;
```

---

<a id="join"></a>
## 🔗 Шаг 7: Соединения **JOIN**

### 7.1. INNER JOIN — только совпадающие строки
```sql
SELECT c.name, o.order_date, o.amount, o.status
FROM customers c
INNER JOIN orders o ON c.id = o.customer_id;
```
**INNER JOIN** и просто **JOIN** — это одно и то же. Слово **INNER** можно опускать.

Чтобы узнать имя клиента по его **id**, нужно соединить таблицы через **JOIN**

**JOIN** — это оператор, который соединяет строки из двух или более таблиц на основе общего столбца (обычно это первичный ключ одной таблицы и внешний ключ другой). Без JOIN работать с реляционными базами данных практически невозможно: данные намеренно разнесены по таблицам, чтобы избежать дублирования

Алиасы в SQL
```sql
FROM customers c
JOIN orders o ON c.id = o.customer_id;
```
Здесь:
- `customers c` — таблица **customers** получает псевдоним `c`
- `orders o` — таблица **orders** получает псевдоним `o`

Зачем нужны?

1. Краткость. Вместо `customers.name` пишете `c.name`. В коротком запросе это мелочь, но в запросе с 5 таблицами — существенная экономия.
2. Разрешение неоднозначности. В обеих таблицах есть столбец `id`. Без алиаса запрос:
```sql
SELECT id FROM customers JOIN orders ON ...;
```
вернёт ошибку:
```sql
ERROR 1052 (23000): Column 'id' in field list is ambiguous
```
т.к. MySQL не знает, какой `id` имеется в виду — из `customers` или из `orders`. С алиасом всё однозначно:
```sql
SELECT c.id, o.id FROM customers c JOIN orders o ON c.id = o.customer_id;
```
[Подробней про алиасы в SQL тут >>>](/content/Courses/Basics_database_design/content/Docs/Aliases.md)


### 7.2. LEFT JOIN — все клиенты, даже без заказов
```sql
SELECT c.name, o.id AS order_id, o.amount
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id;
```
**LEFT JOIN** (левое внешнее соединение) — возвращает все строки из левой таблицы, даже если нет совпадений в правой. Для несовпавших строк правая таблица даёт **NULL**.

Клиенты без заказов будут иметь `NULL` в полях заказа.

### 7.3. RIGHT JOIN — все заказы, даже если клиент удалён (редко используется)
```sql
SELECT c.name, o.id AS order_id
FROM customers c
RIGHT JOIN orders o ON c.id = o.customer_id;
```
RIGHT JOIN (правое внешнее соединение) — возвращает все строки из правой таблицы, даже если нет совпадений в левой.

Результат: все строки из правой таблицы (orders) + совпадения из левой (customers). Если у заказа нет клиента — в поле c.name будет NULL.

На практике: RIGHT JOIN используется редко. Почти всегда его можно переписать как LEFT JOIN, поменяв таблицы местами:
```sql
-- Эквивалент RIGHT JOIN
SELECT c.name, o.id AS order_id
FROM orders o
LEFT JOIN customers c ON o.customer_id = c.id;
```

### 7.4. JOIN и GROUP BY — соединение с агрегацией

Соединим таблицы и посчитаем агрегаты:
```sql
SELECT c.name,
       COUNT(o.id) AS order_count,
       SUM(o.amount) AS total_amount
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY c.id, c.name
ORDER BY total_amount DESC;
```
Чтобы вместо NULL был 0:
```sql
SELECT c.name,
       COUNT(o.id) AS order_count,
       COALESCE(SUM(o.amount), 0) AS total_amount
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY c.id, c.name
ORDER BY total_amount DESC;
```

---

<a id="subqueries"></a>
## 🧩 Шаг 8: Подзапросы и **UNION**

### 8.1. Подзапросы (Subqueries)

Подзапрос — это `SELECT`-запрос, вложенный внутрь другого SQL-запроса. Подзапрос выполняется первым, а его результат используется внешним запросом.

#### Подзапрос в WHERE (с IN)
```sql
SELECT name, city
FROM customers
WHERE id IN (
    SELECT customer_id
    FROM orders
    WHERE amount > 1000
);
```
Вернёт клиентов, у которых есть хотя бы один заказ на сумму больше 1000.

#### Подзапрос в WHERE (со сравнением)
```sql
SELECT name, city
FROM customers
WHERE id = (
    SELECT customer_id
    FROM orders
    ORDER BY amount DESC
    LIMIT 1
);
```
Вернёт клиента с самым крупным заказом.

#### Подзапрос в FROM (производная таблица)
```sql
SELECT c.name, o.total
FROM customers c
JOIN (
    SELECT customer_id, SUM(amount) AS total
    FROM orders
    GROUP BY customer_id
) o ON c.id = o.customer_id
WHERE o.total > 2000;
```
Подзапрос в `FROM` формирует временную таблицу с агрегатами, которую затем соединяем с `customers`.

#### Подзапрос в SELECT (скалярный)
```sql
SELECT c.name,
       (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.id) AS order_count
FROM customers c;
```
Для каждого клиента считается количество его заказов.

#### EXISTS и NOT EXISTS
```sql
-- Клиенты, у которых есть хотя бы один заказ
SELECT name FROM customers c
WHERE EXISTS (
    SELECT 1 FROM orders o WHERE o.customer_id = c.id
);

-- Клиенты без заказов
SELECT name FROM customers c
WHERE NOT EXISTS (
    SELECT 1 FROM orders o WHERE o.customer_id = c.id
);
```
`EXISTS` часто работает быстрее, чем `IN`, особенно если внешняя таблица большая, а внутренняя — маленькая.

### 8.2. UNION и UNION ALL

`UNION` объединяет результаты двух `SELECT`-запросов в один набор строк.

#### UNION (удаляет дубликаты)
```sql
SELECT name, city FROM customers WHERE city = 'Москва'
UNION
SELECT name, city FROM customers WHERE city = 'Казань';
```
Вернёт клиентов из Москвы и Казани, при этом дубликаты строк удаляются.

#### UNION ALL (сохраняет дубликаты, работает быстрее)
```sql
SELECT city FROM customers
UNION ALL
SELECT city FROM customers;
```
Вернёт все города, включая повторы.

#### Требования к UNION
- Одинаковое количество столбцов в обоих запросах.
- Совместимые типы данных.
- Имена столбцов берутся из первого запроса.

### 8.3. Сравнение JOIN и подзапросов

| Критерий | JOIN | Подзапрос |
|----------|------|-----------|
| Читабельность | Лучше для соединения данных | Лучше для фильтрации |
| Производительность | Обычно быстрее | Может быть медленнее |
| Когда использовать | Нужны данные из обеих таблиц | Нужна только фильтрация |
| **EXISTS** | — | Часто быстрее, чем **IN** |

---

<a id="alter"></a>
## ✏️ Шаг 9: Обновление данных (UPDATE)

```sql
UPDATE customers SET city = 'Екатеринбург' WHERE id = 4;
UPDATE orders SET status = 'paid' WHERE id = 3;
```
Проверить:

```sql
SELECT * FROM customers WHERE id = 4;
SELECT * FROM orders WHERE id = 3;
```

⚠️ **Важно:** всегда указывайте `WHERE`, иначе обновятся все строки!

<a id="dump"></a>

### 8.4. Создание дампа

Создание дампа БД (Экспорт в `.sql` файл)

Выйти из БД
```sql
\q
```
Делаем дамп:
```shell
docker exec my-mysql mysqldump -uroot -p123 sql_practice > dump.sql
```
или
```shell
docker exec -e MYSQL_PWD=123 my-mysql mysqldump -uroot sql_practice > dump.sql
```
или
```shell
docker exec my-mysql mysqldump -uroot -p123 --set-gtid-purged=OFF sql_practice > dump_clean.sql
```
после чего в папке `my-mysql` появится текстовый файл `dump.sql`, содержимое которого можно увидеть командой
```shell
cat dump.sql
```
`.sql` файл является текстовым представлением вашей БД (текстовый SQL-скрипт). Его можно хранить как резервную копия вашей БД, из которой потом её можно восстановить

---

## 🗑️ Шаг 10: Удаление данных (DELETE)


Снова зайти в конейнер с БД
```sql
docker exec -it my-mysql mysql --default-character-set=utf8mb4 -uroot -p
```
выбрать БД
```sql
USE sql_practice
```
```sql
SHOW TABLES;
```
```sql
SELECT * FROM customers;
SELECT * FROM orders;
```
Удалить указанную запись из таблицы
```sql
DELETE FROM orders WHERE id = 6;
```
⚠️ Без `WHERE` удалятся все строки: `DELETE FROM orders;`

Проверить:
```sql
SELECT * FROM orders;
```

---

## 🏗️ Шаг 11: Изменение структуры (ALTER TABLE)

### Добавить столбец
```sql
ALTER TABLE customers ADD COLUMN phone VARCHAR(20);
```
проверить
```sql
SELECT * FROM customers;
```
Обновить данные в столбце phone
```sql
UPDATE customers SET phone = '123-36-77' WHERE id = 4;
```
Проверить
```sql
SELECT * FROM customers WHERE id = 4;
```
или все записи
```sql
SELECT * FROM customers;
```

### Изменить тип столбца
```sql
ALTER TABLE customers MODIFY COLUMN phone VARCHAR(30);
```

### Удалить столбец
```sql
ALTER TABLE customers DROP COLUMN phone;
```
проверить
```sql
SELECT * FROM customers;
```

---

<a id="drop"></a>
## 🧨 Шаг 12: Удаление таблиц и базы

```sql
DROP TABLE orders;
SHOW TABLES;
DROP TABLE customers;
SHOW TABLES;
DROP DATABASE sql_practice;
```
Проверить
```sql
SHOW DATABASES;
```
выйти из контейнера
```sql
\q
```

## 🧨 Шаг 13: Восстановление удалённой БД


Проверьте, что контейнер запущен
```shell
docker ps -a
```
если не запущен - запутите:
```shell
docker start my-mysql
```
Проверьте, что дамп на месте и не пуст
```shell
ls -lh dump.sql
```
Файл должен быть в текущей директории, где вы его создавали. Если размер 0 байт — дамп пустой, восстанавливать нечего. Убедитесь, что вы находитесь в той же папке, где запускали mysqldump, либо укажите полный путь

Быстрая проверка содержимого:
```shell
head -n 30 dump.sql
```
зайти в контейнер
```shell
docker exec -it my-mysql mysql --default-character-set=utf8mb4 -uroot -p
```
выполните:
```sql
CREATE DATABASE sql_practice
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
```
проверьте:
```sql
SHOW DATABASES;
```
Выйдите из MySQL:
```sql
\q
```
Команда импорта выполняется не внутри mysql, а в обычном терминале хоста:
```shell
docker exec -i my-mysql mysql -uroot -p123 sql_practice < dump.sql
```
или (с игнорированием ошибок импорта)
```shell
docker exec -i my-mysql mysql -uroot -p123 --force sql_practice < dump.sql
```
Чтобы проверить результат, нужно снова зайти в контейнер с БД
```shell
docker exec -it my-mysql mysql --default-character-set=utf8mb4 -uroot -p
```
И проверить содержимое восстановленной БД
```sql
SHOW DATABASES;
USE sql_practice;
SHOW TABLES;
SELECT * FROM customers;
SELECT * FROM orders;
```

---

## 🧰 Полезные команды

| Команда | Что делает |
|---------|------------|
| `SHOW DATABASES;` | Список баз данных |
| `USE имя_базы;` | Переключиться на базу |
| `SHOW TABLES;` | Список таблиц в текущей базе |
| `DESCRIBE имя_таблицы;` | Структура таблицы |
| `SHOW CREATE TABLE имя_таблицы;` | SQL для создания таблицы |
| `EXIT;` или `\q` | Выйти из MySQL |
| `\G` вместо `;` | Вертикальный вывод строки |

---

<a id="next"></a>
## 📝 Что дальше?

Когда освоите эти основы, можно переходить к:
- **Представлениям** (`CREATE VIEW`)
- **Индексам** (`CREATE INDEX`)
- **Транзакциям** (`START TRANSACTION`, `COMMIT`, `ROLLBACK`)
- **Хранимым процедурам и триггерам**
- **Оконным функциям** (`ROW_NUMBER()`, `RANK()`, `OVER`)

---

> Если вы обнаружили ошибку в этом тексте — сообщите пожалуйста автору!
