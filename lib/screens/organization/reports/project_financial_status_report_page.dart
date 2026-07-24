import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideal_cst/screens/organization/financial_status_report.dart';
import 'package:ideal_cst/screens/organization/components/custom_dropdown.dart';

class ProjectFinancialStatusReportPage extends StatefulWidget {
  const ProjectFinancialStatusReportPage({super.key});

  @override
  State<ProjectFinancialStatusReportPage> createState() =>
      _ProjectFinancialStatusReportPageState();
}

class _ProjectFinancialStatusReportPageState
    extends State<ProjectFinancialStatusReportPage> {
  final Color mainColor = const Color(0xFF003768);

  String? selectedSiteId;
  final projectNameController = TextEditingController();
  final ownerNameController = TextEditingController();
  final siteNameController = TextEditingController();

  List<String> siteIds = [];
  bool isLoadingSites = true;

  @override
  void initState() {
    super.initState();
    _fetchSiteIds();
  }

  @override
  void dispose() {
    projectNameController.dispose();
    ownerNameController.dispose();
    siteNameController.dispose();
    super.dispose();
  }

  Future<void> _fetchSiteIds() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance.collection('projects').get();
      final ids = snapshot.docs
          .map((doc) => doc.data()['siteId'] ?? doc.id)
          .where((value) => value != null && value.toString().trim().isNotEmpty)
          .map((value) => value.toString())
          .toSet()
          .toList();
      ids.sort();
      if (mounted) {
        setState(() {
          siteIds = ids;
          isLoadingSites = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoadingSites = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load sites: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _generateReport() {
    if (selectedSiteId == null || selectedSiteId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a site ID'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FinancialStatusReportPage(
          siteId: selectedSiteId!,
          siteName: siteNameController.text,
          projectName: projectNameController.text,
          ownerName: ownerNameController.text,
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
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
                child: Icon(Icons.arrow_back_ios_new, color: mainColor, size: 20),
              ),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Project Financial Status',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Financial Status Report',
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
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E1E2D),
        fontSize: 14,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool readOnly = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color.fromARGB(255, 245, 247, 250),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: TextField(
        controller: controller,
        readOnly: readOnly,
        style: const TextStyle(
          fontWeight: FontWeight.w500,
          color: Color(0xFF1E1E2D),
        ),
        decoration: InputDecoration(
          hintText: hintText,
          hintStyle: TextStyle(color: Colors.grey[400]),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 207, 226, 243),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 20),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.location_on, color: mainColor),
                            const SizedBox(width: 8),
                            _buildSectionTitle('Select Site ID *'),
                          ],
                        ),
                        const SizedBox(height: 10),
                        isLoadingSites
                            ? Center(
                                child: CircularProgressIndicator(color: mainColor),
                              )
                            : CustomDropdown<String>(
                                hintText: 'Select Site ID',
                                value: selectedSiteId,
                                mainColor: mainColor,
                                items: siteIds
                                    .map(
                                      (id) => DropdownMenuItem<String>(
                                        value: id,
                                        child: Text(
                                          id,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF1E1E2D),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) async {
                                  setState(() {
                                    selectedSiteId = value;
                                  });
                                  if (value != null) {
                                    try {
                                      final query = await FirebaseFirestore.instance
                                          .collection('projects')
                                          .where('siteId', isEqualTo: value)
                                          .limit(1)
                                          .get();
                                      if (query.docs.isNotEmpty) {
                                        final data = query.docs.first.data();
                                        siteNameController.text =
                                            data['siteId']?.toString() ?? '';
                                        projectNameController.text =
                                            data['projectName']?.toString() ?? '';
                                        ownerNameController.text =
                                            data['ownerName']?.toString() ?? '';
                                      } else {
                                        siteNameController.clear();
                                        projectNameController.clear();
                                        ownerNameController.clear();
                                      }
                                    } catch (e) {
                                      siteNameController.clear();
                                      projectNameController.clear();
                                      ownerNameController.clear();
                                    }
                                  }
                                },
                              ),
                        const SizedBox(height: 20),

                        _buildSectionTitle('Project Name'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: projectNameController,
                          hintText: 'Project Name',
                        ),
                        const SizedBox(height: 16),

                        _buildSectionTitle('Owner Name'),
                        const SizedBox(height: 8),
                        _buildTextField(
                          controller: ownerNameController,
                          hintText: 'Owner Name',
                        ),
                        const SizedBox(height: 24),

                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: mainColor,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 2,
                            ),
                            onPressed: _generateReport,
                            child: const Text(
                              'GENERATE REPORT',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}