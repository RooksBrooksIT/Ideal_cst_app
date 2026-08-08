import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:ideal_cst/screens/manager/components/custom_dropdown.dart';

class ReceptionistSupervisorMapScreen extends StatefulWidget {
  const ReceptionistSupervisorMapScreen({super.key});

  @override
  State<ReceptionistSupervisorMapScreen> createState() =>
      _ReceptionistSupervisorMapScreenState();
}

class _ReceptionistSupervisorMapScreenState
    extends State<ReceptionistSupervisorMapScreen> {
  bool isEntrySelected = true;

  List<String> selectedSites = []; // Selected site names
  String? selectedSupervisor;
  String? selectedSupervisorId;
  String? selectedProjectStage;
  String? projectName;
  DateTime? joinedDate;
  DateTime? startDate;
  DateTime? endDate;

  final locationController = TextEditingController();
  final commentsController = TextEditingController();

  Map<String, String> siteIdToNameMap = {};
  Map<String, String> siteNameToIdMap = {};
  List<String> siteNameList = [];

  List<String> supervisorList = [];
  List<String> supervisorIdList = [];
  List<String> projectStageList = [];

  static const Color primaryColor = Color(0xFFD84315);
  static const Color backgroundColor = Color(0xFFFFF3E0);
  static const Color mutedColor = Colors.grey;

  @override
  void initState() {
    super.initState();
    fetchSiteList();
    fetchSupervisorList();
    fetchProjectStageList();
  }

  void fetchSiteList() async {
    try {
      QuerySnapshot siteSnapshot =
          await FirebaseFirestore.instance.collection('Site').get();
      if (!mounted) return;

      final Map<String, String> idToName = {};
      final Map<String, String> nameToId = {};
      final List<String> names = [];

      for (var doc in siteSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>? ?? {};
        final id = doc.id;
        String name = (data['siteName'] ?? data['name'] ?? data['SiteName'] ?? '').toString().trim();
        if (name.isEmpty) {
          if (id.contains('_')) {
            final parts = id.split('_');
            if (parts.length > 1 && parts[1].trim().isNotEmpty) {
              name = parts.sublist(1).join('_').trim();
            } else {
              name = id;
            }
          } else {
            name = id;
          }
        }
        idToName[id] = name;
        nameToId[name] = id;
        if (!names.contains(name)) {
          names.add(name);
        }
      }

      setState(() {
        siteIdToNameMap = idToName;
        siteNameToIdMap = nameToId;
        siteNameList = names;
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching site list')),
      );
    }
  }

  void fetchSupervisorList() async {
    try {
      QuerySnapshot supervisorSnapshot =
          await FirebaseFirestore.instance.collection('supervisor').get();
      if (!mounted) return;
      setState(() {
        supervisorList = supervisorSnapshot.docs
            .map((doc) => doc['UserName'] as String)
            .toList();
        supervisorIdList =
            supervisorSnapshot.docs.map((doc) => doc.id).toList();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching supervisor list')),
      );
    }
  }

  void fetchProjectStageList() async {
    try {
      QuerySnapshot projectStageSnapshot = await FirebaseFirestore.instance
          .collection('projectStages')
          .get();
      if (!mounted) return;
      setState(() {
        projectStageList = projectStageSnapshot.docs
            .map((doc) => doc['projectStage'] as String)
            .toSet()
            .toList();
      });
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching project stage list')),
      );
    }
  }

  void fetchSiteDataBySiteId(String siteId) async {
    try {
      DocumentSnapshot siteSnapshot =
          await FirebaseFirestore.instance.collection('Site').doc(siteId).get();
      if (!mounted) return;
      if (siteSnapshot.exists) {
        final data = siteSnapshot.data() as Map<String, dynamic>? ?? {};

        setState(() {
          locationController.text = data.containsKey('location')
              ? (data['location'] ?? '')
              : '';
          joinedDate = data.containsKey('startDate')
              ? _parseDate(data['startDate'])
              : null;
          startDate = data.containsKey('startDate')
              ? _parseDate(data['startDate'])
              : null;
          endDate = data.containsKey('endDate')
              ? _parseDate(data['endDate'])
              : null;
          projectName =
              data.containsKey('siteName') ? (data['siteName'] ?? siteIdToNameMap[siteId] ?? '') : (siteIdToNameMap[siteId] ?? '');
        });

        try {
          final projQuery = await FirebaseFirestore.instance
              .collection('projects')
              .where('siteId', isEqualTo: siteId)
              .limit(1)
              .get();

          if (!mounted) return;
          if (projQuery.docs.isNotEmpty) {
            final projectData = projQuery.docs.first.data();
            final stage = projectData['projectStage']?.toString();
            if (stage != null && stage.isNotEmpty) {
              setState(() {
                selectedProjectStage = stage;
                if (!projectStageList.contains(stage)) {
                  projectStageList = [...projectStageList, stage];
                }
              });
            }
          }
        } catch (_) {}
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Site data not found')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error fetching site data')),
      );
    }
  }

  DateTime? _parseDate(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  void resetForm() {
    setState(() {
      selectedSites = [];
      selectedSupervisor = null;
      selectedProjectStage = null;
      selectedSupervisorId = null;
      projectName = null;
      locationController.clear();
      commentsController.clear();
      joinedDate = null;
      startDate = null;
      endDate = null;
    });
  }

  Future<Map<String, dynamic>?> fetchSiteDataFromFirestore(
      String siteId) async {
    try {
      DocumentSnapshot siteSnapshot =
          await FirebaseFirestore.instance.collection('Site').doc(siteId).get();
      if (siteSnapshot.exists) {
        return siteSnapshot.data() as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  void saveForm() async {
    if (selectedSites.isEmpty ||
        selectedSupervisor == null ||
        locationController.text.isEmpty ||
        joinedDate == null ||
        startDate == null ||
        endDate == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill all required fields and select at least one site.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    try {
      for (String siteName in selectedSites) {
        String siteId = siteNameToIdMap[siteName] ?? siteName;
        Map<String, dynamic>? siteData =
            await fetchSiteDataFromFirestore(siteId);
        String projName = siteData?['siteName'] ?? siteName;
        String loc = siteData?['location'] ?? locationController.text;

        String docId = '${siteId}_$selectedSupervisorId';

        Map<String, dynamic> data = {
          "joinedOn": joinedDate!.toIso8601String(),
          "startDate": startDate!.toIso8601String(),
          "endDate": endDate!.toIso8601String(),
          "location": loc,
          "siteId": siteId,
          "site": siteId,
          "projectName": projName,
          "siteComments": commentsController.text,
          "supervisor": selectedSupervisor,
          "supervisorId": selectedSupervisorId,
          "Supervisor ID": selectedSupervisorId,
          "assignedBy": "Receptionist",
        };

        DocumentReference docRef = FirebaseFirestore.instance
            .collection('siteSupervisorMap')
            .doc(docId);
        DocumentSnapshot docSnapshot = await docRef.get();
        if (docSnapshot.exists) {
          await docRef.update(data);
        } else {
          await docRef.set(data);
        }
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Assignments saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
      resetForm();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error saving assignments.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    locationController.dispose();
    commentsController.dispose();
    super.dispose();
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        InkWell(
          onTap: () => Navigator.pop(context),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(10),
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
            child: const Icon(Icons.arrow_back_ios_new, color: primaryColor, size: 20),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supervisor Management',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Site-Supervisor Mapping',
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E1E2D),
                  letterSpacing: -0.5,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: _buildHeader(context),
            ),
            const SizedBox(height: 8),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: isEntrySelected ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            setState(() => isEntrySelected = true);
                          },
                          child: Text(
                            'Mapping Entry',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: isEntrySelected ? Colors.white : primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: !isEntrySelected ? primaryColor : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () {
                            setState(() => isEntrySelected = false);
                          },
                          child: Text(
                            'Mappings Info',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: !isEntrySelected ? Colors.white : primaryColor,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: isEntrySelected
                  ? _buildEntrySection(context)
                  : _buildInfoCardSection(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEntrySection(BuildContext context) {
    final inputBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: primaryColor.withValues(alpha: 0.3)),
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                const Text(
                  'Mapping Details',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 20),

                // Multi-select for sites (Showing Site Names ONLY)
                InkWell(
                  onTap: () async {
                    final result = await showDialog<List<String>>(
                      context: context,
                      builder: (context) => MultiSelectDialog(
                        items: siteNameList,
                        initialSelected: selectedSites,
                        title: 'Select Sites',
                        primaryColor: primaryColor,
                      ),
                    );
                    if (result != null) {
                      setState(() {
                        selectedSites = result;
                      });
                      if (result.isNotEmpty) {
                        final firstSiteName = result.first;
                        final firstSiteId = siteNameToIdMap[firstSiteName] ?? firstSiteName;
                        fetchSiteDataBySiteId(firstSiteId);
                      }
                    }
                  },
                  child: InputDecorator(
                    decoration: InputDecoration(
                      labelText: 'Sites (${selectedSites.length} selected)',
                      prefixIcon: const Icon(
                        Icons.location_on_outlined,
                        color: primaryColor,
                      ),
                      border: inputBorder,
                      enabledBorder: inputBorder,
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: primaryColor, width: 2),
                      ),
                      filled: true,
                      fillColor: Colors.white,
                      labelStyle: const TextStyle(color: primaryColor),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 16,
                      ),
                    ),
                    child: Text(
                      selectedSites.isEmpty
                          ? 'Tap to select sites'
                          : selectedSites.join(', '),
                      style: TextStyle(
                        fontSize: 14,
                        color: selectedSites.isEmpty ? mutedColor : Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Project Name',
                    prefixIcon: const Icon(
                      Icons.business_outlined,
                      color: primaryColor,
                    ),
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    filled: true,
                    fillColor: Colors.grey[50],
                    labelStyle: const TextStyle(color: primaryColor),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                  controller: TextEditingController(text: projectName ?? ''),
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: locationController,
                  decoration: InputDecoration(
                    labelText: 'Location',
                    prefixIcon: const Icon(Icons.place_outlined, color: primaryColor),
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primaryColor, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    labelStyle: const TextStyle(color: primaryColor),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                CustomDropdown<String>(
                  value: selectedSupervisorId,
                  labelText: 'Supervisor ID',
                  hintText: 'Select Supervisor ID',
                  prefixIcon: Icons.badge_outlined,
                  items: supervisorIdList.map((id) {
                    return DropdownMenuItem(
                      value: id,
                      child: Text(
                        id,
                        style: const TextStyle(fontSize: 14),
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedSupervisorId = value;
                      int idx = supervisorIdList.indexOf(value ?? '');
                      selectedSupervisor =
                          (idx >= 0 && idx < supervisorList.length)
                              ? supervisorList[idx]
                              : null;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Supervisor',
                    prefixIcon: const Icon(Icons.person_outline, color: primaryColor),
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    filled: true,
                    fillColor: Colors.grey[50],
                    labelStyle: const TextStyle(color: primaryColor),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                  controller: TextEditingController(
                    text: selectedSupervisor ?? '',
                  ),
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: commentsController,
                  decoration: InputDecoration(
                    labelText: 'Site Comments',
                    prefixIcon: const Icon(
                      Icons.comment_outlined,
                      color: primaryColor,
                    ),
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: primaryColor, width: 2),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    labelStyle: const TextStyle(color: primaryColor),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                  maxLines: 3,
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Start Date',
                    prefixIcon: const Icon(
                      Icons.calendar_today_outlined,
                      color: primaryColor,
                    ),
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    filled: true,
                    fillColor: Colors.grey[50],
                    labelStyle: const TextStyle(color: primaryColor),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                  controller: TextEditingController(
                    text: startDate != null
                        ? DateFormat('yyyy-MM-dd').format(startDate!)
                        : '',
                  ),
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'End Date',
                    prefixIcon: const Icon(Icons.calendar_month, color: primaryColor),
                    border: inputBorder,
                    enabledBorder: inputBorder,
                    filled: true,
                    fillColor: Colors.grey[50],
                    labelStyle: const TextStyle(color: primaryColor),
                    contentPadding: const EdgeInsets.symmetric(
                      vertical: 14,
                      horizontal: 16,
                    ),
                  ),
                  controller: TextEditingController(
                    text: endDate != null
                        ? DateFormat('yyyy-MM-dd').format(endDate!)
                        : '',
                  ),
                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                ),
                const SizedBox(height: 16),
                GestureDetector(
                  onTap: () => _selectAnyDate(context, dateType: 'joined'),
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Joined On *',
                        hintText: 'Select Joined On Date',
                        prefixIcon: const Icon(
                          Icons.event_available,
                          color: primaryColor,
                        ),
                        border: inputBorder,
                        enabledBorder: inputBorder,
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: primaryColor, width: 2),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        labelStyle: const TextStyle(color: primaryColor),
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 16,
                        ),
                      ),
                      controller: TextEditingController(
                        text: joinedDate != null
                            ? DateFormat('yyyy-MM-dd').format(joinedDate!)
                            : '',
                      ),
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildActionButtons(context),
        ],
      ),
    );
  }

  Widget _buildInfoCardSection(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('siteSupervisorMap')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: primaryColor),
          );
        }
        if (snapshot.hasError) {
          return const Center(
            child: Text(
              'Error loading site-supervisor mappings.',
              style: TextStyle(color: Colors.red),
            ),
          );
        }
        final docs = snapshot.data?.docs ?? [];
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.map_outlined, size: 60, color: primaryColor.withValues(alpha: 0.4)),
                const SizedBox(height: 16),
                Text(
                  'No site-supervisor mappings available.',
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
          physics: const BouncingScrollPhysics(),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final doc = docs[index];
            final data = doc.data() as Map<String, dynamic>? ?? {};
            String rawSiteId = data['siteId']?.toString() ?? data['site']?.toString() ?? '';
            String rawProjectName = data['projectName']?.toString() ?? '';

            // Clean Site Name for Display
            String displaySiteName = rawProjectName.isNotEmpty && rawProjectName != '-'
                ? rawProjectName
                : (siteIdToNameMap[rawSiteId] ?? (rawSiteId.contains('_') ? rawSiteId.split('_').last : rawSiteId));

            String supervisor = data['supervisor']?.toString() ?? '-';
            String supervisorId = data['supervisorId']?.toString() ?? data['Supervisor ID']?.toString() ?? '';
            String location = data['location']?.toString() ?? '';

            String joinedDateStr = '-';
            final joinedRaw = data['joinedOn'];
            if (joinedRaw != null) {
              try {
                if (joinedRaw is String) {
                  joinedDateStr = DateFormat('yyyy-MM-dd')
                      .format(DateTime.parse(joinedRaw));
                }
              } catch (_) {}
            }

            return Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: primaryColor.withValues(alpha: 0.15)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFBE9E7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.location_city_rounded,
                          color: primaryColor,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              displaySiteName,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E1E2D),
                              ),
                            ),
                            if (location.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                location,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.person_outline, size: 16, color: primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        "Supervisor: ",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1E1E2D)),
                      ),
                      Expanded(
                        child: Text(
                          '$supervisor ${supervisorId.isNotEmpty ? "($supervisorId)" : ""}',
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.event_available, size: 16, color: primaryColor),
                      const SizedBox(width: 8),
                      const Text(
                        "Joined On: ",
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                            color: Color(0xFF1E1E2D)),
                      ),
                      Text(
                        joinedDateStr,
                        style: TextStyle(fontSize: 13, color: Colors.grey[800]),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _selectAnyDate(BuildContext context, {required String dateType}) async {
    DateTime initialDate = DateTime.now();
    if (dateType == 'start') {
      initialDate = startDate ?? DateTime.now();
    } else if (dateType == 'end') {
      initialDate = endDate ?? DateTime.now();
    } else if (dateType == 'joined') {
      initialDate = joinedDate ?? DateTime.now();
    }
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (dateType == 'start') {
          startDate = picked;
        } else if (dateType == 'end') {
          endDate = picked;
        } else if (dateType == 'joined') {
          joinedDate = picked;
        }
      });
    }
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: ElevatedButton.icon(
            onPressed: () => _showSaveConfirmationDialog(context),
            icon: const Icon(Icons.save, color: Colors.white, size: 18),
            label: const Text(
              'Save',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.white),
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
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: resetForm,
            icon: const Icon(Icons.refresh, color: primaryColor, size: 18),
            label: const Text(
              'Reset',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: primaryColor),
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: primaryColor),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showSaveConfirmationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Confirm Save',
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 20,
            ),
          ),
          content: const Text(
            'Assignments will be saved for selected sites. Do you want to continue?',
            style: TextStyle(fontSize: 15),
          ),
          actions: [
            OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: primaryColor, width: 1.5),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text(
                'Cancel',
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              ),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                saveForm();
              },
              child: const Text('Save', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }
}

class MultiSelectDialog extends StatefulWidget {
  final List<String> items;
  final List<String> initialSelected;
  final String title;
  final Color primaryColor;

  const MultiSelectDialog({
    super.key,
    required this.items,
    required this.initialSelected,
    required this.title,
    required this.primaryColor,
  });

  @override
  State<MultiSelectDialog> createState() => _MultiSelectDialogState();
}

class _MultiSelectDialogState extends State<MultiSelectDialog> {
  late List<String> selectedItems;

  @override
  void initState() {
    super.initState();
    selectedItems = List.from(widget.initialSelected);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(
        widget.title,
        style: TextStyle(color: widget.primaryColor, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: widget.items.isEmpty
            ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: Text('No sites available to select.'),
              )
            : ListView.builder(
                shrinkWrap: true,
                itemCount: widget.items.length,
                itemBuilder: (context, index) {
                  final item = widget.items[index];
                  final isSelected = selectedItems.contains(item);
                  return CheckboxListTile(
                    activeColor: widget.primaryColor,
                    title: Text(item, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500)),
                    value: isSelected,
                    onChanged: (checked) {
                      setState(() {
                        if (checked == true) {
                          selectedItems.add(item);
                        } else {
                          selectedItems.remove(item);
                        }
                      });
                    },
                  );
                },
              ),
      ),
      actions: [
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: widget.primaryColor, width: 1.5),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
          onPressed: () => Navigator.pop(context),
          child: Text(
            'Cancel',
            style: TextStyle(
              color: widget.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: widget.primaryColor,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          ),
          onPressed: () => Navigator.pop(context, selectedItems),
          child: const Text(
            'OK',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
        ),
      ],
    );
  }
}
