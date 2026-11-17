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
-- Table structure for table `sales_unnormalized`
--

DROP TABLE IF EXISTS `sales_unnormalized`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `sales_unnormalized` (
  `sale_id` int NOT NULL,
  `sale_date` date NOT NULL,
  `client_id` int NOT NULL,
  `client_name` varchar(100) NOT NULL,
  `client_city` varchar(100) NOT NULL,
  `product_id` int NOT NULL,
  `product_name` varchar(100) NOT NULL,
  `unit_price` decimal(10,2) NOT NULL,
  `quantity` int NOT NULL,
  PRIMARY KEY (`sale_id`,`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `sales_unnormalized`
--

LOCK TABLES `sales_unnormalized` WRITE;
/*!40000 ALTER TABLE `sales_unnormalized` DISABLE KEYS */;
INSERT INTO `sales_unnormalized` VALUES (5001,'2026-11-01',101,'Иванов Иван','Москва',201,'Монитор',15000.00,2),(5001,'2026-11-01',101,'Иванов Иван','Москва',202,'Клавиатура',2000.00,1),(5002,'2026-11-02',102,'Петрова Мария','Санкт-Петербург',203,'Мышь',1000.00,3),(5002,'2026-11-02',102,'Петрова Мария','Санкт-Петербург',204,'Наушники',3500.00,1),(5003,'2026-11-03',101,'Иванов Иван','Москва',205,'Колонки',2500.00,2),(5004,'2026-11-04',103,'Сидоров Алексей','Казань',202,'Клавиатура',2000.00,5),(5004,'2026-11-04',103,'Сидоров Алексей','Казань',203,'Мышь',1000.00,2),(5005,'2026-11-05',102,'Петрова Мария','Санкт-Петербург',201,'Монитор',15000.00,1),(5006,'2026-11-06',103,'Сидоров Алексей','Казань',204,'Наушники',3500.00,2),(5006,'2026-11-06',103,'Сидоров Алексей','Казань',205,'Колонки',2500.00,1);
/*!40000 ALTER TABLE `sales_unnormalized` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-11-11  6:56:57
