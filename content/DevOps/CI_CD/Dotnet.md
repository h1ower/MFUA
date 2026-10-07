## CI/CD на C#/.NET CLI с публикацией бинарников в GitHub Releases

Сборка **.NET CLI** в один `self-contained` исполняемый файл

> Лабораторная работа выполняется в **VS Code**!

- **.NET** — это платформа для разработки приложений от Microsoft. В отличие от **Python**, .**NET** умеет cross-compilation — один runner собирает под все платформы. Это ближе к **Go** и **Rust**, чем к **Python**.
- **GitHub Releases** — раздел репозитория, где публикуются версии проекта: теги, описания и файлы для скачивания.

**Цель** — научиться автоматически собирать бинарники **.NET CLI** под 5 платформ (Linux, macOS, Windows — на двух архитектурах) и публиковать их в **GitHub Releases** при push тега v*.

Что узнаете/вспомните:
- **dotnet CLI** — dotnet build, dotnet test, dotnet publish, dotnet format
- **xUnit** — встроенные тесты в .NET
- **Cross-compilation** в .NET — один runner собирает под все платформы
- **Runtime Identifiers (RID)** — linux-x64, win-x64, osx-arm64 и др.
- **Self-contained** + PublishSingleFile — один файл, без установки .NET
- **Матричные сборки** в **GitHub Actions**
- **softprops/action-gh-release** — публикация артефактов
- **Семантическое версионирование** — теги `v0.1.0`, `v0.2.0`

Ключевое отличие от **Python**:

- **Python** — для каждой ОС нужен свой runner (нет cross-compilation)
- **.NET** — один runner собирает под все платформы через `-r <RID>`, как **Go** и **Rust**

### 1. Создайте на вашем компьютере, в корневом каталоге текущего пользователя такую структуру:

```text
hello-dotnet/
├── .github/workflows/ci.yml
├── src/
│   ├── HelloDotnet.csproj
│   ├── Greeting.cs
│   └── Program.cs
├── tests/
│   ├── HelloDotnet.Tests.csproj
│   └── GreetingTests.cs
└── .gitignore
```
Создать структуру проекта одной bash-командой (Git Bash / Linux / WSL / macOS):
```shell
mkdir -p hello-dotnet/{.github/workflows,src,tests} && \
cd hello-dotnet && \

cat > src/HelloDotnet.csproj << 'EOF'
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <AssemblyName>hello-dotnet</AssemblyName>
    <RootNamespace>HelloDotnet</RootNamespace>
    <InvariantGlobalization>true</InvariantGlobalization>
    <Version>0.1.0</Version>
  </PropertyGroup>

</Project>
EOF

cat > src/Greeting.cs << 'EOF'
namespace HelloDotnet;

public static class Greeting
{
    public static string Greet(string name)
    {
        return $"Hello, {name}!";
    }

    public static int SumRange(int from, int to)
    {
        int sum = 0;
        for (int i = from; i <= to; i++)
        {
            sum += i;
        }
        return sum;
    }
}
EOF

cat > src/Program.cs << 'EOF'
using System.Reflection;
using System.Runtime.InteropServices;
using HelloDotnet;

// Версия читается из атрибута сборки, который задаётся в .csproj (<Version>)
var version = Assembly.GetExecutingAssembly()
    .GetCustomAttribute<AssemblyInformationalVersionAttribute>()?
    .InformationalVersion
    .Split('+')[0] ?? "unknown";

Console.WriteLine($"hello-dotnet version {version}");
Console.WriteLine("Hello from C# in GitHub Actions! 🚀📦");
Console.WriteLine($"OS: {RuntimeInformation.OSDescription}");
Console.WriteLine($"Arch: {RuntimeInformation.OSArchitecture}");
Console.WriteLine(Greeting.Greet("GitHub"));
Console.WriteLine($"Sum 1..10 = {Greeting.SumRange(1, 10)}");

if (args.Length > 0)
{
    Console.WriteLine("Аргументы:");
    for (int i = 0; i < args.Length; i++)
    {
        Console.WriteLine($"  {i + 1}: {args[i]}");
    }
}

return 0;
EOF

cat > tests/HelloDotnet.Tests.csproj << 'EOF'
<Project Sdk="Microsoft.NET.Sdk">

  <PropertyGroup>
    <TargetFramework>net8.0</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
    <IsPackable>false</IsPackable>
    <IsTestProject>true</IsTestProject>
  </PropertyGroup>

  <ItemGroup>
    <PackageReference Include="Microsoft.NET.Test.Sdk" Version="17.11.1" />
    <PackageReference Include="xunit" Version="2.9.2" />
    <PackageReference Include="xunit.runner.visualstudio" Version="2.8.2" />
  </ItemGroup>

  <ItemGroup>
    <ProjectReference Include="..\src\HelloDotnet.csproj" />
  </ItemGroup>

</Project>
EOF

cat > tests/GreetingTests.cs << 'EOF'
using HelloDotnet;
using Xunit;

namespace HelloDotnet.Tests;

public class GreetingTests
{
    [Fact]
    public void Greet_ReturnsExpectedMessage()
    {
        Assert.Equal("Hello, .NET!", Greeting.Greet(".NET"));
        Assert.Equal("Hello, CI!", Greeting.Greet("CI"));
    }

    [Fact]
    public void SumRange_ReturnsCorrectSum()
    {
        Assert.Equal(55, Greeting.SumRange(1, 10));
        Assert.Equal(5050, Greeting.SumRange(1, 100));
    }
}
EOF

cat > .github/workflows/ci.yml << 'EOF'
name: .NET CI/CD

on:
  push:
    branches: [ main ]
    tags: [ 'v*' ]
  pull_request:

jobs:
  # ===== Job 1: CI — форматирование, сборка, тесты =====
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - name: Cache NuGet
        uses: actions/cache@v4
        with:
          path: ~/.nuget/packages
          key: ${{ runner.os }}-nuget-${{ hashFiles('**/*.csproj') }}
          restore-keys: |
            ${{ runner.os }}-nuget-

      - name: Restore dependencies
        run: |
          dotnet restore src/HelloDotnet.csproj
          dotnet restore tests/HelloDotnet.Tests.csproj

      - name: Format check (src)
        run: dotnet format src/HelloDotnet.csproj --verify-no-changes --verbosity diagnostic

      - name: Format check (tests)
        run: dotnet format tests/HelloDotnet.Tests.csproj --verify-no-changes --verbosity diagnostic

      - name: Build
        run: dotnet build tests/HelloDotnet.Tests.csproj --configuration Release --no-restore

      - name: Run tests
        run: dotnet test tests/HelloDotnet.Tests.csproj --configuration Release --no-build --verbosity normal

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
          - rid: linux-x64
            artifact: hello-dotnet-linux-x64
          - rid: linux-arm64
            artifact: hello-dotnet-linux-arm64
          - rid: win-x64
            artifact: hello-dotnet-windows-x64.exe
          - rid: osx-x64
            artifact: hello-dotnet-macos-x64
          - rid: osx-arm64
            artifact: hello-dotnet-macos-arm64

    steps:
      - uses: actions/checkout@v4

      - name: Setup .NET
        uses: actions/setup-dotnet@v4
        with:
          dotnet-version: '8.0.x'

      - name: Cache NuGet
        uses: actions/cache@v4
        with:
          path: ~/.nuget/packages
          key: ${{ runner.os }}-nuget-${{ hashFiles('**/*.csproj') }}
          restore-keys: |
            ${{ runner.os }}-nuget-

      - name: Publish for ${{ matrix.rid }}
        run: |
          dotnet publish src/HelloDotnet.csproj \
            --configuration Release \
            --runtime ${{ matrix.rid }} \
            --self-contained true \
            -p:PublishSingleFile=true \
            -p:IncludeNativeLibrariesForSelfExtract=true \
            --output dist/${{ matrix.rid }}

      - name: Rename binary
        run: |
          if [[ "${{ matrix.rid }}" == win-* ]]; then
            mv dist/${{ matrix.rid }}/hello-dotnet.exe dist/${{ matrix.artifact }}
          else
            mv dist/${{ matrix.rid }}/hello-dotnet dist/${{ matrix.artifact }}
          fi

      - name: Upload to Release
        uses: softprops/action-gh-release@v2
        with:
          files: dist/${{ matrix.artifact }}
          generate_release_notes: true
EOF

cat > .gitignore << 'EOF'
bin/
obj/
*.user
.vs/
.idea/
.vscode/
*.suo
.env
dist/
EOF

echo "✅ Структура создана:"
find . -type f | sort
```

### 2. Тесты в Docker (.NET на хосте не нужен)

Git Bash / Linux / WSL / macOS:
```shell
cd ~/hello-dotnet
docker run --rm \
  -u "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -e DOTNET_CLI_HOME=/tmp \
  -e NUGET_PACKAGES=/tmp/nuget \
  -e DOTNET_CLI_TELEMETRY_OPTOUT=1 \
  -e DOTNET_NOLOGO=1 \
  -v "$(pwd)":/app \
  -w /app \
  mcr.microsoft.com/dotnet/sdk:8.0 \
  dotnet test tests/HelloDotnet.Tests.csproj
```
PowerShell (Windows):
```powershell
cd ~/hello-dotnet
docker run --rm `
  -e DOTNET_CLI_TELEMETRY_OPTOUT=1 `
  -e DOTNET_NOLOGO=1 `
  -v "${PWD}:/app" `
  -w /app `
  mcr.microsoft.com/dotnet/sdk:8.0 `
  dotnet test tests/HelloDotnet.Tests.csproj
```
Ожидаемый вывод:
```shell
Determining projects to restore...
Restored /app/tests/HelloDotnet.Tests.csproj
...
Passed!  - Failed:     0, Passed:     2, Skipped:     0, Total:     2
```

### 3. Локальная сборка бинарника через dotnet publish в Docker

Git Bash / Linux / WSL / macOS:
```shell
cd ~/hello-dotnet
docker run --rm \
  -u "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -e DOTNET_CLI_HOME=/tmp \
  -e NUGET_PACKAGES=/tmp/nuget \
  -e DOTNET_CLI_TELEMETRY_OPTOUT=1 \
  -e DOTNET_NOLOGO=1 \
  -v "$(pwd)":/app \
  -w /app \
  mcr.microsoft.com/dotnet/sdk:8.0 \
  dotnet publish src/HelloDotnet.csproj \
    -c Release \
    -r linux-x64 \
    --self-contained true \
    -p:PublishSingleFile=true \
    -p:IncludeNativeLibrariesForSelfExtract=true \
    -o dist/linux-x64
```
PowerShell (Windows):
```powershell
cd ~/hello-dotnet
docker run --rm `
  -e DOTNET_CLI_TELEMETRY_OPTOUT=1 `
  -e DOTNET_NOLOGO=1 `
  -v "${PWD}:/app" `
  -w /app `
  mcr.microsoft.com/dotnet/sdk:8.0 `
  dotnet publish src/HelloDotnet.csproj -c Release -r linux-x64 --self-contained true -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -o dist/linux-x64
```
После сборки в папке dist/linux-x64/ появится один файл hello-dotnet — размером ~70 MB (внутри — .NET runtime). Запустить его можно в чистом контейнере с Debian:
```shell
docker run --rm \
  -v "$(pwd)/dist/linux-x64":/dist \
  debian:stable-slim \
  /dist/hello-dotnet
```
Ожидаемый вывод:
```shell
hello-dotnet version 0.1.0
Hello from C# in GitHub Actions! 🚀📦
OS: Debian GNU/Linux 12 (bookworm)
Arch: X64
Hello, GitHub!
Sum 1..10 = 55
```
Ключевое отличие от **Python**: в **.NET** не нужно запускать сборку под каждую ОС. Один и тот же `dotnet publish -r <RID>` собирает под любую платформу — как `GOOS=windows go build` в **Go**.

### 4. Создание пустого репозитория на GitHub

Создайте пустой репозиторий `hello-dotnet` на **GitHub**.

> ⚠️ **Не добавляйте сразу `README.md`, `.gitignore` и лицензию — иначе `push` будет отклонён!**

### 5. Запушить проект

На всякий случай вернёмся в каталог проекта:
```shell
cd ~/hello-dotnet
```
Git Bash / Linux / WSL / macOS:
```shell
git init
git add .
git commit -m "Initial commit: .NET CLI with CI/CD to Releases"
git branch -M main
read -p "Введите ваш GitHub username: " GITHUB_USER
git remote add origin "https://github.com/${GITHUB_USER}/hello-dotnet.git"
git remote -v
git push -u origin main
```
PowerShell (Windows):
```powershell
git init
git add .
git commit -m "Initial commit: .NET CLI with CI/CD to Releases"
git branch -M main
$GITHUB_USER = Read-Host "Введите ваш GitHub username"
git remote add origin "https://github.com/$GITHUB_USER/hello-dotnet.git"
git remote -v
git push -u origin main
```
### 6. Первый запуск CI (без релиза)

После `push` в main откройте вкладку **Actions** в **GitHub**. **Workflow** выполняется ~2–3 минуты. После успешного **Actions** (зелёная галочка) можно продолжать.

Что произойдёт:
- **Job test** запустится и пройдёт все проверки: `dotnet format`, `dotnet build`, `dotnet test`
- **Job release** будет пропущен — потому что `push` был в ветку, а не тег

Это нормальное поведение. Релиз создаётся только при push тега v*.

### 7. Создание релиза

Когда код в main стабилен — создайте тег:
```shell
git tag v0.1.0
git push origin v0.1.0
```
**Workflow** выполняется ~3–4 минуты (5 сборок параллельно).

После успешного **Actions** (индикатор - зелёная галочка) произойдёт:
- **test** — снова прогонит тесты
- **release** — запустится, соберёт 5 бинарников параллельно (Linux, macOS, Windows — на двух архитектурах)
- Создастся **GitHub Release v0.1.0** с прикреплёнными файлами

Проверка:
```
https://github.com/<ВАШ-USERNAME>/hello-dotnet/releases
```
Там должен быть релиз **v0.1.0 с 5 файлами**:
- **hello-dotnet-linux-x64**
- **hello-dotnet-linux-arm64**
- **hello-dotnet-windows-x64.exe**
- **hello-dotnet-macos-x64**
- **hello-dotnet-macos-arm64**

### 8. Скачивание и запуск бинарника

Linux (x64):
```shell
read -p "Введите ваш GitHub username: " GITHUB_USER
wget "https://github.com/${GITHUB_USER}/hello-dotnet/releases/download/v0.1.0/hello-dotnet-linux-x64" -O hello-dotnet
chmod +x hello-dotnet
./hello-dotnet
```
macOS (Apple Silicon):
```shell
read -p "Введите ваш GitHub username: " GITHUB_USER
curl -L "https://github.com/${GITHUB_USER}/hello-dotnet/releases/download/v0.1.0/hello-dotnet-macos-arm64" -o hello-dotnet
chmod +x hello-dotnet
./hello-dotnet
```
Windows (PowerShell):
```powershell
$USERNAME = Read-Host "Введите ваш GitHub username"
Invoke-WebRequest -Uri "https://github.com/$USERNAME/hello-dotnet/releases/download/v0.1.0/hello-dotnet-windows-x64.exe" -OutFile "hello-dotnet.exe"
.\hello-dotnet.exe
```
Ожидаемый вывод:
```shell
hello-dotnet version 0.1.0
Hello from C# in GitHub Actions! 🚀📦
OS: Linux 6.5.0-27-generic
Arch: X64
Hello, GitHub!
Sum 1..10 = 55
```
Примечание: `OS` и `Arch` могут отличаться — это зависит от платформы, на которой вы запускаете бинарник. `X64` на `Intel/AMD`, `Arm64` на `Apple Silicon` и `ARM`-серверах.

Примечание: на **macOS** при первом запуске может появиться предупреждение безопасности. Обходится: Системные настройки → Приватность и безопасность → Всё равно открыть.

### 9. Обновление релиза

Внесите изменения в код (например, в `Program.cs`), обновите версию приложения до `0.2.0` и создайте новый git-тег. Старый релиз остаётся нетронутым — пользователи могут скачать любую версию.

⚠️ Релизы в **GitHub** неизменяемы. Нельзя перезаписать файлы внутри `v0.1.0`. Для нового кода — новая версия.

#### 9.1. Определите тип изменений

По **семантическому версионированию** (`MAJOR.MINOR.PATCH`):

| Что изменили | Какую версию | Пример |
|--------------|--------------|--------|
| Исправили баг | patch | `0.1.0` → `0.1.1` |
| Добавили функцию | minor | `0.1.0` → `0.2.0` |
| Сломали совместимость | major | `0.1.0` → `1.0.0` |

Наш выбор — 0.2.0

#### 9.2. Обновите версию в одном файле

В **.NET** версия хранится только в `HelloDotnet.csproj`

Файл `src/HelloDotnet.csproj`:
```xml
<PropertyGroup>
  ...
  <Version>0.2.0</Version>   <!-- ← новая версия -->
</PropertyGroup>
```
Больше нигде менять не нужно — `Program.cs` читает версию из атрибута сборки автоматически.

✅ Преимущество **.NET** перед **Python**: версия в одном месте. В **Python** она была в двух файлах (`pyproject.toml` и `__init__.py` соответственно).

#### 9.3. Проверьте форматирование

**CI** запускает dotnet format --verify-no-changes — если код не отформатирован, workflow упадёт. Проверьте локально до `push`:
```shell
cd ~/hello-dotnet
docker run --rm \
  -u "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -e DOTNET_CLI_HOME=/tmp \
  -e NUGET_PACKAGES=/tmp/nuget \
  -e DOTNET_CLI_TELEMETRY_OPTOUT=1 \
  -e DOTNET_NOLOGO=1 \
  -v "$(pwd)":/app \
  -w /app \
  mcr.microsoft.com/dotnet/sdk:8.0 \
  sh -c "dotnet format src/HelloDotnet.csproj && dotnet format tests/HelloDotnet.Tests.csproj"
```
Что делает: автоматически исправляет форматирование (без `--verify-no-changes`).

После этого закоммитьте изменения — иначе **CI** всё равно упадёт на `--verify-no-changes`.

#### 9.4. Проверьте тесты

```shell
docker run --rm \
  -u "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -e DOTNET_CLI_HOME=/tmp \
  -e NUGET_PACKAGES=/tmp/nuget \
  -e DOTNET_CLI_TELEMETRY_OPTOUT=1 \
  -e DOTNET_NOLOGO=1 \
  -v "$(pwd)":/app \
  -w /app \
  mcr.microsoft.com/dotnet/sdk:8.0 \
  dotnet test tests/HelloDotnet.Tests.csproj
```
Ожидаемый вывод:
```shell
Passed!  - Failed:     0, Passed:     2, Skipped:     0, Total:     2
```
#### 9.5. Закоммитьте и запушьте

```shell
git add .
git commit -m "feat: bump version to 0.2.0"
git push origin main
```
Что произойдёт:
- ✅ **Job test** пройдёт проверки
- ⏭️ **Job release** будет пропущен (это `push` в ветку, не тег)

#### 9.6. Создайте новый тег

```shell
git tag v0.2.0
git push origin v0.2.0
```
Что произойдёт:
- ✅ **test** — снова прогонит тесты
- ✅ **release** — соберёт 5 бинарников параллельно
- ✅ Создастся новый **Release** `v0.2.0`

#### 9.7. Проверьте результат

```
https://github.com/<ВАШ-USERNAME>/hello-dotnet/releases
```
Там будет два релиза:
- `v0.1.0` — старый (не тронут)
- `v0.2.0` — новый (с изменениями)

Скачайте новый бинарник и проверьте (Linux/WSL):
```shell
cd ~
read -p "Введите ваш GitHub username: " GITHUB_USER
URL="https://github.com/${GITHUB_USER}/hello-dotnet/releases/download/v0.2.0/hello-dotnet-linux-x64"

wget "$URL" -O hello-dotnet
chmod +x hello-dotnet
./hello-dotnet
```
Ожидаемый вывод:
```shell
hello-dotnet version 0.2.0
Hello from C# in GitHub Actions! 🚀📦
OS: Linux 6.5.0-27-generic
Arch: X64
Hello, GitHub!
Sum 1..10 = 55
```

#### 9.8. Если ошиблись в теге

Например, создали `v0.2.0`, но забыли обновить <Version> в `.csproj`.

Удалить тег локально:
```shell
git tag -d v0.2.0
```
Удалить тег на GitHub:
```shell
git push origin :refs/tags/v0.2.0
```
Удалить **Release** на **GitHub**:
Откройте `https://github.com/<ВАШ-USERNAME>/hello-dotnet/releases`, у нужного релиза нажмите **Delete**.

Исправить код и повторить:
```shell
code src/HelloDotnet.csproj
git add .
git commit -m "fix: correct version in csproj"
git push origin main

git tag v0.2.0
git push origin v0.2.0
```

#### 9.9. Краткая шпаргалка

```shell
# 1. Изменить код (откройте в VS Code)
#    - src/Program.cs

# 2. Обновить версию в одном файле (откройте в VS Code)
#    - src/HelloDotnet.csproj

# 3. Проверить формат и тесты
docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
  -e DOTNET_CLI_HOME=/tmp -e NUGET_PACKAGES=/tmp/nuget \
  -e DOTNET_CLI_TELEMETRY_OPTOUT=1 -e DOTNET_NOLOGO=1 \
  -v "$(pwd)":/app -w /app mcr.microsoft.com/dotnet/sdk:8.0 \
  sh -c "dotnet format src/HelloDotnet.csproj && dotnet format tests/HelloDotnet.Tests.csproj"

docker run --rm -u "$(id -u):$(id -g)" -e HOME=/tmp \
  -e DOTNET_CLI_HOME=/tmp -e NUGET_PACKAGES=/tmp/nuget \
  -e DOTNET_CLI_TELEMETRY_OPTOUT=1 -e DOTNET_NOLOGO=1 \
  -v "$(pwd)":/app -w /app mcr.microsoft.com/dotnet/sdk:8.0 \
  dotnet test tests/HelloDotnet.Tests.csproj

# 4. Закоммитить и запушить
git add .
git commit -m "feat: bump version to 0.2.0"
git push origin main

# 5. Создать новый тег
git tag v0.2.0
git push origin v0.2.0

# 6. Проверить: https://github.com/<username>/hello-dotnet/releases
```

Что вы освоили:
- **.NET CLI** — dotnet build, dotnet test, dotnet publish, dotnet format
- **xUnit** — тесты и их структура
- **dotnet format** — встроенный форматтер и линтер
- **Cross-compilation** — один runner собирает под 5 платформ через -r <RID>
- **Runtime Identifiers** — linux-x64, win-x64, osx-arm64
- **Self-contained + PublishSingleFile** — один файл, .NET не нужен у пользователя
- **Матричные сборки** — 5 бинарников параллельно с одного runner'а
- **GitHub Actions** — .NET toolchain, кэш NuGet, dotnet test, dotnet publish
- **GitHub Releases** — публикация бинарников через softprops/action-gh-release
- **Семантическое версионирование** — теги `v0.1.0`, `v0.2.0`
- **Обновление релиза** — полный цикл: версия → формат → тесты → тег → новый Release
- Разницу между CI и CI/CD

> **Главный урок: .NET сочетает простоту cross-compilation (как Go) с корпоративной экосистемой (как Java). Один runner — 5 бинарников. Один файл версии — никаких рассинхронов.**


> Если вы обнаружили ошибку в этом тексте — сообщите пожалуйста автору!