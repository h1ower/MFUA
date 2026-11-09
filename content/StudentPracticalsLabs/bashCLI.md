## Самостоятельная работа по командной строке Bash

Выполнять задания, используя bash-выражения типа `mkdir -p project/{css,js,img/ico,fonts,pages}`

> ## Задания выполнять на [Github.com](github.com) или [Gitflic.ru](https://gitflic.ru/)

> ### Для выполнения этих заданий нужно создать новый публичный репозиторий с README.md

> ### Для выполнения этих заданий нужно использовать VSCode и git

1. Создание простой структуры блога
    ```text
    blog/
    ├── posts/
    ├── pages/
    ├── images/
    ├── css/
    └── js/
    ```
1. Двухуровневая структура интернет-магазина
    ```text
    shop/
    ├── products/
    │   ├── electronics/
    │   └── clothing/
    ├── users/
    │   └── profiles/
    └── orders/
    ```
1. Структура веб-проекта с файлами
    ```text
    webapp/
    ├── css/
    │   └── style.css
    ├── js/
    │   └── script.js
    ├── images/
    │   ├── logo.png
    │   └── icons/
    │       └── favicon.ico
    ├── pages/
    │   └── about.html
    └── index.html
    ```
1. Проект с шаблонами и конфигами
    ```text
    framework/
    ├── src/
    │   ├── core/
    │   │   ├── config/
    │   │   │   └── settings.json
    │   │   └── helpers/
    │   │       └── utils.js
    │   └── modules/
    │       ├── auth/
    │       │   └── login.js
    │       └── api/
    │           └── router.js
    ├── tests/
    │   ├── unit/
    │   └── integration/
    ├── docs/
    └── .github/
        └── workflows/
            └── test.yml
    ```
1. Генерация структуры по описанию (рекомендую использовать ИИ)
    ```text
    Описание структуры:
    - Корень: project-x
    - Внутри: src (с подпапками app и lib), tests (с подпапками unit и e2e)
    - В src/app: controllers (с файлами user.js и product.js), models (с файлом db.js)
    - В src/lib: helpers (с файлом logger.js), config (с файлом settings.js)
    - В корне: файлы .env, Dockerfile, docker-compose.yml
    - В tests/unit: файл app.test.js
    - В tests/e2e: файл flow.test.js
    ```
1. Выполнить команды из [примеров](/content/Bash/BashCLI.md) - сохранить их вывод в скриншотах, кроме сетевых команд


> ### Результаты с содержанием выражений поместить в README.md, запушить и прислать мне ссылку

## 💡 **Советы для студентов:**
- Используйте сервисы **Github** или **Gitlab** для удалённого хранения кода
- Тестируйте ваши скрипты, прежде чем отправить их в облако
- Начинайте с простых задач
- Всегда сначала проверяйте команду в отдельной папке (mkdir test && cd test).
- Используйте tree для визуализации (tree -a --dirsfirst).
- Разбивайте сложные структуры на части, если не уверены.
- Помните, что {a,b} работает только в Bash, не в sh (но вам это пока не важно).
- Экспериментируйте с echo {a,b}/{c,d} — это безопасный способ проверить, что сгенерируется.

> Если вы обнаружили ошибку в этом тексте - сообщите пожалуйста автору!