# Учебное руководство по алиасам в SQL (с созданием БД и логированием)

**Алиасы** (псевдонимы) — это временные имена, которые вы даёте таблицам или столбцам в запросе. Они делают код короче, читабельнее и помогают разрешать неоднозначности. В этом руководстве мы сначала создадим учебную базу данных и настроим логирование, а затем разберём алиасы на примерах.

---

> **Задание выполнять в VS Code — Git-Bash — Docker CLI!**

## 🔹 0. Подготовка окружения

### 0.1. Файл `my.cnf`

В каталоге, откуда будете запускать контейнер, создайте файл `my.cnf`:

```ini
[mysqld]
character-set-server = utf8mb4
collation-server = utf8mb4_unicode_ci
general_log = 1
general_log_file = /var/lib/mysql/general.log
log_output = FILE

[client]
default-character-set = utf8mb4

[mysql]
default-character-set = utf8mb4
```

> ⚠️ Если файла `my.cnf` не будет, Docker создаст директорию с таким именем, и MySQL не запустится. Убедитесь, что это именно файл.

### 0.2. Запуск контейнера

Удалите старый контейнер и его volume (если они есть):

```bash
docker stop mysql_alias
docker rm mysql_alias
docker volume rm mysql_alias_data
docker volume prune -a
```

Создайте новый контейнер:

Git-Bash
```bash
docker run --name mysql_alias \
  -e MYSQL_ROOT_PASSWORD=123 \
  -e LANG=C.UTF-8 \
  -e MYSQL_INITDB_SKIP_TZINFO=1 \
  -v mysql_alias_data:/var/lib/mysql \
  -v $(pwd)/my.cnf:/etc/mysql/conf.d/my.cnf \
  -d mysql:8.0
```

Убедитесь, что контейнер запущен:

```bash
docker ps
```

### 0.3. Очистка лога перед началом работы

При первом запуске MySQL загружает системные данные (справку, часовые пояса), которые попадут в лог. Чтобы начать с чистого листа:

```shell
docker exec -u mysql mysql_alias sh -c ': > /var/lib/mysql/general.log'
```

> Флаг `-u mysql` важен: файл должен принадлежать пользователю `mysql`, иначе MySQL не сможет в него писать.

### 0.4. Подключение к MySQL

```shell
docker exec -it mysql_alias mysql --default-character-set=utf8mb4 -uroot -p
```

Введите пароль `123`. Вы увидите приглашение `mysql>`.

### 0.5. Создание базы данных и таблиц

```sql
CREATE DATABASE alias_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE alias_db;

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

CREATE TABLE employees (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    position VARCHAR(100),
    manager_id INT,
    FOREIGN KEY (manager_id) REFERENCES employees(id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

Заполним таблицы данными:

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

INSERT INTO employees (name, position, manager_id) VALUES
  ('Анна Петрова',   'Генеральный директор', NULL),
  ('Игорь Смирнов',  'Финансовый директор',  1),
  ('Елена Кузнецова','Технический директор', 1),
  ('Дмитрий Орлов',  'Ведущий разработчик',  3),
  ('Ольга Зайцева',  'Разработчик',          3),
  ('Сергей Волков',  'Бухгалтер',            2);
```

Проверим:

```sql
SELECT * FROM customers;
SELECT * FROM orders;
SELECT * FROM employees;
```

---

## 🔹 1. Зачем нужны алиасы

| Задача | Как помогает алиас |
|--------|-------------------|
| Сократить длинные имена таблиц | `customers` → `c` |
| Разрешить неоднозначность столбцов | В обеих таблицах есть `id` — указываем `c.id` и `o.id` |
| Улучшить читаемость результата | `SUM(amount)` → `total_amount` |
| Ссылаться на вычисляемые столбцы в `ORDER BY` | `ORDER BY total_amount` вместо повторения выражения |
| Соединить таблицу с самой собой | `employees e` и `employees m` |

---

## 🔹 2. Алиасы таблиц

### Синтаксис

```sql
FROM имя_таблицы [AS] псевдоним
```

> Это для примера — не выполнять!

`AS` необязателен, но его часто пишут для ясности. После объявления алиаса **везде** в запросе используется только он.

### Пример без алиасов

```sql
SELECT customers.name, orders.order_date, orders.amount
FROM customers
JOIN orders ON customers.id = orders.customer_id;
```

### Тот же запрос с алиасами

```sql
SELECT c.name, o.order_date, o.amount
FROM customers c
JOIN orders o ON c.id = o.customer_id;
```

Короче и читабельнее. В запросе с 3–4 таблицами экономия существенна.

### Когда алиасы обязательны

1. **Самосоединение** — одна таблица соединяется с собой:

```sql
SELECT e.name AS employee, m.name AS manager
FROM employees e
JOIN employees m ON e.manager_id = m.id;
```

Без `e` и `m` MySQL не поймёт, к какой «копии» таблицы обращаться.

2. **Неоднозначные имена столбцов** — когда в обеих таблицах есть одинаковые столбцы (например, `id`):

```sql
-- Ошибка: Column 'id' in field list is ambiguous
SELECT id FROM customers JOIN orders ON ...;

-- Правильно:
SELECT c.id, o.id FROM customers c JOIN orders o ON c.id = o.customer_id;
```

3. **Производные таблицы (подзапросы в `FROM`)** — алиас обязателен:

```sql
SELECT *
FROM (SELECT customer_id, SUM(amount) AS total FROM orders GROUP BY customer_id) AS t;
-- без AS t — ошибка
```

---

## 🔹 3. Алиасы столбцов

### Синтаксис

```sql
SELECT выражение [AS] псевдоним
```

`AS` здесь практически обязателен (без него MySQL может работать, но это плохая практика).

### Пример

```sql
SELECT name AS customer_name,
       email AS contact_email
FROM customers;
```

Или для агрегатов:

```sql
SELECT customer_id,
       COUNT(*) AS order_count,
       SUM(amount) AS total_amount
FROM orders
GROUP BY customer_id;
```

Без алиасов заголовки столбцов были бы `COUNT(*)` и `SUM(amount)` — неинформативно.

### Где можно ссылаться на алиас столбца

| Клауза | Можно? | Пример |
|--------|--------|--------|
| `ORDER BY` | ✅ Да | `ORDER BY total_amount DESC` |
| `GROUP BY` | ✅ Да (MySQL) | `GROUP BY total_amount` |
| `HAVING` | ✅ Да (MySQL) | `HAVING total_amount > 1000` |
| `WHERE` | ❌ Нет | `WHERE total_amount > 1000` — ошибка |

**Почему `WHERE` — нет:** `WHERE` выполняется **до** `SELECT`, поэтому алиас ещё не создан. Для фильтрации агрегатов используйте `HAVING`, а для обычных столбцов — повторяйте выражение.

### Пример: алиас в `ORDER BY`

```sql
SELECT id, amount * 2 AS double_amount
FROM orders
ORDER BY double_amount DESC;
```

Работает, потому что `ORDER BY` выполняется после `SELECT`.

### Пример: алиас в `WHERE` (ошибка)

Неправильно:

```sql
-- ❌ Unknown column 'double_amount' in 'where clause'
SELECT id, amount * 2 AS double_amount
FROM orders
WHERE double_amount > 1000;
```

Правильно:

```sql
-- ✅ Правильно: повторить выражение
SELECT id, amount * 2 AS double_amount
FROM orders
WHERE amount * 2 > 1000;
```

---

## 🔹 4. Алиасы в разных частях запроса: порядок выполнения

Понимание порядка помогает не путаться с алиасами.

| Шаг | Клауза | Видны ли алиасы столбцов? |
|-----|--------|---------------------------|
| 1 | `FROM` / `JOIN` | ❌ Нет |
| 2 | `WHERE` | ❌ Нет |
| 3 | `GROUP BY` | ⚠️ Частично (MySQL разрешает) |
| 4 | `HAVING` | ⚠️ Частично (MySQL разрешает) |
| 5 | `SELECT` | ✅ Здесь алиасы создаются |
| 6 | `ORDER BY` | ✅ Да |
| 7 | `LIMIT` | ✅ Да |

**Вывод:** в `WHERE` алиасы недоступны, в `ORDER BY` — доступны. В `GROUP BY` и `HAVING` MySQL разрешает, но это нестандартно.

---

## 🔹 5. Алиасы в подзапросах

### В `FROM` (производная таблица)

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

Здесь `o` — алиас производной таблицы. Без него MySQL выдаст ошибку.

### В `SELECT` (скалярный подзапрос)

```sql
SELECT c.name,
       (SELECT COUNT(*) FROM orders o WHERE o.customer_id = c.id) AS order_count
FROM customers c;
```

`o` — алиас таблицы `orders` внутри подзапроса, `c` — снаружи. Они не конфликтуют.

---

## 🔹 6. Алиасы и `JOIN`

При соединении нескольких таблиц алиасы особенно полезны:

```sql
SELECT c.name AS customer,
       o.order_date,
       o.amount,
       o.amount * 2 AS double_amount
FROM customers c
JOIN orders o ON c.id = o.customer_id
WHERE o.status = 'paid'
ORDER BY double_amount DESC;
```

Без алиасов пришлось бы писать `customers.name`, `orders.order_date` и т.д. — громоздко и трудночитаемо.

---

## 🔹 7. Распространённые ошибки

### 1. Ссылка на старое имя таблицы после объявления алиаса

```sql
-- ❌ Ошибка: Unknown column 'customers.name'
SELECT customers.name
FROM customers c;

-- ✅ Правильно:
SELECT c.name
FROM customers c;
```

После `FROM customers c` имя `customers` в этом запросе **не существует**. Только `c`.

### 2. Пропущен `AS` для производной таблицы

```sql
-- ❌ Ошибка
SELECT * FROM (SELECT id FROM customers);

-- ✅ Правильно
SELECT * FROM (SELECT id FROM customers) AS t;
```

### 3. Алиас в `WHERE`

```sql
-- ❌ Ошибка
SELECT amount * 2 AS double_amount FROM orders WHERE double_amount > 1000;

-- ✅ Правильно
SELECT amount * 2 AS double_amount FROM orders WHERE amount * 2 > 1000;
```

### 4. Неоднозначный `id` без алиаса

```sql
-- ❌ Ошибка: Column 'id' is ambiguous
SELECT id FROM customers JOIN orders ON customers.id = orders.customer_id;

-- ✅ Правильно
SELECT c.id, o.id FROM customers c JOIN orders o ON c.id = o.customer_id;
```

### 5. Забытый алиас в самосоединении

```sql
-- ❌ Ошибка: Not unique table/alias
SELECT * FROM employees JOIN employees ON ...;

-- ✅ Правильно
SELECT e.name, m.name FROM employees e JOIN employees m ON e.manager_id = m.id;
```

---

## 🔹 8. Шпаргалка

| Тип алиаса | Синтаксис | `AS` обязателен? | Где работает |
|------------|-----------|-------------------|--------------|
| **Табличный** | `FROM customers c` | Нет | Везде после `FROM` / `JOIN` |
| **Столбцовый** | `SUM(x) AS total` | Да (практически) | `SELECT`, `ORDER BY`, `GROUP BY` (MySQL), `HAVING` (MySQL) |
| **Производная таблица** | `(SELECT ...) AS t` | Да | — |

---

## 🔹 9. Полный пример «до и после»

### Без алиасов

```sql
SELECT customers.name, COUNT(orders.id) AS order_count, SUM(orders.amount) AS total_amount
FROM customers
JOIN orders ON customers.id = orders.customer_id
GROUP BY customers.id, customers.name
ORDER BY total_amount DESC;
```

### С алиасами

```sql
SELECT c.name, COUNT(o.id) AS order_count, SUM(o.amount) AS total_amount
FROM customers c
JOIN orders o ON c.id = o.customer_id
GROUP BY c.id, c.name
ORDER BY total_amount DESC;
```

Разница очевидна: второй вариант короче и легче читается.

---

## 🔹 10. Ведение и экспорт лога действий пользователя

Все команды, которые вы выполняли, записываются в файл `/var/lib/mysql/general.log` внутри контейнера.

### 10.1. Проверить, что лог пишется

Выйдите из клиента MySQL (если ещё не вышли):

```sql
\q
```

Затем на хосте:

```shell
docker exec mysql_alias ls -la /var/lib/mysql/general.log
```

Файл должен иметь размер > 0 и принадлежать `mysql`.

### 10.2. Посмотреть последние строки

```shell
docker exec mysql_alias tail -n 30 /var/lib/mysql/general.log
```

### 10.3. Отфильтровать только свои действия

```shell
docker exec mysql_alias cat /var/lib/mysql/general.log \
  | grep -E "Query[[:space:]]+(CREATE|INSERT|SELECT|UPDATE|DELETE|ALTER|DROP|RENAME|DESCRIBE|EXPLAIN|SHOW DATABASES|SHOW TABLES|SHOW FULL TABLES|SHOW CREATE|SHOW VARIABLES LIKE)" \
  | grep -v -E "INSERT INTO help_|INSERT INTO time_zone|INSERT INTO mysql\.|SELECT \* FROM mysql\.general_log" \
  > my_actions.log
```

Проверить:

```shell
cat my_actions.log
```

В файле останутся только ваши осмысленные SQL-команды.

### 10.4. Забрать лог на хост

```shell
docker cp mysql_alias:/var/lib/mysql/general.log ./general.log
```

Файл создаётся от вашего пользователя.

### 10.5. Очистить лог

```shell
docker exec -u mysql mysql_alias sh -c ': > /var/lib/mysql/general.log'
```

---

## 🔹 11. Создание дампа базы

Сделайте дамп:

```shell
docker exec -e MYSQL_PWD=123 mysql_alias mysqldump -uroot alias_db > alias_dump.sql
```

Или с дополнительными опциями для чистого дампа:

```shell
docker exec -e MYSQL_PWD=123 mysql_alias mysqldump -uroot \
  --set-gtid-purged=OFF \
  --single-transaction \
  alias_db > alias_dump_clean.sql
```

Посмотрите содержимое:

```shell
cat alias_dump.sql
```

Дамп включает таблицы `customers`, `orders` и `employees` с данными. При необходимости его можно использовать для восстановления базы.

---

**Результат оформить в виде отдельного `README.md` со скриншотами результатов ваших действий, дампом и логом (лог-файл должен содержать только ваши действия) в этой же папке и прислать ссылку преподавателю.**

---

## 📌 Итог

- **Алиасы таблиц** делают код короче и разрешают неоднозначности. Обязательны при самосоединении и для производных таблиц.
- **Алиасы столбцов** дают понятные имена результатам и позволяют ссылаться на них в `ORDER BY`. В `WHERE` недоступны.
- После объявления алиаса старое имя таблицы в запросе **не используется**.
- Для производной таблицы в `FROM` алиас **обязателен**.
- Лог действий удобно фильтровать через `grep` — это не требует SQL-запросов и работает на хосте.
- Дамп создаётся через `mysqldump` и сохраняется на хосте.

ссылка на dump:[dump](/alias_dump_clean.sql)

ссылка на loggg:[loggg](/my_actions.log)

ссылка на generalloggg: [generalloggg](/general.log)

сриншоты ам ам ам :

![miao](./mmiaoo/1.png)

![miao](./mmiaoo/2.png)

![miao](./mmiaoo/3.png)

![miao](./mmiaoo/4.png)

![miao](./mmiaoo/5.png)

![miao](./mmiaoo/6.png)

![miao](./mmiaoo/7.png)

![miao](./mmiaoo/8.png)

![miao](./mmiaoo/9.png)

![miao](./mmiaoo/10.png)


 ![стул](./mmiaoo/Red-Gaming-Chair-Transparent-Image.png)стул  