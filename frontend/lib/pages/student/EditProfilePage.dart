import 'package:flutter/material.dart';

import '../../app/app_controller.dart';

/// Lets a student edit a limited set of profile fields (phone number,
/// current semester, academic advisor, address).
///
/// Read-only fields (name, student ID, course, email) are sourced directly
/// from the database/admin records and are displayed but not editable here.
/// On save, [AppController.updateProfile] sends only the editable fields to
/// the backend and replaces [AppController.currentUser] with the response.
class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key, required this.controller});

  final AppController controller;

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  /// Used to validate the editable fields before saving.
  final _formKey = GlobalKey<FormState>();

  // Controllers for each editable field, pre-filled with the current
  // user's values in initState() and disposed in dispose().
  late final TextEditingController _phoneController;
  late final TextEditingController _semesterController;
  late final TextEditingController _advisorController;
  late final TextEditingController _addressController;

  @override
  void initState() {
    super.initState();
    // Seed each controller with the current value from AppController so the
    // form opens pre-filled with the student's existing profile data.
    final user = widget.controller.currentUser!;
    _phoneController    = TextEditingController(text: user.phoneNumber ?? '');
    _semesterController = TextEditingController(text: user.currentSemester ?? '');
    _advisorController  = TextEditingController(text: user.personalAdvisor ?? '');
    _addressController  = TextEditingController(text: user.address ?? '');
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _semesterController.dispose();
    _advisorController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  /// Validates the form, then sends only the editable fields to the backend
  /// via [AppController.updateProfile].
  ///
  /// On success, pops back to the previous page and shows a confirmation
  /// snackbar. On failure, shows the error message (with the "Exception: "
  /// prefix stripped) in a snackbar without navigating away.
  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await widget.controller.updateProfile({
        'phone_number':     _phoneController.text.trim(),
        'current_semester': _semesterController.text.trim(),
        'personal_advisor': _advisorController.text.trim(),
        'address':          _addressController.text.trim(),
      });

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  /// Builds the form: a read-only section (name, student ID, course, email)
  /// followed by the editable section (phone, semester, advisor, address),
  /// and Cancel/Save buttons at the bottom.
  @override
  Widget build(BuildContext context) {
    final user = widget.controller.currentUser!;
    final isLoading = widget.controller.isLoading;

    return Scaffold(
      backgroundColor: const Color(0xFFEAF3FF),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E5BFF),
        foregroundColor: Colors.white,
        title: const Text(
          'Edit Profile',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Read-only profile info (from admin records) ──────────────
            _SectionCard(
              children: [
                _ReadOnlyField(label: 'Name', value: user.name),
                _ReadOnlyField(label: 'Student ID', value: user.studentId ?? '-'),
                _ReadOnlyField(label: 'Course', value: user.course ?? '-'),
                _ReadOnlyField(label: 'Email', value: user.email, isLast: true),
              ],
            ),
            const SizedBox(height: 16),
            // ── Editable fields ───────────────────────────────────────────
            _SectionCard(
              children: [
                _EditableField(
                  label: 'Phone Number',
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  hint: 'e.g. 012 3456789',
                ),
                _EditableField(
                  label: 'Current Semester',
                  controller: _semesterController,
                  hint: 'e.g. Semester 6',
                ),
                _EditableField(
                  label: 'Academic Advisor',
                  controller: _advisorController,
                  hint: 'e.g. Dr Ahmad bin Ali',
                ),
                _EditableField(
                  label: 'Address',
                  controller: _addressController,
                  hint: 'Enter your home address',
                  maxLines: 3,
                  isLast: true,
                ),
              ],
            ),
            const SizedBox(height: 24),
            // ── Cancel / Save buttons ─────────────────────────────────────
            // Both are disabled while a save request is in flight to avoid
            // duplicate submissions; Save shows a spinner during the request.
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: isLoading ? null : () => Navigator.of(context).pop(),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF5B6B86),
                      side: const BorderSide(color: Color(0xFFD6E0F0)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: isLoading ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1E5BFF),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            'Save',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// White rounded card container used to group related fields together.
class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x120D1B2A),
            blurRadius: 16,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

/// Displays a label and a non-editable value in a greyed-out box.
/// Used for profile fields the student cannot change themselves
/// (name, student ID, course, email).
class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF5B6B86),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5FB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF8A96A8),
              ),
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}

/// Displays a label and an editable [TextFormField] bound to [controller].
/// Used for the profile fields the student is allowed to update.
class _EditableField extends StatelessWidget {
  const _EditableField({
    required this.label,
    required this.controller,
    this.hint = '',
    this.maxLines = 1,
    this.keyboardType,
    this.isLast = false,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final int maxLines;
  final TextInputType? keyboardType;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF111827),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 14),
          child: TextFormField(
            controller: controller,
            maxLines: maxLines,
            keyboardType: keyboardType,
            style: const TextStyle(fontSize: 15, color: Color(0xFF111827)),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Color(0xFFB0BAC9)),
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 12,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD6E0F0)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFFD6E0F0)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: Color(0xFF1E5BFF), width: 1.5),
              ),
            ),
          ),
        ),
        if (!isLast)
          const Divider(height: 1, indent: 16, endIndent: 16),
      ],
    );
  }
}
