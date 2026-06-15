import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class LectureSection {
  String name;
  String lecturer;
  String? schedule;

  LectureSection({required this.name, required this.lecturer, this.schedule});
}

class LabSection {
  String name;
  String instructor;
  String? schedule;

  LabSection({required this.name, required this.instructor, this.schedule});
}

class AddSubjectPage extends StatefulWidget {
  final String token;
  const AddSubjectPage({super.key, required this.token});

  @override
  State<AddSubjectPage> createState() => _AddSubjectPageState();
}

class _AddSubjectPageState extends State<AddSubjectPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _creditController = TextEditingController();
  final ApiService _apiService = ApiService();
  bool _isSaving = false;

  late List<LectureSection> _lectureSections;
  late List<LabSection> _labSections;

  @override
  void initState() {
    super.initState();
    _lectureSections = [LectureSection(name: '', lecturer: '')];
    _labSections = [];
  }

  // REPLACED: New selector logic
  Future<void> _pickDayAndTime(Function(String) onSchedulePicked) async {
    String? selectedDay = await showDialog<String>(
      context: context,
      builder: (context) => SimpleDialog(
        title: const Text('Select Day'),
        children: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
            .map((day) => SimpleDialogOption(
                  onPressed: () => Navigator.pop(context, day),
                  child: Text(day),
                ))
            .toList(),
      ),
    );

    if (selectedDay != null) {
      if (!mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.now(),
      );

      if (time != null) {
        if (!mounted) return;
        final startTime = time.format(context);
        final endHour = (time.hour + 2) % 24;
        final endTime = TimeOfDay(hour: endHour, minute: time.minute).format(context);
        onSchedulePicked('$selectedDay $startTime-$endTime');
      }
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    
    if (_lectureSections.any((s) => s.name.isEmpty || s.lecturer.isEmpty || s.schedule == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all lecture section details')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      final lectureList = _lectureSections
          .map((s) => {'section': s.name, 'lecturer': s.lecturer, 'schedule': s.schedule})
          .toList();
      final labList = _labSections
          .where((s) => s.name.isNotEmpty && s.instructor.isNotEmpty && s.schedule != null)
          .map((s) => {'section': s.name, 'instructor': s.instructor, 'schedule': s.schedule})
          .toList();

      await _apiService.createSubject(
        token: widget.token,
        code: _codeController.text,
        name: _nameController.text,
        creditHours: int.parse(_creditController.text),
        lectureSections: lectureList,
        labSections: labList,
      );

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add New Subject')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(controller: _codeController, decoration: const InputDecoration(labelText: 'Subject Code'), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _nameController, decoration: const InputDecoration(labelText: 'Subject Name'), validator: (v) => v == null || v.isEmpty ? 'Required' : null),
              const SizedBox(height: 12),
              TextFormField(controller: _creditController, decoration: const InputDecoration(labelText: 'Credit Hours'), keyboardType: TextInputType.number, validator: (v) => (v == null || int.tryParse(v) == null) ? 'Required' : null),
              const SizedBox(height: 24),
              
              // Lecture Section
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Lecture Sections', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ElevatedButton.icon(onPressed: () => setState(() => _lectureSections.add(LectureSection(name: '', lecturer: ''))), icon: const Icon(Icons.add, size: 16), label: const Text('Add'))
              ]),
              ..._lectureSections.asMap().entries.map((entry) {
                final idx = entry.key;
                final section = entry.value;
                return Column(key: ValueKey('lecture_$idx'), children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8)),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Lecture Section ${idx + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        if (_lectureSections.length > 1) IconButton(onPressed: () => setState(() => _lectureSections.removeAt(idx)), icon: const Icon(Icons.delete, size: 18, color: Colors.red))
                      ]),
                      TextFormField(initialValue: section.name, decoration: const InputDecoration(labelText: 'Section Name', isDense: true), onChanged: (v) => section.name = v, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                      TextFormField(initialValue: section.lecturer, decoration: const InputDecoration(labelText: 'Lecturer Name', isDense: true), onChanged: (v) => section.lecturer = v, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _pickDayAndTime((s) => setState(() => section.schedule = s)),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(4)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(section.schedule ?? 'Select Schedule (Day & Time)', style: TextStyle(color: section.schedule == null ? Colors.grey : Colors.black)),
                            const Icon(Icons.calendar_today, size: 18, color: Colors.blue),
                          ]),
                        ),
                      )
                    ]),
                  ),
                ]);
              }),
              
              // Lab Section (retaining all original styling)
              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                const Text('Lab Sections (Optional)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ElevatedButton.icon(onPressed: () => setState(() => _labSections.add(LabSection(name: '', instructor: ''))), icon: const Icon(Icons.add, size: 16), label: const Text('Add'))
              ]),
              ..._labSections.asMap().entries.map((entry) {
                final idx = entry.key;
                final section = entry.value;
                return Column(key: ValueKey('lab_$idx'), children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(border: Border.all(color: const Color(0xFFE5E7EB)), borderRadius: BorderRadius.circular(8)),
                    child: Column(children: [
                      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                        Text('Lab Section ${idx + 1}', style: const TextStyle(fontWeight: FontWeight.w600)),
                        IconButton(onPressed: () => setState(() => _labSections.removeAt(idx)), icon: const Icon(Icons.delete, size: 18, color: Colors.red))
                      ]),
                      TextFormField(initialValue: section.name, decoration: const InputDecoration(labelText: 'Lab Section Name', isDense: true), onChanged: (v) => section.name = v),
                      TextFormField(initialValue: section.instructor, decoration: const InputDecoration(labelText: 'Lab Instructor', isDense: true), onChanged: (v) => section.instructor = v),
                      const SizedBox(height: 12),
                      GestureDetector(
                        onTap: () => _pickDayAndTime((s) => setState(() => section.schedule = s)),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(border: Border.all(color: const Color(0xFFCBD5E1)), borderRadius: BorderRadius.circular(4)),
                          child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                            Text(section.schedule ?? 'Select Schedule (Day & Time)', style: TextStyle(color: section.schedule == null ? Colors.grey : Colors.black)),
                            const Icon(Icons.calendar_today, size: 18, color: Colors.blue),
                          ]),
                        ),
                      )
                    ]),
                  ),
                ]);
              }),
              
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSaving ? null : _submit,
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                child: _isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text('Save Subject', style: TextStyle(fontWeight: FontWeight.w700)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}