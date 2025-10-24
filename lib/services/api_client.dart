import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:device_info_plus/device_info_plus.dart';
import '../utils/constants.dart';
import '../models/chr_requests.dart';

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
        },
        responseType: ResponseType.json, // Force JSON parsing
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

    final formData = FormData.fromMap({
      'Email_number': emailOrPhone,
      'password': password,
    });

    final response = await _dio.post(
      AppConstants.loginEndpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );

    return response;
  }

  // Logout
  Future<Response> logout() async {
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
    return await _dio.get(AppConstants.acceptedChildEndpoint);
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

  // Get immunization schedule
  Future<Response> getImmunizationSchedule() async {
    await _ensureInitialized();

    final response = await _dio.get(AppConstants.immunizationScheduleEndpoint);

    return response;
  }

  // Get child list with CHR status
  Future<Response> getChildList() async {
    await _ensureInitialized();
    return await _dio.get(AppConstants.childListEndpoint);
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
          debugPrint('Android 13+ detected, using private directory approach');

          // For Android 13+, try private directory first (no permissions needed)
          final privateResult = await _downloadToPrivateDirectory(chrRequest);
          if (privateResult.success) {
            debugPrint('Private directory download successful');
            return privateResult;
          }

          debugPrint(
            'Private directory failed, requesting manage external storage permission',
          );
          // If private directory fails, try requesting manage external storage permission
          final managePermission = await Permission.manageExternalStorage
              .request();
          if (managePermission.isGranted) {
            debugPrint('Manage external storage permission granted');
            return await _downloadToPublicDirectoryViaBytes(chrRequest);
          } else {
            debugPrint('Manage external storage permission denied');
            return DownloadResult.failure(
              'Storage permission denied. Please enable "All files access" in app settings.',
            );
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
    return originalUrl.replaceAll(
      RegExp(r'/(image|raw)/upload/'),
      r'/$1/upload/fl_attachment/',
    );
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
  Future<Response> claimChildWithCode(String familyCode) async {
    await _ensureInitialized();
    final formData = FormData.fromMap({'family_code': familyCode});
    return await _dio.post(
      AppConstants.claimChildWithCodeEndpoint,
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  // Request immunization (new child registration)
  Future<Response> requestImmunization(
    Map<String, dynamic> formData,
    File? babysCard,
  ) async {
    await _ensureInitialized();

    final data = FormData.fromMap(formData);

    // Add file if provided
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

    return await _dio.post(
      AppConstants.requestImmunizationEndpoint,
      data: data,
      options: Options(contentType: 'multipart/form-data'),
    );
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
      // Get app's downloads directory (private to app)
      final downloadsDir = await getDownloadsDirectory();
      if (downloadsDir == null) {
        return DownloadResult.failure('Downloads directory not available');
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

        debugPrint('File downloaded to private directory: $filePath');
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
}
