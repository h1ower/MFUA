-- MySQL dump 10.13  Distrib 8.0.46, for Linux (x86_64)
--
-- Host: localhost    Database: shop_norm
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
-- Table structure for table `customers_3nf`
--

DROP TABLE IF EXISTS `customers_3nf`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `customers_3nf` (
  `customer_id` int NOT NULL AUTO_INCREMENT,
  `customer_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `customer_city` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  PRIMARY KEY (`customer_id`)
) ENGINE=InnoDB AUTO_INCREMENT=9 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `customers_3nf`
--

LOCK TABLES `customers_3nf` WRITE;
/*!40000 ALTER TABLE `customers_3nf` DISABLE KEYS */;
INSERT INTO `customers_3nf` VALUES (1,'Иван','Сочи'),(2,'Иван','Сочи'),(3,'Мария','Казань'),(4,'Пётр','Санкт-Петербург'),(8,'Новый клиент','Тверь');
/*!40000 ALTER TABLE `customers_3nf` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `order_items_3nf`
--

DROP TABLE IF EXISTS `order_items_3nf`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `order_items_3nf` (
  `order_id` int NOT NULL,
  `product_id` int NOT NULL,
  `quantity` int NOT NULL,
  PRIMARY KEY (`order_id`,`product_id`),
  KEY `product_id` (`product_id`),
  CONSTRAINT `order_items_3nf_ibfk_1` FOREIGN KEY (`order_id`) REFERENCES `orders_3nf` (`order_id`),
  CONSTRAINT `order_items_3nf_ibfk_2` FOREIGN KEY (`product_id`) REFERENCES `products_3nf` (`product_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `order_items_3nf`
--

LOCK TABLES `order_items_3nf` WRITE;
/*!40000 ALTER TABLE `order_items_3nf` DISABLE KEYS */;
INSERT INTO `order_items_3nf` VALUES (1,1,2),(2,2,1),(5,3,2);
/*!40000 ALTER TABLE `order_items_3nf` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `orders_3nf`
--

DROP TABLE IF EXISTS `orders_3nf`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `orders_3nf` (
  `order_id` int NOT NULL AUTO_INCREMENT,
  `customer_id` int NOT NULL,
  `order_date` date NOT NULL,
  PRIMARY KEY (`order_id`),
  KEY `customer_id` (`customer_id`),
  CONSTRAINT `orders_3nf_ibfk_1` FOREIGN KEY (`customer_id`) REFERENCES `customers_3nf` (`customer_id`)
) ENGINE=InnoDB AUTO_INCREMENT=6 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `orders_3nf`
--

LOCK TABLES `orders_3nf` WRITE;
/*!40000 ALTER TABLE `orders_3nf` DISABLE KEYS */;
INSERT INTO `orders_3nf` VALUES (1,1,'2026-10-01'),(2,2,'2026-10-01'),(5,4,'2026-10-04');
/*!40000 ALTER TABLE `orders_3nf` ENABLE KEYS */;
UNLOCK TABLES;

--
-- Table structure for table `products_3nf`
--

DROP TABLE IF EXISTS `products_3nf`;
/*!40101 SET @saved_cs_client     = @@character_set_client */;
/*!50503 SET character_set_client = utf8mb4 */;
CREATE TABLE `products_3nf` (
  `product_id` int NOT NULL AUTO_INCREMENT,
  `product_name` varchar(100) COLLATE utf8mb4_unicode_ci NOT NULL,
  `product_price` int NOT NULL,
  PRIMARY KEY (`product_id`)
) ENGINE=InnoDB AUTO_INCREMENT=4 DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
/*!40101 SET character_set_client = @saved_cs_client */;

--
-- Dumping data for table `products_3nf`
--

LOCK TABLES `products_3nf` WRITE;
/*!40000 ALTER TABLE `products_3nf` DISABLE KEYS */;
INSERT INTO `products_3nf` VALUES (1,'Яблоки',120),(2,'Лимоны',200),(3,'Каштаны',200);
/*!40000 ALTER TABLE `products_3nf` ENABLE KEYS */;
UNLOCK TABLES;
/*!40103 SET TIME_ZONE=@OLD_TIME_ZONE */;

/*!40101 SET SQL_MODE=@OLD_SQL_MODE */;
/*!40014 SET FOREIGN_KEY_CHECKS=@OLD_FOREIGN_KEY_CHECKS */;
/*!40014 SET UNIQUE_CHECKS=@OLD_UNIQUE_CHECKS */;
/*!40101 SET CHARACTER_SET_CLIENT=@OLD_CHARACTER_SET_CLIENT */;
/*!40101 SET CHARACTER_SET_RESULTS=@OLD_CHARACTER_SET_RESULTS */;
/*!40101 SET COLLATION_CONNECTION=@OLD_COLLATION_CONNECTION */;
/*!40111 SET SQL_NOTES=@OLD_SQL_NOTES */;

-- Dump completed on 2026-11-09  8:51:01
