### Самостоятельная работа: "Создание портфолио проектов с использованием Git и Markdown"

**Цель:** Освоить базовые workflow Git, научиться оформлять документацию в Markdown и создать структурированный публичный проект.

**Легенда:** Вы начинающий разработчик и хотите создать публичное портфолио на GitHub, чтобы показать свои навыки будущим работодателям.

---

> ### Это задание дает полный цикл работы с Git и Markdown!

> ## Делать только задания 1, 2 и 5

### **Задание 1: Настройка репозитория и базовое workflow**

**Цель:** Создать репозиторий, освоить коммиты и работу с ветками.

1.  **Создайте публичный репозиторий на GitHub или Gitflic:**
    *   Название: `my-dev-portfolio`
    *   Описание: "A collection of my projects and learning path"
    *   Добавьте `README.md` при создании.

2.  **Клонируйте репозиторий на локальную машину:**
    ```shell
    git clone адрес_репозитория
    ```

3.  **В VSCode откройте новый проект и создайте файл `.gitignore`:**
    *   Используйте шаблон для вашей ОС (например, из [gitignore.io](https://www.toptal.com/developers/gitignore))
    *   Добавьте в него строки для игнорирования:
        *   Локальных конфигов IDE (`.vscode/`, `.idea/`)
        *   Файлов с паролями (`config.ini`, `secrets.json`)
        *   Системных файлов (`.DS_Store`, `Thumbs.db`)
    *   Сделайте коммит:
    ```shell
    git add .gitignore
    git commit -m "Add .gitignore for common development files"
    git push origin main (или master, если используете Gitflic)
    ```

---

### **Задание 2: Создание структуры проекта в ветке `develop`**

**Цель:** Освоить создание веток и организацию проекта.

1.  **Во встроенном терминале VSCode создайте и перейдите в ветку `develop`:**
    ```shell
    git checkout -b develop
    ```

2.  **Создайте структуру папок и файлов:**
    ```
    projects/
    ├── python-web-scraper/
    │   └── README.md
    ├── java-calculator/
    │   └── README.md
    └── sql-database/
        └── README.md
    docs/
    ├── learning-path.md
    └── skills.md
    assets/
    └── images/
    ```

3.  **Заполните основные файлы используя Markdown:**

    **В `README.md` в корне** (замените основной файл):
    ```markdown
    # My Developer Portfolio

    Welcome to my portfolio! Here I document my learning journey and projects.

    ## 📁 Projects
    - [Python Web Scraper](./projects/python-web-scraper/README.md)
    - [Java Calculator](./projects/java-calculator/README.md)
    - [SQL Database Project](./projects/sql-database/README.md)

    ## 📚 Learning Path
    Check out my [learning journey](./docs/learning-path.md)

    ## 🛠 Skills
    See my [technical skills](./docs/skills.md)
    ```

    **В `projects/python-web-scraper/README.md`:**
    ```markdown
    # Python Web Scraper

    A simple web scraper for collecting data from websites.

    ## Features
    - Extracts article titles
    - Saves data to CSV
    - Handles pagination

    ## Installation
    ```shell
    pip install requests beautifulsoup4
    ```
    ```

4.  **Завершите работу в ветке `develop`:**
    ```shell
    git add .
    git commit -m "Add project structure and basic documentation"
    git push origin develop
    ```

---

> ### Задание 3 пока не делать!

### **Задание 3: Работа с feature-ветками и конфликтами**

> ### Студенты самостоятельно изучают с помощью нейронки о Feature branch!

**Цель:** Освоить работу в изолированных ветках и разрешение конфликтов.

1.  **Создайте feature-ветку для добавления нового проекта:**
    ```shell
    git checkout develop
    git checkout -b feature/add-react-project
    ```

2.  **Добавьте новый проект в `projects/react-todo-app/README.md`:**
    ```markdown
    # React Todo Application

    A modern todo app with React hooks.

    ## Features
    - Add/delete tasks
    - Mark tasks as completed
    - Local storage persistence
    ```

3.  **Обновите основной `README.md` - добавьте ссылку на новый проект в список.**

4.  **Симуляция конфликта:**
    *   Представьте, что другой разработчик тоже добавил проект в `develop` ветку
    *   Вернитесь в `develop` и "имитируйте" изменения:
    ```bash
    git checkout develop
    # Внесите изменение в тот же файл README.md - добавьте другой проект
    echo "- [Node.js API](./projects/node-api/README.md)" >> README.md
    git add README.md
    git commit -m "Add Node.js API project to main README"
    git push origin develop
    ```

5.  **Вернитесь в feature-ветку и разрешите конфликт:**
    ```shell
    git checkout feature/add-react-project
    git merge develop
    ```
    *   **Возникнет конфликт в README.md!**
    *   Откройте файл, найдите конфликтующие изменения (между `<<<<<<<` и `>>>>>>>`)
    * **Вручную отредактируйте файл** - объедините оба списка проектов
    *   Сохраните файл и завершите мерж:
    ```shell
    git add README.md
    git commit -m "Resolve merge conflict in README.md"
    ```

---

> ### Задание 4 пока не делать!

### **Задание 4: Создание Pull Request и слияние**

**Цель:** Освоить процесс code review и слияния изменений.

1.  **Запушьте feature-ветку и создайте Pull Request:**
    ```shell
    git push origin feature/add-react-project
    ```

2.  **На GitHub:**
    *   Перейдите в репозиторий
    *   Создайте Pull Request из `feature/add-react-project` в `develop`
    *   Добавьте описание: "Add React Todo App project to portfolio"
    *   Укажите ревьювера (если работаете в группе) или создайте PR самостоятельно

3.  **Симуляция code review (если работаете solo):**
    *   Оставьте комментарий к своему PR с предложением улучшения
    *   Например: "Consider adding installation instructions for the React app"

4.  **Внесите исправления (если нужно) и выполните слияние:**
    *   На GitHub нажмите "Merge pull request"
    *   Удалите ветку после слияния

---

### **Задание 5: Финальное оформление портфолио**

**Цель:** Закрепить навыки работы с Markdown.

1.  **Вернитесь в локальную ветку `develop` и обновите её:**
    ```shell
    git checkout develop
    git pull origin develop
    ```

2.  **Дополните файлы качественным Markdown-контентом:**

    **В `docs/skills.md`:**
    ```markdown
    # Technical Skills

    ## Programming Languages
    | Language | Level | Projects |
    |----------|-------|----------|
    | Python | Intermediate | [Web Scraper](../projects/python-web-scraper/README.md) |
    | Java | Beginner | [Calculator](../projects/java-calculator/README.md) |
    | SQL | Intermediate | [Database Project](../projects/sql-database/README.md) |

    ## Tools & Technologies
    - **Version Control:** Git, GitHub
    - **Databases:** MySQL, PostgreSQL
    - **IDEs:** VS Code, IntelliJ IDEA
    ```

    **В `docs/learning-path.md`:**
    ```markdown
    # My Learning Path

    ## 2025 Goals
    - [x] Learn Git and GitHub fundamentals
    - [x] Create first portfolio project
    - [ ] Complete React course
    - [ ] Build full-stack application

    ## Completed Courses
    1. **Git Complete Guide** - Udemy
    2. **Python for Everybody** - Coursera
    3. **SQL Fundamentals** - Codecademy
    ```

3.  **Завершите работу и обновите репозиторий:**
    ```shell
    git add .
    git commit -m "Enhance documentation with skills and learning path"
    git push origin develop
    ```

---

### **Критерии оценки:**

| Задание | Критерии | Баллы |
|---------|----------|-------|
| **1** | Корректный `.gitignore`, осмысленные коммиты | 20 |
| **2** | Логичная структура проекта, валидный Markdown | 25 |
| **3** | Успешное создание feature-ветки, разрешение конфликта | 25 |
| **4** | Корректно созданный PR, процесс слияния | 15 |
| **5** | Качество и полнота Markdown-документации | 15 |
| **Итого** | | **100** |

### **Что должен содержать итоговый репозиторий:**

- [ ] Публичный репозиторий на GitHub
- [ ] Файл `.gitignore`
- [ ] Ветки: `main`, `develop`
- [ ] Структуру папок `projects/`, `docs/`, `assets/`
- [ ] Не менее 4 файлов `.md` с качественным контентом
- [ ] История коммитов с осмысленными сообщениями
- [ ] Завершенный Pull Request в истории

### Выполненные задания присылать в чат Собрания или преподавателю в Телеграм

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!
