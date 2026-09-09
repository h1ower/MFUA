## Dockerfile. Java приложение

**Java** — строго типизированный объектно‑ориентированный язык программирования общего назначения

> Для выполнения этого задания лучше используйте WSL/Ubuntu, установленную на вашем компьютере с Windows или любой другой десктопный Linux

> Никогда в разработке не используйте русские имена файлов и каталогов!

> Никогда в разработке не используйте пробелы и спец.символы в именах файлов и каталогов!

### 1. Структура проекта
```
my-java-app/
├── Dockerfile
├── pom.xml
└── src/
    └── main/
        └── java/
            └── com/
                └── example/
                    └── MyApp.java
```

В каталоге для Docker-проектов создать одной bash-командой всю структуру для нового приложения:
```shell
mkdir -p my-java-app/src/main/java/com/example && \
touch my-java-app/Dockerfile my-java-app/pom.xml my-java-app/src/main/java/com/example/MyApp.java && cd my-java-app
```

### 2. Содержимое файла `Dockerfile`
```dockerfile
# ---- Этап 1: Сборка с Maven ----
# Используем образ с Maven и Eclipse Temurin JDK 17
FROM maven:3.8.5-eclipse-temurin-17 AS builder
WORKDIR /build
# Копируем файл проекта и исходный код
COPY pom.xml .
COPY src ./src
# Собираем приложение (без запуска тестов для скорости)
RUN mvn clean package -DskipTests
# ---- Этап 2: Финальный образ для запуска ----
# Используем минимальный JRE-образ от Eclipse Temurin
FROM eclipse-temurin:17-jre-alpine
# Создаём непривилегированного пользователя (рекомендация безопасности)
RUN addgroup -S appgroup && adduser -S appuser -G appgroup
WORKDIR /app
# Копируем JAR-файл из первого этапа
COPY --from=builder --chown=appuser:appgroup /build/target/*.jar app.jar
USER appuser
ENTRYPOINT ["java", "-jar", "app.jar"]
```

### 3. Содержимое файла `myapp.jar`
```java
package com.example;

public class MyApp {
    public static void main(String[] args) {
        System.out.println("Hello, World! from Dockerized Java! 🐳");
    }
}
```

### 4. Содержимое файла `pom.xml`
```xml
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0
         http://maven.apache.org/xsd/maven-4.0.0.xsd">
    <modelVersion>4.0.0</modelVersion>

    <groupId>com.example</groupId>
    <artifactId>my-java-app</artifactId>
    <version>1.0.0</version>
    <packaging>jar</packaging>

    <properties>
        <maven.compiler.source>17</maven.compiler.source>
        <maven.compiler.target>17</maven.compiler.target>
        <project.build.sourceEncoding>UTF-8</project.build.sourceEncoding>
    </properties>

    <build>
        <plugins>
            <plugin>
                <groupId>org.apache.maven.plugins</groupId>
                <artifactId>maven-jar-plugin</artifactId>
                <version>3.3.0</version>
                <configuration>
                    <archive>
                        <manifest>
                            <mainClass>com.example.MyApp</mainClass>
                        </manifest>
                    </archive>
                </configuration>
            </plugin>
        </plugins>
    </build>
</project>
```

### 5. Сборка и запуск

В командной строке, находясь в папке `my-java-app`, выполнить:
```shell
docker build -t my-java-app .
```
> Флаг `-t` задает имя образа

Создание и запуск контейнера:
```shell
docker run --rm my-java-app
```

Вы должны увидеть: `Hello, World! from Dockerized Java! 🐳`