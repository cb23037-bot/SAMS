import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../app/app_controller.dart';
import '../../models/attendance_report.dart';

/// Lets the lecturer pick one of their classes and view/export an
/// attendance report summarizing every session for that class.
class LecturerAttendanceReportPage extends StatefulWidget {
  const LecturerAttendanceReportPage({super.key, required this.controller});

  final AppController controller;

  @override
  State<LecturerAttendanceReportPage> createState() => _LecturerAttendanceReportPageState();
}

class _LecturerAttendanceReportPageState extends State<LecturerAttendanceReportPage> {
  late Future<List<ReportClassModel>> _classesFuture;

  ReportClassModel? _selectedClass;
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
    final classes = await widget.controller.apiService.getAttendanceReportFilters(
      token: widget.controller.token!,
    );
    if (classes.isNotEmpty) {
      _selectedClass = classes.first;
      _loadReport();
    }
    return classes;
  }

  Future<void> _loadReport() async {
    final selected = _selectedClass;
    if (selected == null) return;

    setState(() {
      _isLoadingReport = true;
      _reportError = null;
    });
    try {
      final report = await widget.controller.apiService.generateAttendanceReport(
        token: widget.controller.token!,
        classId: selected.classId,
      );
      if (!mounted) return;
      setState(() => _report = report);
    } catch (e) {
      if (!mounted) return;
      setState(() => _reportError = e.toString().replaceAll('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _isLoadingReport = false);
    }
  }

  Future<void> _exportPdf() async {
    final report = _report;
    if (report == null) return;

    setState(() => _isExporting = true);
    try {
      final bytes = await _buildReportPdf(report);
      await Printing.sharePdf(bytes: bytes, filename: 'attendance_report_${report.classInfo.courseCode}.pdf');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to export report: ${e.toString().replaceAll('Exception: ', '')}')),
      );
    } finally {
      if (mounted) setState(() => _isExporting = false);
    }
  }

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
        actions: [
          if (_report != null)
            IconButton(
              tooltip: 'Export PDF',
              icon: _isExporting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.picture_as_pdf_outlined, color: Color(0xFF111827)),
              onPressed: _isExporting ? null : _exportPdf,
            ),
        ],
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

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: const [
                      BoxShadow(color: Color(0x1F0D1B2A), blurRadius: 16, offset: Offset(0, 6)),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      value: _selectedClass?.classId,
                      items: classes
                          .map((c) => DropdownMenuItem(
                                value: c.classId,
                                child: Text(
                                  '${c.courseCode} - ${c.courseName} (Sec ${c.section})',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Color(0xFF111827), fontWeight: FontWeight.w600),
                                ),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setState(() {
                          _selectedClass = classes.firstWhere((c) => c.classId == value);
                          _report = null;
                        });
                        _loadReport();
                      },
                    ),
                  ),
                ),
              ),
              Expanded(child: _buildBody()),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoadingReport) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_reportError != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(_reportError!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF5B6B86))),
        ),
      );
    }

    final report = _report;
    if (report == null) {
      return const Center(child: Text('Select a class to view its report.', style: TextStyle(color: Color(0xFF5B6B86))));
    }

    if (report.sessions.isEmpty) {
      return const Center(
        child: Text('No attendance sessions have been recorded for this class yet.', style: TextStyle(color: Color(0xFF5B6B86))),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            boxShadow: const [
              BoxShadow(color: Color(0x1F0D1B2A), blurRadius: 16, offset: Offset(0, 6)),
            ],
          ),
          child: DataTable(
            columnSpacing: 20,
            columns: [
              const DataColumn(label: Text('Matric No', style: TextStyle(fontWeight: FontWeight.w700))),
              const DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.w700))),
              for (final session in report.sessions)
                DataColumn(label: Text(session.sessionDate, style: const TextStyle(fontWeight: FontWeight.w700))),
              const DataColumn(label: Text('Present', style: TextStyle(fontWeight: FontWeight.w700))),
              const DataColumn(label: Text('Total', style: TextStyle(fontWeight: FontWeight.w700))),
              const DataColumn(label: Text('%', style: TextStyle(fontWeight: FontWeight.w700))),
            ],
            rows: report.students.map((student) {
              return DataRow(cells: [
                DataCell(Text(student.matricNo)),
                DataCell(Text(student.name)),
                for (final mark in student.attendance)
                  DataCell(
                    Icon(
                      mark == 'present' ? Icons.check_circle : Icons.cancel,
                      color: mark == 'present' ? const Color(0xFF22C55E) : const Color(0xFFFF3B30),
                      size: 18,
                    ),
                  ),
                DataCell(Text(student.presentCount.toString())),
                DataCell(Text(student.totalSessions.toString())),
                DataCell(Text('${student.percentage.toStringAsFixed(1)}%')),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}

Future<Uint8List> _buildReportPdf(ReportSummaryModel report) async {
  final doc = pw.Document();

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4.landscape,
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
                style: pw.TextStyle(color: PdfColors.white, fontSize: 18, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 2),
              pw.Text(
                '${report.classInfo.courseCode} - ${report.classInfo.courseName} (Section ${report.classInfo.section})',
                style: pw.TextStyle(color: PdfColors.white, fontSize: 11),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 16),
        pw.TableHelper.fromTextArray(
          headerDecoration: const pw.BoxDecoration(color: PdfColors.grey200),
          headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9),
          cellStyle: const pw.TextStyle(fontSize: 8),
          cellAlignment: pw.Alignment.center,
          cellAlignments: {0: pw.Alignment.centerLeft, 1: pw.Alignment.centerLeft},
          headers: [
            'Matric No',
            'Name',
            ...report.sessions.map((s) => s.sessionDate),
            'Present',
            'Total',
            '%',
          ],
          data: report.students.map((student) {
            return [
              student.matricNo,
              student.name,
              ...student.attendance.map((mark) => mark == 'present' ? 'P' : 'A'),
              student.presentCount.toString(),
              student.totalSessions.toString(),
              '${student.percentage.toStringAsFixed(1)}%',
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
