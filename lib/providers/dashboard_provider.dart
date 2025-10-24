import 'package:flutter/foundation.dart';
import 'package:dio/dio.dart';
import '../services/api_client.dart';
import '../models/child.dart';

class DashboardProvider extends ChangeNotifier {
  DashboardSummary? _summary;
  ChildrenSummaryResponse? _childrenSummary;
  List<AcceptedChild> _acceptedChildren = [];
  bool _isLoading = false;
  String _selectedFilter = 'upcoming'; // 'upcoming' or 'missed'

  DashboardSummary? get summary => _summary;
  ChildrenSummaryResponse? get childrenSummary => _childrenSummary;
  List<AcceptedChild> get acceptedChildren => _acceptedChildren;
  bool get isLoading => _isLoading;
  String get selectedFilter => _selectedFilter;

  Future<void> loadDashboardData() async {
    _setLoading(true);

    try {
      // Load all dashboard data in parallel
      final futures = await Future.wait([
        ApiClient.instance.getDashboardSummary(),
        ApiClient.instance.getChildrenSummary(
          filter: _selectedFilter,
        ), // Use current filter
        ApiClient.instance.getAcceptedChildren(),
      ]);

      // Parse dashboard summary
      if (futures[0].data['status'] == 'success') {
        _summary = DashboardSummary.fromJson(futures[0].data);
      }

      // Parse children summary
      if (futures[1].data['status'] == 'success') {
        _childrenSummary = ChildrenSummaryResponse.fromJson(futures[1].data);
      }

      // Parse accepted children
      if (futures[2].data is List) {
        _acceptedChildren = (futures[2].data as List)
            .map((item) => AcceptedChild.fromJson(item))
            .toList();
      }

      notifyListeners();
    } on DioException catch (e) {
      debugPrint('Failed to load dashboard data: $e');
      throw Exception('Failed to load dashboard data');
    } catch (e) {
      if (e is AuthExpiredException) {
        rethrow; // Let the error handler manage auth expiry
      }
      debugPrint('Failed to load dashboard data: $e');
      throw Exception('Failed to load dashboard data. Please try again.');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadChildrenByFilter(String filter) async {
    // Always update the filter and reload data
    _selectedFilter = filter;
    _setLoading(true);

    try {
      final response = await ApiClient.instance.getChildrenSummary(
        filter: filter,
      );

      if (response.data['status'] == 'success') {
        _childrenSummary = ChildrenSummaryResponse.fromJson(response.data);
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Failed to load children by filter: $e');
    } finally {
      _setLoading(false);
    }
  }

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
