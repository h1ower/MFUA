## **📊 Что такое `docker stats`?**

`docker stats` — встроенная команда Docker для **мониторинга использования ресурсов** контейнерами в реальном времени. Показывает:
- Использование CPU
- Потребление памяти
- Сетевой ввод/вывод
- I/O дисков
- Количество процессов (PIDs)

## **🎯 Основное использование**

```bash
# Базовая команда - мониторинг всех запущенных контейнеров
docker stats

# Вывод будет обновляться каждые 2 секунды
CONTAINER ID   NAME            CPU %     MEM USAGE / LIMIT     MEM %     NET I/O           BLOCK I/O         PIDS
abc123def456   myapp-container 0.15%     125.3MiB / 1.945GiB   6.29%     1.45kB / 648B     0B / 0B           8
def456ghi789   postgres-db     2.35%     328.7MiB / 1.945GiB   16.52%    45.6kB / 21.4kB   12.3MB / 4.1MB    32
```

## **🔧 Параметры команды**

### **Основные флаги:**
```bash
# Однократный вывод (без постоянного обновления)
docker stats --no-stream

# Только определенные контейнеры
docker stats myapp-container postgres-db

# Форматированный вывод
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Показать все контейнеры (включая остановленные)
docker stats --all

# Вывод в JSON формате
docker stats --no-stream --format json
```

## **📈 Подробный разбор показателей**

### **1. CPU Usage**
```
CPU %: 2.35%
```
- Процент использования одного ядра CPU
- Если контейнер использует 200% — значит использует 2 ядра на 100%
- Включает user + system CPU time

### **2. Memory Usage**
```
MEM USAGE / LIMIT: 328.7MiB / 1.945GiB
MEM %: 16.52%
```
- **MEM USAGE**: Фактическое использование RAM
- **LIMIT**: Лимит памяти контейнера
- Включает кэш, буферы, shared memory

### **3. Network I/O**
```
NET I/O: 45.6kB / 21.4kB
```
- **Первое число**: Полученные данные (RX)
- **Второе число**: Переданные данные (TX)
- В байтах/килобайтах/мегабайтах

### **4. Block I/O**
```
BLOCK I/O: 12.3MB / 4.1MB
```
- **Первое число**: Чтение с диска
- **Второе число**: Запись на диск
- Полезно для анализа дисковых операций

### **5. PIDs**
```
PIDS: 32
```
- Количество процессов внутри контейнера
- Помогает выявить fork bombs или утечки процессов

## **🎛️ Продвинутое использование**

### **Форматированный вывод:**
```bash
# Свой формат вывода
docker stats --format "table {{.Container}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemPerc}}"

# С использованием псевдонимов
docker stats --format "table {{.ID}}\t{{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Компактный вывод
docker stats --format "{{.Name}}: CPU {{.CPUPerc}} | MEM {{.MemPerc}} | NET {{.NetIO}}"
```

### **Доступные переменные для форматирования:**
- **`.Container`** - ID контейнера
- **`.Name`** - Имя контейнера
- **`.ID`** - ID контейнера (полный)
- **`.CPUPerc`** - Использование CPU в процентах
- **`.MemUsage`** - Использование памяти (абсолютное)
- **`.MemPerc`** - Использование памяти в процентах
- **`.NetIO`** - Сетевой ввод/вывод
- **`.BlockIO`** - Дисковый ввод/вывод
- **`.PIDs`** - Количество процессов

## **📝 Практические примеры**

### **Пример 1: Мониторинг в реальном времени**
```bash
# Запустим несколько контейнеров
docker run -d --name stress-test1 --memory=100m alpine sh -c "while true; do echo 'test'; done"
docker run -d --name stress-test2 alpine sh -c "dd if=/dev/zero of=/dev/null"

# Мониторинг в реальном времени
docker stats stress-test1 stress-test2

# После теста остановим
docker stop stress-test1 stress-test2
docker rm stress-test1 stress-test2
```

### **Пример 2: Создание дашборда**
```bash
#!/bin/bash
# dashboard.sh - простой дашборд мониторинга

while true; do
    clear
    echo "=== Docker Stats Dashboard ==="
    echo "Обновляется каждые 3 секунды"
    echo "=============================="

    # Выводим статистику
    docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}"

    # Общая статистика системы
    echo -e "\n=== Системные ресурсы ==="
    docker system df

    # Количество контейнеров
    echo -e "\n=== Контейнеры ==="
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

    sleep 3
done
```

### **Пример 3: Логирование статистики в файл**
```bash
# Логировать статистику каждые 5 секунд
while true; do
    date >> docker-stats.log
    docker stats --no-stream --format "{{.Name}},{{.CPUPerc}},{{.MemUsage}},{{.NetIO}}" >> docker-stats.log
    sleep 5
done

# Парсинг лога для анализа
cat docker-stats.log | grep myapp-container | awk -F',' '{print $2}' | sed 's/%//' > cpu-usage.txt
```

## **🔍 Анализ проблем с помощью `docker stats`**

### **Высокое использование CPU:**
```bash
# Найти контейнеры с высоким CPU
docker stats --format "table {{.Name}}\t{{.CPUPerc}}" | sort -k2 -nr

# Если контейнер использует > 100% CPU, он использует несколько ядер
# Пример: 250% = 2.5 ядра на 100%
```

### **Утечка памяти:**
```bash
# Мониторить использование памяти
watch -n 1 'docker stats --no-stream --format "table {{.Name}}\t{{.MemUsage}}\t{{.MemPerc}}" | grep -v "NAME"'

# Проверить лимиты памяти
docker inspect myapp-container | grep -i memory
```

### **Сетевые проблемы:**
```bash
# Контейнеры с высокой сетевой активностью
docker stats --format "table {{.Name}}\t{{.NetIO}}" | sort -k2 -hr

# Проверить сетевые соединения внутри контейнера
docker exec myapp-container netstat -tuln
```

## **📊 Сравнение с другими инструментами мониторинга**

| Инструмент | Преимущества | Недостатки |
|------------|--------------|------------|
| **`docker stats`** | Встроен в Docker, простой, реальное время | Нет истории, базовые метрики |
| **`docker top`** | Процессы внутри контейнера | Только процессы |
| **cAdvisor** | Детальные метрики, история, веб-интерфейс | Требует отдельного контейнера |
| **Prometheus** | Продвинутый мониторинг, алерты | Сложная настройка |

## **📈 Использование в скриптах**

### **Мониторинг с алертами:**
```bash
#!/bin/bash
# monitor.sh - мониторинг с уведомлениями

THRESHOLD_CPU=80
THRESHOLD_MEM=90

while true; do
    # Получаем статистику
    STATS=$(docker stats --no-stream --format "{{.Name}}|{{.CPUPerc}}|{{.MemPerc}}" | sed 's/%//g')

    while IFS='|' read -r name cpu mem; do
        if (( $(echo "$cpu > $THRESHOLD_CPU" | bc -l) )); then
            echo "ALERT: Контейнер $name использует $cpu% CPU" >> alerts.log
        fi

        if (( $(echo "$mem > $THRESHOLD_MEM" | bc -l) )); then
            echo "ALERT: Контейнер $name использует $mem% памяти" >> alerts.log
        fi
    done <<< "$STATS"

    sleep 10
done
```

### **Сбор метрик для Grafana:**
```bash
# Сбор метрик в формате для Prometheus
while true; do
    echo "# HELP container_cpu_usage CPU usage in percent"
    echo "# TYPE container_cpu_usage gauge"
    docker stats --no-stream --format "container_cpu_usage{name=\"{{.Name}}\"} {{.CPUPerc}}" | sed 's/%//'

    echo -e "\n# HELP container_memory_usage Memory usage in percent"
    echo "# TYPE container_memory_usage gauge"
    docker stats --no-stream --format "container_memory_usage{name=\"{{.Name}}\"} {{.MemPerc}}" | sed 's/%//'

    sleep 5
done > /var/lib/node_exporter/docker_stats.prom
```

## **🎛️ Интеграция с другими командами**

### **С `docker ps`:**
```bash
# Показать статистику только для работающих контейнеров определенного образа
docker stats $(docker ps --filter ancestor=nginx --format "{{.Names}}")

# Мониторить контейнеры в определенной сети
docker stats $(docker ps --filter network=my-network --format "{{.Names}}")
```

### **С `watch`:**
```bash
# Обновлять каждую секунду
watch -n 1 docker stats --no-stream

# Цветной вывод
watch -c 'docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"'
```

## **🚨 Ограничения и важные моменты**

1. **Нет истории** — только текущие значения
2. **Метрики усредненные** — за период между обновлениями
3. **Только запущенные контейнеры** (если не использовать `--all`)
4. **Производительность** — частый опрос может нагружать систему
5. **Точность** — для высокоточного мониторинга используйте cAdvisor/Prometheus

## **🔧 Трюки и советы**

### **Создание алиасов:**
```bash
# Добавить в ~/.bashrc или ~/.zshrc
alias dstats='docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}"'
alias dstats-all='docker stats --all --format "table {{.Name}}\t{{.Status}}\t{{.CPUPerc}}\t{{.MemUsage}}"'
alias dtop='docker stats --no-stream | sort -k3 -hr'
```

### **Быстрые команды:**
```bash
# Самый прожорливый контейнер по CPU
docker stats --no-stream --format "{{.Name}}: {{.CPUPerc}}" | sort -t: -k2 -nr | head -5

# Самый прожорливый по памяти
docker stats --no-stream --format "{{.Name}}: {{.MemUsage}}" | sort -t: -k2 -hr | head -5

# Контейнеры с активным сетевым трафиком
docker stats --no-stream --format "{{.Name}}: {{.NetIO}}" | grep -v "0B / 0B"
```

## **📱 Графические альтернативы**

```bash
# 1. Portainer (веб-интерфейс)
docker run -d -p 9000:9000 -v /var/run/docker.sock:/var/run/docker.sock portainer/portainer

# 2. cAdvisor (от Google)
docker run -d \
  --name=cadvisor \
  -p 8080:8080 \
  -v /:/rootfs:ro \
  -v /var/run:/var/run:ro \
  -v /sys:/sys:ro \
  -v /var/lib/docker/:/var/lib/docker:ro \
  google/cadvisor:latest

# 3. DockStation (десктопное приложение)
# https://dockstation.io/
```

## **🎯 Краткая шпаргалка:**

```bash
# Основные команды
docker stats                    # Все контейнеры, реальное время
docker stats --no-stream        # Однократный вывод
docker stats nginx postgres     # Только указанные контейнеры

# Форматирование
docker stats --format "{{.Name}} CPU: {{.CPUPerc}} MEM: {{.MemPerc}}"
docker stats --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Полезные комбинации
docker stats $(docker ps -q)    # Только запущенные
watch -n 2 docker stats         # Обновление каждые 2 секунды
```

`docker stats` — это ваш первый инструмент при диагностике проблем с производительностью контейнеров. Быстро, просто и информативно! 🐳
> Если вы обраружили ошибку в этом тексте - сообщите пожалуйста автору!

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
