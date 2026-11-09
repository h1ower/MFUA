# Руководство по представлениям (VIEW) в MySQL

Представление — это **сохранённый SQL-запрос, который выглядит как таблица**. Вы обращаетесь к нему по имени, как к обычной таблице, но данных он не хранит — при каждом обращении запрос выполняется заново.

---

## 🔹 1. Зачем нужны представления

| Задача | Как помогает **VIEW** |
|--------|-------------------|
| Упростить сложные запросы | Пишете `SELECT * FROM my_view` вместо трёхэтажного `JOIN` |
| Скрыть структуру таблиц | Пользователь видит только нужные столбцы |
| Ограничить доступ | Даёте права на **VIEW**, а не на таблицу |
| Переиспользовать логику | Один раз определили — используете везде |
| Абстракция | При изменении таблиц приложение продолжает работать |

---

## 🔹 2. Подготовка (если ещё не сделано)

Используем базу `sql_practice` из предыдущих примеров. Проверьте, что она есть:
```sql
SHOW DATABASES;
USE sql_practice;
SHOW TABLES;
```

Должны быть таблицы `customers` и `orders`. Если их нет — [создайте](/content/Courses/Basics_database_design/content/bd/MySQL.md).

---

## 🔹 3. Простейшее представление

**Задача:** часто нужен список клиентов из Москвы.

Без VIEW:
```sql
SELECT * FROM customers WHERE city = 'Москва';
```
С VIEW:
```sql
CREATE VIEW moscow_customers AS
SELECT id, name, email
FROM customers
WHERE city = 'Москва';
```
Теперь обращайтесь к нему как к таблице:
```sql
SELECT * FROM moscow_customers;
```

**Результат:**

| id | name | email |
|----|------|-------|
| 1 | Иван Иванов | ivan@example.com |
| 3 | Мария Сидорова | maria@example.com |

**Ключевая мысль:** данные не скопированы. При каждом `SELECT * FROM moscow_customers` MySQL **заново выполняет** запрос `SELECT ... WHERE city = 'Москва'`. Если добавите нового клиента из Москвы в `customers` — он **сразу появится** в представлении.

---

## 🔹 4. VIEW с JOIN и агрегацией

**Задача:** сводка по клиентам — сколько заказов и на какую сумму.

```sql
CREATE VIEW customer_summary AS
SELECT c.id,
       c.name,
       c.city,
       COUNT(o.id)              AS order_count,
       COALESCE(SUM(o.amount), 0) AS total_amount
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY c.id, c.name, c.city;
```

Использование:

```sql
SELECT * FROM customer_summary ORDER BY total_amount DESC;
```

**Результат:**

| id | name | city | order_count | total_amount |
|----|------|------|-------------|--------------|
| 3 | Мария Сидорова | Москва | 2 | 5300.00 |
| 1 | Иван Иванов | Москва | 2 | 3800.50 |
| 4 | Алексей Смирнов | Казань | 1 | 950.00 |
| 2 | Пётр Петров | Санкт-Петербург | 1 | 800.00 |
| 5 | Ольга Кузнецова | Новосибирск | 0 | 0.00 |

Теперь вместо сложного `JOIN` с `GROUP BY` достаточно одной строки:

```sql
SELECT name, total_amount FROM customer_summary WHERE total_amount > 2000;
```

---

## 🔹 5. VIEW с фильтрацией внутри

Можно комбинировать **VIEW** с дополнительным `WHERE` снаружи:

```sql
SELECT * FROM customer_summary WHERE city = 'Москва';
```

MySQL «завернёт» ваш `WHERE` внутрь запроса представления. Это работает, но **не всегда эффективно** — см. раздел 9.

---

## 🔹 6. Просмотр существующих VIEW

```sql
SHOW FULL TABLES WHERE Table_type = 'VIEW';
```
Или в общем списке таблиц:
```sql
SHOW TABLES;
```
**MySQL** покажет **VIEW** рядом с обычными таблицами — визуально их не отличить.

Посмотреть **определение** (SQL-запрос, лежащий в основе):
```sql
SHOW CREATE VIEW customer_summary\G
```

Вы увидите что-то вроде:

```
*************************** 1. row ***************************
                View: customer_summary
         Create View: CREATE ALGORITHM=UNDEFINED DEFINER=`root`@`%`
                      SQL SECURITY DEFINER VIEW `customer_summary` AS
                      select ... from customers c left join orders o ...
        character_set_client: utf8mb4
        collation_connection: utf8mb4_unicode_ci
```

---

## 🔹 7. Изменение и удаление VIEW

### Изменить существующее представление

Получить таблицу для сравнения:
```sql
SELECT * FROM moscow_customers;
```
и выполнить запрос изменения
```sql
CREATE OR REPLACE VIEW moscow_customers AS
SELECT id, name, email, created_at
FROM customers
WHERE city = 'Москва';
```
`CREATE OR REPLACE` перезаписываеDROP VIEW IF EXISTS moscow_customers;т старое определение новым, не удаляя VIEW.

Получить результат:
```sql
SELECT * FROM moscow_customers;
```

### Удалить

```sql
DROP VIEW moscow_customers;
```
Если **VIEW** не существует — ошибка. Чтобы не падало:
```sql
DROP VIEW IF EXISTS moscow_customers;
```
Получить результат:
```sql
SHOW TABLES;
```

---

## 🔹 8. Обновляемые VIEW (UPDATE, INSERT, DELETE)

**Не все VIEW можно обновлять.** Представление обновляемо, если MySQL может однозначно сопоставить строку VIEW со строкой базовой таблицы.

### ✅ Обновляемое VIEW

```sql
CREATE VIEW active_customers AS
SELECT id, name, email, city
FROM customers
WHERE city IS NOT NULL;
```

Можно:

```sql
UPDATE active_customers SET city = 'Сочи' WHERE id = 2;
SELECT * FROM customers WHERE id = 2;  -- city действительно изменился
```

```sql
INSERT INTO active_customers (name, email, city)
VALUES ('Новый Клиент', 'new@example.com', 'Уфа');
```

```sql
DELETE FROM active_customers WHERE id = 6;
```

### ❌ Необновляемое VIEW

```sql
CREATE VIEW customer_summary AS
SELECT c.id, c.name, COUNT(o.id) AS order_count
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY c.id, c.name;
```
Попытка обновления:
```sql
UPDATE customer_summary SET name = 'X' WHERE id = 1;
```
**Ошибка:**
```
ERROR 1288 (HY000): The target table customer_summary of the UPDATE is not updatable
```

**Почему:** `COUNT(o.id)` — это агрегат, его нельзя «разложить обратно» на строки таблицы. MySQL не знает, какую строку `customers` менять.

**Правило:** VIEW с `GROUP BY`, `DISTINCT`, `UNION`, агрегатами, `JOIN` (часто) — **необновляемы**.

---

## 🔹 9. VIEW и производительность

**Важно понимать:** VIEW — это **не материализованное представление**. Он не хранит данные и не имеет индексов. При каждом обращении MySQL выполняет **весь запрос заново**.

### Что это значит на практике

```sql
SELECT * FROM customer_summary WHERE city = 'Москва';
```
MySQL **не** сначала считает всю сводку, а потом фильтрует. Он «вставляет» ваш `WHERE` внутрь запроса и пытается оптимизировать. Иногда получается хорошо, иногда — нет.
**Проверить план:**
```sql
EXPLAIN SELECT * FROM customer_summary WHERE city = 'Москва';
```
Если план плохой — можно:

1. Упростить **VIEW**.
2. Использовать прямые запросы.
3. В PostgreSQL — `MATERIALIZED VIEW`, который хранит данные и имеет индексы. **В MySQL такого нет.**

---

## 🔹 10. VIEW с проверкой опций (WITH CHECK OPTION)

По умолчанию через **VIEW** можно вставить строку, которая **не попадёт** в его фильтр:

```sql
CREATE VIEW moscow_customers AS
SELECT id, name, city FROM customers WHERE city = 'Москва';

INSERT INTO moscow_customers (name, city) VALUES ('Пётр', 'Казань');
-- Строка вставится в customers, но через VIEW её не будет видно!
```
Чтобы запретить такие вставки:
```sql
CREATE OR REPLACE VIEW moscow_customers AS
SELECT id, name, city FROM customers WHERE city = 'Москва'
WITH CHECK OPTION;
```
Теперь:
```sql
INSERT INTO moscow_customers (name, city) VALUES ('Пётр', 'Казань');
-- ERROR 1369 (HY000): CHECK OPTION failed 'sql_practice.moscow_customers'
```
**Правило:** `WITH CHECK OPTION` запрещает вставки/обновления, которые не соответствуют условию `WHERE` в VIEW.

---

## 🔹 11. Права доступа через VIEW

Частый сценарий: скрыть от пользователя столбец `email`.

```sql
CREATE VIEW public_customers AS
SELECT id, name, city FROM customers;  -- без email

-- Создать пользователя (пример)
CREATE USER 'analyst'@'%' IDENTIFIED BY 'pass';
GRANT SELECT ON sql_practice.public_customers TO 'analyst'@'%';
-- Доступ к самой таблице customers не даём
```
Теперь `analyst` видит `public_customers` без email, но не может обратиться к `customers` напрямую.

## 🔹 12. Создание дампа

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
после чего в папке `my-mysql` появится текстовый файл `dump.sql`, содержимое которого можно увидеть командой
```shell
cat dump.sql
```
`.sql` файл является текстовым представлением вашей БД (текстовый SQL-скрипт). Его можно хранить как резервную копия вашей БД, из которой потом её можно восстановить

По умолчанию **VIEW** включаются в дамп. Когда вы выполняете стандартную команду `mysqldump`, утилита по умолчанию включает в выходной файл не только таблицы, но и определения всех представлений

---

## 🔹 13. Шпаргалка по командам

| Действие | Команда |
|----------|---------|
| Создать | `CREATE VIEW name AS SELECT ...;` |
| Создать или заменить | `CREATE OR REPLACE VIEW name AS SELECT ...;` |
| Удалить | `DROP VIEW name;` |
| Удалить безопасно | `DROP VIEW IF EXISTS name;` |
| Показать все VIEW | `SHOW FULL TABLES WHERE Table_type = 'VIEW';` |
| Показать определение | `SHOW CREATE VIEW name\G` |
| Использовать | `SELECT * FROM name;` |
| Обновить через VIEW | `UPDATE name SET ... WHERE ...;` |
| Вставить через VIEW | `INSERT INTO name ... VALUES ...;` |
| Удалить через VIEW | `DELETE FROM name WHERE ...;` |

---

## 🔹 14. Типичные ошибки

| Ошибка | Причина | Решение |
|--------|---------|---------|
| `View 'x' already exists` | VIEW с таким именем уже есть | `DROP VIEW x;` или `CREATE OR REPLACE` |
| `The target table x of the UPDATE is not updatable` | VIEW содержит `GROUP BY` / агрегаты / `UNION` | Не обновлять через VIEW |
| `CHECK OPTION failed` | Вставка нарушает `WHERE` в VIEW | Не вставлять или убрать `WITH CHECK OPTION` |
| `Unknown table 'x'` | VIEW не существует или не выбрана база | `SHOW FULL TABLES WHERE Table_type = 'VIEW';` |
| VIEW работает медленно | Сложный запрос внутри | `EXPLAIN`, упростить VIEW |

---

## 🔹 15. Полный пример «с нуля»

```sql
USE sql_practice;

-- 1. Создать VIEW
CREATE OR REPLACE VIEW moscow_customers AS
SELECT id, name, email
FROM customers
WHERE city = 'Москва';

-- 2. Использовать
SELECT * FROM moscow_customers;

-- 3. Проверить, что данные «живые»
INSERT INTO customers (name, email, city)
VALUES ('Тест Тестов', 'test@example.com', 'Москва');

SELECT * FROM moscow_customers;  -- новый клиент уже виден

-- 4. Посмотреть определение
SHOW CREATE VIEW moscow_customers\G

-- 5. Удалить
DROP VIEW moscow_customers;

-- 6. Убедиться, что удалено
SHOW FULL TABLES WHERE Table_type = 'VIEW';

-- 7. Убрать тестового клиента
DELETE FROM customers WHERE email = 'test@example.com';
```

---

## 📌 Итог

| Что важно запомнить о VIEW |
|----------------------------|
| VIEW — это **сохранённый запрос**, а не таблица |
| Данные **не копируются**, запрос выполняется при каждом обращении |
| VIEW **автоматически** показывает изменения в базовых таблицах |
| VIEW может быть **обновляемым** или нет (зависит от запроса) |
| VIEW **не ускоряет** запросы — иногда замедляет |
| `WITH CHECK OPTION` защищает от «невидимых» вставок |
| VIEW — удобный инструмент **абстракции** и **контроля доступа** |

**Когда использовать VIEW:**
- Часто повторяющийся сложный запрос → сохранить как VIEW.
- Нужно скрыть часть столбцов от пользователя → VIEW + права.
- Хочется «стабилизировать» интерфейс для приложения → VIEW переживёт изменение таблиц.

**Когда не использовать:**
- Ради ускорения — VIEW не материализован.
- Для очень больших агрегатов с частыми запросами — лучше хранить результат в отдельной таблице и обновлять по расписанию.

---

> Если вы обнаружили ошибку в этом тексте — сообщите пожалуйста автору!