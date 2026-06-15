// lecturer_attendance_report.dart — Boundary Screen
// Requirement ID : SAMS-PACK-410
// Responsibility : Displays attendance report filter, summary statistics, detailed records,
//                  and provides download (CSV) and print (PDF) options.
//
// Attributes:
//   selectedSchedule  ClassSchedule
//   selectedDate      Date
//   reportSummary     ReportDTO
//   detailedRecord    List<AttendanceSubmission>
//
// Methods:
//   render()                              — Renders attendance report interface.
//   generateReport(schedule_id, date)     — Generates attendance summary and detailed record.
//   downloadReport(reportData)            — Downloads attendance report as CSV.
//   printReport(reportData)               — Prints attendance report as PDF.

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../models/models.dart';
import '../../services/api_service.dart';

class LecturerAttendanceReport extends StatefulWidget {
  final UserModel? user;
  const LecturerAttendanceReport({super.key, required this.user});

  @override
  State<LecturerAttendanceReport> createState() => _LecturerAttendanceReportState();
}

class _LecturerAttendanceReportState extends State<LecturerAttendanceReport> {
  List<ClassScheduleModel> _schedules = [];
  ClassScheduleModel? _selectedSchedule;
  DateTime? _selectedDate;
  Map<String, dynamic>? _reportData;
  bool _loadingSchedules = true;
  bool _generating  = false;
  bool _exporting   = false;
  bool _printing    = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    // getReportFilter() — SAMS-PACK-410
    _loadFilter();
  }

  // getReportFilter() — List<ClassSchedule>
  // SAMS-PACK-410
  Future<void> _loadFilter() async {
    try {
      final res = await ApiService.getReportFilter();
      if (res['status'] == 200) {
        setState(() {
          _schedules = (res['schedules'] as List)
              .map((j) => ClassScheduleModel.fromJson(j))
              .toList();
        });
      }
    } catch (_) {}
    setState(() => _loadingSchedules = false);
  }

  // generateReport(schedule_id, session_date) — ReportDTO
  // SAMS-PACK-410
  Future<void> _generate() async {
    if (_selectedSchedule == null || _selectedDate == null) {
      setState(() => _error = 'Please select a class and date.');
      return;
    }
    setState(() { _generating = true; _error = null; _reportData = null; });
    try {
      final res = await ApiService.generateReport(
          _selectedSchedule!.scheduleId, _fmtDate(_selectedDate!));
      if (res['status'] == 200) {
        setState(() => _reportData = res);
      } else {
        setState(() => _error = res['message'] ?? 'No report data found.');
      }
    } catch (_) {
      setState(() => _error = 'Failed to generate report. Check your connection.');
    }
    setState(() => _generating = false);
  }

  // downloadReport(reportData) — File
  // SAMS-PACK-410
  Future<void> _exportReport() async {
    if (_reportData == null || _selectedSchedule == null || _selectedDate == null) return;
    setState(() => _exporting = true);
    try {
      final dateStr  = _fmtDate(_selectedDate!);
      final response = await ApiService.downloadReport(_selectedSchedule!.scheduleId, dateStr);
      if (response.statusCode == 200) {
        final dir      = await getTemporaryDirectory();
        final filename = 'attendance_${_selectedSchedule!.courseCode}_$dateStr.csv';
        final file     = File('${dir.path}/$filename');
        await file.writeAsBytes(response.bodyBytes);
        await SharePlus.instance.share(ShareParams(
          files: [XFile(file.path, mimeType: 'text/csv', name: filename)],
          subject: 'Attendance Report — ${_selectedSchedule!.courseName} ($dateStr)',
        ));
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Export failed. Please try again.'),
          backgroundColor: Color(0xFFFF3B30),
          behavior: SnackBarBehavior.floating,
        ));
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Export failed. Check your connection.'),
        backgroundColor: Color(0xFFFF3B30),
        behavior: SnackBarBehavior.floating,
      ));
    }
    if (mounted) setState(() => _exporting = false);
  }

  // printReport(reportData) — void
  // SAMS-PACK-410
  Future<void> _printReport() async {
    if (_reportData == null || _selectedSchedule == null || _selectedDate == null) return;
    setState(() => _printing = true);
    try {
      final summary = ReportSummaryModel.fromJson(_reportData!['summary']);
      final records = (_reportData!['detailed_records'] as List)
          .map((j) => AttendanceSubmissionModel.fromJson(j))
          .toList();
      final dateStr = _fmtDate(_selectedDate!);
      final doc = pw.Document();
      doc.addPage(pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (ctx) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Attendance Report',
                style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 4),
            pw.Text('${_selectedSchedule!.courseName} (${_selectedSchedule!.courseCode}) · ${_selectedSchedule!.section}'),
            pw.Text('Date: $dateStr'),
            pw.SizedBox(height: 12),
            pw.Row(children: [
              pw.Text('Total: ${summary.totalStudents}   '),
              pw.Text('Present: ${summary.presentStudents}   '),
              pw.Text('Absent: ${summary.absentStudents}   '),
              pw.Text('Rate: ${summary.attendancePercentage.toStringAsFixed(1)}%'),
            ]),
            pw.SizedBox(height: 16),
            pw.Text('Detailed Records',
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 8),
            pw.TableHelper.fromTextArray(
              headers: ['No', 'Name', 'Matric', 'Submitted At', 'Status'],
              data: records.asMap().entries.map((e) => [
                '${e.key + 1}',
                e.value.studentName ?? '—',
                e.value.studentMatric ?? '—',
                e.value.submittedAt.length >= 16 ? e.value.submittedAt.substring(0, 16) : e.value.submittedAt,
                e.value.attendanceStatus,
              ]).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 10),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
            ),
          ],
        ),
      ));
      await Printing.layoutPdf(onLayout: (_) async => doc.save());
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Print failed. Please try again.'),
        backgroundColor: Color(0xFFFF3B30),
        behavior: SnackBarBehavior.floating,
      ));
    }
    if (mounted) setState(() => _printing = false);
  }

  String _fmtDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  String _displayDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')} / ${d.month.toString().padLeft(2, '0')} / ${d.year}';

  // render() — void  (SAMS-PACK-410)
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0,
        title: const Text('Attendance Report',
          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [

          // Generate Report card
          _SectionCard(
            title: 'Generate Report',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const _FieldLabel('Class Schedule'),
              const SizedBox(height: 6),
              _loadingSchedules
                ? const Center(child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(color: Color(0xFF1E5BFF)),
                  ))
                : DropdownButtonFormField<ClassScheduleModel>(
                    initialValue: _selectedSchedule,
                    hint: const Text('Select a class...', style: TextStyle(fontSize: 14, color: Color(0xFF5B6B86))),
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: const Color(0xFFF8FAFD),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE8EDF6)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE8EDF6)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFF1E5BFF), width: 1.5),
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                    ),
                    items: _schedules.map((s) => DropdownMenuItem(
                      value: s,
                      child: Text('${s.courseCode} – ${s.className} (${s.section})',
                        style: const TextStyle(fontSize: 13)),
                    )).toList(),
                    onChanged: (v) => setState(() { _selectedSchedule = v; _reportData = null; }),
                  ),
              const SizedBox(height: 16),

              const _FieldLabel('Session Date'),
              const SizedBox(height: 6),
              GestureDetector(
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate ?? DateTime.now(),
                    firstDate: DateTime(2024),
                    lastDate: DateTime.now(),
                    builder: (ctx, child) => Theme(
                      data: Theme.of(ctx).copyWith(
                        colorScheme: const ColorScheme.light(primary: Color(0xFF1E5BFF)),
                      ),
                      child: child!,
                    ),
                  );
                  if (picked != null) setState(() { _selectedDate = picked; _reportData = null; });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFD),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE8EDF6)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined, size: 16, color: Color(0xFF5B6B86)),
                    const SizedBox(width: 10),
                    Text(
                      _selectedDate == null ? 'Pick a date...' : _displayDate(_selectedDate!),
                      style: TextStyle(
                        fontSize: 14,
                        color: _selectedDate == null ? const Color(0xFF5B6B86) : const Color(0xFF111827),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down, color: Color(0xFF5B6B86)),
                  ]),
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F0),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFCDD2)),
                  ),
                  child: Row(children: [
                    const Icon(Icons.error_outline, size: 15, color: Color(0xFFFF3B30)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_error!,
                      style: const TextStyle(fontSize: 13, color: Color(0xFFFF3B30)))),
                  ]),
                ),
              ],
              const SizedBox(height: 16),

              // generateReport() trigger — SAMS-PACK-410
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _generating ? null : _generate,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E5BFF),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _generating
                    ? const SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Text('Generate Report',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                ),
              ),
            ]),
          ),

          if (_reportData != null) ...[
            const SizedBox(height: 14),

            // downloadReport() and printReport() triggers — SAMS-PACK-410
            Row(children: [
              Expanded(child: _ActionButton(
                icon: Icons.download_outlined,
                label: 'Export CSV',
                loading: _exporting,
                onTap: _exporting ? null : _exportReport,
                color: const Color(0xFF22C55E),
              )),
              const SizedBox(width: 10),
              Expanded(child: _ActionButton(
                icon: Icons.print_outlined,
                label: 'Print PDF',
                loading: _printing,
                onTap: _printing ? null : _printReport,
                color: const Color(0xFF1E5BFF),
              )),
            ]),
            const SizedBox(height: 14),

            _ReportOutput(data: _reportData!),
          ],
          const SizedBox(height: 16),
        ]),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  const _SectionCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE8EDF6)),
        boxShadow: const [BoxShadow(color: Color(0x120D1B2A), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
          child: Text(title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
        ),
        const Divider(height: 20, indent: 16, endIndent: 16, color: Color(0xFFE8EDF6)),
        Padding(padding: const EdgeInsets.fromLTRB(16, 0, 16, 16), child: child),
      ]),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)));
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool loading;
  final VoidCallback? onTap;
  final Color color;
  const _ActionButton({
    required this.icon, required this.label, required this.loading,
    required this.onTap, required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: loading
        ? SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: color))
        : Icon(icon, size: 16),
      label: Text(loading ? 'Please wait…' : label, style: const TextStyle(fontSize: 13)),
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color),
        minimumSize: const Size(0, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

class _ReportOutput extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ReportOutput({required this.data});

  @override
  Widget build(BuildContext context) {
    final summary  = ReportSummaryModel.fromJson(data['summary']);
    final schedule = ClassScheduleModel.fromJson(data['schedule']);
    final session  = AttendanceSessionModel.fromJson(data['session']);
    final records  = (data['detailed_records'] as List)
        .map((j) => AttendanceSubmissionModel.fromJson(j))
        .toList();
    final pct = summary.attendancePercentage;
    final pctColor = pct >= 80
        ? const Color(0xFF22C55E)
        : pct >= 50
          ? const Color(0xFFC47F00)
          : const Color(0xFFFF3B30);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Summary card
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8EDF6)),
          boxShadow: const [BoxShadow(color: Color(0x120D1B2A), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Summary',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
              const SizedBox(height: 2),
              Text('${schedule.courseName}  ·  ${schedule.section}',
                style: const TextStyle(fontSize: 13, color: Color(0xFF5B6B86))),
              Text(session.sessionDate,
                style: const TextStyle(fontSize: 12, color: Color(0xFF5B6B86))),
            ]),
          ),
          const Divider(height: 20, indent: 16, endIndent: 16, color: Color(0xFFE8EDF6)),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(children: [
              Row(children: [
                _metricBox('Total',   '${summary.totalStudents}',   const Color(0xFF1E5BFF)),
                const SizedBox(width: 8),
                _metricBox('Present', '${summary.presentStudents}', const Color(0xFF22C55E)),
                const SizedBox(width: 8),
                _metricBox('Absent',  '${summary.absentStudents}',  const Color(0xFFFF3B30)),
                const SizedBox(width: 8),
                _metricBox('Rate', '${pct.toStringAsFixed(1)}%', pctColor),
              ]),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: pct / 100,
                  minHeight: 8,
                  backgroundColor: const Color(0xFFE8EDF6),
                  valueColor: AlwaysStoppedAnimation(pctColor),
                ),
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerRight,
                child: Text('${summary.presentStudents} of ${summary.totalStudents} present',
                  style: const TextStyle(fontSize: 12, color: Color(0xFF5B6B86))),
              ),
            ]),
          ),
        ]),
      ),
      const SizedBox(height: 12),

      // Detailed records card
      Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFE8EDF6)),
          boxShadow: const [BoxShadow(color: Color(0x120D1B2A), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text('Detailed Records',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Color(0xFF111827))),
          ),
          const Divider(height: 20, indent: 16, endIndent: 16, color: Color(0xFFE8EDF6)),
          if (records.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: Text('No submissions recorded',
                style: TextStyle(color: Color(0xFF5B6B86)))),
            )
          else
            ...records.asMap().entries.map((e) {
              final r         = e.value;
              final isLast    = e.key == records.length - 1;
              final isPresent = r.attendanceStatus == 'present';
              final color     = isPresent ? const Color(0xFF22C55E) : const Color(0xFFFF3B30);
              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                  child: Row(children: [
                    CircleAvatar(
                      radius: 17,
                      backgroundColor: color.withValues(alpha: 0.12),
                      child: Text(
                        (r.studentName ?? '?')[0].toUpperCase(),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(r.studentName ?? '—',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827))),
                      Text('${r.studentMatric ?? ''}  ·  ${r.submittedAt.length >= 16 ? r.submittedAt.substring(0, 16) : r.submittedAt}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF5B6B86))),
                    ])),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        isPresent ? 'Present' : 'Rejected',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color),
                      ),
                    ),
                  ]),
                ),
                if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16, color: Color(0xFFE8EDF6)),
              ]);
            }),
          const SizedBox(height: 4),
        ]),
      ),
    ]);
  }
}

Widget _metricBox(String label, String value, Color color) {
  return Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.07),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: color)),
      const SizedBox(height: 2),
      Text(label, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.75))),
    ]),
  ));
}
