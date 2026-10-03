import 'package:design_system/design_system.dart';
import 'package:feature_auth/src/domain/validators/cedula.dart';
import 'package:feature_auth/src/presentation/auth_strings.dart';
import 'package:feature_auth/src/presentation/sign_up/sign_up_cubit.dart';
import 'package:feature_auth/src/presentation/sign_up/sign_up_state.dart';
import 'package:feature_auth/src/presentation/widgets/auth_page.dart';
import 'package:feature_auth/src/presentation/widgets/failure_alert.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Step "Tus datos": who the customer is and how to reach them.
class PersonalDataStep extends StatefulWidget {
  const PersonalDataStep({super.key});

  @override
  State<PersonalDataStep> createState() => _PersonalDataStepState();
}

class _PersonalDataStepState extends State<PersonalDataStep> {
  late final TextEditingController _nationalId;
  late final TextEditingController _fullName;
  late final TextEditingController _email;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    // Start from what the cubit holds, so coming back to this step shows
    // what was typed before.
    final state = context.read<SignUpCubit>().state;
    _nationalId = TextEditingController(text: state.nationalId);
    _fullName = TextEditingController(text: state.fullName);
    _email = TextEditingController(text: state.email);
    _phone = TextEditingController(text: state.phone);
  }

  @override
  void dispose() {
    _nationalId.dispose();
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SignUpCubit>();
    final state = context.watch<SignUpCubit>().state;
    final invalid = state.invalidFields;

    String? emailError() {
      if (state.emailTaken) return AuthStrings.emailTaken;
      if (invalid.contains(SignUpField.email)) return AuthStrings.emailInvalid;
      return null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const AuthHeading(
          title: AuthStrings.personalDataTitle,
          body: AuthStrings.personalDataBody,
        ),
        FailureAlert(failure: state.failure),
        AppTextField(
          label: AuthStrings.nationalId,
          controller: _nationalId,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(Cedula.length),
          ],
          errorText: invalid.contains(SignUpField.nationalId)
              ? AuthStrings.nationalIdInvalid
              : null,
          onChanged: cubit.nationalIdChanged,
        ),
        const SizedBox(height: AppSpacing.componentGap),
        AppTextField(
          label: AuthStrings.fullName,
          controller: _fullName,
          keyboardType: TextInputType.name,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.name],
          errorText: invalid.contains(SignUpField.fullName)
              ? AuthStrings.fullNameInvalid
              : null,
          onChanged: cubit.fullNameChanged,
        ),
        const SizedBox(height: AppSpacing.componentGap),
        AppTextField(
          label: AuthStrings.email,
          controller: _email,
          // The address of an existing account is not up for editing.
          enabled: state.mode == SignUpMode.newAccount,
          keyboardType: TextInputType.emailAddress,
          textInputAction: TextInputAction.next,
          autofillHints: const [AutofillHints.email],
          errorText: emailError(),
          onChanged: cubit.emailChanged,
        ),
        const SizedBox(height: AppSpacing.componentGap),
        AppTextField(
          label: AuthStrings.phone,
          controller: _phone,
          hintText: AuthStrings.phoneHint,
          keyboardType: TextInputType.phone,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.telephoneNumber],
          errorText: invalid.contains(SignUpField.phone)
              ? AuthStrings.phoneInvalid
              : null,
          onChanged: cubit.phoneChanged,
          onSubmitted: (_) => cubit.next(),
        ),
        const SizedBox(height: AppSpacing.componentGap),
        AppButton(label: AuthStrings.next, onPressed: cubit.next),
      ],
    );
  }
}
