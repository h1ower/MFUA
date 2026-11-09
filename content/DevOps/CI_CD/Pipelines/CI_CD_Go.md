## CI/CD на Go с публикацией в GHCR

Что узнаете/вспомните:
- `go` — `go.mod`, команды `build`, `test`, `vet`
- `gofmt` — проверка форматирования (в CI — `gofmt -l`)
- Встроенные тесты — _test.go, func TestXxx(t *testing.T)
- `Go` компилируется в один статический бинарник — JVM/интерпретатор не нужен
- `Multi-stage Docker` — сборка в golang:alpine, запуск в alpine
- `GitHub Actions` — Go toolchain, кэш модулей, `docker build`
- `GHCR` — публикация образа через `GITHUB_TOKEN`

**GHCR** (GitHub Container Registry) — это реестр Docker-образов от **GitHub**. Работает так же, как Docker Hub, но не требует отдельной регистрации и токенов — всё через встроенный `GITHUB_TOKEN`.

**Цель** — научиться публиковать Docker-образ в **GHCR** автоматически при `push`
в `main`. Это превращает **CI** в **CI/CD** (Continuous Delivery): код не только
проверяется, но и превращается в готовый к развёртыванию артефакт.

Ключевое отличие `CI` от `CI/CD`:
- `CI` — код проверяется: `fmt`, `vet`, `test`, `docker build`
- `CI/CD` — то же + образ публикуется в реестр (GHCR) и готов к деплою (развёртыванию)

### 1. Создайте на вашем компьютере, в корневом каталоге текущего пользователя такую структуру:
```text
hello-go/
├── .github/workflows/ci.yml
├── greeting/
│   ├── greeting.go
│   └── greeting_test.go
├── .gitignore
├── .dockerignore
├── Dockerfile
├── go.mod
└── main.go
```
Создать структуру проекта одной bash-командой (Git Bash / Linux / WSL / macOS):

Перейдём в корневой каталог текущего пользователя
```shell
cd ~
```
и выполним создание структуры проекта
```shell
mkdir -p hello-go/{.github/workflows,greeting} && \
cd hello-go && \

cat > go.mod << 'EOF'
module hello-go

go 1.23
EOF

cat > greeting/greeting.go << 'EOF'
package greeting

import "fmt"

func Greet(name string) string {
	return fmt.Sprintf("Hello, %s!", name)
}

func SumRange(from, to int) int {
	sum := 0
	for i := from; i <= to; i++ {
		sum += i
	}
	return sum
}
EOF

cat > greeting/greeting_test.go << 'EOF'
package greeting

import "testing"

func TestGreet(t *testing.T) {
	got := Greet("Docker")
	want := "Hello, Docker!"
	if got != want {
		t.Errorf("Greet() = %q, want %q", got, want)
	}
}

func TestSumRange(t *testing.T) {
	got := SumRange(1, 10)
	want := 55
	if got != want {
		t.Errorf("SumRange(1, 10) = %d, want %d", got, want)
	}
}
EOF

cat > main.go << 'EOF'
package main

import (
	"fmt"
	"os"
	"runtime"

	"hello-go/greeting"
)

func main() {
	fmt.Println("Hello from Go in Docker! 🐹🐳")
	fmt.Printf("OS: %s\n", runtime.GOOS)
	fmt.Printf("Arch: %s\n", runtime.GOARCH)
	fmt.Println(greeting.Greet("Docker"))
	fmt.Printf("Sum 1..10 = %d\n", greeting.SumRange(1, 10))

	if len(os.Args) > 1 {
		fmt.Println("Аргументы:")
		for i, arg := range os.Args[1:] {
			fmt.Printf("  %d: %s\n", i+1, arg)
		}
	}
}
EOF

cat > Dockerfile << 'EOF'
# Этап 1: сборка
FROM golang:1.23-alpine AS builder
WORKDIR /build

# Копируем go.mod и go.sum (если есть)
COPY go.* ./

# Скачиваем зависимости (кэшируется при неизменном go.mod)
RUN go mod download

# Копируем исходники
COPY . .

# Собираем статический бинарник
RUN CGO_ENABLED=0 GOOS=linux go build -ldflags="-s -w" -o hello-go .

# Этап 2: запуск
FROM alpine:3.20

# Непривилегированный пользователь
RUN adduser -D appuser
USER appuser
WORKDIR /home/appuser

COPY --from=builder /build/hello-go ./hello-go

ENTRYPOINT ["./hello-go"]
EOF

cat > .github/workflows/ci.yml << 'EOF'
name: Go CI/CD

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest

    permissions:
      contents: read
      packages: write

    steps:
      - uses: actions/checkout@v7

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.23'
          cache: true

      - name: Format check
        run: |
          UNFORMATTED=$(gofmt -l .)
          if [ -n "$UNFORMATTED" ]; then
            echo "❌ Следующие файлы не отформатированы:"
            echo "$UNFORMATTED"
            echo "Запустите локально: gofmt -w ."
            exit 1
          fi

      - name: Lint with go vet
        run: go vet ./...

      - name: Run tests
        run: go test ./... -v

      - name: Build release
        run: CGO_ENABLED=0 go build -o hello-go .

      - name: Log in to GHCR
        if: github.event_name == 'push' && github.ref == 'refs/heads/main'
        uses: docker/login-action@v4
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v4

      - name: Extract Docker metadata
        id: meta
        uses: docker/metadata-action@v6
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=sha,prefix=,format=short
            type=raw,value=latest,enable={{is_default_branch}}

      - name: Build and push Docker image
        uses: docker/build-push-action@v7
        with:
          context: .
          push: ${{ github.event_name == 'push' && github.ref == 'refs/heads/main' }}
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
EOF

cat > .gitignore << 'EOF'
/hello-go
.env
.idea/
.vscode/
*.iml
EOF

cat > .dockerignore << 'EOF'
.git/
.github/
*.md
.gitignore
.dockerignore
hello-go
EOF

echo "✅ Структура создана:"
find . -type f | sort
```

### 2. Сборка проекта и тесты в Docker (Go на хосте не нужен)

**Git Bash / Linux / WSL / macOS:**
```shell
cd ~/hello-go
mkdir -p ~/.go-docker-cache
docker run --rm \
  -u "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -e GOPATH=/tmp/go \
  -e GOCACHE=/tmp/go-cache \
  -v "$(pwd)":/app \
  -v ~/.go-docker-cache:/tmp/go \
  -w /app \
  golang:1.23-alpine \
  go test ./... -v
```
**PowerShell (Windows):**
```powershell
cd ~/hello-go
docker run --rm `
  -e GOPATH=/tmp/go `
  -e GOCACHE=/tmp/go-cache `
  -v "${PWD}:/app" `
  -w /app `
  golang:1.23-alpine `
  go test ./... -v
```
Ожидаемый вывод:
```shell
=== RUN   TestGreet
--- PASS: TestGreet (0.00s)
=== RUN   TestSumRange
--- PASS: TestSumRange (0.00s)
PASS
ok      hello-go/greeting   0.002s
```

### 3. Сборка Docker-образа

На всякий случай переходим в каталог проекта:
```shell
cd ~/hello-go
```
И выполняем сборку:
```shell
docker build -t hello-go .
```

### 4. Запуск контейнера

```shell
docker run --rm hello-go
```
Ожидаемый вывод:
```shell
Hello from Go in Docker! 🐹🐳
OS: linux
Arch: amd64
Hello, Docker!
Sum 1..10 = 55
```

### 5. Создание пустого репозитория на GitHub

Создайте пустой репозиторий `hello-go` на **GitHub**.

> ⚠️ Не добавляйте сразу README.md, .gitignore и лицензию — иначе push будет отклонён!

### 6. Запушить проект

Находясь в каталоге проекта:

**Git Bash / Linux / WSL / macOS:**
```shell
git init
git add .
git commit -m "Initial commit: Go app with Docker and CI/CD to GHCR"
git branch -M main
read -p "Введите ваш GitHub username: " GITHUB_USER
git remote add origin "https://github.com/${GITHUB_USER}/hello-go.git"
git remote -v
git push -u origin main
```
**PowerShell (Windows):**
```powershell
git init
git add .
git commit -m "Initial commit: Go app with Docker and CI/CD to GHCR"
git branch -M main
$GITHUB_USER = Read-Host "Введите ваш GitHub username"
git remote add origin "https://github.com/$GITHUB_USER/hello-go.git"
git remote -v
git push -u origin main
```

### 7. Проверка публикации в GHCR

**Workflow** выполняется ~2–3 минуты. Когда появится зелёная галочка — образ опубликован.

Проверка в **GitHub**:
- Откройте страницу репозитория
- В правой колонке — вкладка `Packages`
- Там будет пакет `hello-go`

Прямой URL пакета:

`https://github.com/users/<ВАШ-USERNAME>/packages/container/hello-go`

- Замените <ВАШ-USERNAME> на ваш логин **GitHub** — без угловых скобок.
- Например: https://github.com/users/ivanov/packages/container/hello-go

### 8. Сделать образ публичным

По умолчанию образ в **GHCR** приватный — только вы можете его скачать. Даже если репозиторий публичный, пакет остаётся приватным — видимость настраивается отдельно.

1. Откройте страницу пакета:
`https://github.com/users/<ВАШ-USERNAME>/packages/container/hello-go`
2. Справа вверху — `Package settings`
3. Прокрутите до `Danger Zone → Change visibility`
4. Выберите `Public`
5. Введите имя пакета `hello-go` для подтверждения
6. Нажмите `I understand the consequences, change package visibility`

### 9. Проверка локально

**Git Bash / Linux / WSL / macOS:**
```shell
docker logout ghcr.io
read -p "Введите ваш GitHub username: " GITHUB_USER
docker pull "ghcr.io/${GITHUB_USER}/hello-go:latest"
docker run --rm "ghcr.io/${GITHUB_USER}/hello-go"
```
**PowerShell (Windows):**
```powershell
docker logout ghcr.io
$GITHUB_USER = Read-Host "Введите ваш GitHub username"
docker pull "ghcr.io/$GITHUB_USER/hello-go:latest"
docker run --rm "ghcr.io/$GITHUB_USER/hello-go"
```
Ожидаемый вывод:
```shell
Hello from Go in Docker! 🐹🐳
OS: linux
Arch: amd64
Hello, Docker!
Sum 1..10 = 55
```

***

Что вы освоили:
- **Go** — go.mod, go test, go vet, gofmt
- **Multi-stage Docker** — сборка в golang:alpine, запуск в alpine
- Статический бинарник — CGO_ENABLED=0 GOOS=linux
- **GitHub Actions** — Go toolchain, кэш модулей, docker build
- **GHCR** — публикация через GITHUB_TOKEN
- **docker/metadata-action** — автоматические теги
- Разницу между **CI** и **CI/CD**

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!