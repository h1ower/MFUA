-- MySQL dump 10.13  Distrib 8.0.46, for Linux (x86_64)
--
-- Host: localhost    Database: sales_norm
-- ------------------------------------------------------
-- Server version	8.0.46

/*!40101 SET @OLD_CHARACTER_SET_CLIENT=@@CHARACTER_SET_CLIENT */;
/*!40101 SET @OLD_CHARACTER_SET_RESULTS=@@CHARACTER_SET_RESULTS */;
/*!40101 SET @OLD_COLLATION_CONNECTION=@@COLLATION_CONNECTION */;
/*!50503 SET NAMES utf8mb4 */;
/*!40103 SET @OLD_TIME_ZONE=@@TIME_ZONE */;
/*!40103 SET TIME_ZONE='+00:00' */;
/*!40014 SET @OLD_UNIQUE_CHECKS=@@UNIQUE_CHECKS, UNIQUE_CHECKS=0 */;
/*!40014 SET @OLD_FOREIGN_KEY_CHECKS=@@FOREIGN_KEY_CHECKS, FOREIGN_KEY_CHECKS=0 */;
/*!40101 SET @OLD_SQL_MODE=@@SQL_MODE, SQL_MODE='NO_AUTO_VALUE_ON_ZERO' */;
/*!40111 SET @OLD_SQL_NOTES=@@SQL_NOTES, SQL_NOTES=0 */;

--
-- Table structure for table `orders_bad`
--

DROP TABLE IF EXISTS `orders_bad`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `orders_bad` (
  `order_id` int DEFAULT NULL,
  `order_date` date DEFAULT NULL,
  `client_id` int DEFAULT NULL,
  `client_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `product_id` int DEFAULT NULL,
  `product_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `price` decimal(10,2) DEFAULT NULL,
  `category_id` int DEFAULT NULL,
  `category_name` varchar(100) COLLATE utf8mb4_unicode_ci DEFAULT NULL,
  `quantity` int DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `orders_bad`
--

LOCK TABLES `orders_bad` WRITE;
/*!40000 ALTER TABLE `orders_bad` DISABLE KEYS */;
INSERT INTO `orders_bad` VALUES (7001,'2026-11-01',101,'Иванов Иван',201,'Монитор',15000.00,10,'Периферия',2),(7001,'2026-11-01',101,'Иванов Иван',202,'Клавиатура',2000.00,10,'Периферия',1),(7002,'2026-11-02',102,'Петрова Мария',203,'Мышь',1000.00,10,'Периферия',3),(7002,'2026-11-02',102,'Петрова Мария',204,'Наушники',3500.00,20,'Аудио',1),(7003,'2026-11-03',101,'Иванов Иван',205,'Колонки',2500.00,20,'Аудио',2),(7004,'2026-11-04',103,'Сидоров Алексей',202,'Клавиатура',2000.00,10,'Периферия',5),(7004,'2026-11-04',103,'Сидоров Алексей',203,'Мышь',1000.00,10,'Периферия',2),(7005,'2026-11-05',102,'Петрова Мария',201,'Монитор',15000.00,10,'Периферия',1),(7006,'2026-11-06',103,'Сидоров Алексей',204,'Наушники',3500.00,20,'Аудио',2),(7006,'2026-11-06',103,'Сидоров Алексей',205,'Колонки',2500.00,20,'Аудио',1);
/*!40000 ALTER TABLE `orders_bad` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-11-13 10:14:40
