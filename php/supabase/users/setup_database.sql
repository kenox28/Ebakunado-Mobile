-- Complete database setup for Ebakunado Create Account functionality
-- Run this script to set up all necessary tables

-- Create users table
CREATE TABLE IF NOT EXISTS users (
    id INT AUTO_INCREMENT PRIMARY KEY,
    fname VARCHAR(100) NOT NULL,
    lname VARCHAR(100) NOT NULL,
    email VARCHAR(255) UNIQUE NOT NULL,
    phone_number VARCHAR(20) UNIQUE NOT NULL,
    gender ENUM('Male', 'Female', 'Other') NOT NULL,
    place TEXT NOT NULL,
    passw VARCHAR(255) NOT NULL,
    salt VARCHAR(32) NOT NULL,
    role ENUM('admin', 'super_admin', 'midwife', 'bhw', 'parent') DEFAULT 'parent',
    profile_img TEXT,
    family_code VARCHAR(8) UNIQUE,
    status ENUM('active', 'inactive', 'suspended') DEFAULT 'active',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_email (email),
    INDEX idx_phone_number (phone_number),
    INDEX idx_role (role),
    INDEX idx_status (status),
    INDEX idx_created_at (created_at)
);

-- Create OTP verifications table
CREATE TABLE IF NOT EXISTS otp_verifications (
    id INT AUTO_INCREMENT PRIMARY KEY,
    phone_number VARCHAR(20) NOT NULL,
    otp VARCHAR(6) NOT NULL,
    expires_at TIMESTAMP NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_phone_number (phone_number),
    INDEX idx_otp (otp),
    INDEX idx_expires_at (expires_at),
    INDEX idx_created_at (created_at)
);

-- Create locations table for cascading dropdowns
CREATE TABLE IF NOT EXISTS locations (
    id INT AUTO_INCREMENT PRIMARY KEY,
    province VARCHAR(100) NOT NULL,
    city_municipality VARCHAR(100) NOT NULL,
    barangay VARCHAR(100) NOT NULL,
    purok VARCHAR(100) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_province (province),
    INDEX idx_city_municipality (city_municipality),
    INDEX idx_barangay (barangay),
    INDEX idx_purok (purok),
    INDEX idx_province_city (province, city_municipality),
    INDEX idx_province_city_barangay (province, city_municipality, barangay)
);

-- Create activity logs table
CREATE TABLE IF NOT EXISTS activity_logs (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT,
    action VARCHAR(100) NOT NULL,
    details TEXT,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_user_id (user_id),
    INDEX idx_action (action),
    INDEX idx_created_at (created_at),
    INDEX idx_user_action (user_id, action),

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE SET NULL
);

-- Create rate limit log table
CREATE TABLE IF NOT EXISTS rate_limit_log (
    id INT AUTO_INCREMENT PRIMARY KEY,
    ip_address VARCHAR(45) NOT NULL,
    attempt_type VARCHAR(50) NOT NULL,
    attempt_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    INDEX idx_ip_address (ip_address),
    INDEX idx_attempt_type (attempt_type),
    INDEX idx_attempt_time (attempt_time),
    INDEX idx_ip_type_time (ip_address, attempt_type, attempt_time)
);

-- Insert sample Philippine locations for testing
INSERT INTO locations (province, city_municipality, barangay, purok) VALUES
-- Leyte Province
('Leyte', 'Tacloban City', 'Abucay', 'Purok 1'),
('Leyte', 'Tacloban City', 'Abucay', 'Purok 2'),
('Leyte', 'Tacloban City', 'Abucay', 'Purok 3'),
('Leyte', 'Tacloban City', 'Baras', 'Purok 1'),
('Leyte', 'Tacloban City', 'Baras', 'Purok 2'),
('Leyte', 'Tacloban City', 'Caibaan', 'Purok 1'),
('Leyte', 'Tacloban City', 'Caibaan', 'Purok 2'),

-- Cebu Province
('Cebu', 'Cebu City', 'Lahug', 'Purok 1'),
('Cebu', 'Cebu City', 'Lahug', 'Purok 2'),
('Cebu', 'Cebu City', 'Mabolo', 'Purok 1'),
('Cebu', 'Cebu City', 'Mabolo', 'Purok 2'),
('Cebu', 'Mandaue City', 'Centro', 'Purok 1'),
('Cebu', 'Mandaue City', 'Centro', 'Purok 2'),

-- Bohol Province
('Bohol', 'Tagbilaran City', 'Dao', 'Purok 1'),
('Bohol', 'Tagbilaran City', 'Dao', 'Purok 2'),
('Bohol', 'Tagbilaran City', 'Mansasa', 'Purok 1'),
('Bohol', 'Tagbilaran City', 'Mansasa', 'Purok 2'),

-- Samar Province
('Samar', 'Catbalogan City', 'Poblacion 1', 'Purok 1'),
('Samar', 'Catbalogan City', 'Poblacion 1', 'Purok 2'),
('Samar', 'Catbalogan City', 'Poblacion 2', 'Purok 1'),
('Samar', 'Catbalogan City', 'Poblacion 2', 'Purok 2')
ON DUPLICATE KEY UPDATE id=id;

-- Create a sample admin user for testing (optional)
-- Password: Admin123!
INSERT INTO users (fname, lname, email, phone_number, gender, place, passw, salt, role, status) VALUES
('Admin', 'User', 'admin@ebakunado.com', '+639123456789', 'Male', 'Leyte, Tacloban City, Abucay, Purok 1',
 '$2y$12$LQv3c1yqBWVHxkd0LHAkCOYz6TtxMQJqhN8/J1kKxzGLYADJ7xIQa', 'a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6', 'admin', 'active')
ON DUPLICATE KEY UPDATE id=id;
