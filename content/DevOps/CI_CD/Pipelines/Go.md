## Pipeline CI на Go в GitHub Actions

**Цель** — учебный пример — простой проект, который можно склонировать, настроить и убедиться, что приложение в контейнере на **Go**, и **GitHub Actions** работает

Вы научитесь:
- Настроить **CI** для **Go** проектов
- Научиться контейнеризировать приложения с **Docker**
- Сборку Docker-образа
- Сохранение артефактов для локального использования

**Go** (Golang) — это компилируемый, многопоточный язык программирования от **Google** с открытым исходным кодом, созданный для разработки высокопроизводительных веб-сервисов, микросервисов и облачных инфраструктур. Он сочетает синтаксис, похожий на **C**, с простотой, высокой скоростью выполнения

### 1. Создайте на **GitHub** новый публичный репозиторий `my-go-app` с `README.md`

Склонируйте его себе, откройте в **VS Code** и создайте такую структуру будущего проекта:

Структура проекта
```
my-go-app/
├── .github/
│   └── workflows/
│       └── ci.yml
├── main.go
├── sum.go
├── sum_test.go
├── Dockerfile
└── README.md
```

Структуру проекта можно сделать одной **bash**-командой, которая автоматически создаст все файлы и каталоги проекта:
```shell
mkdir -p .github/workflows && \
touch .github/workflows/ci.yml \
      main.go sum.go sum_test.go \
      Dockerfile README.md
```

### 2. Инициализация Go-модуля

 т.к. **Go** в вашей ОС скорей всего не установлен

Windows/PowerShell (надо проверять)
```shell
docker run --rm -v "${PWD}:/app" -w /app golang:1.22-alpine go mod init my-go-app
```
Любой Unix
```shell
docker run --rm -v "$(pwd):/app" -w /app golang:1.22-alpine go mod init my-go-app
```

Инициализация модуля go mod для удовлетворения зависимостей

Windows/PowerShell (надо проверять)
```shell
docker run --rm -v "${PWD}:/app" -w /app golang:1.22-alpine go mod tidy
```
Любой Unix
```shell
docker run --rm -v "$(pwd):/app" -w /app golang:1.22-alpine go mod tidy
```

### 3. Файл `sum.go` (простая функция)
```go
package main

func Sum(a, b int) int {
    return a + b
}
```

### 4. Файл `main.go`
```go
package main

import "fmt"

func main() {
    fmt.Println("Hello from Go app!")
    fmt.Println("2 + 3 =", Sum(2, 3))
}
```

### 5. Файл `sum_test.go` (тесты)
```go
package main
import "testing"

func TestSum(t *testing.T) {
    tests := []struct {
        a, b, expected int
    } {
        {2, 3, 5},
        {-1, 1, 0},
        {0, 0, 0},
    }
    for _, tt := range tests {
        result := Sum(tt.a, tt.b)
        if result != tt.expected {
            t.Errorf("Sum(%d, %d) = %d; want %d", tt.a, tt.b, result, tt.expected)
        }
    }
}
```

### 6. Файл `Dockerfile`
```dockerfile
FROM golang:1.22-alpine AS builder
WORKDIR /app
COPY go.mod .
RUN go mod download
COPY . .
RUN CGO_ENABLED=0 GOOS=linux go build -o my-app .

FROM alpine:latest
RUN apk --no-cache add ca-certificates
WORKDIR /root/
COPY --from=builder /app/my-app .
CMD ["./my-app"]
```

### 7. Файл GitHub Actions CI `.github/workflows/ci.yml`
```yaml
name: CI for Go App

on:
  push:
    branches: [ main, master ]
  pull_request:
    branches: [ main, master ]

jobs:
  test:
    name: Lint & Test
    runs-on: ubuntu-latest

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.22'
          cache: true   # кэширует go mod

      - name: Download dependencies
        run: go mod download

      - name: Run golangci-lint
        uses: golangci/golangci-lint-action@v6
        with:
          version: latest
          args: --timeout=5m

      - name: Run tests with coverage
        run: go test -v -coverprofile=coverage.out ./...

      - name: Upload coverage report
        uses: actions/upload-artifact@v4
        with:
          name: coverage-report
          path: coverage.out

  docker-build:
    name: Build Docker Image (no push)
    runs-on: ubuntu-latest
    needs: test
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'

    steps:
      - uses: actions/checkout@v4
      - name: Build Docker image
        run: docker build -t my-go-app:test .
```

### 8. Запуск локальных тестов через Docker

чтобы убедиться, что код приложения работает

Windows/PowerShell (надо проверять)
```shell
docker run --rm -v "${PWD}:/app" -w /app golang:1.22-alpine go test ./...
```
Любой Unix
```shell
docker run --rm -v "$(pwd):/app" -w /app golang:1.22-alpine go test ./...
```

если всё нормально, то тесты в командной строке могут показать что-то типа:
```shell
ok      my-go-app       0.002s
```

### 9. Сборка бинарного файла локально

Windows/PowerShell (надо проверять)
```shell
docker run --rm -v "${PWD}:/app" -w /app golang:1.22-alpine go build -o my-app .
```
Любой Unix
```shell
docker run --rm -v "$(pwd):/app" -w /app golang:1.22-alpine go build -o my-app .
```
Бинарник программы на **Go** появится в текущей папке. Запустить его можно на хосте (на вашем компьютере), если он совместим с вашей системой, либо через **Docker** (опционально):

Windows/PowerShell (надо проверять)
```shell
docker run --rm -v "${PWD}:/app" -w /app alpine ./my-app
```
Любой Unix
```shell
docker run --rm -v "$(pwd):/app" -w /app alpine ./my-app
```
если всё нормально, то тесты могут показать что-то типа:
```shell
Hello from Go app!
2 + 3 = 5
```
![Hello from my Go app!](/content/DevOps/CI_CD/img/6_workflow.png)

либо запустить бинарный файл собранного на Go приложения в консоле
```shell
./my-app
```
> в Windows это может не сработать!

### 10. Проверить сборку онлайн

- Закоммитьте и запушите в ветку `main` эти файлы в ваш репозиторий
- Перейдите на вкладку **Actions** в вашем репозитории на **GitHub**. Вы увидите, как ваш **Workflow** запустился, а через несколько минут загорится **зеленая** галочка, которая означает, что все шаги прошли успешно
- Если ваш **Workflow** стал красным - исправьте ошибки и запуштесь снова

![Скрин](/content/DevOps/CI_CD/img/5_workflow.png)


### 11. Проверить сборку Docker-образа локально

На своём компьютере, находясь в папке `my-go-app` этого репозитория выполнить:

Сборка проекта в Docker-образ
```shell
docker build -t my-go-app:latest .
```
Создание и запуск контейнера:
```shell
docker run --rm my-go-app:latest
```

Вы увидите вывод:
```shell
Hello from Go app!
2 + 3 = 5
```

![Hello from my Go app!](/content/DevOps/CI_CD/img/7_workflow.png)

Опционально вы можете зайти в интерактивный режим контейнера для ознакомления и отладки:
```shell
docker run -it --rm my-go-app:latest /bin/sh
```
выполнить команду получения ин-фы об используемой в контейнере ОС
```shell
cat /etc/os-release
```
![Hello from my Go app!](/content/DevOps/CI_CD/img/8_workflow.png)

выйти из контейнра:
```shell
exit
```

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
