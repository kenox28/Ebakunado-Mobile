import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/dashboard_provider.dart';
import '../utils/constants.dart';
import '../models/child.dart';

class DashboardContent extends StatelessWidget {
  const DashboardContent({super.key});

  // Sort children by upcoming date (closest first), then by missed count
  List<ChildSummaryItem> _sortChildrenByDate(List<ChildSummaryItem> children) {
    return children..sort((a, b) {
      // First sort by upcoming date (closest first)
      if (a.upcomingDate != null && b.upcomingDate != null) {
        final dateComparison = a.upcomingDate!.compareTo(b.upcomingDate!);
        if (dateComparison != 0) return dateComparison;
      } else if (a.upcomingDate != null) {
        return -1; // a has date, b doesn't - a comes first
      } else if (b.upcomingDate != null) {
        return 1; // b has date, a doesn't - b comes first
      }

      // If dates are equal or both null, sort by missed count (higher first)
      return b.missedCount.compareTo(a.missedCount);
    });
  }

  // Format date from "2025-01-15" to "Jan 15, 2025"
  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Not scheduled';

    try {
      final date = DateTime.parse(dateString);
      final months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      return '${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return 'Invalid date';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DashboardProvider>(
      builder: (context, dashboardProvider, child) {
        if (dashboardProvider.isLoading && dashboardProvider.summary == null) {
          return const Center(child: CircularProgressIndicator());
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppConstants.defaultPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // KPI Cards
              _buildKPISection(dashboardProvider),
              const SizedBox(height: 24),

              // Filter Chips
              _buildFilterChips(context, dashboardProvider),
              const SizedBox(height: 16),

              // Children List
              _buildChildrenList(context, dashboardProvider),
            ],
          ),
        );
      },
    );
  }

  Widget _buildKPISection(DashboardProvider provider) {
    final summary = provider.summary;
    final childrenSummary = provider.childrenSummary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Overview',
          style: AppConstants.headingStyle.copyWith(fontSize: 20),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _KPICard(
                title: 'Total Children',
                value: summary?.totalChildren.toString() ?? '0',
                icon: Icons.child_care,
                color: AppConstants.primaryGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KPICard(
                title: 'Upcoming Today',
                value: summary?.upcomingScheduleToday.toString() ?? '0',
                icon: Icons.schedule,
                color: AppConstants.warningOrange,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _KPICard(
                title: 'Upcoming',
                value: childrenSummary?.upcomingCount.toString() ?? '0',
                icon: Icons.upcoming,
                color: AppConstants.successGreen,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _KPICard(
                title: 'Missed',
                value: childrenSummary?.missedCount.toString() ?? '0',
                icon: Icons.warning,
                color: AppConstants.errorRed,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChips(BuildContext context, DashboardProvider provider) {
    return Row(
      children: [
        Text(
          'Children:',
          style: AppConstants.subheadingStyle.copyWith(fontSize: 16),
        ),
        const SizedBox(width: 12),
        FilterChip(
          label: const Text('Upcoming'),
          selected: provider.selectedFilter == 'upcoming',
          onSelected: (selected) {
            if (selected) {
              provider.loadChildrenByFilter('upcoming');
            }
          },
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Missed'),
          selected: provider.selectedFilter == 'missed',
          onSelected: (selected) {
            if (selected) {
              provider.loadChildrenByFilter('missed');
            }
          },
        ),
      ],
    );
  }

  Widget _buildChildrenList(BuildContext context, DashboardProvider provider) {
    final childrenSummary = provider.childrenSummary;

    if (childrenSummary == null || childrenSummary.items.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(Icons.child_care, size: 64, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'No records found',
              style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${provider.selectedFilter == 'upcoming' ? 'Upcoming' : 'Missed'} Immunizations',
          style: AppConstants.subheadingStyle.copyWith(fontSize: 16),
        ),
        const SizedBox(height: 12),
        Builder(
          builder: (context) {
            final sortedChildren = _sortChildrenByDate(childrenSummary.items);
            return ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sortedChildren.length,
              itemBuilder: (context, index) {
                final child = sortedChildren[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            CircleAvatar(
                              backgroundColor:
                                  provider.selectedFilter == 'upcoming'
                                  ? AppConstants.successGreen.withValues(
                                      alpha: 0.1,
                                    )
                                  : AppConstants.errorRed.withValues(
                                      alpha: 0.1,
                                    ),
                              child: Icon(
                                Icons.child_care,
                                color: provider.selectedFilter == 'upcoming'
                                    ? AppConstants.successGreen
                                    : AppConstants.errorRed,
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
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  if (child.upcomingVaccine != null)
                                    Text(
                                      'Vaccine: ${child.upcomingVaccine}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  if (child.upcomingDate != null)
                                    Text(
                                      'Date: ${_formatDate(child.upcomingDate)}',
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  if (child.missedCount > 0)
                                    Text(
                                      'Missed: ${child.missedCount}',
                                      style: const TextStyle(
                                        color: AppConstants.errorRed,
                                        fontSize: 13,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context,
                                    AppConstants.upcomingScheduleRoute,
                                    arguments: {'baby_id': child.babyId},
                                  );
                                },
                                icon: const Icon(Icons.schedule, size: 16),
                                label: const Text('View Schedule'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.mediumGreen,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _KPICard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _KPICard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                color: AppConstants.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
