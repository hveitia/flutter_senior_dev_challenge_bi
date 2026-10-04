import 'dart:async';

import 'package:design_system/design_system.dart';
import 'package:feature_auth/src/domain/user_profile.dart';
import 'package:feature_auth/src/presentation/auth_strings.dart';
import 'package:feature_auth/src/presentation/preferences/preferences_cubit.dart';
import 'package:feature_auth/src/presentation/widgets/auth_page.dart';
import 'package:feature_auth/src/presentation/widgets/failure_alert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// "Personalización": the customer changes their interests and the segment
/// their home is composed for, the same two questions of the sign-up.
///
/// It reads `PreferencesCubit` and `ConnectivityCubit` from the tree and
/// calls [onSaved] once the change is stored.
class PreferencesScreen extends StatelessWidget {
  const PreferencesScreen({required this.onSaved, super.key});

  final VoidCallback onSaved;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<PreferencesCubit>();

    return BlocConsumer<PreferencesCubit, PreferencesState>(
      listenWhen: (previous, current) => current.wasSaved && !previous.wasSaved,
      listener: (context, state) => onSaved(),
      builder: (context, state) => Scaffold(
        appBar: AppBar(title: const Text(AuthStrings.preferencesTitle)),
        body: AuthPage(
          children: [
            const AuthHeading(
              title: AuthStrings.preferencesHeading,
              body: AuthStrings.preferencesBody,
            ),
            FailureAlert(failure: state.failure),
            Wrap(
              spacing: AppSpacing.x2,
              children: [
                for (final interest in Interest.values)
                  AppChip(
                    label: AuthStrings.interest(interest),
                    selected: state.interests.contains(interest),
                    onSelected: (_) => cubit.interestToggled(interest),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.x6),
            Semantics(
              header: true,
              child: Text(
                AuthStrings.segmentQuestion,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: AppSpacing.x3),
            for (final segment in Segment.values)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.x2),
                child: RadioCard(
                  label: AuthStrings.segment(segment),
                  selected: state.segment == segment,
                  onSelected: () => cubit.segmentSelected(segment),
                ),
              ),
            const SizedBox(height: AppSpacing.x2),
            AppButton(
              label: AuthStrings.savePreferences,
              isLoading: state.isSaving,
              onPressed: state.hasChanges
                  ? () => unawaited(cubit.save())
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
