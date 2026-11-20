# Индексы в MySQL. Практическое руководство (с ведением лога)

> **Это задание выполнять строго в WSL!**

**Цель:** научиться создавать индексы, читать план выполнения запроса (`EXPLAIN`) и понимать, когда индекс работает, а когда — нет.

**План руководства:**

1. Посмотреть, какие индексы уже есть в таблице `orders` (`SHOW INDEX`).
2. Выполнить `EXPLAIN` для запроса без индекса — увидеть `full scan`.
3. Создать индекс `CREATE INDEX` и повторить `EXPLAIN`.
4. Сравнить `type` и `rows`.
5. Убедиться, что функция в `WHERE` ломает индекс (`YEAR(order_date)`), и переписать запрос.
6. Дополнительно: составной и покрывающий индексы.
7. Научиться вести и экспортировать лог действий пользователя.

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

> ⚠️ Если файла `my.cnf` не будет, Docker создаст **директорию** с таким именем, и MySQL не запустится. Убедитесь, что это именно файл.

---

## 🔹 1. Запуск контейнера MySQL

### 1.1. Удалите старый контейнер и volume (если есть)

```shell
# Останавливаем и удаляем только учебный контейнер (если он есть)
docker stop my-mysql 2>/dev/null
docker rm my-mysql 2>/dev/null
docker volume rm mysql_data 2>/dev/null
```

> ⚠️ **Не используйте `docker volume prune -a`** — эта команда удаляет **все** неиспользуемые volumes на хосте, а не только `mysql_data`.

### 1.2. Создайте новый контейнер

```bash
docker run --name my-mysql \
  -e MYSQL_ROOT_PASSWORD=123 \
  -e LANG=C.UTF-8 \
  -e MYSQL_INITDB_SKIP_TZINFO=1 \
  -v mysql_data:/var/lib/mysql \
  -v $(pwd)/my.cnf:/etc/mysql/conf.d/my.cnf \
  -d mysql:8.0
```

Разберём опции:

| Опция | Зачем |
|-------|-------|
| `--name my-mysql` | Понятное имя контейнера |
| `-e MYSQL_ROOT_PASSWORD=123` | Пароль пользователя `root` (в учебных целях — `123`) |
| `-e LANG=C.UTF-8` | UTF-8 локаль для корректной работы с кириллицей |
| `-e MYSQL_INITDB_SKIP_TZINFO=1` | Не загружать часовые пояса при инициализации — лог будет чище |
| `-v mysql_data:/var/lib/mysql` | Volume для данных — сохраняются между перезапусками |
| `-v $(pwd)/my.cnf:...` | Монтирует ваш `my.cnf` с настройками кодировки и логирования |
| `-d mysql:8.0` | LTS-версия MySQL, стабильная и предсказуемая |

Убедитесь, что контейнер запущен:

```bash
docker ps
```

### 1.3. Очистите лог перед началом работы

При первом запуске MySQL загружает системные данные (справку, часовые пояса), которые попадут в лог. Чтобы в `my_actions.log` были только **ваши** действия, очистите лог перед началом:

```shell
docker exec -u mysql my-mysql sh -c ': > /var/lib/mysql/general.log'
```

> Флаг `-u mysql` важен: файл должен принадлежать пользователю `mysql`, иначе MySQL не сможет в него писать.

### 1.4. Подключение к MySQL

```bash
docker exec -it my-mysql mysql --default-character-set=utf8mb4 -uroot -p
```
Введите пароль `123`. Вы увидите приглашение `mysql>`.

---

## 🔹 2. Создание базы `index_practice` и таблиц

```sql
CREATE DATABASE index_practice
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_unicode_ci;
USE index_practice;

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

Проверим:
```sql
SHOW TABLES;
SELECT * FROM customers;
SELECT * FROM orders;
```

---

## 🔹 3. Кратко: что такое индекс

Индекс — это **отдельная структура** (B-дерево), которая хранит отсортированные значения столбца и указатели на строки. Без индекса MySQL просматривает **все** строки (`full scan`). С индексом — прыгает сразу к нужным.

**Главное правило:** индекс ускоряет **чтение**, но замедляет **запись** (каждый `INSERT`/`UPDATE` обновляет все индексы). Не индексируйте «на всякий случай».

---

## 🔹 4. Эксперимент 1: какие индексы уже есть

```sql
SHOW INDEX FROM orders;
```

Вы увидите примерно такую картину:

| Table | Key_name | Column_name | Non_unique |
|-------|----------|-------------|------------|
| orders | PRIMARY | id | 0 |
| orders | customer_id | customer_id | 1 |

**Что это значит:**
- `PRIMARY` — кластеризованный индекс по `id` (создаётся автоматически).
- `customer_id` — некластеризованный индекс по внешнему ключу (создаётся автоматически при `FOREIGN KEY`).
- **Индекса по `amount` нет** — значит, запросы по `amount` будут делать `full scan`.

---

## 🔹 5. Эксперимент 2: `EXPLAIN` до индекса

```sql
EXPLAIN SELECT * FROM orders WHERE amount > 1000;
```

**Результат:**

| id | select_type | table | type | possible_keys | key | rows | Extra |
|----|-------------|-------|------|---------------|-----|------|-------|
| 1 | SIMPLE | orders | **ALL** | NULL | NULL | 6 | Using where |

**Что означают ключевые столбцы:**

| Столбец | Значение | Что значит |
|---------|----------|------------|
| `type` | `ALL` | **Full scan** — просматриваются все строки (плохо) |
| `key` | `NULL` | Индекс **не используется** |
| `rows` | `6` | Предполагается просмотреть 6 строк |

> 💡 На 6 строках `full scan` может быть **быстрее**, чем использование индекса — MySQL намеренно выбирает полный перебор для маленьких таблиц. Но на 1 000 000 строк `full scan` — катастрофа. `EXPLAIN` показывает план, а не гарантию оптимальности.

---

## 🔹 6. Эксперимент 3: `CREATE INDEX` и `EXPLAIN` после

Создадим индекс по `amount`:

```sql
CREATE INDEX idx_amount ON orders(amount);
```

Убедимся, что он появился:

```sql
SHOW INDEX FROM orders;
```

В списке появится `idx_amount` с `Non_unique = 1` (неуникальный индекс).

Повторим `EXPLAIN`:

```sql
EXPLAIN SELECT * FROM orders WHERE amount > 1000;
```

**Результат:**

| id | select_type | table | type | possible_keys | key | rows | Extra |
|----|-------------|-------|------|---------------|-----|------|-------|
| 1 | SIMPLE | orders | **range** | idx_amount | **idx_amount** | 4 | Using where |

**Что изменилось:**

| Столбец | Было | Стало | Что значит |
|---------|------|-------|------------|
| `type` | `ALL` | **`range`** | Используется диапазонный поиск по индексу (хорошо) |
| `key` | `NULL` | **`idx_amount`** | Индекс `idx_amount` задействован |
| `rows` | `6` | **`4`** | Просматривается меньше строк |

**Вывод:** индекс работает. `type: range` — это то, что мы хотим видеть для запросов с `>`, `<`, `BETWEEN`.

---

## 🔹 7. Эксперимент 4: функция в `WHERE` ломает индекс

```sql
EXPLAIN SELECT * FROM orders WHERE YEAR(order_date) = 2026;
```

**Результат:**

| id | select_type | table | type | possible_keys | key | rows | Extra |
|----|-------------|-------|------|---------------|-----|------|-------|
| 1 | SIMPLE | orders | **ALL** | NULL | NULL | 6 | Using where |

Снова `type: ALL` — **full scan**. Причина: **функция `YEAR()` в `WHERE`**. MySQL не может использовать индекс, потому что применяет функцию к каждой строке и только потом сравнивает.

### Создадим индекс по `order_date`

```sql
CREATE INDEX idx_order_date ON orders(order_date);
SHOW INDEX FROM orders;
```

### Перепишем запрос без функции

```sql
EXPLAIN SELECT * FROM orders
WHERE order_date >= '2026-01-01' AND order_date < '2027-01-01';
```

**Результат:**

| id | select_type | table | type | possible_keys | key | rows | Extra |
|----|-------------|-------|------|---------------|-----|------|-------|
| 1 | SIMPLE | orders | **range** | idx_order_date | **idx_order_date** | 6 | Using where |

**Вывод:** `type: range`, `key: idx_order_date` — индекс используется. Функция убрана, условие переписано в виде диапазона.

**Правило:** если в `WHERE` есть функция над столбцом (`YEAR()`, `MONTH()`, `DATE()`, `LOWER()` и т.д.) — индекс **не используется**. Переписывайте запрос без функции.

---

## 🔹 8. Эксперимент 5: составной индекс

Порядок столбцов в составном индексе **критичен**. Индекс `(status, amount)` работает для `WHERE status = ...` и `WHERE status = ... AND amount > ...`, но **не** для `WHERE amount > ...` без `status`.

```sql
CREATE INDEX idx_status_amount ON orders(status, amount);
SHOW INDEX FROM orders;
```

**Проверим три запроса:**

```sql
-- ✅ Использует индекс (status — первый столбец):
EXPLAIN SELECT * FROM orders WHERE status = 'paid';

-- ✅ Использует индекс (status + amount):
EXPLAIN SELECT * FROM orders WHERE status = 'paid' AND amount > 1000;

-- ⚠️ Составной индекс НЕ используется (amount — не первый столбец)
EXPLAIN SELECT * FROM orders WHERE amount > 1000;
```

**Важно:** в третьем запросе MySQL **не будет** использовать `idx_status_amount`, но **может** использовать `idx_amount`, созданный ранее в разделе 6. Чтобы увидеть поведение именно составного индекса, временно удалите `idx_amount`:

```sql
DROP INDEX idx_amount ON orders;
EXPLAIN SELECT * FROM orders WHERE amount > 1000;
```

Теперь `type` будет `ALL` или `index` (полный просмотр), `key` — `NULL` или другой индекс. Составной `idx_status_amount` для этого запроса не подходит.

> 💡 После эксперимента можно вернуть `idx_amount`:
> ```sql
> CREATE INDEX idx_amount ON orders(amount);
> ```

**Правило левого префикса:** индекс `(A, B)` работает для `A` и `(A, B)`, но не для `B` или `(B, ...)`.

**Как выбрать порядок:**
1. Столбец с наибольшей селективностью — первым.
2. Столбцы из `WHERE` — в начало.
3. Столбцы из `ORDER BY` — в конец (если не конфликтуют).

---

## 🔹 9. Эксперимент 6: покрывающий индекс

Если индекс содержит **все** столбцы, которые нужны запросу, MySQL **не обращается к таблице**. Это называется **Index-Only Scan**. В `EXPLAIN` в столбце `Extra` появляется `Using index`.

```sql
CREATE INDEX idx_customer_amount ON orders(customer_id, amount);
EXPLAIN SELECT customer_id, SUM(amount) FROM orders GROUP BY customer_id;
```

**Результат:**

| id | select_type | table | type | key | Extra |
|----|-------------|-------|------|-----|-------|
| 1 | SIMPLE | orders | index | idx_customer_amount | **Using index** |

`Using index` — значит, таблица не читается, всё берётся из индекса. Это самый быстрый вариант.

---

## 🔹 10. Итоговая шпаргалка по `EXPLAIN`

| `type` | Что значит | Хорошо/плохо |
|--------|------------|--------------|
| `ALL` | Full scan — просмотр всех строк | ❌ Плохо |
| `index` | Полный просмотр индекса (может быть быстрее `ALL`, если индекс содержит нужные столбцы) | ⚠️ Средне |
| `range` | Диапазонный поиск по индексу | ✅ Хорошо |
| `ref` | Точечный поиск по индексу | ✅ Хорошо |
| `eq_ref` | Уникальный поиск (по PK или UNIQUE) | ✅ Отлично |
| `const` | Константа (одна строка) | ✅ Идеально |

| `Extra` | Что значит | Хорошо/плохо |
|---------|------------|--------------|
| `Using index` | Покрывающий индекс, таблица не читается | ✅ Отлично |
| `Using where` | Фильтрация после чтения | ⚠️ Нормально |
| `Using filesort` | Сортировка после чтения | ⚠️ Может быть медленно |
| `Using temporary` | Временная таблица | ❌ Плохо |

**Что дальше:** в MySQL 8.0.18+ есть `EXPLAIN ANALYZE` — он показывает **реальное** время выполнения каждого шага, а не оценку. Попробуйте:

```sql
EXPLAIN ANALYZE SELECT * FROM orders WHERE amount > 1000;
```

---

## 🔹 11. Ведение и экспорт лога действий пользователя

Все команды, которые вы выполняли, записываются в файл `/var/lib/mysql/general.log` внутри контейнера (благодаря `general_log = 1` и `log_output = FILE` в `my.cnf`).

### 11.1. Проверить, что лог пишется

Выйдите из клиента MySQL (если ещё не вышли):
```sql
\q
```
Затем на хосте:
```shell
docker exec my-mysql ls -la /var/lib/mysql/general.log
```

Файл должен иметь размер > 0 и принадлежать `mysql`.

### 11.2. Посмотреть последние строки

```shell
docker exec my-mysql tail -n 30 /var/lib/mysql/general.log
```

### 11.3. Отфильтровать только свои действия

```shell
docker exec my-mysql cat /var/lib/mysql/general.log \
  | grep -E "Query[[:space:]]+(CREATE|INSERT|SELECT|UPDATE|DELETE|ALTER|DROP|RENAME|DESCRIBE|EXPLAIN|SHOW|USE|SET)" \
  | grep -v -E "INSERT INTO help_|INSERT INTO time_zone|INSERT INTO mysql\.|SELECT \* FROM mysql\.general_log|SET NAMES|SET autocommit|SET sql_mode|SET character_set_results" \
  > my_actions.log
```

Проверить:
```shell
cat my_actions.log
```
или
```shell
bat my_actions.log
```

В файле останутся **только ваши осмысленные SQL-команды** — без `Connect`, `Quit`, `SET NAMES`, `help_topic`, `time_zone`. Команды `SET GLOBAL` (если вы их выполняли) тоже попадут, но служебные `SET NAMES` и `SET autocommit` отфильтрованы.

> 💡 Если хотите видеть **только** `CREATE`/`INSERT`/`SELECT`/`EXPLAIN` и т.п., уберите `|SET` из первого `grep`. Но тогда ваши `SET GLOBAL` не попадут в лог.

### 11.4. Забрать полный лог на хост

```shell
docker cp my-mysql:/var/lib/mysql/general.log ./general.log
```
Файл создаётся от вашего пользователя.

### 11.5. Очистить лог (опционально)

```shell
docker exec -u mysql my-mysql sh -c ': > /var/lib/mysql/general.log'
```

---

## 🔹 12. Создание дампа базы

Выйдите из клиента MySQL, если ещё не вышли:
```sql
\q
```
Сделайте дамп:
```shell
docker exec -e MYSQL_PWD=123 my-mysql mysqldump -uroot index_practice > index_dump.sql
```
Или с дополнительными опциями для чистого дампа:
```shell
docker exec -e MYSQL_PWD=123 my-mysql mysqldump -uroot \
  --set-gtid-purged=OFF \
  --single-transaction \
  index_practice > index_dump_clean.sql
```
Посмотрите содержимое (первые 30 строк):
```shell
head -n 30 index_dump.sql
```

> ⚠️ В дамп попадут **все** индексы, созданные в экспериментах: `idx_amount`, `idx_order_date`, `idx_status_amount`, `idx_customer_amount`. Если хотите «чистый» дамп без экспериментальных индексов — удалите их перед дампом:
> ```sql
> DROP INDEX idx_amount ON orders;
> DROP INDEX idx_order_date ON orders;
> DROP INDEX idx_status_amount ON orders;
> DROP INDEX idx_customer_amount ON orders;
> ```
> Или оставьте — они полезны, если восстанавливаете базу для продолжения экспериментов.

Дамп включает таблицы `customers` и `orders` с данными и всеми индексами. При необходимости его можно использовать для восстановления базы.

---

**Результат оформить в виде отдельного `README.md` со скриншотами результатов `EXPLAIN` до и после создания индексов, дампом и логом (лог-файл должен содержать только ваши действия) в этой же папке и прислать ссылку преподавателю.**

---

# Скриншоты о выполнении работы

![alt](<screen/1.png>)

![alt](<screen/2.png>)

![alt](<screen/3.png>)

![alt](<screen/4.png>)

![alt](<screen/5.png>)

![alt](<screen/6.png>)

![alt](<screen/7.png>)

![alt](<screen/8.png>)

![alt](<screen/9.png>)
> Если вы обнаружили ошибку в этом тексте — сообщите пожалуйста автору!
