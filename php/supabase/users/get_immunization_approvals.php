<?php
header('Content-Type: application/json');
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

require_once 'db_config.php';

try {
    // Get the authorization header
    $headers = getallheaders();
    $auth_header = isset($headers['Authorization']) ? $headers['Authorization'] : '';
    $cookie_header = isset($headers['Cookie']) ? $headers['Cookie'] : '';

    // Verify authentication
    if (empty($auth_header) && empty($cookie_header)) {
        throw new Exception('Authentication required');
    }

    // Get user ID from session or JWT token
    $user_id = null;

    if (!empty($auth_header)) {
        // Handle JWT token authentication
        $token = str_replace('Bearer ', '', $auth_header);
        // Verify JWT token and extract user ID
        // This is a simplified version - implement proper JWT verification
        $token_parts = explode('.', $token);
        if (count($token_parts) === 3) {
            $payload = json_decode(base64_decode($token_parts[1]), true);
            $user_id = $payload['user_id'] ?? null;
        }
    }

    if (!$user_id) {
        throw new Exception('Invalid authentication');
    }

    // Get immunization approvals from database
    $query = "
        SELECT
            ir.id,
            ir.baby_id,
            chr.name as child_name,
            ir.vaccine_name,
            ir.status,
            ir.certificate_url,
            ir.requested_at,
            ir.approved_at,
            ir.created_at,
            ir.updated_at
        FROM immunization_approvals ir
        LEFT JOIN child_health_records chr ON ir.baby_id = chr.baby_id
        WHERE ir.user_id = ?
        ORDER BY ir.created_at DESC
    ";

    $stmt = $pdo->prepare($query);
    $stmt->execute([$user_id]);
    $approvals = $stmt->fetchAll(PDO::FETCH_ASSOC);

    // Format the response
    $response = [
        'status' => 'success',
        'data' => $approvals,
        'message' => count($approvals) > 0 ? 'Immunization approvals retrieved successfully' : 'No immunization approvals found'
    ];

    echo json_encode($response);

} catch (Exception $e) {
    error_log('Error in get_immunization_approvals.php: ' . $e->getMessage());

    $response = [
        'status' => 'error',
        'message' => $e->getMessage()
    ];

    echo json_encode($response);
}
?>
