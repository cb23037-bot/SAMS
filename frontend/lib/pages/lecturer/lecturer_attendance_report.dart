import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../app/app_controller.dart';
import '../../models/attendance_report.dart';

/// SDD Flow:
/// Step 16 → Lecturer clicks Attendance Report menu
/// Step 17 → System displays search options (class + session date)
/// Step 18 → Lecturer selects class and session date, taps Generate Report
/// Step 19 → System retrieves attendance data
/// Step 20 → System displays summary and detailed record
/// Step 21 → Lecturer downloads or prints the report
class LecturerAttendanceReportPage extends StatefulWidget {
  const LecturerAttendanceReportPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<LecturerAttendanceReportPage> createState() => _LecturerAttendanceReportPageState();
}

class _LecturerAttendanceReportPageState extends State<LecturerAttendanceReportPage> {
  late Future<List<ReportClassModel>> _classesFuture;

  ReportClassModel? _selectedClass;

  /// All sessions for the selected class (loaded after class is picked).
  List<ReportSessionModel> _availableSessions = [];
  ReportSessionModel? _selectedSession;
  bool _isLoadingSessions = false;

  /// The final report shown after tapping Generate Report.
  ReportSummaryModel? _report;
  bool _isLoadingReport = false;
  bool _isExporting = false;
  String? _reportError;

  @override
  void initState() {
    super.initState();
    _classesFuture = _loadClasses();
  }

  Future<List<ReportClassModel>> _loadClasses() async {
    return widget.controller.apiService.getAttendanceReportFilters(
      token: widget.controller.token!,
    );
  }

  /// When lecturer selects a class, load its sessions for the date dropdown.
  Future<void> _onClassSelected(ReportClassModel cls) async {
    setState(() {
      _selectedClass = cls;
      _availableSessions = [];
      _selectedSession = null;
      _report = null;
      _reportError = null;
      _isLoadingSessions = true;
    });
    try {
      final report = await widget.controller.apiService.generateAttendanceReport(
        token: widget.controller.token!,
        classId: cls.classId,
      );
      if (!mounted) return;
      setState(() {
        _availableSessions = report.sessions;
        _selectedSession = report.sessions.isNotEmpty ? report.sessions.last : null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _reportError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoadingSessions = false);
    }
  }

  /// SAMS-PACK-410: generateReport(schedule_id, session_date)
  /// Retrieves the attendance summary and detailed student record from the backend
  /// for the selected class and session date, then updates [_report] for display.
  /// Steps 18–19: Lecturer taps Generate Report — fetch and display.
  /// Returns: ReportDTO (ReportSummaryModel) — summary and per-student attendance.
  Future<void> generateReport(int scheduleId, String sessionDate) async {
    final cls = _selectedClass;
    if (cls == null) return;

    setState(() {
      _isLoadingReport = true;
      _reportError = null;
      _report = null;
    });
    try {
      final fullReport = await widget.controller.apiService.generateAttendanceReport(
        token: widget.controller.token!,
        classId: cls.classId,
      );
      if (!mounted) return;

      // Filter to selected session date if one is chosen.
      final session = _selectedSession;
      if (session != null) {
        final filteredSessions = fullReport.sessions
            .where((s) => s.attendanceSessionId == session.attendanceSessionId)
            .toList();
        final sessionIndex = fullReport.sessions
            .indexWhere((s) => s.attendanceSessionId == session.attendanceSessionId);

        final filteredStudents = fullReport.students.map((student) {
          final sessionMark = sessionIndex >= 0 && sessionIndex < student.attendance.length
              ? student.attendance[sessionIndex]
              : 'absent';
          final isPresent = sessionMark == 'present';
          return ReportStudentModel(
            studentId: student.studentId,
            matricNo: student.matricNo,
            name: student.name,
            attendance: [sessionMark],
            presentCount: isPresent ? 1 : 0,
            totalSessions: 1,
            percentage: isPresent ? 100.0 : 0.0,
          );
        }).toList();

        setState(() => _report = ReportSummaryModel(
              classInfo: fullReport.classInfo,
              sessions: filteredSessions,
              students: filteredStudents,
            ));
      } else {
        setState(() => _report = fullReport);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _reportError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoadingReport = false);
    }
  }

  /// SAMS-PACK-410: downloadReport(reportData)
  /// Exports the generated attendance report as a PDF file and triggers the
  /// system share/save dialog so the lecturer can download it to their device.
  /// Returns: File — the exported PDF shared via the system dialog.
  Future<void> downloadReport(ReportSummaryModel reportData) async {
    setState(() => _isExporting = true);
    try {
      final bytes = await _buildReportPdf(reportData);
      await Printing.sharePdf(
        bytes: bytes,
        filename: 'attendance_report_${reportData.classInfo.courseCode}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to download: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// SAMS-PACK-410: printReport(reportData)
  /// Sends the generated attendance report to the system print dialog so the
  /// lecturer can print it directly from their device.
  /// Returns: void
  Future<void> printReport(ReportSummaryModel reportData) async {
    setState(() => _isExporting = true);
    try {
      final bytes = await _buildReportPdf(reportData);
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: 'attendance_report_${reportData.classInfo.courseCode}',
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to print: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

  /// SAMS-PACK-410: render()
  /// Renders the attendance report interface — search options card (class +
  /// session date dropdowns), Generate Report button, report summary card,
  /// detailed record table, and Download / Print buttons.
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Color(0xFF111827)),
        title: const Text(
          'Attendance Report',
          style: TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w700),
        ),
      ),
      body: FutureBuilder<List<ReportClassModel>>(
        future: _classesFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(
                  snapshot.error.toString().replaceAll('Exception: ', ''),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF5B6B86)),
                ),
              ),
            );
          }

          final classes = snapshot.data ?? [];
          if (classes.isEmpty) {
            return const Center(
              child: Text('No classes available for reports.', style: TextStyle(color: Color(0xFF5B6B86))),
            );
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step 17: Search options card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    boxShadow: const [
                      BoxShadow(color: Color(0x1F0D1B2A), blurRadius: 16, offset: Offset(0, 6)),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Report Search Options',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
                      ),
                      const SizedBox(height: 16),

                      // Class / Subject dropdown (Step 18)
                      const Text(
                        'Class / Subject',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF5B6B86)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<int>(
                            isExpanded: true,
                            hint: const Text('Select class', style: TextStyle(color: Color(0xFF8A96A8))),
                            value: _selectedClass?.classId,
                            items: classes.map((c) => DropdownMenuItem(
                              value: c.classId,
                              child: Text(
                                '${c.courseCode} - ${c.courseName} (Sec ${c.section})',
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600),
                              ),
                            )).toList(),
                            onChanged: (value) {
                              if (value == null) return;
                              _onClassSelected(classes.firstWhere((c) => c.classId == value));
                            },
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Session date dropdown (Step 18)
                      const Text(
                        'Session Date',
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF5B6B86)),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: _isLoadingSessions
                            ? const Padding(
                                padding: EdgeInsets.symmetric(vertical: 12),
                                child: Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))),
                              )
                            : DropdownButtonHideUnderline(
                                child: DropdownButton<int>(
                                  isExpanded: true,
                                  hint: const Text('Select session date', style: TextStyle(color: Color(0xFF8A96A8))),
                                  value: _selectedSession?.attendanceSessionId,
                                  items: _availableSessions.map((s) => DropdownMenuItem(
                                    value: s.attendanceSessionId,
                                    child: Text(
                                      '${s.sessionDate}  (${s.presentCount} present)',
                                      style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600),
                                    ),
                                  )).toList(),
                                  onChanged: _availableSessions.isEmpty ? null : (value) {
                                    if (value == null) return;
                                    setState(() {
                                      _selectedSession = _availableSessions.firstWhere((s) => s.attendanceSessionId == value);
                                      _report = null;
                                    });
                                  },
                                ),
                              ),
                      ),

                      const SizedBox(height: 20),

                      // Step 18: Generate Report button
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: (_selectedClass == null || _selectedSession == null || _isLoadingReport)
                              ? null
                              : () => generateReport(
                                    _selectedClass!.classId,
                                    _selectedSession!.sessionDate,
                                  ),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF2E6BFF),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          icon: _isLoadingReport
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.bar_chart, color: Colors.white),
                          label: const Text(
                            'Generate Report',
                            style: TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                if (_reportError != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF3B30).withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(_reportError!, style: const TextStyle(color: Color(0xFFFF3B30))),
                  ),
                ],

                // Steps 20–21: Report summary + detailed record + download
                if (_report != null) ...[
                  const SizedBox(height: 20),
                  _buildReportResult(_report!),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildReportResult(ReportSummaryModel report) {
    if (report.sessions.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: Color(0x1F0D1B2A), blurRadius: 16, offset: Offset(0, 6))],
        ),
        child: const Center(
          child: Text('No attendance sessions recorded for this selection.', style: TextStyle(color: Color(0xFF5B6B86))),
        ),
      );
    }

    final session = report.sessions.first;
    final presentCount = report.students.where((s) => s.presentCount > 0).length;
    final totalStudents = report.students.length;
    final absentCount = totalStudents - presentCount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Step 20: Summary card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2E6BFF), Color(0xFF1544D9)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${report.classInfo.courseCode} - ${report.classInfo.courseName}',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 4),
              Text(
                'Section ${report.classInfo.section}  •  Session: ${session.sessionDate}',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _SummaryChip(label: 'Present', value: presentCount.toString(), color: const Color(0xFF22C55E)),
                  const SizedBox(width: 10),
                  _SummaryChip(label: 'Absent', value: absentCount.toString(), color: const Color(0xFFFF3B30)),
                  const SizedBox(width: 10),
                  _SummaryChip(label: 'Total', value: totalStudents.toString(), color: Colors.white54),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // Step 20: Detailed record table
        const Text(
          'Detailed Attendance Record',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Color(0xFF111827)),
        ),
        const SizedBox(height: 10),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [BoxShadow(color: Color(0x1F0D1B2A), blurRadius: 16, offset: Offset(0, 6))],
          ),
          child: Column(
            children: [
              // Header row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: const BoxDecoration(
                  color: Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                ),
                child: const Row(
                  children: [
                    Expanded(flex: 2, child: Text('Matric No', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF5B6B86)))),
                    Expanded(flex: 3, child: Text('Name', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF5B6B86)))),
                    Text('Status', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 12, color: Color(0xFF5B6B86))),
                  ],
                ),
              ),
              const Divider(height: 1),
              ...report.students.asMap().entries.map((entry) {
                final isLast = entry.key == report.students.length - 1;
                final student = entry.value;
                final isPresent = student.presentCount > 0;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: Text(student.matricNo, style: const TextStyle(fontSize: 13, color: Color(0xFF111827)))),
                          Expanded(flex: 3, child: Text(student.name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF111827)))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (isPresent ? const Color(0xFF22C55E) : const Color(0xFFFF3B30)).withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              isPresent ? 'Present' : 'Absent',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isPresent ? const Color(0xFF22C55E) : const Color(0xFFFF3B30),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!isLast) const Divider(height: 1, indent: 16, endIndent: 16),
                  ],
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Step 21: Download Report button — downloadReport(reportData)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isExporting ? null : () => downloadReport(report),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF2E6BFF),
              side: const BorderSide(color: Color(0xFF2E6BFF)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: _isExporting
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download_outlined),
            label: const Text('Download Report', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),

        const SizedBox(height: 10),

        // Step 21: Print Report button — printReport(reportData)
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isExporting ? null : () => printReport(report),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF8A96A8),
              side: const BorderSide(color: Color(0xFF8A96A8)),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.print_outlined),
            label: const Text('Print Report', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(value, style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 14)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        ],
      ),
    );
  }
}

Future<Uint8List> _buildReportPdf(ReportSummaryModel report) async {
  final doc = pw.Document();

  final session = report.sessions.isNotEmpty ? report.sessions.first : null;

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        pw.Container(
          width: double.infinity,
          padding: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: pw.BoxDecoration(
            color: PdfColors.blue800,
            borderRadius: pw.BorderRadius.circular(8),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'Class Attendance Report',
                style: pw.TextStyle(color: PdfColors.white, fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                '${report.classInfo.courseCode} - ${report.classInfo.courseName} (Section ${report.classInfo.section})',
                style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 11),
              ),
              if (session != null) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  'Session Date: ${session.sessionDate}',
                  style: const pw.TextStyle(color: PdfColors.grey300, fontSize: 10),
                ),
              ],
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
          cellStyle: const pw.TextStyle(fontSize: 9),
          cellAlignment: pw.Alignment.center,
          cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft},
          headers: ['Matric No', 'Name', 'Status'],
          data: report.students.map((student) {
            return [
              student.matricNo,
              student.name,
              student.presentCount > 0 ? 'Present' : 'Absent',
            ];
          }).toList(),
        ),
        pw.SizedBox(height: 12),
        pw.Text(
          'Generated on ${DateTime.now().toLocal().toString().split('.').first}',
          style: pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
      ],
    ),
  );

  return doc.save();
}
