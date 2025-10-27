<?php
header('Access-Control-Allow-Origin: *');
header('Access-Control-Allow-Methods: GET, POST, OPTIONS');
header('Access-Control-Allow-Headers: Content-Type, Authorization');

// Handle preflight OPTIONS request
if ($_SERVER['REQUEST_METHOD'] === 'OPTIONS') {
    exit(0);
}

try {
    // Get the URL parameter
    $url = $_GET['url'] ?? '';

    if (empty($url)) {
        throw new Exception('URL parameter is required');
    }

    // Decode the URL
    $decoded_url = urldecode($url);

    // Validate URL (basic security check)
    if (!filter_var($decoded_url, FILTER_VALIDATE_URL)) {
        throw new Exception('Invalid URL format');
    }

    // Check if URL is from allowed domains (add your allowed domains here)
    $allowed_domains = ['res.cloudinary.com', 'your-domain.com'];
    $url_host = parse_url($decoded_url, PHP_URL_HOST);

    if (!in_array($url_host, $allowed_domains)) {
        throw new Exception('URL not allowed');
    }

    // Set headers for file download
    header('Content-Type: application/pdf');
    header('Content-Disposition: attachment; filename="chr_document.pdf"');

    // Initialize cURL
    $ch = curl_init();

    curl_setopt_array($ch, [
        CURLOPT_URL => $decoded_url,
        CURLOPT_RETURNTRANSFER => true,
        CURLOPT_FOLLOWLOCATION => true,
        CURLOPT_MAXREDIRS => 5,
        CURLOPT_TIMEOUT => 30,
        CURLOPT_SSL_VERIFYPEER => false, // For development only
        CURLOPT_USERAGENT => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36',
        CURLOPT_HTTPHEADER => [
            'Accept: application/pdf,*/*',
            'Accept-Encoding: gzip, deflate, br',
            'Connection: keep-alive'
        ]
    ]);

    // Execute the request
    $response = curl_exec($ch);
    $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
    $error = curl_error($ch);

    curl_close($ch);

    // Check for errors
    if ($error) {
        throw new Exception('cURL error: ' . $error);
    }

    if ($http_code !== 200) {
        throw new Exception('HTTP error: ' . $http_code);
    }

    if (empty($response)) {
        throw new Exception('Empty response received');
    }

    // Output the file content
    echo $response;

} catch (Exception $e) {
    error_log('Error in download_chr_doc.php: ' . $e->getMessage());

    // Return JSON error response instead of file content
    header('Content-Type: application/json');
    echo json_encode([
        'status' => 'error',
        'message' => $e->getMessage()
    ]);
}
?>
