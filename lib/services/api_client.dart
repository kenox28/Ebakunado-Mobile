import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/constants.dart';
import '../models/chr_requests.dart';
import '../models/child_registration_form.dart';
import '../models/immunization_approval.dart' as immunization;
import '../models/create_account_request.dart';
import '../models/otp_response.dart';
import '../models/locations_response.dart';
import '../models/create_account_response.dart';
import '../models/csrf_token.dart';
import '../models/google_sign_in_response.dart';

class AuthExpiredException implements Exception {
  final String message;
  AuthExpiredException(this.message);
}

class ApiClient {
  static ApiClient? _instance;
  late Dio _dio;
  late CookieJar _cookieJar;
  bool _isInitialized = false;

  static ApiClient get instance {
    _instance ??= ApiClient._internal();
    return _instance!;
  }

  ApiClient._internal();

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      await _initializeDio();
      _isInitialized = true;
    }
  }

  Future<void> _initializeDio() async {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'Cache-Control': 'no-cache, no-store, must-revalidate',
          'Pragma': 'no-cache',
          'Expires': '0',
          'User-Agent':
              'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36',
        },
        responseType: ResponseType.json, // Force JSON parsing
      ),
    );

    // Handle SSL certificate validation - ALWAYS ALLOW FOR RELEASE BUILD FIX
    // This is critical for release builds to work
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        (_dio.httpClientAdapter as IOHttpClientAdapter).onHttpClientCreate =
            (HttpClient client) {
              // ALWAYS allow all certificates - required for release builds
              client.badCertificateCallback =
                  (X509Certificate cert, String host, int port) {
                    return true; // Always allow - fixes release build blocking
                  };
              return client;
            };
      } catch (e) {
        // If adapter setup fails, continue anyway
      }
    }

    // Add request interceptor to log all requests and add cache-busting (BEFORE cookie manager)
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          // Ensure User-Agent is set (mimics browser to avoid server blocking)
          if (!options.headers.containsKey('User-Agent')) {
            options.headers['User-Agent'] =
                'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.120 Mobile Safari/537.36';
          }

          // Add cache-busting headers to prevent stale responses
          // Only add to GET requests or if not using FormData
          final isFormData = options.data is FormData;
          if (!isFormData) {
            options.headers['Cache-Control'] =
                'no-cache, no-store, must-revalidate';
            options.headers['Pragma'] = 'no-cache';
            options.headers['Expires'] = '0';
          }

          // Add timestamp to GET requests as cache-busting parameter
          if (options.method == 'GET') {
            options.queryParameters['_t'] = DateTime.now()
                .millisecondsSinceEpoch
                .toString();
          }

          debugPrint('🌐 Making request to: ${options.uri}');
          debugPrint('🌐 Full URL: ${options.baseUrl}${options.path}');
          debugPrint('🌐 Method: ${options.method}');
          debugPrint('🌐 Headers: ${options.headers}');
          debugPrint('🌐 Data type: ${options.data.runtimeType}');
          handler.next(options);
        },
      ),
    );

    // Initialize cookie jar for session management
    final appDocDir = await getApplicationDocumentsDirectory();
    _cookieJar = PersistCookieJar(
      storage: FileStorage('${appDocDir.path}/.cookies/'),
    );
    _dio.interceptors.add(CookieManager(_cookieJar));

    // Add response interceptor for error handling
    _dio.interceptors.add(
      InterceptorsWrapper(
        onResponse: (response, handler) {
          // Handle JSON string responses
          if (response.data is String) {
            try {
              response.data = json.decode(response.data);
            } catch (e) {
              // Failed to parse JSON string, continue with original data
            }
          }

          // Check for unauthorized responses in JSON
          if (response.data is Map<String, dynamic>) {
            final message =
                response.data['message']?.toString().toLowerCase() ?? '';
            if (message.contains('unauthor') || message.contains('session')) {
              throw AuthExpiredException('Session expired');
            }
          }
          handler.next(response);
        },
        onError: (error, handler) {
          // Enhanced error logging for debugging
          debugPrint('═══════════════════════════════════════');
          debugPrint('🚨 DIO ERROR DETAILS 🚨');
          debugPrint('═══════════════════════════════════════');
          debugPrint('Error Type: ${error.type}');
          debugPrint('Error Message: ${error.message}');
          debugPrint('Request URL: ${error.requestOptions.uri}');
          debugPrint('Request Method: ${error.requestOptions.method}');
          debugPrint('Request Headers: ${error.requestOptions.headers}');
          debugPrint('Request Data: ${error.requestOptions.data}');

          if (error.type == DioExceptionType.connectionTimeout ||
              error.type == DioExceptionType.receiveTimeout ||
              error.type == DioExceptionType.sendTimeout) {
            debugPrint('⏱️ Timeout error: ${error.type}');
            debugPrint(
              '⏱️ Timeout Duration: ${error.requestOptions.connectTimeout}',
            );
          } else if (error.type == DioExceptionType.connectionError) {
            debugPrint('🔌 Connection error: ${error.message}');
            debugPrint('🔌 Error Object: ${error.error}');
            debugPrint('🔌 Error Runtime Type: ${error.error?.runtimeType}');
            if (error.error is SocketException) {
              final socketError = error.error as SocketException;
              debugPrint('🔌 Socket Exception: ${socketError.message}');
              debugPrint('🔌 OS Error: ${socketError.osError}');
            }
          } else if (error.response != null) {
            debugPrint('❌ HTTP Error: ${error.response?.statusCode}');
            debugPrint('❌ Response Headers: ${error.response?.headers}');
            debugPrint('❌ Response Data: ${error.response?.data}');
          } else {
            debugPrint('❌ Unknown error: ${error.type}');
            debugPrint('❌ Error Object: ${error.error}');
            if (error.error is FormatException) {
              final formatError = error.error as FormatException;
              debugPrint('❌ FormatException: ${formatError.message}');
              debugPrint('❌ FormatException Source: ${formatError.source}');
              debugPrint('❌ FormatException Offset: ${formatError.offset}');
            }
            // Try to get raw response if available
            if (error.response != null) {
              debugPrint(
                '❌ Response Status Code: ${error.response?.statusCode}',
              );
              debugPrint(
                '❌ Response Data Type: ${error.response?.data.runtimeType}',
              );
              if (error.response?.data is String) {
                final responseStr = error.response!.data as String;
                debugPrint(
                  '❌ Response Data (first 1000 chars): ${responseStr.length > 1000 ? responseStr.substring(0, 1000) : responseStr}',
                );
              } else {
                debugPrint('❌ Response Data: ${error.response?.data}');
              }
            }
            debugPrint('❌ Stack Trace: ${error.stackTrace}');
          }
          debugPrint('═══════════════════════════════════════');

          if (error.response?.statusCode == 401) {
            throw AuthExpiredException('Session expired');
          }
          handler.next(error);
        },
      ),
    );
  }

  // Login with form data
  Future<Response> login(String emailOrPhone, String password) async {
    await _ensureInitialized();

    debugPrint('═══════════════════════════════════════');
    debugPrint('🔐 LOGIN REQUEST DETAILS 🔐');
    debugPrint('═══════════════════════════════════════');
    debugPrint(
      'Endpoint: ${AppConstants.baseUrl}${AppConstants.loginEndpoint}',
    );
    debugPrint(
      'Full URL: ${AppConstants.baseUrl}${AppConstants.loginEndpoint}',
    );
    debugPrint(
      'Email/Phone: ${emailOrPhone.replaceRange(0, emailOrPhone.length > 3 ? emailOrPhone.length - 3 : emailOrPhone.length, "*" * (emailOrPhone.length > 3 ? emailOrPhone.length - 3 : emailOrPhone.length))}',
    );
    debugPrint('Password Length: ${password.length}');

    final formData = FormData.fromMap({
      'Email_number': emailOrPhone,
      'password': password,
    });

    debugPrint('FormData Fields: ${formData.fields}');
    debugPrint('FormData Files: ${formData.files}');
    debugPrint('═══════════════════════════════════════');

    try {
      final response = await _dio.post(
        AppConstants.loginEndpoint,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      debugPrint('✅ Login Response Status: ${response.statusCode}');
      debugPrint('✅ Login Response Data: ${response.data}');

      return response;
    } catch (e) {
      debugPrint('❌ Login Exception: $e');
      debugPrint('❌ Exception Type: ${e.runtimeType}');
      rethrow;
    }
  }

  // Logout
  Future<Response> logout() async {
    // Ensure Dio and cookies are initialized before making the request.
    // This is important for the very first logout after fresh install.
    await _ensureInitialized();
    return await _dio.post(AppConstants.logoutEndpoint);
  }

  // Get notifications
  Future<Response> getNotifications() async {
    return await _dio.get(AppConstants.notificationsEndpoint);
  }

  // Mark notification as read
  Future<Response> markNotificationRead(String notificationId) async {
    final formData = FormData.fromMap({'id': notificationId});

    return await _dio.post(
      AppConstants.markNotificationReadEndpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  // Mark all notifications as read
  Future<Response> markAllNotificationsRead() async {
    return await _dio.post(AppConstants.markAllNotificationsReadEndpoint);
  }

  // Get daily notifications (alternative to direct Supabase queries)
  Future<Response> getDailyNotifications() async {
    return await _dio.get(AppConstants.dailyNotificationsEndpoint);
  }

  // Get children summary
  Future<Response> getChildrenSummary({String? filter}) async {
    final queryParams = filter != null
        ? {'filter': filter}
        : <String, dynamic>{};
    return await _dio.get(
      AppConstants.childrenSummaryEndpoint,
      queryParameters: queryParams,
    );
  }

  // Get accepted children
  Future<Response> getAcceptedChildren() async {
    // Use scope=all to get all children including transfers
    return await _dio.get(
      AppConstants.acceptedChildEndpoint,
      queryParameters: {'scope': 'all'},
    );
  }

  // Get dashboard summary
  Future<Response> getDashboardSummary() async {
    await _ensureInitialized();
    return await _dio.get(AppConstants.dashboardSummaryEndpoint);
  }

  // Get child details
  Future<Response> getChildDetails(String babyId) async {
    await _ensureInitialized();
    final formData = FormData.fromMap({'baby_id': babyId});

    final response = await _dio.post(
      AppConstants.childDetailsEndpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return response;
  }

  // Download Baby Card PDF directly from Cloudinary URL - returns raw bytes
  Future<Uint8List> downloadBabyCardFromUrl(String docUrl) async {
    await _ensureInitialized();

    // Download directly from Cloudinary (public URL, no auth needed)
    final response = await _dio.get<List<int>>(
      docUrl,
      options: Options(responseType: ResponseType.bytes),
    );

    return Uint8List.fromList(response.data ?? []);
  }

  // Get immunization schedule
  // Optional babyId parameter: when provided, backend will include transferred children
  // When not provided, backend filters by status='accepted' only
  Future<Response> getImmunizationSchedule({String? babyId}) async {
    await _ensureInitialized();

    final queryParameters = babyId != null && babyId.isNotEmpty
        ? {'baby_id': babyId}
        : null;

    try {
      final response = await _dio.get(
        AppConstants.immunizationScheduleEndpoint,
        queryParameters: queryParameters,
      );

      return response;
    } on DioException catch (e) {
      // If JSON parsing failed, try to get raw response
      if (e.type == DioExceptionType.unknown && e.error is FormatException) {
        debugPrint('⚠️ JSON Parse Error - Attempting to get raw response');

        // Try to get raw response by making request with plain text
        try {
          final rawResponse = await _dio.get(
            AppConstants.immunizationScheduleEndpoint,
            queryParameters: queryParameters,
            options: Options(responseType: ResponseType.plain),
          );

          debugPrint('📄 Raw Server Response (first 500 chars):');
          debugPrint(
            rawResponse.data.toString().substring(
              0,
              rawResponse.data.toString().length > 500
                  ? 500
                  : rawResponse.data.toString().length,
            ),
          );

          // Try to extract JSON from response (may have PHP warnings before it)
          try {
            final responseStr = rawResponse.data.toString();

            // Try to find JSON object in the response (handles PHP warnings before JSON)
            final jsonMatch = RegExp(
              r'\{.*\}',
              dotAll: true,
            ).firstMatch(responseStr);
            if (jsonMatch != null) {
              final jsonStr = jsonMatch.group(0)!;
              debugPrint(
                '📄 Extracted JSON from response (length: ${jsonStr.length})',
              );
              final jsonData = json.decode(jsonStr);
              // Return as if it was parsed normally
              return Response(
                requestOptions: rawResponse.requestOptions,
                data: jsonData,
                statusCode: rawResponse.statusCode,
                statusMessage: rawResponse.statusMessage,
                headers: rawResponse.headers,
              );
            } else {
              // No JSON found, try parsing entire response
              final jsonData = json.decode(responseStr);
              return Response(
                requestOptions: rawResponse.requestOptions,
                data: jsonData,
                statusCode: rawResponse.statusCode,
                statusMessage: rawResponse.statusMessage,
                headers: rawResponse.headers,
              );
            }
          } catch (parseError) {
            debugPrint('❌ Failed to parse as JSON: $parseError');
            debugPrint('📄 Full response: ${rawResponse.data}');
            rethrow;
          }
        } catch (retryError) {
          debugPrint('❌ Failed to get raw response: $retryError');
          rethrow;
        }
      }
      rethrow;
    }
  }

  // Get child list with CHR status
  Future<Response> getChildList() async {
    await _ensureInitialized();
    return await _dio.get(AppConstants.childListEndpoint);
  }

  // Get user info (for QR generation - parent profile image and name)
  Future<Response> getUserInfo(String userId) async {
    await _ensureInitialized();
    final formData = FormData.fromMap({'user_id': userId});
    return await _dio.post(
      AppConstants.getUserInfoEndpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  // CHR Request methods
  Future<Response> requestChrDoc(String babyId, String requestType) async {
    await _ensureInitialized();
    final formData = FormData.fromMap({
      'baby_id': babyId,
      'request_type': requestType, // 'transfer' or 'school'
    });
    return await _dio.post(
      AppConstants.requestChrDocEndpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<Response> getChrDocStatus(String babyId) async {
    await _ensureInitialized();
    final formData = FormData.fromMap({'baby_id': babyId});
    return await _dio.post(
      AppConstants.getChrDocStatusEndpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<Response> getMyChrRequests() async {
    await _ensureInitialized();
    return await _dio.get(AppConstants.getMyChrRequestsEndpoint);
  }

  // Immunization Approval methods
  Future<Response> getImmunizationApprovals() async {
    await _ensureInitialized();
    return await _dio.get(AppConstants.getImmunizationApprovalsEndpoint);
  }

  // Download immunization certificate with modern permission handling
  Future<DownloadResult> downloadImmunizationCertificate(
    immunization.ImmunizationApproval approval,
  ) async {
    await _ensureInitialized();

    try {
      // Check Android version and request appropriate permissions
      if (Platform.isAndroid) {
        final isAndroid13OrHigher = await _isAndroid13OrHigher();

        if (isAndroid13OrHigher) {
          debugPrint(
            'Android 13+ detected, requesting manage external storage permission',
          );

          // For Android 13+, request manage external storage permission first
          final managePermission = await Permission.manageExternalStorage
              .request();
          if (managePermission.isGranted) {
            debugPrint('Manage external storage permission granted');
            return await _downloadImmunizationCertificateToPublicDirectoryViaBytes(
              approval,
            );
          } else {
            debugPrint(
              'Manage external storage permission denied, trying private directory',
            );
            // Fallback to private directory if permission denied
            final privateResult =
                await _downloadImmunizationCertificateToPrivateDirectory(
                  approval,
                );
            if (privateResult.success) {
              debugPrint('Private directory download successful');
              return privateResult;
            } else {
              return DownloadResult.failure(
                'Storage permission denied. Please enable "All files access" in app settings to save to Downloads folder.',
              );
            }
          }
        } else {
          debugPrint(
            'Older Android version detected, requesting storage permission',
          );
          // For older Android versions, request storage permission
          final permission = await Permission.storage.request();
          if (!permission.isGranted) {
            debugPrint('Storage permission denied for older Android');
            return DownloadResult.failure(
              'Storage permission denied. Please enable storage access in settings.',
            );
          }
          debugPrint('Storage permission granted for older Android');
        }
      }

      // Try direct download first
      final directResult = await _downloadImmunizationCertificateDirect(
        approval,
      );
      if (directResult.success) {
        return directResult;
      }

      // Fallback to proxy download
      return await _downloadImmunizationCertificateViaProxy(approval);
    } catch (e) {
      return DownloadResult.failure('Download failed: $e');
    }
  }

  // Add Child method
  Future<Response> addChild(Map<String, dynamic> childData) async {
    await _ensureInitialized();
    final formData = FormData.fromMap(childData);
    return await _dio.post(
      AppConstants.addChildEndpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  // Download CHR Document methods with modern permission handling
  Future<DownloadResult> downloadChrDocument(ChrRequest chrRequest) async {
    await _ensureInitialized();

    try {
      // Check Android version and request appropriate permissions
      if (Platform.isAndroid) {
        final isAndroid13OrHigher = await _isAndroid13OrHigher();

        if (isAndroid13OrHigher) {
          debugPrint(
            'Android 13+ detected, requesting manage external storage permission',
          );

          // For Android 13+, request manage external storage permission first
          final managePermission = await Permission.manageExternalStorage
              .request();
          if (managePermission.isGranted) {
            debugPrint('Manage external storage permission granted');
            // Try direct download first, fallback to proxy if it fails
            final directResult = await _downloadToPublicDirectoryViaBytes(
              chrRequest,
            );
            if (directResult.success) {
              return directResult;
            }
            debugPrint('Direct download failed, trying proxy download');
            return await _downloadViaProxy(chrRequest);
          } else {
            debugPrint(
              'Manage external storage permission denied, trying private directory',
            );
            // Fallback to private directory if permission denied
            final privateResult = await _downloadToPrivateDirectory(chrRequest);
            if (privateResult.success) {
              debugPrint('Private directory download successful');
              return privateResult;
            } else {
              return DownloadResult.failure(
                'Storage permission denied. Please enable "All files access" in app settings to save to Downloads folder.',
              );
            }
          }
        } else {
          debugPrint(
            'Older Android version detected, requesting storage permission',
          );
          // For older Android versions, request storage permission
          final permission = await Permission.storage.request();
          if (!permission.isGranted) {
            debugPrint('Storage permission denied for older Android');
            return DownloadResult.failure(
              'Storage permission denied. Please enable storage access in settings.',
            );
          }
          debugPrint('Storage permission granted for older Android');
          // Try direct download first, fallback to proxy if it fails
          final directResult = await _downloadDirect(chrRequest);
          if (directResult.success) {
            return directResult;
          }
          debugPrint('Direct download failed, trying proxy download');
          return await _downloadViaProxy(chrRequest);
        }
      }

      // For non-Android platforms or if we reach here
      // Try direct download first, fallback to proxy if it fails
      final directResult = await _downloadDirect(chrRequest);
      if (directResult.success) {
        return directResult;
      }

      // Fallback to proxy download
      return await _downloadViaProxy(chrRequest);
    } catch (e) {
      return DownloadResult.failure('Download failed: $e');
    }
  }

  Future<DownloadResult> _downloadDirect(ChrRequest chrRequest) async {
    try {
      final transformedUrl = _transformCloudinaryUrl(chrRequest.docUrl);
      final response = await _dio.get(
        transformedUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        // For Android 13+, use private directory, for older versions use public directory
        String filePath;
        if (Platform.isAndroid) {
          final isAndroid13OrHigher = await _isAndroid13OrHigher();
          if (isAndroid13OrHigher) {
            filePath = await _saveToPrivateDirectory(
              response.data,
              chrRequest.getFileName(),
            );
          } else {
            filePath = await _saveToPublicDirectory(
              response.data,
              chrRequest.getFileName(),
            );
          }
        } else {
          filePath = await _saveToPrivateDirectory(
            response.data,
            chrRequest.getFileName(),
          );
        }

        return DownloadResult.success(filePath);
      }
    } catch (e) {
      debugPrint('Direct download error: $e');
      // Fall through to proxy
    }
    return DownloadResult.failure('Direct download failed');
  }

  Future<DownloadResult> _downloadViaProxy(ChrRequest chrRequest) async {
    try {
      final encodedUrl = Uri.encodeComponent(chrRequest.docUrl);
      final proxyUrl =
          '${AppConstants.baseUrl}/php/supabase/users/download_chr_doc.php?url=$encodedUrl';

      debugPrint('Proxy download URL: $proxyUrl');

      final response = await _dio.get(
        proxyUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        debugPrint('Proxy download successful, saving file');
        // Use the same directory logic as direct download
        String filePath;
        if (Platform.isAndroid) {
          final isAndroid13OrHigher = await _isAndroid13OrHigher();
          if (isAndroid13OrHigher) {
            filePath = await _saveToPrivateDirectory(
              response.data,
              chrRequest.getFileName(),
            );
          } else {
            filePath = await _saveToPublicDirectory(
              response.data,
              chrRequest.getFileName(),
            );
          }
        } else {
          filePath = await _saveToPrivateDirectory(
            response.data,
            chrRequest.getFileName(),
          );
        }

        debugPrint('Proxy download saved to: $filePath');
        return DownloadResult.success(filePath);
      }
    } catch (e) {
      debugPrint('Proxy download error: $e');
      return DownloadResult.failure('Proxy download failed: ${e.toString()}');
    }
    return DownloadResult.failure('Download failed');
  }

  String _transformCloudinaryUrl(String originalUrl) {
    debugPrint('Original Cloudinary URL: $originalUrl');

    // Transform Cloudinary URL for direct download
    // Replace /image/upload/ or /raw/upload/ with /image/upload/fl_attachment/ or /raw/upload/fl_attachment/
    String transformedUrl = originalUrl.replaceAll(
      RegExp(r'/(image|raw)/upload/'),
      r'/$1/upload/fl_attachment/',
    );

    debugPrint('Transformed Cloudinary URL: $transformedUrl');
    return transformedUrl;
  }

  // Save file to private directory (no permissions needed)
  Future<String> _saveToPrivateDirectory(
    List<int> bytes,
    String fileName,
  ) async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    debugPrint('File saved to private directory: ${file.path}');
    return file.path;
  }

  // Save file to public Downloads directory (requires permissions on Android 13+)
  Future<String> _saveToPublicDirectory(
    List<int> bytes,
    String fileName,
  ) async {
    final directory = await getDownloadsDirectory();
    if (directory == null) {
      // Fallback to private directory if public directory not available
      return await _saveToPrivateDirectory(bytes, fileName);
    }

    final file = File('${directory.path}/$fileName');
    await file.writeAsBytes(bytes);
    debugPrint('File saved to public directory: ${file.path}');
    return file.path;
  }

  // Clear cookies (for logout)
  Future<void> clearCookies() async {
    await _cookieJar.deleteAll();
  }

  // Claim child with family code
  Future<ClaimChildResult> claimChildWithCode(String familyCode) async {
    await _ensureInitialized();
    final formData = FormData.fromMap({'family_code': familyCode});
    final response = await _dio.post(
      AppConstants.claimChildWithCodeEndpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    final payload = response.data is String
        ? json.decode(response.data)
        : response.data;

    if (payload is Map<String, dynamic>) {
      return ClaimChildResult.fromJson(payload);
    }

    throw Exception('Unexpected response from claim_child_with_code endpoint.');
  }

  Future<ClaimChildResult> previewChildByCode(String familyCode) async {
    await _ensureInitialized();
    final formData = FormData.fromMap({'family_code': familyCode});
    final response = await _dio.post(
      AppConstants.previewChildByCodeEndpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    final payload = response.data is String
        ? json.decode(response.data)
        : response.data;

    if (payload is Map<String, dynamic>) {
      return ClaimChildResult.fromJson(payload);
    }

    throw Exception('Unexpected response from preview_child_by_code endpoint.');
  }

  // Request immunization (new child registration)
  Future<ChildRegistrationResult> requestImmunization(
    ChildRegistrationRequest request, {
    File? babysCard,
  }) async {
    await _ensureInitialized();

    final formMap = request.toFormMap();
    final vaccines =
        (formMap['vaccines_received[]'] as List<String>?) ?? const <String>[];
    formMap.remove('vaccines_received[]');
    if (vaccines.isNotEmpty) {
      formMap['vaccines_received'] = vaccines.join(',');
    }

    final data = FormData.fromMap(formMap, ListFormat.multiCompatible);

    if (babysCard != null) {
      data.files.add(
        MapEntry(
          'babys_card',
          MultipartFile.fromFileSync(
            babysCard.path,
            filename: 'babys_card_${DateTime.now().millisecondsSinceEpoch}.jpg',
          ),
        ),
      );
    }

    final response = await _dio.post(
      AppConstants.requestImmunizationEndpoint,
      data: data,
      options: Options(contentType: 'multipart/form-data'),
    );

    final payload = response.data is String
        ? json.decode(response.data)
        : response.data;

    if (payload is Map<String, dynamic>) {
      return ChildRegistrationResult.fromJson(payload);
    }

    throw Exception('Unexpected response from request_immunization endpoint.');
  }

  // Get user profile data
  Future<Response> getProfileData() async {
    await _ensureInitialized();
    return await _dio.get(AppConstants.getProfileDataEndpoint);
  }

  // Update user profile
  Future<Response> updateProfile(Map<String, dynamic> formData) async {
    await _ensureInitialized();
    final data = FormData.fromMap(formData);
    return await _dio.post(
      AppConstants.updateProfileEndpoint,
      data: data,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  // Upload profile photo
  Future<Response> uploadProfilePhoto(File photo) async {
    await _ensureInitialized();
    final data = FormData.fromMap({
      'photo': MultipartFile.fromFileSync(
        photo.path,
        filename: 'profile_photo_${DateTime.now().millisecondsSinceEpoch}.jpg',
      ),
    });
    return await _dio.post(
      AppConstants.uploadProfilePhotoEndpoint,
      data: data,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  // Create Account API Methods

  // Send OTP for phone verification
  Future<OtpResponse> sendOtp(String phoneNumber) async {
    await _ensureInitialized();

    print('Sending OTP to: $phoneNumber');
    print('Endpoint: ${AppConstants.baseUrl}${AppConstants.sendOtpEndpoint}');

    final formData = FormData.fromMap({'phone_number': phoneNumber});

    try {
      final response = await _dio.post(
        AppConstants.sendOtpEndpoint,
        data: formData,
        options: Options(
          contentType: 'multipart/form-data',
          // Increase timeouts for OTP requests (SMS can take longer)
          sendTimeout: const Duration(seconds: 60),
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      print('OTP Response: ${response.data}');
      return OtpResponse.fromJson(response.data);
    } on DioException catch (e) {
      // Handle specific DioException types
      String errorMessage = 'Failed to send OTP';

      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        errorMessage =
            'Request timeout. Please check your internet connection and try again.';
      } else if (e.type == DioExceptionType.connectionError) {
        errorMessage =
            'Connection error. Please check your internet connection.';
      } else if (e.message?.contains('Connection closed') == true) {
        errorMessage =
            'Server connection closed. The server may be busy. Please try again in a moment.';
      } else if (e.response != null) {
        // Server responded with error
        errorMessage =
            e.response?.data['message'] ??
            'Failed to send OTP. Please try again.';
      } else {
        errorMessage =
            'Network error: ${e.message ?? "Unknown error"}. Please try again.';
      }

      print('OTP Error: ${e.type} - ${e.message}');
      throw Exception(errorMessage);
    } catch (e) {
      print('OTP Error Details: $e');
      rethrow;
    }
  }

  // Verify OTP
  Future<OtpResponse> verifyOtp(String otp) async {
    await _ensureInitialized();

    final formData = FormData.fromMap({'otp': otp});

    final response = await _dio.post(
      AppConstants.verifyOtpEndpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return OtpResponse.fromJson(response.data);
  }

  // Get locations (provinces, cities, barangays, puroks)
  Future<LocationsResponse> getLocations({
    String? type,
    String? province,
    String? cityMunicipality,
    String? barangay,
  }) async {
    await _ensureInitialized();

    final queryParams = <String, dynamic>{};
    if (type != null) queryParams['type'] = type;
    if (province != null) queryParams['province'] = province;
    if (cityMunicipality != null)
      queryParams['city_municipality'] = cityMunicipality;
    if (barangay != null) queryParams['barangay'] = barangay;

    print('Fetching locations with params: $queryParams');
    print('Endpoint: ${AppConstants.baseUrl}${AppConstants.getPlacesEndpoint}');

    final response = await _dio.get(
      AppConstants.getPlacesEndpoint,
      queryParameters: queryParams,
    );

    print('Locations Response: ${response.data}');
    return LocationsResponse.fromJson(response.data);
  }

  // Generate CSRF token
  Future<CsrfToken> generateCsrfToken() async {
    await _ensureInitialized();

    final response = await _dio.get(AppConstants.generateCsrfEndpoint);
    return CsrfToken.fromJson(response.data);
  }

  // Create account
  Future<CreateAccountResponse> createAccount(
    CreateAccountRequest request,
  ) async {
    await _ensureInitialized();

    // Use special mobile app token as per PHP endpoint requirements
    final requestWithCsrf = CreateAccountRequest(
      fname: request.fname,
      lname: request.lname,
      email: request.email,
      number: request.number,
      gender: request.gender,
      relationship: request.relationship,
      province: request.province,
      cityMunicipality: request.cityMunicipality,
      barangay: request.barangay,
      purok: request.purok,
      password: request.password,
      confirmPassword: request.confirmPassword,
      csrfToken: 'BYPASS_FOR_MOBILE_APP', // Special token for mobile apps
      mobileAppRequest: true,
      skipOtp: false, // OTP already verified in previous step
      agreedToTerms: request.agreedToTerms,
    );

    print('Creating account with data: ${requestWithCsrf.toJson()}');

    final formData = FormData.fromMap(requestWithCsrf.toJson());

    final response = await _dio.post(
      AppConstants.createAccountEndpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    print('Create Account Response: ${response.data}');
    return CreateAccountResponse.fromJson(response.data);
  }

  // Generic GET request
  Future<Response> get(
    String path, {
    Map<String, dynamic>? queryParameters,
  }) async {
    return await _dio.get(path, queryParameters: queryParameters);
  }

  // Generic POST request
  Future<Response> post(String path, {dynamic data}) async {
    return await _dio.post(path, data: data);
  }

  // Check if Android version is 13 or higher (API 33+)
  Future<bool> _isAndroid13OrHigher() async {
    if (!Platform.isAndroid) return false;

    try {
      final androidInfo = await DeviceInfoPlugin().androidInfo;
      final sdkInt = androidInfo.version.sdkInt;
      return sdkInt >= 33; // API 33 = Android 13
    } catch (e) {
      debugPrint('Error checking Android version: $e');
      return false;
    }
  }

  // Download to app private directory (no permissions needed)
  Future<DownloadResult> _downloadToPrivateDirectory(
    ChrRequest chrRequest,
  ) async {
    try {
      // Get app's documents directory (private to app)
      final appDir = await getApplicationDocumentsDirectory();

      // Create a downloads subdirectory within the app directory
      final downloadsDir = Directory('${appDir.path}/Downloads');
      if (!downloadsDir.existsSync()) {
        await downloadsDir.create();
      }

      // Create the file path
      final fileName = chrRequest.getFileName();
      final filePath = '${downloadsDir.path}/$fileName';

      // Download the file
      final transformedUrl = _transformCloudinaryUrl(chrRequest.docUrl);
      final response = await _dio.get(
        transformedUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        // Write file to private directory
        final file = File(filePath);
        await file.writeAsBytes(response.data);

        debugPrint('File downloaded to private app directory: $filePath');
        return DownloadResult.success(filePath);
      } else {
        debugPrint(
          'Private directory download failed with status: ${response.statusCode}',
        );
        return DownloadResult.failure(
          'Download failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('Error downloading to private directory: $e');
      return DownloadResult.failure('Download failed: $e');
    }
  }

  // Download to public directory with manage external storage permission
  Future<DownloadResult> _downloadToPublicDirectoryViaBytes(
    ChrRequest chrRequest,
  ) async {
    try {
      final transformedUrl = _transformCloudinaryUrl(chrRequest.docUrl);
      final response = await _dio.get(
        transformedUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        final filePath = await _saveToPublicDirectory(
          response.data,
          chrRequest.getFileName(),
        );
        return DownloadResult.success(filePath);
      }

      return DownloadResult.failure('Download failed: ${response.statusCode}');
    } catch (e) {
      debugPrint('Error downloading to public directory: $e');
      return DownloadResult.failure('Download failed: $e');
    }
  }

  // Immunization Certificate Download Methods
  Future<DownloadResult> _downloadImmunizationCertificateDirect(
    immunization.ImmunizationApproval approval,
  ) async {
    try {
      final transformedUrl = _transformCloudinaryUrl(approval.certificateUrl!);
      final response = await _dio.get(
        transformedUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        // For Android 13+, use private directory, for older versions use public directory
        String filePath;
        if (Platform.isAndroid) {
          final isAndroid13OrHigher = await _isAndroid13OrHigher();
          if (isAndroid13OrHigher) {
            filePath = await _saveToPrivateDirectory(
              response.data,
              approval.getFileName(),
            );
          } else {
            filePath = await _saveToPublicDirectory(
              response.data,
              approval.getFileName(),
            );
          }
        } else {
          filePath = await _saveToPrivateDirectory(
            response.data,
            approval.getFileName(),
          );
        }

        return DownloadResult.success(filePath);
      }
    } catch (e) {
      debugPrint('Direct immunization certificate download error: $e');
      // Fall through to proxy
    }
    return DownloadResult.failure('Direct download failed');
  }

  Future<DownloadResult> _downloadImmunizationCertificateViaProxy(
    immunization.ImmunizationApproval approval,
  ) async {
    try {
      final encodedUrl = Uri.encodeComponent(approval.certificateUrl!);
      final proxyUrl =
          '${AppConstants.baseUrl}/php/supabase/users/download_immunization_certificate.php?url=$encodedUrl';

      final response = await _dio.get(
        proxyUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        debugPrint(
          'Proxy immunization certificate download successful, saving file',
        );
        // Use the same directory logic as direct download
        String filePath;
        if (Platform.isAndroid) {
          final isAndroid13OrHigher = await _isAndroid13OrHigher();
          if (isAndroid13OrHigher) {
            filePath = await _saveToPrivateDirectory(
              response.data,
              approval.getFileName(),
            );
          } else {
            filePath = await _saveToPublicDirectory(
              response.data,
              approval.getFileName(),
            );
          }
        } else {
          filePath = await _saveToPrivateDirectory(
            response.data,
            approval.getFileName(),
          );
        }

        debugPrint('Proxy download saved to: $filePath');
        return DownloadResult.success(filePath);
      }
    } catch (e) {
      debugPrint('Proxy immunization certificate download error: $e');
      return DownloadResult.failure('Proxy download failed: ${e.toString()}');
    }
    return DownloadResult.failure('Download failed');
  }

  // Download immunization certificate to app private directory (no permissions needed)
  Future<DownloadResult> _downloadImmunizationCertificateToPrivateDirectory(
    immunization.ImmunizationApproval approval,
  ) async {
    try {
      // Get app's documents directory (private to app)
      final appDir = await getApplicationDocumentsDirectory();

      // Create a downloads subdirectory within the app directory
      final downloadsDir = Directory('${appDir.path}/Downloads');
      if (!downloadsDir.existsSync()) {
        await downloadsDir.create();
      }

      // Create the file path
      final fileName = approval.getFileName();
      final filePath = '${downloadsDir.path}/$fileName';

      // Download the file
      final transformedUrl = _transformCloudinaryUrl(approval.certificateUrl!);
      final response = await _dio.get(
        transformedUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        // Write file to private directory
        final file = File(filePath);
        await file.writeAsBytes(response.data);

        debugPrint(
          'Immunization certificate downloaded to private app directory: $filePath',
        );
        return DownloadResult.success(filePath);
      } else {
        debugPrint(
          'Private directory download failed with status: ${response.statusCode}',
        );
        return DownloadResult.failure(
          'Download failed: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint(
        'Error downloading immunization certificate to private directory: $e',
      );
      return DownloadResult.failure('Download failed: $e');
    }
  }

  // Download immunization certificate to public directory with manage external storage permission
  Future<DownloadResult>
  _downloadImmunizationCertificateToPublicDirectoryViaBytes(
    immunization.ImmunizationApproval approval,
  ) async {
    try {
      final transformedUrl = _transformCloudinaryUrl(approval.certificateUrl!);
      final response = await _dio.get(
        transformedUrl,
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        final filePath = await _saveToPublicDirectory(
          response.data,
          approval.getFileName(),
        );
        return DownloadResult.success(filePath);
      }

      return DownloadResult.failure('Download failed: ${response.statusCode}');
    } catch (e) {
      debugPrint(
        'Error downloading immunization certificate to public directory: $e',
      );
      return DownloadResult.failure('Download failed: $e');
    }
  }

  // Forgot Password API Methods

  // Request password reset (send OTP via email or SMS)
  Future<Response> forgotPassword(String emailPhone) async {
    await _ensureInitialized();

    print('Requesting password reset for: $emailPhone');
    print(
      'Endpoint: ${AppConstants.baseUrl}${AppConstants.forgotPasswordEndpoint}',
    );

    final formData = FormData.fromMap({'email_phone': emailPhone});

    final response = await _dio.post(
      AppConstants.forgotPasswordEndpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    print('Forgot Password Response: ${response.data}');
    return response;
  }

  // Verify reset OTP
  Future<Response> verifyResetOtp(String otp) async {
    await _ensureInitialized();

    print('Verifying reset OTP: $otp');
    print(
      'Endpoint: ${AppConstants.baseUrl}${AppConstants.verifyResetOtpEndpoint}',
    );

    final formData = FormData.fromMap({'otp': otp});

    final response = await _dio.post(
      AppConstants.verifyResetOtpEndpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    print('Verify Reset OTP Response: ${response.data}');
    return response;
  }

  // Reset password
  Future<Response> resetPassword(
    String newPassword,
    String confirmPassword,
  ) async {
    await _ensureInitialized();

    print('Resetting password');
    print(
      'Endpoint: ${AppConstants.baseUrl}${AppConstants.resetPasswordEndpoint}',
    );

    final formData = FormData.fromMap({
      'new_password': newPassword,
      'confirm_password': confirmPassword,
    });

    final response = await _dio.post(
      AppConstants.resetPasswordEndpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    print('Reset Password Response: ${response.data}');
    return response;
  }

  // ============================================
  // Google Sign-In Methods
  // ============================================

  /// Google Sign-Up - For new users registering with Google
  /// Requires Google ID token + profile information (phone, address, etc.)
  Future<GoogleSignInResponse> googleSignUp(GoogleSignUpRequest request) async {
    await _ensureInitialized();

    debugPrint('═══════════════════════════════════════');
    debugPrint('🔵 GOOGLE SIGN-UP REQUEST 🔵');
    debugPrint('═══════════════════════════════════════');
    debugPrint(
      'Endpoint: ${AppConstants.baseUrl}${AppConstants.googleSignupEndpoint}',
    );

    final response = await _dio.post(
      AppConstants.googleSignupEndpoint,
      data: request.toJson(),
      options: Options(contentType: 'application/json'),
    );

    debugPrint('Google Sign-Up Response: ${response.data}');

    Map<String, dynamic> responseData;
    if (response.data is String) {
      responseData = json.decode(response.data);
    } else {
      responseData = response.data;
    }

    return GoogleSignInResponse.fromJson(responseData);
  }

  /// Google Login - For existing users signing in with Google
  /// Only requires Google ID token
  Future<GoogleSignInResponse> googleLogin(String credential) async {
    await _ensureInitialized();

    debugPrint('═══════════════════════════════════════');
    debugPrint('🔵 GOOGLE LOGIN REQUEST 🔵');
    debugPrint('═══════════════════════════════════════');
    debugPrint(
      'Endpoint: ${AppConstants.baseUrl}${AppConstants.googleLoginEndpoint}',
    );

    final response = await _dio.post(
      AppConstants.googleLoginEndpoint,
      data: {'credential': credential},
      options: Options(contentType: 'application/json'),
    );

    debugPrint('Google Login Response: ${response.data}');

    Map<String, dynamic> responseData;
    if (response.data is String) {
      responseData = json.decode(response.data);
    } else {
      responseData = response.data;
    }

    return GoogleSignInResponse.fromJson(responseData);
  }

  // Baby Card PDF Generation Endpoints

  /// Get Baby Card layout configuration JSON
  Future<Map<String, dynamic>> getBabyCardLayout() async {
    await _ensureInitialized();
    final response = await _dio.get(AppConstants.getBabyCardLayoutEndpoint);

    if (response.data is String) {
      return json.decode(response.data);
    }
    return response.data as Map<String, dynamic>;
  }

  /// Get immunization records for a specific child
  Future<List<Map<String, dynamic>>> getMyImmunizationRecords(
    String babyId,
  ) async {
    await _ensureInitialized();

    final formData = FormData.fromMap({'baby_id': babyId});
    final response = await _dio.post(
      AppConstants.getMyImmunizationRecordsEndpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    Map<String, dynamic> responseData;
    if (response.data is String) {
      responseData = json.decode(response.data);
    } else {
      responseData = response.data as Map<String, dynamic>;
    }

    if (responseData['status'] == 'success') {
      final data = responseData['data'] as List;
      return data.cast<Map<String, dynamic>>();
    }

    throw Exception(
      responseData['message'] ?? 'Failed to load immunization records',
    );
  }

  /// Download Baby Card background image as bytes
  Future<List<int>> getBabyCardBackground() async {
    await _ensureInitialized();

    final response = await _dio.get(
      '/assets/images/babycard.jpg',
      options: Options(responseType: ResponseType.bytes),
    );

    return response.data as List<int>;
  }
}
