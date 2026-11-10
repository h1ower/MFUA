# Нормализация данных. Практическое руководство (с ведением лога)

**Задачи:**
1. Создать базу `shop_norm` и «плохую» таблицу `orders_bad`.
2. Продемонстрировать три аномалии (обновления, удаления, вставки).
3. Привести данные к **третьей нормальной форме (3NF)** — разбить на 4 таблицы.
4. Перенести данные из «плохой» таблицы в нормализованные.
5. Проверить, что данные не потерялись и аномалии исчезли.
6. Сделать дамп базы до и после нормализации.
7. **Научиться вести лог действий пользователя и экспортировать его.**

---

## 🔹 0. Подготовка `my.cnf`

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

> ⚠️ Если файла `my.cnf` не будет, Docker при монтировании создаст **директорию** с таким именем, и MySQL не запустится. Убедитесь, что это именно файл.

**Что делают настройки логирования:**

| Параметр | Зачем |
|----------|-------|
| `general_log = 1` | Включает общий лог |
| `general_log_file = /var/lib/mysql/general.log` | Путь к файлу лога внутри контейнера |
| `log_output = FILE` | Лог пишется в файл, а не в таблицу |

---

## 🔹 1. Запуск контейнера MySQL

Git-Bash:
```bash
docker run --name shop_norm \
  -e MYSQL_ROOT_PASSWORD=123 \
  -e LANG=C.UTF-8 \
  -e MYSQL_INITDB_SKIP_TZINFO=1 \
  -v mysql_data:/var/lib/mysql \
  -v $(pwd)/my.cnf:/etc/mysql/conf.d/my.cnf \
  -d mysql:8.0
```
Убедитесь, что контейнер запущен:
```bash
docker ps
```

### 🧹 Очистите лог перед началом работы

При первом запуске MySQL автоматически загружает справку (`help_topic`) и другие системные данные. Если лог уже включён, всё это попадёт в него. Чтобы начать с чистого листа:

```shell
docker exec shop_norm sh -c ': > /var/lib/mysql/general.log'
```
Файл обнулится. Теперь в лог попадут **только ваши действия**.

### Подключение к MySQL

```shell
docker exec -it shop_norm mysql --default-character-set=utf8mb4 -uroot -p
```

Введите пароль `123`. Вы увидите приглашение `mysql>`.

---

## 🔹 2. Создание БД и «плохой» таблицы `orders_bad`

### 2.1. Создание БД

```sql
CREATE DATABASE shop_norm
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE shop_norm;
```
Проверить:
```sql
SHOW DATABASES;
```

### 2.2. Создание «плохой» таблицы

```sql
CREATE TABLE orders_bad (
    order_id      INT AUTO_INCREMENT PRIMARY KEY,
    customer_name VARCHAR(100),
    customer_city VARCHAR(100),
    product_name  VARCHAR(100),
    product_price INT,
    quantity      INT,
    order_date    DATE
);
```

### 2.3. Наполнение данными

```sql
INSERT INTO orders_bad (customer_name, customer_city, product_name, product_price, quantity, order_date) VALUES
  ('Иван',  'Москва',          'Яблоки',   120, 2, '2026-10-01'),
  ('Иван',  'Москва',          'Лимоны',   200, 1, '2026-10-01'),
  ('Мария', 'Казань',          'Яблоки',   120, 3, '2026-10-02'),
  ('Мария', 'Казань',          'Хурма',    350, 1, '2026-10-03'),
  ('Пётр',  'Санкт-Петербург', 'Каштаны',  200, 2, '2026-10-04');
```
Проверить:
```sql
SHOW TABLES;
SELECT * FROM orders_bad;
```
**Сколько потратил Иван?**
```sql
SELECT SUM(product_price * quantity) AS total
FROM orders_bad
WHERE customer_name = 'Иван';
```
Работает, но данные дублируются, и любое изменение — риск аномалии.

---

## 🔹 3. Демонстрация аномалий «плохой» таблицы

### 3.1. Аномалия обновления

Обновим город Ивана **только в одной строке**:
```sql
UPDATE orders_bad
SET customer_city = 'Сочи'
WHERE order_id = 1;
```
Проверим:
```sql
SELECT * FROM orders_bad WHERE customer_name = 'Иван';
```
**Результат:** у Ивана теперь два разных города — «Сочи» и «Москва».

**Вывод:** один и тот же факт (место жительства) продублирован. При изменении легко забыть обновить все строки. В нормализованной базе город хранился бы в одной строке таблицы `customers`.

---

### 3.2. Аномалия удаления

Удалим **один** заказ Марии (последний по дате):
```sql
DELETE FROM orders_bad WHERE order_id = 4;
```
Проверим:
```sql
SELECT * FROM orders_bad WHERE customer_name = 'Мария';
```
**Результат:** информация о Марии пока осталась — у неё есть ещё заказ `order_id = 3`.

> ⚠️ Если удалить и второй заказ, Мария полностью исчезнет из базы. Мы **не будем** этого делать, чтобы сохранить данные для нормализации. Но вы можете убедиться в этом самостоятельно, а затем вернуть данные, выполнив `INSERT` заново.

**Вывод:** при удалении всех заказов клиент исчезает из базы. В нормализованной схеме клиент хранится отдельно и не удаляется вместе с заказами.

---

### 3.3. Аномалия вставки

Попробуем добавить клиента **без заказа**:
```sql
INSERT INTO orders_bad (customer_name, customer_city)
VALUES ('Новый клиент', 'Тверь');
```
Проверим:
```sql
SELECT * FROM orders_bad WHERE customer_name = 'Новый клиент';
```
**Результат:** строка есть, но все поля, относящиеся к заказу, — `NULL`.

**Вывод:** нельзя сохранить клиента, не создавая фиктивный заказ. Таблица не позволяет хранить сущность «клиент» отдельно от сущности «заказ».

**После демонстрации удалим эту тестовую строку**, чтобы она не мешала переносу данных (в ней `NULL` в полях заказа, а в нормализованных таблицах эти поля обязательны):
```sql
DELETE FROM orders_bad WHERE customer_name = 'Новый клиент';
```

---

### 3.4. Итог по аномалиям

| Аномалия | Что делает запрос | Что показывает |
|----------|-------------------|----------------|
| **Обновления** | Меняет город только в одной строке | Тот же клиент имеет разные города в разных заказах |
| **Удаления** | Удаляет один заказ Марии | Информация о клиенте сохраняется, пока есть хотя бы один заказ. При удалении всех заказов клиент исчезает |
| **Вставки** | Пытается добавить клиента без заказа | Появляется строка с `NULL` в полях заказа |

---

## 🔹 4. Дамп «плохой» базы (до нормализации)

Выйдите из клиента MySQL:
```sql
\q
```
Сделайте дамп:
```shell
docker exec -e MYSQL_PWD=123 shop_norm mysqldump -uroot shop_norm > dump_bad.sql
```
Посмотрите содержимое:
```shell
cat dump_bad.sql
```
`.sql`-файл — текстовое представление вашей БД. Его можно хранить как резервную копию и использовать для восстановления.

---

## 🔹 5. Создание нормализованной схемы (3NF)

Вернитесь в клиент MySQL:
```shell
docker exec -it shop_norm mysql --default-character-set=utf8mb4 -uroot -p
```
Выберите базу:
```sql
USE shop_norm;
```

> ⚠️ **Важно:** таблицы создаются **пустыми**. Данные будут перенесены из `orders_bad` в шаге 6. Не заполняйте их вручную — иначе при переносе возникнут дубликаты и конфликты ключей.
>
> Если вы уже выполняли это руководство раньше и таблицы 3NF уже существуют, удалите их перед созданием:
> ```sql
> DROP TABLE IF EXISTS order_items_3nf;
> DROP TABLE IF EXISTS orders_3nf;
> DROP TABLE IF EXISTS customers_3nf;
> DROP TABLE IF EXISTS products_3nf;
> ```

### 5.1. Четыре таблицы в 3NF

```sql
-- Клиенты
CREATE TABLE customers_3nf (
    customer_id   INT AUTO_INCREMENT PRIMARY KEY,
    customer_name VARCHAR(100) NOT NULL,
    customer_city VARCHAR(100) NOT NULL
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Товары
CREATE TABLE products_3nf (
    product_id    INT AUTO_INCREMENT PRIMARY KEY,
    product_name  VARCHAR(100) NOT NULL,
    product_price INT NOT NULL
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Заказы (шапка)
CREATE TABLE orders_3nf (
    order_id    INT AUTO_INCREMENT PRIMARY KEY,
    customer_id INT NOT NULL,
    order_date  DATE NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers_3nf(customer_id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Позиции заказа (строки)
CREATE TABLE order_items_3nf (
    order_id   INT NOT NULL,
    product_id INT NOT NULL,
    quantity   INT NOT NULL,
    PRIMARY KEY (order_id, product_id),
    FOREIGN KEY (order_id)   REFERENCES orders_3nf(order_id),
    FOREIGN KEY (product_id) REFERENCES products_3nf(product_id)
) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
```
Проверить структуру:
```sql
SHOW TABLES;
DESCRIBE customers_3nf;
DESCRIBE products_3nf;
DESCRIBE orders_3nf;
DESCRIBE order_items_3nf;
```

### 5.2. Что мы получили

| Таблица | Что хранит | Дублирование |
|---------|-----------|--------------|
| `customers_3nf` | Клиенты (имя, город) | ❌ Нет |
| `products_3nf` | Товары (название, цена) | ❌ Нет |
| `orders_3nf` | Заказы (кто, когда) | ❌ Нет |
| `order_items_3nf` | Позиции (что, сколько) | ❌ Нет |

**Что это даёт:**
- Иван хранится **один раз**. Переезд → одно `UPDATE`.
- Цена яблок хранится **один раз**. Изменение → одно `UPDATE`.
- Можно добавить клиента без заказа. Можно добавить товар без продаж.
- Удаление заказа не удаляет клиента и товар.

---

## 🔹 6. Перенос данных из `orders_bad` в 3NF

> ⚠️ Если вы уже выполняли перенос раньше и в таблицах 3NF есть данные, очистите их перед повторным запуском:
> ```sql
> TRUNCATE TABLE order_items_3nf;
> TRUNCATE TABLE orders_3nf;
> TRUNCATE TABLE customers_3nf;
> TRUNCATE TABLE products_3nf;
> ```

### 6.1. Клиенты (уникальные пары «имя + город»)

```sql
INSERT INTO customers_3nf (customer_name, customer_city)
SELECT DISTINCT customer_name, customer_city
FROM orders_bad;
```

### 6.2. Товары (уникальные пары «название + цена»)

```sql
INSERT INTO products_3nf (product_name, product_price)
SELECT DISTINCT product_name, product_price
FROM orders_bad;
```

### 6.3. Заказы (шапки)

```sql
INSERT INTO orders_3nf (order_id, customer_id, order_date)
SELECT o.order_id, c.customer_id, o.order_date
FROM orders_bad o
JOIN customers_3nf c
  ON c.customer_name = o.customer_name
 AND c.customer_city = o.customer_city;
```

### 6.4. Позиции заказов

```sql
INSERT INTO order_items_3nf (order_id, product_id, quantity)
SELECT o.order_id, p.product_id, o.quantity
FROM orders_bad o
JOIN products_3nf p
  ON p.product_name = o.product_name
 AND p.product_price = o.product_price;
```

### 6.5. Проверить, что данные вставились

```sql
SELECT * FROM customers_3nf;
SELECT * FROM products_3nf;
SELECT * FROM orders_3nf;
SELECT * FROM order_items_3nf;
```

---

## 🔹 7. Проверка корректности переноса

### 7.1. Общая сумма должна совпасть

```sql
-- Старая таблица
SELECT SUM(product_price * quantity) AS total_old
FROM orders_bad;

-- Новая схема
SELECT SUM(p.product_price * oi.quantity) AS total_new
FROM order_items_3nf oi
JOIN products_3nf p ON oi.product_id = p.product_id;
```

**Числа должны совпасть.** Если нет — где-то ошибка в переносе, и старая таблица ещё пригодится для отладки.

### 7.2. Количество заказов, клиентов, товаров

```sql
-- Заказы
SELECT COUNT(DISTINCT order_id) AS old_count FROM orders_bad;
SELECT COUNT(*) AS new_count FROM orders_3nf;

-- Клиенты
SELECT COUNT(*) AS old_count FROM
  (SELECT DISTINCT customer_name, customer_city FROM orders_bad) AS t;
SELECT COUNT(*) AS new_count FROM customers_3nf;

-- Товары
SELECT COUNT(*) AS old_count FROM
  (SELECT DISTINCT product_name, product_price FROM orders_bad) AS t;
SELECT COUNT(*) AS new_count FROM products_3nf;
```

Все пары чисел должны совпасть.

### 7.3. Сколько потратил Иван (новая схема)

```sql
SELECT SUM(p.product_price * oi.quantity) AS total
FROM customers_3nf c
JOIN orders_3nf o       ON c.customer_id = o.customer_id
JOIN order_items_3nf oi ON o.order_id = oi.order_id
JOIN products_3nf p     ON oi.product_id = p.product_id
WHERE c.customer_name = 'Иван';
```

Результат должен совпасть с тем, что был в «плохой» таблице (до изменений).

---

## 🔹 8. Повторение операций — аномалии исчезли

### 8.1. Обновление города Ивана

```sql
-- Старая таблица: два разных города
SELECT * FROM orders_bad WHERE customer_name = 'Иван';

-- Новая схема: одно обновление
UPDATE customers_3nf SET customer_city = 'Сочи' WHERE customer_name = 'Иван';
SELECT * FROM customers_3nf WHERE customer_name = 'Иван';
```

**Результат:** город Ивана изменён **в одном месте**. Все заказы автоматически «видят» новый город через `JOIN`.

### 8.2. Удаление заказов Марии

```sql
-- Удаляем все заказы Марии по её имени (через подзапрос)
DELETE FROM order_items_3nf
WHERE order_id IN (
    SELECT o.order_id
    FROM orders_3nf o
    JOIN customers_3nf c ON o.customer_id = c.customer_id
    WHERE c.customer_name = 'Мария'
);

DELETE FROM orders_3nf
WHERE customer_id IN (
    SELECT customer_id FROM customers_3nf WHERE customer_name = 'Мария'
);

-- Клиент остался!
SELECT * FROM customers_3nf WHERE customer_name = 'Мария';
```

**Результат:** Мария осталась в таблице `customers_3nf`, хотя её заказов больше нет.

### 8.3. Добавление клиента без заказа

```sql
INSERT INTO customers_3nf (customer_name, customer_city)
VALUES ('Новый клиент', 'Тверь');

SELECT * FROM customers_3nf WHERE customer_name = 'Новый клиент';
```

**Результат:** клиент добавлен, полей `NULL`, связанных с заказом, нет.

---

## 🔹 9. Удаление «плохой» таблицы

После проверок можно избавиться от старой таблицы.

**Вариант 1:** удалить совсем:

```sql
DROP TABLE orders_bad;
```

**Вариант 2 (безопаснее):** переименовать в архив (не обязательно!):

```sql
RENAME TABLE orders_bad TO orders_bad_backup;
```

`RENAME` безопаснее: таблица остаётся в базе, но под другим именем. Если через неделю выяснится, что что-то упустили, — данные под рукой.

Проверить:

```sql
SHOW TABLES;
```

---

## 🔹 10. Дамп нормализованной базы (после нормализации)

Выйдите из клиента MySQL:

```sql
\q
```

Сделайте дамп:

```shell
docker exec -e MYSQL_PWD=123 shop_norm mysqldump -uroot shop_norm > norm_dump.sql
```

Посмотрите содержимое:

```shell
cat norm_dump.sql
```

Сравните с `dump_bad.sql` — во втором дампе должны быть четыре таблицы вместо одной, и не должно быть дублирования клиентов и товаров.

---

## 🔹 11. Ведение и экспорт лога действий пользователя

Все команды, которые вы выполняли, записываются в файл `/var/lib/mysql/general.log` внутри контейнера (благодаря `general_log = 1` и `log_output = FILE` в `my.cnf`).

### 11.1. Проверить, что лог пишется

```shell
docker exec shop_norm ls -la /var/lib/mysql/general.log
```
Команда должна вернуть примерно это:
```shell
-rw-r----- 1 mysql mysql 18934 Nov  9 08:22 /var/lib/mysql/general.log
```
Заглянуть в лог:
```shell
docker exec shop_norm cat /var/lib/mysql/general.log
```

### 11.2. Забрать лог на хост

```shell
docker cp shop_norm:/var/lib/mysql/general.log ./general.log
```

Файл `general.log` появится в текущей папке. Он создаётся **от вашего пользователя** — никаких `chown` не нужно.

### 11.3. Отфильтровать только свои действия

В логе много служебных записей: `Connect`, `Quit`, `SET NAMES`, `SHOW VARIABLES`, `INSERT INTO help_topic` и т.п. Отфильтровать их можно одной командой **на хосте**:

```shell
docker exec shop_norm cat /var/lib/mysql/general.log \
  | grep -E "Query[[:space:]]+(CREATE|INSERT|SELECT|UPDATE|DELETE|ALTER|DROP|RENAME|DESCRIBE|EXPLAIN|SHOW DATABASES|SHOW TABLES|SHOW FULL TABLES|SHOW CREATE|SHOW VARIABLES LIKE|SET GLOBAL general_log|SET GLOBAL log_output)" \
  | grep -v -E "INSERT INTO help_|INSERT INTO time_zone|INSERT INTO mysql\.|SELECT \* FROM mysql\.general_log" \
  > my_actions.log
```

Что делает эта команда:

| Шаг | Что оставляет / исключает |
|-----|--------------------------|
| `grep -E "Query ... (CREATE\|INSERT\|...)"` | Только `Query` с осмысленными командами |
| `grep -v -E "INSERT INTO help_\|..."` | Убирает загрузку справки, часовых поясов и системных таблиц |
| `> my_actions.log` | Пишет результат на хост от вашего пользователя |

Проверить результат:

```shell
cat my_actions.log
```
В файле `my_actions.log` останутся **только ваши осмысленные SQL-команды** — без служебного шума.

### 11.4. Что примерно попадёт в `my_actions.log`

Для этого руководства — примерно так:

```sql
CREATE DATABASE shop_norm ...
USE shop_norm
CREATE TABLE orders_bad ...
INSERT INTO orders_bad ... VALUES ...
SELECT * FROM orders_bad
SELECT SUM(product_price * quantity) AS total FROM orders_bad WHERE ...
UPDATE orders_bad SET customer_city = 'Сочи' WHERE order_id = 1
DELETE FROM orders_bad WHERE order_id = 4
INSERT INTO orders_bad (customer_name, customer_city) VALUES ...
DELETE FROM orders_bad WHERE customer_name = 'Новый клиент'
CREATE TABLE customers_3nf ...
CREATE TABLE products_3nf ...
CREATE TABLE orders_3nf ...
CREATE TABLE order_items_3nf ...
INSERT INTO customers_3nf ... SELECT DISTINCT ...
INSERT INTO products_3nf ... SELECT DISTINCT ...
INSERT INTO orders_3nf ... SELECT ...
INSERT INTO order_items_3nf ... SELECT ...
SELECT SUM(...) AS total_old FROM orders_bad
SELECT SUM(...) AS total_new FROM order_items_3nf ...
...
```
Никаких `SET NAMES`, `SELECT @@version_comment`, `Connect`, `Quit`, `INSERT INTO help_topic` и `time_zone`.

### 11.5. Очистить лог (если нужно начать заново)

```shell
docker exec shop_norm sh -c ': > /var/lib/mysql/general.log'
```
Файл обнулится, но останется на месте. MySQL продолжит в него писать.

### 11.6. Рекомендация для чистого лога

Если хотите, чтобы в логе были **только** действия по нормализации:

1. **Перед началом работы** (сразу после запуска контейнера):
   ```shell
   docker exec shop_norm sh -c ': > /var/lib/mysql/general.log'
   ```
2. Выполните все SQL-команды.
3. **В конце** — экспорт с фильтром (раздел 11.3).

Тогда в `my_actions.log` попадут только ваши команды — без накопленного шума с инициализации.

---

## 📌 Итог

**Главная мысль:** нормализация — это не «максимальное количество таблиц», а **устранение аномалий**. Каждый факт должен храниться в одном месте.

| Что демонстрирует руководство | Результат |
|-------------------------------|-----------|
| Аномалия обновления | Два разных города у одного клиента → в 3NF одно обновление |
| Аномалия удаления | Удаление всех заказов «убивает» клиента → в 3NF клиент остаётся |
| Аномалия вставки | Клиент без заказа невозможен → в 3NF возможен |
| Дублирование данных | Имя клиента повторяется в каждой строке → в 3NF хранится один раз |
| Цена товара | Повторяется в каждой строке → в 3NF хранится один раз |
| Лог действий | Файл `general.log` с фильтрацией → только осмысленные команды |

**Когда использовать нормализацию:**
- Всегда — как отправную точку.
- Денормализацию — только **после** 3NF и только при доказанной необходимости (например, для ускорения отчётов).

**Что важно запомнить:**
- 3NF — это «рабочий стандарт», достаточный для большинства задач.
- Перенос данных нужно делать **после** создания структуры, а не вручную.
- Проверка сумм и количеств — обязательный шаг: она доказывает, что данные не потерялись.
- Лог действий удобно фильтровать через `grep` — это не требует SQL-запросов и работает на хосте.

---

ссылка на плохой dump: [baddump](/dump_bad.sql)
ссылка на новый dump: [newdump](/norm_dump.sql)
ссылка на my_actions.log: [loggg](/my_actions.log)

скриншоты ам ам ам:

![miao](./mioamiao/1.png)

![miao](./mioamiao/2.png)

![miao](./mioamiao/3.png)

![miao](./mioamiao/4.png)

![miao](./mioamiao/5.png)

![miao](./mioamiao/6.png)

![miao](./mioamiao/7.png)

![miao](./mioamiao/8.png)

![miao](./mioamiao/9.png)

![miao](./mioamiao/10.png)
