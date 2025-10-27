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
