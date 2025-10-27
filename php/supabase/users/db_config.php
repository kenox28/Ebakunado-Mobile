<?php
// Database configuration
$host = 'localhost';
$dbname = 'ebakunado_db'; // Update with your actual database name
$username = 'root'; // Update with your database username
$password = ''; // Update with your database password

try {
    $pdo = new PDO("mysql:host=$host;dbname=$dbname;charset=utf8mb4", $username, $password);
    $pdo->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
    $pdo->setAttribute(PDO::ATTR_DEFAULT_FETCH_MODE, PDO::FETCH_ASSOC);
} catch (PDOException $e) {
    error_log('Database connection error: ' . $e->getMessage());
    die(json_encode([
        'status' => 'error',
        'message' => 'Database connection failed'
    ]));
}
?>
