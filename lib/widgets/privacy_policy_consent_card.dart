import 'package:flutter/material.dart';
import '../utils/constants.dart';

class PrivacyPolicyConsentCard extends StatelessWidget {
  final bool agreed;
  final ValueChanged<bool?>? onChanged;
  final VoidCallback? onOpenPrivacy;
  final VoidCallback? onOpenTerms;

  const PrivacyPolicyConsentCard({
    super.key,
    required this.agreed,
    this.onChanged,
    this.onOpenPrivacy,
    this.onOpenTerms,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Policy Card
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: AppConstants.primaryGreen.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppConstants.backgroundWhite,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    Icon(
                      Icons.privacy_tip_outlined,
                      color: AppConstants.primaryGreen,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Privacy Policy & Terms of Service',
                        style: AppConstants.subheadingStyle.copyWith(
                          color: AppConstants.primaryGreen,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Policy Content
                _buildPolicyList(),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Checkbox
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Checkbox(
              value: agreed,
              onChanged: onChanged,
              activeColor: AppConstants.primaryGreen,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: RichText(
                  text: TextSpan(
                    style: AppConstants.bodyStyle.copyWith(fontSize: 14),
                    children: [
                      const TextSpan(text: 'I agree to the '),
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: onOpenPrivacy,
                          child: Text(
                            'Privacy Policy',
                            style: TextStyle(
                              color: AppConstants.primaryGreen,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: ' and '),
                      WidgetSpan(
                        child: GestureDetector(
                          onTap: onOpenTerms,
                          child: Text(
                            'Terms of Service',
                            style: TextStyle(
                              color: AppConstants.primaryGreen,
                              fontWeight: FontWeight.w600,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                      const TextSpan(text: ' of Linao Health Center'),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPolicyList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildPolicyItem(
          'I am the parent or legal guardian of the child whose information will be entered in this system managed by Linao Health Center Ormoc City.',
        ),
        const SizedBox(height: 12),
        _buildPolicyItem(
          'I voluntarily give consent for the collection, storage, and processing of my child\'s personal and health information, including immunization records, following the Data Privacy Act of 2012 (RA 10173).',
        ),
        const SizedBox(height: 12),
        _buildPolicyItem(
          'I understand that my child\'s data will be used only for immunization services, such as scheduling, tracking, and verifying vaccination status.',
        ),
        const SizedBox(height: 12),
        _buildPolicyItem(
          'I consent that the data may be shared only with authorized health workers of Linao Health Center Ormoc City, the Local Government Unit (LGU), or the Department of Health (DOH) for legitimate health service purposes.',
        ),
        const SizedBox(height: 12),
        _buildPolicyItem(
          'I understand that my child\'s data will NOT be shared with unauthorized persons, agencies, or for any purpose not related to healthcare.',
        ),
        const SizedBox(height: 12),
        _buildPolicyItem(
          'I have the right to:',
          children: [
            _buildSubItem('Access my child\'s records'),
            _buildSubItem('Correct inaccurate information'),
            _buildSubItem('Withdraw consent at any time'),
          ],
        ),
        const SizedBox(height: 12),
        _buildPolicyItem(
          'I understand that withdrawing my consent may limit the ability of Linao Health Center Ormoc City to provide full immunization services.',
        ),
      ],
    );
  }

  Widget _buildPolicyItem(String text, {List<Widget>? children}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, right: 8),
              child: Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: AppConstants.primaryGreen,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            Expanded(
              child: Text(
                text,
                style: AppConstants.bodyStyle.copyWith(
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        if (children != null) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildSubItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 6, right: 8),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: AppConstants.textSecondary,
                shape: BoxShape.circle,
              ),
            ),
          ),
          Expanded(
            child: Text(
              text,
              style: AppConstants.bodyStyle.copyWith(
                fontSize: 12,
                color: AppConstants.textSecondary,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
