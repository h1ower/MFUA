# Основные SQL-операции на примере двух таблиц «products 1» и «products 2»

Все команды можно выполнить в любом клиенте **MySQL** (в том числе в вашем Docker-контейнере `my-mysql`). Для MySQL 8.0.31+ доступны операторы `EXCEPT` и `INTERSECT`; для более старых версий даны альтернативы.

---

[Можно использовать имеющийся контейнер с MySQL](/content/Courses/Basics_database_design/content/bd/MySQL.md)

## 🔹 Шаг 1. Создание базы данных

Войти в контейнер с БД
```bash
docker exec -it my-mysql mysql --default-character-set=utf8mb4 -uroot -p
```
Создать новую БД
```sql
CREATE DATABASE shop
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;

USE shop;
```
Проверить результат
```sql
SHOW DATABASES;
SHOW TABLES;
```

---

## 🔹 Шаг 2. Создание таблиц

```sql
CREATE TABLE products1 (
    name  VARCHAR(100) NOT NULL,
    price INT NOT NULL
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

CREATE TABLE products2 (
    name  VARCHAR(100) NOT NULL,
    price INT NOT NULL
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```

---

## 🔹 Шаг 3. Вставка данных

```sql
INSERT INTO products1 (name, price) VALUES
  ('Дыни', 800),
  ('Клубника', 150),
  ('Яблоки', 120),
  ('Лимоны', 200);

INSERT INTO products2 (name, price) VALUES
  ('Дыни', 800),
  ('Клубника', 150),
  ('Каштаны', 200),
  ('Хурма', 350);
```

Проверим:

```sql
SELECT * FROM products1;
SELECT * FROM products2;
```

**products1:**

| name | price |
|------|-------|
| Дыни | 800 |
| Клубника | 150 |
| Яблоки | 120 |
| Лимоны | 200 |

**products2:**

| name | price |
|------|-------|
| Дыни | 800 |
| Клубника | 150 |
| Каштаны | 200 |
| Хурма | 350 |

---

## 🔹 Шаг 4. Основные операции

### 1. Выборка (SELECT) — фильтрация строк

**Задача:** показать товары из `products1` дороже 150.

```sql
SELECT * FROM products1 WHERE price > 150;
```

**Результат:**

| name | price |
|------|-------|
| Дыни | 800 |
| Лимоны | 200 |

---

### 2. Проекция (PROJECTION) — выбор столбцов

**Задача:** вывести только названия товаров из `products1`.

```sql
SELECT name FROM products1;
```

**Результат:**

| name |
|------|
| Дыни |
| Клубника |
| Яблоки |
| Лимоны |

---

### 3. Объединение (UNION)

**Задача:** получить единый список названий товаров из обеих таблиц (без дубликатов).

```sql
SELECT name FROM products1
UNION
SELECT name FROM products2;
```

**Результат:**

| name |
|------|
| Дыни |
| Клубника |
| Яблоки |
| Лимоны |
| Каштаны |
| Хурма |

`UNION` удаляет дубликаты. Если нужны все строки, включая повторы, используйте `UNION ALL`.

---

### 4. Разность (EXCEPT / MINUS)

**Задача:** найти товары, которые есть в `products1`, но отсутствуют в `products2`.

**MySQL 8.0.31+:**

```sql
SELECT name, price FROM products1
EXCEPT
SELECT name, price FROM products2;
```

**Результат:**

| name | price |
|------|-------|
| Яблоки | 120 |
| Лимоны | 200 |

**Для старых версий MySQL (не обязательно это выполнять):**

```sql
SELECT name, price FROM products1
WHERE (name, price) NOT IN (SELECT name, price FROM products2);
```

---

### 5. Пересечение (INTERSECT)

**Задача:** найти товары, которые есть и в `products1`, и в `products2` (с одинаковой ценой).

**MySQL 8.0.31+:**

```sql
SELECT name, price FROM products1
INTERSECT
SELECT name, price FROM products2;
```

**Результат:**

| name | price |
|------|-------|
| Дыни | 800 |
| Клубника | 150 |

**Для старых версий MySQL:**

```sql
SELECT t1.name, t1.price
FROM products1 t1
JOIN products2 t2 ON t1.name = t2.name AND t1.price = t2.price;
```

---

### 6. Декартово произведение (CARTESIAN PRODUCT)

**Задача:** получить все возможные пары «товар из первой таблицы — товар из второй».

```sql
SELECT t1.name AS name1, t1.price AS price1,
       t2.name AS name2, t2.price AS price2
FROM products1 t1
CROSS JOIN products2 t2;
```

**Результат:** 4 × 4 = **16 строк**. Фрагмент:

| name1 | price1 | name2 | price2 |
|-------|--------|-------|--------|
| Дыни | 800 | Дыни | 800 |
| Дыни | 800 | Клубника | 150 |
| Дыни | 800 | Каштаны | 200 |
| Дыни | 800 | Хурма | 350 |
| Клубника | 150 | Дыни | 800 |
| ... | ... | ... | ... |

---

### 7. Соединение (JOIN)

**Задача:** соединить таблицы по названию товара и показать цены из обеих таблиц.

```sql
SELECT t1.name, t1.price AS price1, t2.price AS price2
FROM products1 t1
JOIN products2 t2 ON t1.name = t2.name;
```

**Результат:**

| name | price1 | price2 |
|------|--------|--------|
| Дыни | 800 | 800 |
| Клубника | 150 | 150 |

`JOIN` (INNER JOIN) возвращает только совпадающие строки.

Если нужны все товары из первой таблицы, даже без пары во второй:

```sql
SELECT t1.name, t1.price AS price1, t2.price AS price2
FROM products1 t1
LEFT JOIN products2 t2 ON t1.name = t2.name;
```

**Результат:**

| name | price1 | price2 |
|------|--------|--------|
| Дыни | 800 | 800 |
| Клубника | 150 | 150 |
| Яблоки | 120 | NULL |
| Лимоны | 200 | NULL |

---

### 8. Деление (DIVISION) — краткое пояснение

Операция деления в реляционной алгебре отвечает на вопрос: «найти A, которые связаны со **всеми** B». Для двух таблиц с простыми списками товаров деление не имеет смысла — нужна третья таблица связи (например, «поставщик — товар»). Поэтому в этом примере мы её не рассматриваем.

---

## 🔹 Шаг 5. Создание дампа

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
после чего в папке `my-mysql` появится текстовый файл `dump.sql`, содержимое которого можно увидеть командой
```shell
cat dump.sql
```
`.sql` файл является текстовым представлением вашей БД (текстовый SQL-скрипт). Его можно хранить как резервную копия вашей БД, из которой потом её можно восстановить

## 🔹 Шаг 6. Уборка

```sql
DROP DATABASE shop;
```

---

## 📌 Итог

| Операция | SQL | Что делает |
|----------|-----|------------|
| Выборка | `WHERE` | Фильтр строк |
| Проекция | `SELECT name` | Выбор столбцов |
| Объединение | `UNION` | Все уникальные строки из двух таблиц |
| Разность | `EXCEPT` / `NOT IN` | Строки первой таблицы, которых нет во второй |
| Пересечение | `INTERSECT` / `JOIN` | Общие строки |
| Декартово произведение | `CROSS JOIN` | Все комбинации строк |
| Соединение | `JOIN` | Совпадающие строки по ключу |

Этого достаточно, чтобы понять, как работают базовые операции над множествами в SQL. Экспериментируйте: меняйте данные, добавляйте строки, пробуйте разные условия — так вы быстро освоите материал.

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

> Если вы обнаружили ошибку в этом тексте — сообщите пожалуйста автору!