import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideal_cst/screens/supervisor/daily_labour_entry_screen.dart';

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
  final Color primaryColor = const Color(0xFF4527A0);
  final Color backgroundColor = const Color.fromARGB(255, 213, 207, 232);

  Widget _buildHeader(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 20),
          ),
        ),
        const SizedBox(width: 16),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Supervisor',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                fontWeight: FontWeight.w500,
              ),
            ),
            SizedBox(height: 2),
            Text(
              'Select Site',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1E1E2D),
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 24),
              Expanded(
                child: widget.assignedSites.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.location_off, size: 64, color: Colors.grey.shade400),
                            const SizedBox(height: 16),
                            Text(
                              'No sites assigned',
                              style: TextStyle(fontSize: 18, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 16),
                        itemCount: widget.assignedSites.length,
                        itemBuilder: (context, index) {
                          final site = widget.assignedSites[index];
                          final siteData = site.data() as Map<String, dynamic>;
                          final siteName = _getDisplaySiteName(siteData, site.id);
                          
                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            elevation: 4,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: primaryColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Icon(Icons.location_city, color: primaryColor, size: 24),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Text(
                                          siteName,
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF1E1E2D),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),
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
                                              siteName: siteName,
                                            ),
                                          ),
                                        );
                                      },
                                      icon: const Icon(Icons.work, color: Colors.white),
                                      label: const Text(
                                        'Open Daily Labour Entry',
                                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: primaryColor,
                                        padding: const EdgeInsets.symmetric(vertical: 14),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
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
}
