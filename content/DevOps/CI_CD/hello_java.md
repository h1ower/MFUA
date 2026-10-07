## Pipeline CI на Java в GitHub Actions

**Apache Maven** — это инструмент для автоматизации сборки проектов (чаще всего на **Java**), управления зависимостями и структурирования кода.

**Цель** - знакомство с `Maven` и `Java CI`, получить небольшой размер Docker-образа

Что узнаете:
- `maven` — `pom.xml`, фазы: `clean`, `verify`, `package`
- `JUnit 5` — как пишутся тесты и как они запускаются
- `Shade Plugin` — как собрать «толстый» JAR с main-классом
- `Multi-stage Docker` — зачем разделять сборку и запуск
- `GitHub Actions` — `JDK`, кэш `Maven`, `docker build`
- Разницу между `Maven`-сборкой и `Docker`-сборкой

> `clean`, `verify`, `package` - фазы жизненного цикла Maven

### 1. Создайте на вашем компьютере, в корневом каталоге текущего пользователя такую структуру:

```text
hello-java/
├── .github/workflows/ci.yml
├── src/
│   ├── main/java/Hello.java
│   └── test/java/HelloTest.java
├── .gitignore
├── Dockerfile
└── pom.xml
```
Для перехода в корень текущего пользователя компьютера выполните команду:
```shell
cd ~
```
Создать папку со структурой проекта (в терминале):
```shell
mkdir -p hello-java/{.github/workflows,src/main/java,src/test/java} && \
cd hello-java && \

cat > pom.xml << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>hello-java</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>

    <properties>
        <maven.compiler.source>17</maven.compiler.source>
        <maven.compiler.target>17</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <dependencies>
        <dependency>
            <groupId>org.junit.jupiter</groupId>
            <artifactId>junit-jupiter</artifactId>
            <version>5.10.2</version>
            <scope>test</scope>
        </dependency>
    </dependencies>

    <build>
        <finalName>hello-java</finalName>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-surefire-plugin</artifactId>
                <version>3.2.5</version>
            </plugin>

            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-shade-plugin</artifactId>
                <version>3.5.2</version>
                <executions>
                    <execution>
                        <phase>package</phase>
                        <goals>
                            <goal>shade</goal>
                        </goals>
                        <configuration>
                            <transformers>
                                <transformer implementation="org.apache.maven.plugins.shade.resource.ManifestResourceTransformer">
                                    <mainClass>Hello</mainClass>
                                </transformer>
                            </transformers>
                        </configuration>
                    </execution>
                </executions>
            </plugin>
        </plugins>
    </build>
</project>
EOF

cat > src/main/java/Hello.java << 'EOF'
public class Hello {
    public static void main(String[] args) {
        System.out.println("Hello from Java in Docker! ☕🐳");
        System.out.println("Java version: " + System.getProperty("java.version"));
        System.out.println("OS: " + System.getProperty("os.name"));

        if (args.length > 0) {
            System.out.println("Аргументы:");
            for (int i = 0; i < args.length; i++) {
                System.out.println("  " + (i + 1) + ": " + args[i]);
            }
        }
    }
}
EOF

cat > src/test/java/HelloTest.java << 'EOF'
import org.junit.jupiter.api.Test;
import static org.junit.jupiter.api.Assertions.*;

public class HelloTest {

    @Test
    void testGreeting() {
        String greeting = "Hello from Java in Docker!";
        assertTrue(greeting.contains("Hello"));
        assertTrue(greeting.contains("Docker"));
    }

    @Test
    void testSimpleMath() {
        assertEquals(4, 2 + 2);
    }
}
EOF

cat > Dockerfile << 'EOF'
# Этап 1: сборка
FROM maven:3.9-eclipse-temurin-17 AS builder
WORKDIR /build
COPY pom.xml .
COPY src ./src
RUN mvn clean package -DskipTests

# Этап 2: запуск
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app
COPY --from=builder /build/target/hello-java.jar app.jar
ENTRYPOINT ["java", "-jar", "app.jar"]
EOF

cat > .github/workflows/ci.yml << 'EOF'
name: Java CI

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v4

      - name: Set up JDK 17
        uses: actions/setup-java@v4
        with:
          java-version: '17'
          distribution: 'temurin'
          cache: maven

      - name: Build and test
        run: mvn clean verify

      - name: Build Docker image
        run: docker build -t hello-java .
EOF

cat > .gitignore << 'EOF'
target/
.idea/
*.iml
.vscode/
EOF

echo "✅ Структура создана:"
find . -type f | sort
```

### 2. Сборка проекта

Перейти в проект
```shell
cd ~/hello-java
```
- 2.1. Сборка и тесты внутри **Docker** (`Maven` и `JDK` на хосте не нужны)

Git Bash/Linux/WSL/macOS
```shell
mkdir -p ~/.m2-docker-cache
docker run --rm \
  -u "$(id -u):$(id -g)" \
  -e HOME=/tmp \
  -e MAVEN_CONFIG=/tmp/.m2 \
  -v "$(pwd)":/app \
  -v ~/.m2-docker-cache:/tmp/.m2 \
  -w /app \
  maven:3.9-eclipse-temurin-17 \
  mvn clean verify
```
Windows
```shell
docker run --rm `
  -v "${PWD}:/app" `
  -w /app `
  maven:3.9-eclipse-temurin-17 `
  mvn clean verify
```
В Windows:
- Docker Desktop должен быть запущен
- Папка проекта должна быть в разрешённых для Docker Desktop дисках. Обычно C:\ разрешён по умолчанию, но если проект на D:\ — зайдите в Docker Desktop → Settings → Resources → File Sharing и добавьте диск
- Первый запуск будет долгим

- 2.2. Сборка Docker-образа (нужно находиться в каталоге проекта)
```shell
docker build -t hello-java .
```
- 2.3. Запуск контейнера
```shell
docker run --rm hello-java
```
Ожидаемый вывод
```text
Hello from Java in Docker! ☕🐳
Java version: 17.0.x
OS: Linux
```
> **В `GitHub Actions` `mvn` `clean` `verify` работает напрямую, потому что образ `ubuntu-latest` уже содержит `JDK` и `Maven`. Роль «чистого окружения» играет сам раннер, а не Docker-контейнер**

### 3. Создание пустого репозитория на GitHub

Создайте пустой репозиторий `hello-java` на [GitHub](https://github.com/new).

> ⚠️ **Не добавляйте README, .gitignore и лицензию — иначе push будет отклонён.**

### 4. Запушить проект

> **Если впервые пушитесь на этом компьютере, задайте имя и email:**
```shell
git config --global user.name "Ваше Имя"
git config --global user.email "ваш@email.com"
```

Находясь в каталоге проекта, выполните последовательно:
1. Инициализация
```shell
git init
```
2. Подготовка:
```shell
git add .
```
3. Коммит:
```shell
git commit -m "Initial commit: Java app with Docker and CI"
```
4. Создание ветки `main`
```shell
git branch -M main
```
5. Создание удалённой копии проекта
```shell
git remote add origin https://github.com/ВАШ-USERNAME/hello-java.git
```
где `username` — ваш логин на `GitHub`
6. Пуш
```shell
git push -u origin main
```
> **После push откройте вкладку Actions в GitHub — workflow «Java CI» запустится автоматически.**

> **После успешного Actions (зелёная лампочка во вкладке Actions) можно добавить файл README.md, .gitignore и лицензию.**

### 5. Если push не проходит

> **`Repository not found`**
> Проверьте, что репозиторий `hello-java` создан и URL в `git remote -v` совпадает с `https://github.com/ваш-логин/hello-java.git`.
>
> **`Authentication failed`**
> GitHub больше не принимает пароль от аккаунта. Используйте Personal Access Token (Settings → Developer settings → Personal access tokens) или SSH-ключ. Или используйте VS Code.
>
> **`Rejected (non-fast-forward)`**
> На GitHub уже есть коммит (например, README). Выполните:
> ```shell
> git pull --rebase origin main
> git push origin main
> ```
>
> **`src refspec main does not match any`**
> Вы ещё не сделали ни одного коммита. Выполните `git add .` и `git commit -m "..."`.

***

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!

