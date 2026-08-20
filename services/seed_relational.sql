-- SmartRetailX Relational Database Baseline Seed Dataset
-- Target: Aurora Serverless MySQL database cluster

-- 1. Populate Users (SHA-256 hashed mock passwords)
INSERT INTO `users` (`id`, `email`, `password_hash`, `role`)
VALUES
  ('usr-uuid-admin-0001', 'admin@smartretailx.com', '8c6976e5b5410415bde908bd4dee15dfb167a9c873fc4bb8a81f6f2ab448a918', 'admin'),
  ('usr-uuid-manager-0002', 'manager@smartretailx.com', 'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3', 'store_manager'),
  ('customer-001', 'lalan@smartretailx.com', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', 'customer'),
  ('customer-002', 'john.doe@smartretailx.com', '5e884898da28047151d0e56f8dc6292773603d0d6aabbdd62a11ef721d1542d8', 'customer')
ON DUPLICATE KEY UPDATE `role` = VALUES(`role`);

-- 2. Populate Orders (Sample retail transaction states)
INSERT INTO `orders` (`id`, `customer_id`, `status`, `total_amount`)
VALUES
  ('ord-uuid-001', 'customer-001', 'Pending', 129.99),
  ('ord-uuid-002', 'customer-001', 'Paid', 89.50),
  ('ord-uuid-003', 'customer-002', 'Shipped', 450.00),
  ('ord-uuid-004', 'customer-002', 'Pending', 45.00)
ON DUPLICATE KEY UPDATE `status` = VALUES(`status`), `total_amount` = VALUES(`total_amount`);

-- 3. Populate Payments (Linked to active orders)
INSERT INTO `payments` (`id`, `order_id`, `transaction_token`, `status`, `amount`)
VALUES
  ('pay-uuid-001', 'ord-uuid-001', 'tx-pending-token-101', 'PENDING', 129.99),
  ('pay-uuid-002', 'ord-uuid-002', 'tx-approved-token-102', 'APPROVED', 89.50),
  ('pay-uuid-003', 'ord-uuid-003', 'tx-approved-token-103', 'APPROVED', 450.00)
ON DUPLICATE KEY UPDATE `status` = VALUES(`status`);
