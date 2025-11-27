import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/api_client.dart';
import '../models/child_list_item.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import '../widgets/app_bottom_navigation.dart';

class MyChildrenScreen extends StatefulWidget {
  const MyChildrenScreen({super.key});

  @override
  State<MyChildrenScreen> createState() => _MyChildrenScreenState();
}

class _MyChildrenScreenState extends State<MyChildrenScreen> {
  List<ChildListItem> _allChildren = [];
  List<ChildListItem> _filteredChildren = [];
  String _selectedFilter = 'accepted';
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load children data
      final response = await ApiClient.instance.getAcceptedChildren();

      // Parse children data
      Map<String, dynamic> childrenData;
      if (response.data is String) {
        childrenData = json.decode(response.data);
      } else {
        childrenData = response.data;
      }

      final childrenResponse = AcceptedChildResponse.fromJson(childrenData);

      if (childrenResponse.status == 'success') {
        setState(() {
          _allChildren = childrenResponse.data;
          _applyFilter();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load children data';
          _isLoading = false;
        });
      }
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        if (mounted) {
          ErrorHandler.handleError(
            context,
            AuthExpiredException('Session expired'),
          );
        }
      } else {
        setState(() {
          _error = 'Network error. Please try again.';
          _isLoading = false;
        });
      }
    } catch (e) {
      if (e is AuthExpiredException) {
        if (mounted) {
          ErrorHandler.handleError(context, e);
        }
      } else {
        setState(() {
          _error = 'Failed to load children. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilter() {
    setState(() {
      if (_selectedFilter == 'pending') {
        _filteredChildren =
            _allChildren.where((child) => child.isPending).toList();
      } else {
        _filteredChildren =
            _allChildren.where((child) => child.isAccepted).toList();
      }
    });
  }

  void _onFilterChanged(String? newFilter) {
    if (newFilter != null && newFilter != _selectedFilter) {
      setState(() {
        _selectedFilter = newFilter;
      });
      _applyFilter();
    }
  }

  String _getFilterDisplayName(String filter) {
    switch (filter) {
      case 'pending':
        return 'Pending Registration';
      case 'accepted':
        return 'Approved Children';
      default:
        return 'Approved Children';
    }
  }

  String _getEmptyStateMessage() {
    switch (_selectedFilter) {
      case 'pending':
        return 'No children pending registration';
      case 'accepted':
        return 'No approved children found';
      default:
        return 'No approved children found';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Children'),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
      bottomNavigationBar: const AppBottomNavigation(
        current: BottomNavDestination.myChildren,
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: _loadData, child: const Text('Retry')),
          ],
        ),
      );
    }

    if (_filteredChildren.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildFilterControls(),
            const SizedBox(height: 16),
            Text(
              '${_getFilterDisplayName(_selectedFilter)} (${_filteredChildren.length})',
              style: AppConstants.subheadingStyle,
            ),
            const SizedBox(height: 16),
            _buildChildrenTable(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.child_care, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              _getEmptyStateMessage(),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppConstants.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Children will appear here once they are registered',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChildrenTable() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _filteredChildren.length,
      itemBuilder: (context, index) {
        final child = _filteredChildren[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          elevation: AppConstants.cardElevation,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Child info row
                Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: child.isAccepted
                          ? AppConstants.successGreen.withValues(alpha: 0.1)
                          : AppConstants.warningOrange.withValues(alpha: 0.1),
                      child: Icon(
                        Icons.child_care,
                        color: child.isAccepted
                            ? AppConstants.successGreen
                            : AppConstants.warningOrange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child.name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${child.ageDisplay} • ${child.gender}',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatColumn(
                      'Upcoming',
                      child.scheduledCount.toString(),
                      Icons.schedule,
                    ),
                    _buildStatColumn(
                      'Missed',
                      child.missedCount.toString(),
                      Icons.error,
                    ),
                    _buildStatColumn(
                      'Taken',
                      child.takenCount.toString(),
                      Icons.check_circle,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Action button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: child.babyId.isNotEmpty
                        ? () {
                            Navigator.pushNamed(
                              context,
                              AppConstants.childRecordRoute,
                              arguments: {'baby_id': child.babyId},
                            );
                          }
                        : null,
                    icon: const Icon(Icons.person, size: 18),
                    label: const Text('View'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterControls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Filter by status',
          style: AppConstants.subheadingStyle.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            FilterChip(
              label: const Text('Approved'),
              selected: _selectedFilter == 'accepted',
              onSelected: (selected) {
                if (selected) {
                  _onFilterChanged('accepted');
                }
              },
            ),
            FilterChip(
              label: const Text('Pending'),
              selected: _selectedFilter == 'pending',
              onSelected: (selected) {
                if (selected) {
                  _onFilterChanged('pending');
                }
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildStatColumn(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, size: 20, color: AppConstants.textSecondary),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        Text(label, style: AppConstants.captionStyle),
      ],
    );
  }
}
