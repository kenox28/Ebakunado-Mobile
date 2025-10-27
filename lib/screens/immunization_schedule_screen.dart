import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import '../services/api_client.dart';
import '../models/immunization.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';

class ImmunizationScheduleScreen extends StatefulWidget {
  final String babyId;

  const ImmunizationScheduleScreen({super.key, required this.babyId});

  @override
  State<ImmunizationScheduleScreen> createState() =>
      _ImmunizationScheduleScreenState();
}

class _ImmunizationScheduleScreenState extends State<ImmunizationScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  ImmunizationScheduleResponse? _scheduleResponse;
  bool _isLoading = true;
  String? _error;
  String? _childName;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadSchedule();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadSchedule() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final response = await ApiClient.instance.getImmunizationSchedule();

      // Handle JSON string response
      Map<String, dynamic> responseData;
      if (response.data is String) {
        responseData = json.decode(response.data);
      } else {
        responseData = response.data;
      }

      final scheduleResponse = ImmunizationScheduleResponse.fromJson(
        responseData,
      );

      if (scheduleResponse.status == 'success') {
        // Find child name from the data
        final childData = scheduleResponse.getForBaby(widget.babyId);
        if (childData.isNotEmpty) {
          _childName = childData.first.childName;
        }

        setState(() {
          _scheduleResponse = scheduleResponse;
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = 'Failed to load immunization schedule.';
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
          _error = 'Failed to load schedule. Please try again.';
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Immunization Schedule'),
            if (_childName != null)
              Text(
                _childName!,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.normal,
                ),
              ),
          ],
        ),
        backgroundColor: AppConstants.primaryGreen,
        foregroundColor: Colors.white,
        bottom: _isLoading || _error != null
            ? null
            : TabBar(
                controller: _tabController,
                indicatorColor: Colors.white,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.white70,
                tabs: [
                  Tab(
                    text: 'Schedule (${_getUpcomingCount()})',
                    icon: const Icon(Icons.schedule),
                  ),
                  Tab(
                    text: 'Missed (${_getMissedCount()})',
                    icon: const Icon(Icons.warning_rounded),
                  ),
                  Tab(
                    text: 'Taken (${_getTakenCount()})',
                    icon: const Icon(Icons.check_circle),
                  ),
                ],
              ),
      ),
      body: _buildBody(),
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
            ElevatedButton(
              onPressed: _loadSchedule,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (_scheduleResponse == null) {
      return const Center(child: Text('No data available'));
    }

    return RefreshIndicator(
      onRefresh: _loadSchedule,
      child: TabBarView(
        controller: _tabController,
        children: [_buildScheduleTab(), _buildMissedTab(), _buildTakenTab()],
      ),
    );
  }

  Widget _buildScheduleTab() {
    final upcomingItems = _scheduleResponse!.getUpcomingForBaby(widget.babyId);

    if (upcomingItems.isEmpty) {
      return _buildEmptyState(
        'No scheduled immunizations',
        'All scheduled immunizations are up to date.',
        Icons.check_circle_outline,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      itemCount: upcomingItems.length,
      itemBuilder: (context, index) {
        final item = upcomingItems[index];
        return _buildScheduleCard(item, isUpcoming: true);
      },
    );
  }

  Widget _buildMissedTab() {
    final missedItems = _scheduleResponse!.getMissedForBaby(widget.babyId);

    if (missedItems.isEmpty) {
      return _buildEmptyState(
        'No missed immunizations',
        'All immunizations are on track.',
        Icons.sentiment_satisfied_alt_rounded,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      itemCount: missedItems.length,
      itemBuilder: (context, index) {
        final item = missedItems[index];
        return _buildMissedCard(item);
      },
    );
  }

  Widget _buildTakenTab() {
    final takenItems = _scheduleResponse!.getTakenForBaby(widget.babyId);

    if (takenItems.isEmpty) {
      return _buildEmptyState(
        'No immunizations taken yet',
        'Completed immunizations will appear here.',
        Icons.vaccines_outlined,
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(AppConstants.defaultPadding),
      itemCount: takenItems.length,
      itemBuilder: (context, index) {
        final item = takenItems[index];
        return _buildScheduleCard(item, isUpcoming: false);
      },
    );
  }

  Widget _buildMissedCard(ImmunizationItem item) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: AppConstants.cardElevation,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          color: AppConstants.errorRed.withValues(alpha: 0.1),
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            backgroundColor: AppConstants.errorRed.withValues(alpha: 0.2),
            child: const Icon(
              Icons.warning_rounded,
              color: AppConstants.errorRed,
            ),
          ),
          title: Text(
            item.vaccineWithDose,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              // Original scheduled date (missed)
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    'Scheduled: ${_formatDate(item.scheduleDate)}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 13),
                  ),
                ],
              ),
              // Catch-up date (rescheduled) in RED
              if (item.catchUpDate != null) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppConstants.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppConstants.errorRed, width: 1),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.update,
                        size: 16,
                        color: AppConstants.errorRed,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Catch Up: ${_formatDate(item.catchUpDate!)}',
                        style: const TextStyle(
                          color: AppConstants.errorRed,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: AppConstants.errorRed.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'MISSED',
                  style: TextStyle(
                    color: AppConstants.errorRed,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScheduleCard(ImmunizationItem item, {required bool isUpcoming}) {
    final cardColor = isUpcoming
        ? AppConstants.warningOrange.withValues(alpha: 0.1)
        : AppConstants.successGreen.withValues(alpha: 0.1);

    final iconColor = isUpcoming
        ? AppConstants.warningOrange
        : AppConstants.successGreen;

    final icon = isUpcoming ? Icons.schedule : Icons.check_circle;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: AppConstants.cardElevation,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppConstants.borderRadius),
          color: cardColor,
        ),
        child: ListTile(
          contentPadding: const EdgeInsets.all(16),
          leading: CircleAvatar(
            backgroundColor: iconColor.withValues(alpha: 0.2),
            child: Icon(icon, color: iconColor),
          ),
          title: Text(
            item.vaccineWithDose,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.calendar_today, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Text(
                    isUpcoming
                        ? 'Scheduled: ${_formatDate(item.scheduleDate)}'
                        : 'Given: ${_formatDate(item.dateGiven ?? item.scheduleDate)}',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
              if (!isUpcoming &&
                  item.dateGiven != null &&
                  item.dateGiven != item.scheduleDate)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    children: [
                      Icon(Icons.event_note, size: 16, color: Colors.grey[600]),
                      const SizedBox(width: 4),
                      Text(
                        'Scheduled: ${_formatDate(item.scheduleDate)}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                    ],
                  ),
                ),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  item.status.toUpperCase(),
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppConstants.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  int _getUpcomingCount() {
    if (_scheduleResponse == null) return 0;
    return _scheduleResponse!.getUpcomingForBaby(widget.babyId).length;
  }

  int _getMissedCount() {
    if (_scheduleResponse == null) return 0;
    return _scheduleResponse!.getMissedForBaby(widget.babyId).length;
  }

  int _getTakenCount() {
    if (_scheduleResponse == null) return 0;
    return _scheduleResponse!.getTakenForBaby(widget.babyId).length;
  }
}
