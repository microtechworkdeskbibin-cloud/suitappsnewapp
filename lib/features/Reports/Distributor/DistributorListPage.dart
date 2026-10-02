import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:suitapps/core/config/api_config.dart'; // adjust import path
import 'package:suitapps/features/Reports/Distributor/DistributorOrderReportPage.dart';


/// First screen of the report flow — lists distributors for the logged-in
/// user. Tapping one opens DistributorOrderReportPage for date selection.
class DistributorListPage extends StatefulWidget {
  const DistributorListPage({super.key});

  @override
  State<DistributorListPage> createState() => _DistributorListPageState();
}

class _DistributorListPageState extends State<DistributorListPage> {
  List<dynamic> _distributors = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDistributors();
  }

  Future<void> _fetchDistributors() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('UserID') ?? prefs.getInt('UserId') ?? 0;

      final uri = Uri.parse(
        '${ApiConfig.apiBaseUrl}${ApiConfig.getDistributorsByUserUrl}'
        '?UserID=$userId',
      );

      final response = await http
          .get(uri)
          .timeout(ApiConfig.connectionTimeout);

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true) {
          setState(() {
            _distributors = body['data'] ?? [];
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = body['message']?.toString() ?? 'Failed to load distributors';
            _isLoading = false;
          });
        }
      } else {
        setState(() {
          _error = 'Server error: ${response.statusCode}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Error: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select Distributor')),
      body: RefreshIndicator(
        onRefresh: _fetchDistributors,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        children: [
          const SizedBox(height: 80),
          Icon(Icons.error_outline, size: 48, color: Colors.red.shade300),
          const SizedBox(height: 12),
          Center(child: Text(_error!, textAlign: TextAlign.center)),
          const SizedBox(height: 12),
          Center(
            child: ElevatedButton(
              onPressed: _fetchDistributors,
              child: const Text('Retry'),
            ),
          ),
        ],
      );
    }

    if (_distributors.isEmpty) {
      return ListView(
        children: const [
          SizedBox(height: 80),
          Icon(Icons.inbox_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 12),
          Center(child: Text('No distributors found')),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _distributors.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final d = _distributors[index];
        final name = (d['DistributorName'] ?? d['AccountName'] ?? '').toString();
        final code = (d['DistributorCode'] ?? d['AccountCode'] ?? '').toString();
        final accountId = d['DistributorAccountID'] ?? d['AccountID'];

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.store)),
            title: Text(name, style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(code),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => DistributorOrderReportPage(
                    distributorAccountId: accountId is int
                        ? accountId
                        : int.tryParse(accountId.toString()) ?? 0,
                    distributorName: name,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}