-- Create immunization_approvals table
CREATE TABLE IF NOT EXISTS immunization_approvals (
    id INT AUTO_INCREMENT PRIMARY KEY,
    user_id INT NOT NULL,
    baby_id VARCHAR(50) NOT NULL,
    vaccine_name VARCHAR(255) NOT NULL,
    status ENUM('pending', 'approved', 'rejected') DEFAULT 'pending',
    certificate_url TEXT,
    request_type ENUM('immunization_record', 'certificate') DEFAULT 'immunization_record',
    requested_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    approved_at TIMESTAMP NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,

    INDEX idx_user_id (user_id),
    INDEX idx_baby_id (baby_id),
    INDEX idx_status (status),
    INDEX idx_requested_at (requested_at),

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    FOREIGN KEY (baby_id) REFERENCES child_health_records(baby_id) ON DELETE CASCADE
);

-- Insert some sample data for testing
INSERT INTO immunization_approvals (user_id, baby_id, child_name, vaccine_name, status, certificate_url, request_type, requested_at, approved_at) VALUES
(1, 'BABY001', 'John Doe', 'DTP Vaccine', 'approved', 'https://res.cloudinary.com/demo/image/upload/sample.pdf', 'certificate', NOW() - INTERVAL 2 DAY, NOW() - INTERVAL 1 DAY),
(1, 'BABY002', 'Jane Smith', 'Measles Vaccine', 'pending', NULL, 'immunization_record', NOW() - INTERVAL 1 DAY, NULL),
(1, 'BABY003', 'Bob Johnson', 'Polio Vaccine', 'approved', 'https://res.cloudinary.com/demo/image/upload/sample2.pdf', 'certificate', NOW() - INTERVAL 3 DAY, NOW() - INTERVAL 2 DAY);
