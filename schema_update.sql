-- 1. Add the role column (using IF NOT EXISTS as requested)
ALTER TABLE customers ADD COLUMN IF NOT EXISTS role VARCHAR(50) DEFAULT 'customer';

-- 2. Ensure the email column is unique to prevent duplicate registration errors
ALTER TABLE customers ADD CONSTRAINT unique_email UNIQUE (email);
