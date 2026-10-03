import 'package:design_system/design_system.dart';
import 'package:feature_auth/src/domain/user_profile.dart';
import 'package:feature_auth/src/presentation/auth_strings.dart';
import 'package:feature_auth/src/presentation/sign_up/sign_up_cubit.dart';
import 'package:feature_auth/src/presentation/widgets/auth_page.dart';
import 'package:feature_auth/src/presentation/widgets/failure_alert.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Step "Cuéntanos qué te interesa": what personalizes the home.
class InterestsStep extends StatelessWidget {
  const InterestsStep({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SignUpCubit>();
    final state = context.watch<SignUpCubit>().state;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthHeading(
          title: AuthStrings.interestsTitle,
          body: AuthStrings.interestsBody,
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
          label: AuthStrings.next,
          // Only shows progress when this is the step that submits.
          isLoading: state.isSubmitting,
          onPressed: cubit.next,
        ),
        const SizedBox(height: AppSpacing.x2),
        AppButton(
          label: AuthStrings.skip,
          variant: AppButtonVariant.text,
          onPressed: state.isSubmitting ? null : cubit.skipInterests,
        ),
      ],
    );
  }
}
