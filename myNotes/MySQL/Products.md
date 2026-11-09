# Основные SQL-операции на примере двух таблиц «products 1» и «products 2»

Все команды и запросы можно выполнить в любом клиенте **MySQL 8.0.31+** (в Docker-контейнере). Для MySQL 8.0.31+ доступны операторы `EXCEPT` и `INTERSECT`; для более старых версий даны альтернативы.

---

[Задание выполняется по аналогии с БД **sql_practice**](/content/Courses/Basics_database_design/content/bd/MySQL.md)

## 🔹 Шаг 1. Создание базы данных

Получить список текущих контейнеров
```shell
docker ps -a
```
Остановить контейнер
```shell
docker stop имя_контейнера
```
Удаление всех остановленных контейнеров
```shell
docker container prune
```
Выполните очистку томов в Docker от предыдущих проектов:
```shell
docker volume prune -a
```

- Создайте отдельный каталог `products-mysql` (`mkdir products-mysql`) и перейдите в него (`cd products-mysql`).
- Создайте в каталоге `products-mysql` файл `my.cnf` (для корректного отображения кириллицы) с содержимым:
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
docker run --name products-mysql \
  -e MYSQL_ROOT_PASSWORD=123 \
  -e LANG=C.UTF-8 \
  -v mysql_data:/var/lib/mysql \
  -v $(pwd)/my.cnf:/etc/mysql/conf.d/my.cnf \
  -d mysql:latest
```
Чтобы убедиться, что контейнер успешно запущен, выполните:
```bash
docker ps
```
Войти в контейнер с БД
```bash
docker exec -it products-mysql mysql --default-character-set=utf8mb4 -uroot -p
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
Проверить результат
```sql
SHOW DATABASES;
SHOW TABLES;
```

![amam](./Products/1.png)

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

![amam](./Products/2.png)

---

## 🔹 Шаг 4. Основные операции

### 1. Выборка (SELECT) — фильтрация строк

**Задача:** показать товары из `products1` дороже 150.
```sql
SELECT * FROM products1 WHERE price > 150;
```
![amam](./Products/3.png)

---

### 2. Проекция (PROJECTION) — выбор столбцов

**Задача:** вывести только названия товаров из `products1`.

```sql
SELECT name FROM products1;
```
![amam](./Products/4.png)

---

### 3. Объединение (UNION)

**Задача:** получить единый список названий товаров из обеих таблиц (без дубликатов).
```sql
SELECT name FROM products1
UNION
SELECT name FROM products2;
```
![amam](./Products/5.png)

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
![amam](./Products/6.png)


---

### 5. Пересечение (INTERSECT)

**Задача:** найти товары, которые есть и в `products1`, и в `products2` (с одинаковой ценой).

**MySQL 8.0.31+:**
```sql
SELECT name, price FROM products1
INTERSECT
SELECT name, price FROM products2;
```
![amam](./Products/7.png)

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
![amam](./Products/8.png)

---

### 7. Соединение (JOIN)

**Задача:** соединить таблицы по названию товара и показать цены из обеих таблиц.
```sql
SELECT t1.name, t1.price AS price1, t2.price AS price2
FROM products1 t1
JOIN products2 t2 ON t1.name = t2.name;
```
**Результат:**

![amam](./Products/9.png)

`JOIN` (INNER JOIN) возвращает только совпадающие строки.

Если нужны все товары из первой таблицы, даже без пары во второй:
```sql
SELECT t1.name, t1.price AS price1, t2.price AS price2
FROM products1 t1
LEFT JOIN products2 t2 ON t1.name = t2.name;
```
**Результат:**

![amam](./Products/10.png)

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
docker exec products-mysql mysqldump -uroot -p123 shop > dump.sql
```
или
```shell
docker exec -e MYSQL_PWD=123 products-mysql mysqldump -uroot shop > dump.sql
```
после чего в папке `products-mysql` появится текстовый файл `dump.sql`, содержимое которого можно увидеть командой
```shell
cat dump.sql
```
`.sql` файл является текстовым представлением вашей БД (текстовый SQL-скрипт). Его можно хранить как резервную копия вашей БД, из которой потом её можно восстановить

## 🔹 Шаг 6. Уборка

Снова войтив в контейнер с БД
```shell
docker exec -it products-mysql mysql --default-character-set=utf8mb4 -uroot -p
```
Проверить состояние и получить таблицы указанной БД
```sql
SHOW DATABASES;
USE shop;
SHOW TABLES;
```
Удалить указанную БД
```sql
DROP DATABASE shop;
```
Проверить результат
```sql
SHOW DATABASES;
```
Выйти из контейнера
```shell
\q
```

## 🔹 Шаг 7. Восстановление БД из дампа

- Проверьте, что контейнер запущен
- Проверьте, что дамп на месте и не пуст

зайти в контейнер
```shell
docker exec -it products-mysql mysql --default-character-set=utf8mb4 -uroot -p
```
Проверить результат
```sql
SHOW DATABASES;
```
выполните создание пустой БД с именем `shop`
```sql
CREATE DATABASE shop
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
```
Проверить результат
```sql
SHOW DATABASES;
```
Выйти из контейнера:
```shell
\q
```
Команда импорта выполняется не внутри mysql, а в обычном терминале хоста (с игнорированием ошибок импорта):
```shell
docker exec -i products-mysql mysql -uroot -p123 --force shop < dump.sql
```
Чтобы проверить результат, нужно снова зайти в контейнер с БД
```shell
docker exec -it products-mysql mysql --default-character-set=utf8mb4 -uroot -p
```
И проверить содержимое восстановленной БД
```sql
SHOW DATABASES;
USE shop;
SHOW TABLES;
SELECT * FROM products1;
SELECT * FROM products2;
```

## 🔹 Шаг 7. Опубликовать БД в своём GitHub

- Закоммитить и запушить дамп БД этого задания
- Прислать ссылку преподавателю

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

ссылка на dump : [dump](./dump.sql)