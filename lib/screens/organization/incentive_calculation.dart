import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideal_cst/screens/organization/incentive_calculation_sheet.dart';
import 'package:ideal_cst/screens/organization/components/custom_dropdown.dart';

class IncentiveCalculation extends StatefulWidget {
  const IncentiveCalculation({super.key});

  @override
  State<IncentiveCalculation> createState() => _IncentiveCalculationState();
}

class _IncentiveCalculationState extends State<IncentiveCalculation> {
  final _formKey = GlobalKey<FormState>();
  final Color mainColor = const Color(0xFF003768);

  String? _selectedSiteId;
  String? _selectedProjectStage;
  String _supervisorName = '';

  List<String> _siteIds = [];
  List<String> _filteredProjectStages = [];
  Map<String, String> _siteSupervisors = {};
  Map<String, Set<String>> _siteProjectStages = {};

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchSiteSupervisorData();
  }

  Future<void> _fetchSiteSupervisorData() async {
    setState(() {
      _loading = true;
    });
    try {
      final siteIds = <String>{};
      final siteSupervisors = <String, String>{};
      final siteProjectStages = <String, Set<String>>{};

      // 1. Fetch siteSupervisorEntries
      try {
        final snapshot = await FirebaseFirestore.instance
            .collection('siteSupervisorEntries')
            .get();
        for (var doc in snapshot.docs) {
          final data = doc.data();
          final site = data['siteId'] as String? ?? doc.id;
          final supervisor = data['supervisorId'] as String? ?? data['supervisor'] as String? ?? '';
          final projectStage = data['projectStage'] as String? ?? '';

          if (site.isNotEmpty) siteIds.add(site);
          if (site.isNotEmpty && supervisor.isNotEmpty) {
            siteSupervisors[site] = supervisor;
          }
          if (site.isNotEmpty && projectStage.isNotEmpty) {
            siteProjectStages.putIfAbsent(site, () => <String>{}).add(projectStage);
          }
        }
      } catch (e) {
        debugPrint('Error fetching siteSupervisorEntries: $e');
      }

      // 2. Fetch siteSupervisorMap
      try {
        final mapSnap = await FirebaseFirestore.instance
            .collection('siteSupervisorMap')
            .get();
        for (var doc in mapSnap.docs) {
          final data = doc.data();
          final site = data['site'] as String? ?? doc.id;
          final supervisor = data['supervisor'] as String? ?? '';
          final projectStage = data['projectStage'] as String? ?? '';

          if (site.isNotEmpty) siteIds.add(site);
          if (site.isNotEmpty && supervisor.isNotEmpty && !siteSupervisors.containsKey(site)) {
            siteSupervisors[site] = supervisor;
          }
          if (site.isNotEmpty && projectStage.isNotEmpty) {
            siteProjectStages.putIfAbsent(site, () => <String>{}).add(projectStage);
          }
        }
      } catch (e) {
        debugPrint('Error fetching siteSupervisorMap: $e');
      }

      // 3. Fetch projects (for remaining sites)
      try {
        final projectsSnap = await FirebaseFirestore.instance
            .collection('projects')
            .get();
        for (var doc in projectsSnap.docs) {
          final data = doc.data();
          final site = data['siteId'] as String? ?? doc.id;
          final supervisor = data['supervisor'] as String? ?? data['supervisorName'] as String? ?? '';
          final projectStage = data['projectStage'] as String? ?? '';

          if (site.isNotEmpty) siteIds.add(site);
          if (site.isNotEmpty && supervisor.isNotEmpty && !siteSupervisors.containsKey(site)) {
            siteSupervisors[site] = supervisor;
          }
          if (site.isNotEmpty && projectStage.isNotEmpty) {
            siteProjectStages.putIfAbsent(site, () => <String>{}).add(projectStage);
          }
        }
      } catch (e) {
        debugPrint('Error fetching projects: $e');
      }

      final sortedSiteIds = siteIds.toList()..sort();

      if (mounted) {
        setState(() {
          _siteIds = sortedSiteIds;
          _siteSupervisors = siteSupervisors;
          _siteProjectStages = siteProjectStages;
          _filteredProjectStages = [];
          _loading = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching data: $e');
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
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
                  'Incentive',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Calculation',
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

  Widget _buildTextFieldContainer({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: mainColor.withValues(alpha: 0.04),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  InputDecoration _inputDecoration({String? hintText}) {
    return InputDecoration(
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      hintText: hintText,
      hintStyle: TextStyle(color: Colors.grey[500], fontSize: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: mainColor.withValues(alpha: 0.25)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: mainColor.withValues(alpha: 0.25)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: mainColor, width: 2),
      ),
    );
  }

  void _calculate() {
    if (_formKey.currentState!.validate()) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => IncentiveCalculationSheet(
            siteId: _selectedSiteId!,
            supervisor: _supervisorName,
            projectStage: _selectedProjectStage!,
          ),
        ),
      );
    }
  }

  void _reset() {
    setState(() {
      _selectedSiteId = null;
      _selectedProjectStage = null;
      _supervisorName = '';
      _filteredProjectStages = [];
      _formKey.currentState?.reset();
    });
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
                  child: _loading
                      ? Center(
                          child: CircularProgressIndicator(color: mainColor),
                        )
                      : SingleChildScrollView(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.card_giftcard, color: mainColor),
                                    const SizedBox(width: 8),
                                    _buildSectionTitle('Select Calculation Criteria'),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Site ID Dropdown
                                _buildSectionTitle('Site ID *'),
                                const SizedBox(height: 8),
                                CustomDropdown<String>(
                                  hintText: 'Select Site ID',
                                  value: _selectedSiteId,
                                  mainColor: mainColor,
                                  items: _siteIds
                                      .map(
                                        (site) => DropdownMenuItem<String>(
                                          value: site,
                                          child: Text(
                                            site,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF1E1E2D),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedSiteId = newValue;
                                      _supervisorName = newValue != null
                                          ? (_siteSupervisors[newValue] ?? '')
                                          : '';
                                      _filteredProjectStages = newValue != null
                                          ? _siteProjectStages[newValue]?.toList() ?? []
                                          : [];
                                      _selectedProjectStage = null;
                                    });
                                  },
                                ),
                                const SizedBox(height: 20),

                                // Supervisor Name (Auto-filled)
                                _buildSectionTitle('Supervisor Name'),
                                const SizedBox(height: 8),
                                _buildTextFieldContainer(
                                  child: TextFormField(
                                    controller: TextEditingController(text: _supervisorName),
                                    readOnly: true,
                                    style: TextStyle(fontWeight: FontWeight.w600, color: mainColor),
                                    decoration: _inputDecoration(hintText: 'Auto-filled supervisor name'),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Project Stage Dropdown
                                _buildSectionTitle('Project Stage *'),
                                const SizedBox(height: 8),
                                CustomDropdown<String>(
                                  hintText: 'Select Project Stage',
                                  value: _selectedProjectStage,
                                  mainColor: mainColor,
                                  items: _filteredProjectStages
                                      .map(
                                        (stage) => DropdownMenuItem<String>(
                                          value: stage,
                                          child: Text(
                                            stage,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF1E1E2D),
                                            ),
                                          ),
                                        ),
                                      )
                                      .toList(),
                                  onChanged: (String? newValue) {
                                    setState(() {
                                      _selectedProjectStage = newValue;
                                    });
                                  },
                                ),
                                const SizedBox(height: 28),

                                // Info Banner
                                Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: mainColor.withValues(alpha: 0.05),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: mainColor.withValues(alpha: 0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline, color: mainColor, size: 20),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Select a site to view available project stages and calculate supervisor performance incentives.',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[700],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 28),

                                // Action Buttons
                                Column(
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: mainColor,
                                          padding: const EdgeInsets.symmetric(vertical: 14),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                          elevation: 2,
                                        ),
                                        onPressed: _calculate,
                                        child: const Text(
                                          'CALCULATE INCENTIVES',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.1,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(color: mainColor, width: 1.5),
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: _reset,
                                            child: Text(
                                              'RESET',
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: mainColor,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.1,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              side: BorderSide(color: Colors.grey.shade400, width: 1.5),
                                              padding: const EdgeInsets.symmetric(vertical: 14),
                                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                            ),
                                            onPressed: () => Navigator.pop(context),
                                            child: Text(
                                              'CANCEL',
                                              style: TextStyle(
                                                fontSize: 15,
                                                color: Colors.grey[700],
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.1,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
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