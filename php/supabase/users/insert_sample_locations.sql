-- Insert sample Philippine locations for testing
-- This is sample data - replace with actual Philippine locations data

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
