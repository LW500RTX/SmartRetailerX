-- SmartRetailX Schema Initialization SQL Script
-- Target: Aurora Serverless v2 Multi-AZ Cluster (MySQL 8.0 / Aurora MySQL Compatibility)

-- 1. Create Users Table (User Management Service Context)
CREATE TABLE IF NOT EXISTS `users` (
  `id` VARCHAR(36) NOT NULL,
  `email` VARCHAR(255) NOT NULL UNIQUE,
  `password_hash` VARCHAR(255) NOT NULL,
  `role` VARCHAR(50) NOT NULL DEFAULT 'customer',
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_user_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 2. Create Orders Table (Order Processing Service Context)
CREATE TABLE IF NOT EXISTS `orders` (
  `id` VARCHAR(36) NOT NULL,
  `customer_id` VARCHAR(255) NOT NULL,
  `status` VARCHAR(50) NOT NULL DEFAULT 'Pending',
  `total_amount` DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_order_customer` (`customer_id`),
  INDEX `idx_order_status` (`status`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 3. Create Payments Table (Payment Microservice Context)
CREATE TABLE IF NOT EXISTS `payments` (
  `id` VARCHAR(36) NOT NULL,
  `order_id` VARCHAR(36) NOT NULL,
  `transaction_token` VARCHAR(255) NOT NULL UNIQUE,
  `status` VARCHAR(50) NOT NULL DEFAULT 'PENDING',
  `amount` DECIMAL(10, 2) NOT NULL DEFAULT 0.00,
  `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  INDEX `idx_payment_order` (`order_id`),
  INDEX `idx_payment_token` (`transaction_token`),
  CONSTRAINT `fk_payment_order` FOREIGN KEY (`order_id`) REFERENCES `orders` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
