import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart' as firestore;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:open_file/open_file.dart';
import '../services/report_service.dart';
import '../services/database_service.dart';
import '../models/transaction.dart' as fintrack;

class ReportScreen extends StatefulWidget {
  @override
  _ReportScreenState createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  final ReportService _reportService = ReportService();
  final DatabaseService _dbService = DatabaseService();
  DateTime _startDate = DateTime.now().subtract(Duration(days: 30));
  DateTime _endDate = DateTime.now();
  bool _isGenerating = false;

  Future<void> _generateReport() async {
    setState(() => _isGenerating = true);

    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User not logged in')),
        );
        return;
      }

      // Fetch transactions
      final snapshot = await firestore.FirebaseFirestore.instance
          .collection('transactions')
          .where('userId', isEqualTo: userId)
          .where('date', isGreaterThanOrEqualTo: _startDate.toIso8601String())
          .where('date', isLessThanOrEqualTo: _endDate.toIso8601String())
          .get();

      if (snapshot.docs.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No transactions found for selected period')),
        );
        return;
      }

      // Convert to Transaction objects
      final transactions = snapshot.docs.map((doc) {
        final data = doc.data();
        return fintrack.Transaction(
          id: doc.id,
          userId: data['userId'] as String,
          amount: (data['amount'] as num).toDouble(),
          category: data['category'] as String,
          description: data['description'] as String,
          date: DateTime.parse(data['date'] as String),
          type: data['type'] as String,
        );
      }).toList();

      // Generate and open report
      final file = await _reportService.generateReport(
        transactions,
        _startDate,
        _endDate,
      );

      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done) {
        throw Exception('Could not open file: ${result.message}');
      }

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: ${e.toString()}')),
      );
    } finally {
      setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Generate Report'),
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      'Select Date Range',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            icon: Icon(Icons.calendar_today),
                            label: Text('From: ${_startDate.toString().split(' ')[0]}'),
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _startDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => _startDate = date);
                              }
                            },
                          ),
                        ),
                        SizedBox(width: 16),
                        Expanded(
                          child: TextButton.icon(
                            icon: Icon(Icons.calendar_today),
                            label: Text('To: ${_endDate.toString().split(' ')[0]}'),
                            onPressed: () async {
                              final date = await showDatePicker(
                                context: context,
                                initialDate: _endDate,
                                firstDate: DateTime(2020),
                                lastDate: DateTime.now(),
                              );
                              if (date != null) {
                                setState(() => _endDate = date);
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24),
            ElevatedButton.icon(
              icon: Icon(Icons.description),
              label: Text(_isGenerating ? 'Generating...' : 'Generate Text Report'),
              onPressed: _isGenerating ? null : _generateReport,
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}