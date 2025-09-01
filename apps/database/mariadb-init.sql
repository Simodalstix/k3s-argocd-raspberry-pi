-- MariaDB initialization script for sample application
-- This script sets up the database schema and initial data

-- Use the application database
USE appdb;

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Create index on email for faster lookups
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);

-- Create index on created_at for sorting
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at);

-- Insert sample data
INSERT IGNORE INTO users (name, email) VALUES 
    ('John Doe', 'john.doe@example.com'),
    ('Jane Smith', 'jane.smith@example.com'),
    ('Bob Johnson', 'bob.johnson@example.com'),
    ('Alice Brown', 'alice.brown@example.com'),
    ('Charlie Wilson', 'charlie.wilson@example.com');

-- Create a view for user statistics
CREATE OR REPLACE VIEW user_stats AS
SELECT 
    COUNT(*) as total_users,
    COUNT(CASE WHEN created_at >= DATE_SUB(CURDATE(), INTERVAL 7 DAY) THEN 1 END) as users_last_week,
    COUNT(CASE WHEN created_at >= DATE_SUB(CURDATE(), INTERVAL 30 DAY) THEN 1 END) as users_last_month,
    MIN(created_at) as first_user_created,
    MAX(created_at) as last_user_created
FROM users;

-- Display initialization results
SELECT 'MariaDB initialization completed successfully' as status;
SELECT * FROM user_stats;