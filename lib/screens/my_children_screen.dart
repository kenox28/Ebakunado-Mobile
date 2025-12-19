import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/api_client.dart';
import '../models/child_list_item.dart';
import '../models/immunization.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import '../widgets/app_bottom_navigation.dart';
import '../widgets/app_drawer.dart';

class MyChildrenScreen extends StatefulWidget {
  const MyChildrenScreen({super.key});

  @override
  State<MyChildrenScreen> createState() => _MyChildrenScreenState();
}

class _MyChildrenScreenState extends State<MyChildrenScreen> {
  List<ChildListItem> _allChildren = [];
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
      // Load all children data (no filter - all children are automatically registered)
      final response = await ApiClient.instance.getChildList();

      // Parse children data
      Map<String, dynamic> childrenData;
      if (response.data is String) {
        childrenData = json.decode(response.data);
      } else {
        childrenData = response.data;
      }

      final childrenResponse = AcceptedChildResponse.fromJson(childrenData);

      if (childrenResponse.status == 'success') {
        // Fetch immunization schedules for all children to get counts
        final childrenWithCounts = await _fetchImmunizationCounts(
          childrenResponse.data,
        );

        setState(() {
          _allChildren = childrenWithCounts;
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

  /// Fetch immunization counts for each child
  Future<List<ChildListItem>> _fetchImmunizationCounts(
    List<ChildListItem> children,
  ) async {
    if (children.isEmpty) return children;

    // Fetch immunization schedules for all children in parallel
    final futures = children.map((child) async {
      try {
        final response = await ApiClient.instance.getImmunizationSchedule(
          babyId: child.babyId,
        );

        Map<String, dynamic> scheduleData;
        if (response.data is String) {
          scheduleData = json.decode(response.data);
        } else {
          scheduleData = response.data;
        }

        final scheduleResponse = ImmunizationScheduleResponse.fromJson(
          scheduleData,
        );

        // Count immunizations by status
        final takenCount = scheduleResponse
            .getTakenForBaby(child.babyId)
            .length;
        final missedCount = scheduleResponse
            .getMissedForBaby(child.babyId)
            .length;
        final scheduledCount = scheduleResponse
            .getUpcomingForBaby(child.babyId)
            .length;

        // Return updated child with counts
        return ChildListItem(
          id: child.id,
          babyId: child.babyId,
          name: child.name,
          age: child.age,
          weeksOld: child.weeksOld,
          gender: child.gender,
          vaccine: child.vaccine,
          dose: child.dose,
          scheduleDate: child.scheduleDate,
          status: child.status,
          takenCount: takenCount,
          missedCount: missedCount,
          scheduledCount: scheduledCount,
        );
      } catch (e) {
        // If fetching schedule fails, return child with zero counts
        debugPrint(
          'Error fetching immunization schedule for ${child.babyId}: $e',
        );
        return child;
      }
    }).toList();

    return await Future.wait(futures);
  }

  String _getEmptyStateMessage() {
    return 'No children found';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Children'),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
      ),
      drawer: const AppDrawer(),
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

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppConstants.defaultPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_allChildren.isEmpty)
              _buildEmptyState()
            else
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
              'Add a child to get started',
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
      itemCount: _allChildren.length,
      itemBuilder: (context, index) {
        final child = _allChildren[index];
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
                          : child.isTransfer
                          ? AppConstants.alertInfo.withValues(alpha: 0.1)
                          : AppConstants.warningOrange.withValues(alpha: 0.1),
                      child: Icon(
                        child.isTransfer ? Icons.swap_horiz : Icons.child_care,
                        color: child.isAccepted
                            ? AppConstants.successGreen
                            : child.isTransfer
                            ? AppConstants.alertInfo
                            : AppConstants.warningOrange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  child.name,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                              _buildStatusBadge(child),
                            ],
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

  Widget _buildStatusBadge(ChildListItem child) {
    String statusText;
    Color backgroundColor;
    Color textColor;

    if (child.isTransfer) {
      statusText = 'Transferred';
      backgroundColor = AppConstants.alertInfo.withValues(alpha: 0.1);
      textColor = AppConstants.alertInfo;
    } else if (child.isAccepted) {
      statusText = 'Approved';
      backgroundColor = AppConstants.successGreen.withValues(alpha: 0.1);
      textColor = AppConstants.successGreen;
    } else if (child.isPending) {
      statusText = 'Pending';
      backgroundColor = AppConstants.warningOrange.withValues(alpha: 0.1);
      textColor = AppConstants.warningOrange;
    } else {
      statusText = '';
      backgroundColor = Colors.transparent;
      textColor = Colors.transparent;
    }

    if (statusText.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: textColor,
        ),
      ),
    );
  }
}
