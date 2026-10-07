## CI/CD на Go с публикацией бинарников в GitHub Releases

> **Лабораторная работа выполняется в VS Code, без Docker!**

**GitHub Releases** — это раздел репозитория, где публикуются версии проекта: теги, описания, и главное — **файлы для скачивания**. Для Go это **самый естественный способ доставки**: бинарник самодостаточный, его не нужно упаковывать в Docker-образ.

**Цель** — научиться автоматически собирать и публиковать бинарники под 5 платформ (Linux, macOS, Windows) при push тега `v*`.

Что узнаете/вспомните:
- `go` — `go.mod`, команды `build`, `test`, `vet`
- Встроенные тесты — `_test.go`, `func TestXxx(t *testing.T)`
- **Cross-compilation** — `GOOS`/`GOARCH` из коробки
- **Матричные сборки** в **GitHub Actions** — параллельная сборка под 5 платформ
- **Семантическое версионирование** — теги `v1.0.0`
- **`softprops/action-gh-release`** — создание Release с файлами
- **`-ldflags -X`** — внедрение версии в бинарник при компиляции

Ключевое отличие от **GHCR**-руководства:
- **GHCR** — публикуется **Docker-образ** при push в `main` → для деплоя на серверы
- **Releases** — публикуются **бинарники** при push тега `v*` → для конечных пользователей

### 1. Создайте на вашем компьютере, в корневом каталоге текущего пользователя такую структуру:

```text
hello-go_bin/
├── .github/workflows/ci.yml
├── greeting/
│   ├── greeting.go
│   └── greeting_test.go
├── .gitignore
├── go.mod
└── main.go
```

Для перехода в корень текущего пользователя:
```shell
cd ~
```
Создать структуру проекта одной bash-командой (**Git Bash / Linux / WSL / macOS**):
```shell
mkdir -p hello-go_bin/{.github/workflows,greeting} && \
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

// version перезаписывается через -ldflags "-X main.version=..." во время сборки.
// Локально остаётся "dev".
var version = "dev"

func main() {
	fmt.Printf("hello-go version %s\n", version)
	fmt.Println("Hello from Go! 🐹")
	fmt.Printf("OS: %s\n", runtime.GOOS)
	fmt.Printf("Arch: %s\n", runtime.GOARCH)
	fmt.Println(greeting.Greet("GitHub"))
	fmt.Printf("Sum 1..10 = %d\n", greeting.SumRange(1, 10))

	if len(os.Args) > 1 {
		fmt.Println("Аргументы:")
		for i, arg := range os.Args[1:] {
			fmt.Printf("  %d: %s\n", i+1, arg)
		}
	}
}
EOF

cat > .github/workflows/ci.yml << 'EOF'
name: Go CI/CD

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]
  pull_request:

jobs:
  # ===== Job 1: CI — линтеры и тесты =====
  test:
    runs-on: ubuntu-latest

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

      - name: Build (smoke check)
        run: CGO_ENABLED=0 go build -o hello-go .

  # ===== Job 2: CD — публикация бинарников по тегу =====
  release:
    needs: test
    if: startsWith(github.ref, 'refs/tags/v')
    runs-on: ubuntu-latest

    permissions:
      contents: write

    strategy:
      matrix:
        include:
          - goos: linux
            goarch: amd64
            suffix: linux-amd64
          - goos: linux
            goarch: arm64
            suffix: linux-arm64
          - goos: darwin
            goarch: amd64
            suffix: darwin-amd64
          - goos: darwin
            goarch: arm64
            suffix: darwin-arm64
          - goos: windows
            goarch: amd64
            suffix: windows-amd64.exe

    steps:
      - uses: actions/checkout@v7

      - name: Set up Go
        uses: actions/setup-go@v5
        with:
          go-version: '1.23'

      - name: Build binary
        env:
          GOOS: ${{ matrix.goos }}
          GOARCH: ${{ matrix.goarch }}
          CGO_ENABLED: 0
        run: |
          go build \
            -ldflags="-s -w -X main.version=${{ github.ref_name }}" \
            -o hello-go-${{ matrix.suffix }} .

      - name: Upload to Release
        uses: softprops/action-gh-release@v2
        with:
          files: hello-go-${{ matrix.suffix }}
          generate_release_notes: true
EOF

cat > .gitignore << 'EOF'
/hello-go
/hello-go-*
.env
.idea/
.vscode/
*.iml
EOF

echo "✅ Структура создана:"
find . -type f | sort
```

### 2. Сборка и тесты в Docker (Go на хосте не нужен)

**Git Bash / Linux / WSL / macOS:**
```shell
cd ~/hello-go_bin
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

### 3. Локальная проверка кросс-компиляции (опционально)

Убедиться, что **Go** соберёт бинарники под все платформы, можно **без установки Go** — внутри **Docker**.

**Git Bash / Linux / WSL / macOS:**
```shell
cd ~/hello-go
docker run --rm \
  -u "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -e GOPATH=/tmp/go \
  -e GOCACHE=/tmp/go-cache \
  -v "$(pwd)":/app \
  -v ~/.go-docker-cache:/tmp/go \
  -w /app \
  golang:1.23-alpine \
  sh -c 'GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags="-s -w -X main.version=v0.0.1-local" -o hello-go-linux-amd64 .'
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
  sh -c "GOOS=linux GOARCH=amd64 CGO_ENABLED=0 go build -ldflags='-s -w -X main.version=v0.0.1-local' -o hello-go-linux-amd64 ."
```
После этого в папке проекта появится файл `hello-go-linux-amd64`. Его можно запустить локально (только на Linux) или просто убедиться, что файл создан:
```shell
ls -la hello-go-linux-amd64
```

> **Примечание:** если вы на macOS или Windows — этот бинарник не запустится на вашей системе, но он **точно заработает на Linux**. Это демонстрация кросс-компиляции.

### 4. Создание пустого репозитория на GitHub

Создайте пустой репозиторий `hello-go` на **GitHub**.

> ⚠️ Не добавляйте сразу `README.md`, `.gitignore` и лицензию — иначе `push` будет отклонён!

### 5. Запушить проект

Находясь в каталоге проекта:

**Git Bash / Linux / WSL / macOS:**
```shell
cd ~/hello-go
git init
git add .
git commit -m "Initial commit: Go app with CI/CD to GitHub Releases"
git branch -M main
read -p "Введите ваш GitHub username: " GITHUB_USER
git remote add origin "https://github.com/${GITHUB_USER}/hello-go.git"
git remote -v
git push -u origin main
```
**PowerShell (Windows):**
```powershell
cd ~/hello-go
git init
git add .
git commit -m "Initial commit: Go app with CI/CD to GitHub Releases"
git branch -M main
$GITHUB_USER = Read-Host "Введите ваш GitHub username"
git remote add origin "https://github.com/$GITHUB_USER/hello-go.git"
git remote -v
git push -u origin main
```

### 6. Первый запуск CI (без релиза)

После push в `main` откройте вкладку **Actions** в GitHub.

**Workflow** выполняется ~2–3 минуты. После успешного Actions (зелёная лампочка во вкладке Actions) можно продолжить выполнение задания.

**Что произойдёт:**
- Job `test` запустится и пройдёт все проверки (`gofmt`, `go vet`, `go test`)
- Job `release` будет **пропущен** — потому что push был в ветку, а не тег

Это нормальное поведение. Релиз создаётся **только при push тега `v*`**.

### 7. Создание релиза

Когда код в `main` стабилен — создайте тег:
```shell
git tag v1.0.0
git push origin v1.0.0
```
**Что произойдёт:**
1. `test` — снова прогонит тесты
2. `release` — **запустится**, соберёт 5 бинарников в параллельных job'ах
3. Создастся GitHub Release `v1.0.0` с прикреплёнными файлами

**Workflow** выполняется ~2–3 минуты. После успешного **Actions** (зелёная лампочка во вкладке **Actions**) можно продолжить выполнение задания.

**Проверка:** откройте
```
https://github.com/<ВАШ-USERNAME>/hello-go/releases
```
Там будет релиз `v1.0.0` с 5 файлами:
- `hello-go-linux-amd64`
- `hello-go-linux-arm64`
- `hello-go-darwin-amd64`
- `hello-go-darwin-arm64`
- `hello-go-windows-amd64.exe`

### 8. Скачивание и запуск бинарника

**Linux / macOS:**
```shell
# Скачать бинарник под вашу платформу
wget https://github.com/<ВАШ-USERNAME>/hello-go/releases/download/v1.0.0/hello-go-linux-amd64
# Дать права на исполнение
chmod +x hello-go-linux-amd64
# Запустить — Docker не нужен!
./hello-go-linux-amd64
```
**Windows (PowerShell):**
```powershell
Invoke-WebRequest `
  -Uri "https://github.com/<ВАШ-USERNAME>/hello-go/releases/download/v1.0.0/hello-go-windows-amd64.exe" `
  -OutFile "hello-go.exe"

.\hello-go.exe
```

**Ожидаемый вывод:**
```text
hello-go version v1.0.0
Hello from Go! 🐹
OS: linux
Arch: amd64
Hello, GitHub!
Sum 1..10 = 55
```
Обратите внимание на **первую строку**: `hello-go version v1.0.0`. Это версия, которая была **внедрена во время компиляции** через `-ldflags "-X main.version=..."`.

### 9. Создание нового релиза (опционально)

Для следующего релиза — просто создайте новый тег:
```shell
git tag v1.1.0
git push origin v1.1.0
```
GitHub создаст **новый Release** `v1.1.0`, старый `v1.0.0` останется доступным.

### 10. Если push не проходит

> **`remote origin already exists`** — URL уже добавлен. Проверьте `git remote -v`. Если неправильный — `git remote remove origin` и заново.
>
> **`Repository not found`** — проверьте URL и что репозиторий создан.
>
> **`Authentication failed`** — GitHub не принимает пароль. Используйте Personal Access Token (Settings → Developer settings → Tokens classic → право `repo`) или SSH-ключ.
>
> **`Rejected (non-fast-forward)`** — на GitHub уже есть коммит. `git pull --rebase origin main`, затем `git push origin main`.
>
> **`src refspec main does not match any`** — вы ещё не сделали коммит.

### 11. Если релиз не создаётся

> **Job `release` не запустился** — проверьте, что push был именно **тега** (`git push origin v1.0.0`), а не ветки. Job имеет условие `if: startsWith(github.ref, 'refs/tags/v')`.
>
> **`Error: Resource not accessible by integration`** — забыли `permissions: contents: write` в job'е `release`.
>
> **Workflow упал на `gofmt`** — код не отформатирован. Запустите локально `gofmt -w .` и закоммитьте.
>
> **Workflow упал на `go vet`** — `vet` нашёл проблемы. Исправьте.
>
> **Workflow упал на `go build`** — смотрите логи. Возможно, проблема с версией Go или несовместимость пакетов.
>
> **Релиз есть, но без файлов** — проверьте, что `files:` в `softprops/action-gh-release@v2` совпадает с именем, которое генерирует `go build -o`.
>
> **Все 5 job'ов пишут в один релиз одновременно** — это **нормально**. `softprops/action-gh-release@v2` умеет добавлять файлы в существующий релиз по тому же тегу. Никаких конфликтов не будет.

### Что вы освоили

- **Go** — `go.mod`, `go test`, `go vet`, `gofmt`
- **Cross-compilation** — `GOOS`/`GOARCH` без установки целевой платформы
- **Матричные сборки** — 5 параллельных job'ов в GitHub Actions
- **GitHub Actions** — Go toolchain, кэш модулей
- **GitHub Releases** — публикация бинарников через `softprops/action-gh-release`
- **Семантическое версионирование** — теги `v1.0.0`, `v1.1.0`
- **`-ldflags -X`** — внедрение версии в бинарник при компиляции
- **Разницу между CI и CI/CD**

### Ключевые отличия Releases от GHCR

| Аспект | GHCR (Docker) | GitHub Releases (бинарники) |
|--------|:---:|:---:|
| **Триггер** | push в `main` | push тега `v*` |
| **Артефакт** | Docker-образ | Бинарник |
| **Кросс-компиляция** | через `buildx` (multi-arch) | через `GOOS`/`GOARCH` |
| **Размер** | ~10–15 MB | ~2–5 MB |
| **Установка у пользователя** | Docker обязателен | Не нужен |
| **Версионирование** | `latest`, `sha-xxx` | `v1.0.0`, `v1.1.0` |
| **Кому** | DevOps, серверы | Конечные пользователи |

**Оба подхода дополняют друг друга:**
- **GHCR** — для деплоя на серверы (Docker Compose, Kubernetes)
- **Releases** — для распространения среди пользователей

![Screen](/content/DevOps/CI_CD/img/17_workflow.png)

> Если вы обнаружили ошибку в этом тексте — сообщите пожалуйста автору!


