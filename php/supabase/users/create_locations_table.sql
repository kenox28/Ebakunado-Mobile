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
