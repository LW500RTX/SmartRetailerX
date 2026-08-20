-- 1. Add the role column
ALTER TABLE customers ADD COLUMN role VARCHAR(20) DEFAULT 'customer';

-- 2. Promote the specific user to admin
UPDATE customers SET role = 'admin' WHERE email = 'lalanweerasooriya@gmail.com';

-- 3. Ensure the email column is set to UNIQUE
ALTER TABLE customers ADD CONSTRAINT unique_email UNIQUE (email);
