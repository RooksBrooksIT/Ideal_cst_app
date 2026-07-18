import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideal_cst/screens/daily_labour_entry_screen.dart';

class SiteSelectionScreen extends StatefulWidget {
  final String supervisorId;
  final String supervisorName;
  final List<DocumentSnapshot> assignedSites;

  const SiteSelectionScreen({
    super.key,
    required this.supervisorId,
    required this.supervisorName,
    required this.assignedSites,
  });

  @override
  _SiteSelectionScreenState createState() => _SiteSelectionScreenState();
}

class _SiteSelectionScreenState extends State<SiteSelectionScreen> {
  final Color primaryColor = const Color(0xFF0b3470);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Site'),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
      ),
      body: widget.assignedSites.isEmpty
          ? const Center(
              child: Text(
                'No sites assigned',
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.assignedSites.length,
              itemBuilder: (context, index) {
                final site = widget.assignedSites[index];
                final siteData = site.data() as Map<String, dynamic>;
                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getDisplaySiteName(siteData, site.id),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Project:',
                          siteData['projectName'] ??
                              siteData['Project Name'] ??
                              '',
                        ),
                        _buildInfoRow(
                          'Stage:',
                          siteData['projectStage'] ??
                              siteData['Project Stage'] ??
                              '',
                        ),
                        _buildInfoRow(
                          'Location:',
                          siteData['location'] ?? siteData['Location'] ?? '',
                        ),
                        _buildInfoRow(
                          'Start Date:',
                          siteData['startDate'] ?? siteData['Start Date'] ?? '',
                        ),
                        _buildInfoRow(
                          'End Date:',
                          siteData['endDate'] ?? siteData['End Date'] ?? '',
                        ),
                        _buildInfoRow(
                          'Comments:',
                          siteData['siteComments'] ??
                              siteData['Site Comments'] ??
                              '',
                        ),
                        _buildInfoRow(
                          'Joined On:',
                          siteData['joinedOn'] ?? siteData['Joined On'] ?? '',
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => DailyLabourEntryScreen(
                                    supervisorId: widget.supervisorId,
                                    supervisorName: widget.supervisorName,
                                    siteId: site.id,
                                    siteName: _getDisplaySiteName(siteData, site.id),
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.work, color: Colors.white),
                            label: const Text(
                              'Open Daily Labour Entry',
                              style: TextStyle(color: Colors.white),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }

  String _getDisplaySiteName(Map<String, dynamic> siteData, String docId) {
    final name = siteData['siteName'] ?? siteData['Site Name'];
    if (name != null && name.toString().trim().isNotEmpty && name.toString() != 'Unknown Site') {
      return name.toString();
    }
    final siteId = siteData['site'] ?? siteData['siteId'] ?? siteData['Site ID'];
    if (siteId != null && siteId.toString().trim().isNotEmpty) {
      return siteId.toString();
    }
    return docId.split('_').first;
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(
            child: Text(value, style: TextStyle(color: Colors.grey[700])),
          ),
        ],
      ),
    );
  }
}
