-- Migration Script for AquaSense Database

-- 1. Add the 'role' column to the existing customers table
ALTER TABLE customers
ADD COLUMN role VARCHAR(20) DEFAULT 'customer';

-- 2. Update the specified user to have the 'admin' role
UPDATE customers
SET role = 'admin'
WHERE email = 'lalanweerasooriya@gmail.com';
