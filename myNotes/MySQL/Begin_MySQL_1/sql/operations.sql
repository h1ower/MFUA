help
SHOW VARIABLES LIKE 'character_set%';
SHOW DATABASES;
CREATE DATABASE my_database CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE my_database;
CREATE TABLE users (id INT AUTO_INCREMENT PRIMARY KEY, name VARCHAR(100) NOT NULL, email VARCHAR(100) NOT NULL UNIQUE) CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
INSERT INTO users (name, email) VALUES ('Иван Иванов', 'ivan@example.com'), ('Пётр Петров', 'petr@example.com'), ('Мария Сидорова', 'maria@example.com');
SELECT * FROM users;
SHOW DATABASES;
SHOW TABLES;
SELECT * FROM users;
INSERT INTO users (name, email) VALUES ('Павел Иванов', 'pavel@example.com');
INSERT INTO users (name, email) VALUES ('Марк Аврелий', 'mark@example.com');
SELECT * FROM users;
SELECT name, HEX(name) FROM users WHERE id = 1;
UPDATE users SET name = 'Иван Петров' WHERE id = 1;
SELECT * FROM users;
SELECT * FROM users WHERE id = 1;
SELECT name, email FROM users;
SELECT name FROM users;
SELECT name, email FROM users WHERE id = 1;
SELECT * FROM users WHERE id = 1\G
