import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:ideal_cst/screens/manager/components/custom_dropdown.dart';

class ReceptionistAllSitePage extends StatefulWidget {
  const ReceptionistAllSitePage({super.key});

  @override
  State<ReceptionistAllSitePage> createState() => _ReceptionistAllSitePageState();
}

class _ReceptionistAllSitePageState extends State<ReceptionistAllSitePage>
    with SingleTickerProviderStateMixin {
  final Color themeColor = const Color(0xFFD84315);
  final Color backgroundColor = const Color(0xFFFFF3E0);

  TabController? _tabController;
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _siteNameController = TextEditingController();
  final TextEditingController _locationController = TextEditingController();
  final TextEditingController _latitudeController = TextEditingController();
  final TextEditingController _longitudeController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;
  String? _projectType;
  String _status = 'In-Progress';
  bool _isGettingLocation = false;
  bool _isSaving = false;
  String _searchText = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeDefaults();
  }

  Future<void> _initializeDefaults() async {
    final statusList = await fetchProjectStatus();
    if (statusList.isNotEmpty) {
      if (mounted) {
        setState(() {
          _status = statusList.first;
        });
      }
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    _siteNameController.dispose();
    _locationController.dispose();
    _latitudeController.dispose();
    _longitudeController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<List<String>> fetchProjectCategories() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projectCategories')
          .get();
      final categories = snapshot.docs
          .map((doc) => doc['projectCategory']?.toString().trim())
          .where((val) => val != null && val.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();
      if (categories.isEmpty) {
        return ['Residential', 'Commercial', 'Infrastructure', 'Industrial'];
      }
      return categories;
    } catch (e) {
      return ['Residential', 'Commercial', 'Infrastructure', 'Industrial'];
    }
  }

  Future<List<String>> fetchProjectStatus() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projectStatus')
          .get();
      final statusList = snapshot.docs
          .map((doc) => doc['projectState']?.toString().trim())
          .where((val) => val != null && val.isNotEmpty)
          .cast<String>()
          .toSet()
          .toList();
      if (statusList.isEmpty) {
        return ['In-Progress', 'Completed', 'On-Hold'];
      }
      return statusList;
    } catch (e) {
      return ['In-Progress', 'Completed', 'On-Hold'];
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate
          ? (_startDate ?? DateTime.now())
          : (_endDate ?? DateTime.now()),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: themeColor,
              onPrimary: Colors.white,
              onSurface: Colors.black87,
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(foregroundColor: themeColor),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        if (isStartDate) {
          _startDate = picked;
          if (_endDate != null && _endDate!.isBefore(picked)) {
            _endDate = null;
          }
        } else {
          _endDate = picked;
        }
      });
    }
  }

  Future<String> _getNextSiteId(String siteName) async {
    final snapshot = await FirebaseFirestore.instance.collection('Site').get();
    int maxSiteNum = 0;
    for (final doc in snapshot.docs) {
      if (doc.data().containsKey('siteId')) {
        final siteId = doc['siteId'] as String;
        final match = RegExp(r'^ST(\d{3})').firstMatch(siteId);
        if (match != null) {
          final num = int.tryParse(match.group(1)!);
          if (num != null && num > maxSiteNum) {
            maxSiteNum = num;
          }
        }
      }
    }
    final nextNum = maxSiteNum + 1;
    return 'ST${nextNum.toString().padLeft(3, '0')}';
  }

  Future<void> _getCurrentLocation() async {
    setState(() => _isGettingLocation = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        throw 'Location services are disabled.';
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw 'Location permissions are denied';
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw 'Location permissions are permanently denied';
      }
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
      );
      List<Placemark> placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isNotEmpty) {
        Placemark place = placemarks.first;
        String address = [
          place.street,
          place.locality,
          place.administrativeArea,
          place.country,
        ].where((part) => part?.isNotEmpty ?? false).join(', ');
        setState(() {
          _latitudeController.text = position.latitude.toStringAsFixed(6);
          _longitudeController.text = position.longitude.toStringAsFixed(6);
          _locationController.text = address;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error getting location: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGettingLocation = false);
    }
  }

  Future<void> _saveSiteDetails() async {
    if (!_formKey.currentState!.validate() || _isSaving) return;

    setState(() => _isSaving = true);

    final siteName = _siteNameController.text.trim();
    final location = _locationController.text.trim();
    final latitude = _latitudeController.text.trim();
    final longitude = _longitudeController.text.trim();
    final startDate = _startDate != null
        ? DateFormat('yyyy-MM-dd').format(_startDate!)
        : '';
    final endDate = _endDate != null
        ? DateFormat('yyyy-MM-dd').format(_endDate!)
        : '';
    final projectType = _projectType ?? '';
    final status = _status.isNotEmpty ? _status : 'In-Progress';

    try {
      final dupQuery = await FirebaseFirestore.instance
          .collection('Site')
          .where('siteName', isEqualTo: siteName)
          .where('location', isEqualTo: location)
          .limit(1)
          .get();

      if (dupQuery.docs.isNotEmpty) {
        setState(() => _isSaving = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Duplicate detected. Value already exists.'),
              backgroundColor: Colors.orange.shade700,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          );
        }
        return;
      }

      final nextId = await _getNextSiteId(siteName);

      final siteData = {
        'siteId': nextId,
        'siteName': siteName,
        'location': location,
        'latitude': latitude.isNotEmpty ? double.tryParse(latitude) : null,
        'longitude': longitude.isNotEmpty ? double.tryParse(longitude) : null,
        'projectType': projectType,
        'startDate': startDate,
        'endDate': endDate,
        'status': status,
        'createdAt': FieldValue.serverTimestamp(),
      };

      final siteDocId = '${nextId}_${siteName.replaceAll(' ', '')}';
      await FirebaseFirestore.instance
          .collection('Site')
          .doc(siteDocId)
          .set(siteData);

      final projectsSnapshot = await FirebaseFirestore.instance
          .collection('projects')
          .get();
      int maxPRNum = 0;
      for (final doc in projectsSnapshot.docs) {
        final docId = doc.id;
        if (docId.startsWith('PR')) {
          final numeric = int.tryParse(docId.substring(2));
          if (numeric != null && numeric > maxPRNum) {
            maxPRNum = numeric;
          }
        }
      }
      final nextPrDocId = 'PR${(maxPRNum + 1).toString().padLeft(3, '0')}';

      final Timestamp? plannedStartDateTs = _startDate != null
          ? Timestamp.fromDate(_startDate!)
          : null;
      final Timestamp? plannedEndDateTs = _endDate != null
          ? Timestamp.fromDate(_endDate!)
          : null;

      final projectData = {
        'createdAt': FieldValue.serverTimestamp(),
        'siteId': '${nextId}_${siteName.replaceAll(' ', '')}',
        'siteName': siteName,
        'plannedStartDate': plannedStartDateTs,
        'plannedEndDate': plannedEndDateTs,
        'projectType': projectType,
        'status': status,
        'siteLocation': location,
      };

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(nextPrDocId)
          .set(projectData);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Site "$siteName" ($nextId) created successfully!'),
            backgroundColor: Colors.green.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }

      _resetForm();
      _tabController?.animateTo(1); // Switch to All Sites tab
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save site: $e'),
            backgroundColor: Colors.red.shade700,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetForm() {
    setState(() {
      _siteNameController.clear();
      _locationController.clear();
      _latitudeController.clear();
      _longitudeController.clear();
      _startDate = null;
      _endDate = null;
      _projectType = null;
      _status = 'In-Progress';
    });
  }

  Stream<List<Map<String, dynamic>>> _getAllSitesStream() {
    late StreamController<List<Map<String, dynamic>>> controller;
    List<Map<String, dynamic>> siteDocs = [];
    List<Map<String, dynamic>> projectDocs = [];
    StreamSubscription? sub1;
    StreamSubscription? sub2;

    void emitCombined() {
      final Map<String, Map<String, dynamic>> siteMap = {};

      for (var doc in siteDocs) {
        final name = (doc['siteName'] ?? doc['name'] ?? doc['SiteName'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          siteMap[name.toLowerCase()] = {
            'id': doc['id'],
            'siteName': name,
            'location': (doc['location'] ?? doc['siteLocation'] ?? '').toString(),
            'status': (doc['status'] ?? doc['projectStatus'] ?? 'Active').toString(),
            'siteId': (doc['siteId'] ?? doc['id'] ?? '').toString(),
          };
        }
      }

      for (var doc in projectDocs) {
        final name = (doc['siteName'] ?? doc['name'] ?? doc['projectName'] ?? doc['SiteName'] ?? '').toString().trim();
        if (name.isNotEmpty) {
          final key = name.toLowerCase();
          if (!siteMap.containsKey(key)) {
            siteMap[key] = {
              'id': doc['id'],
              'siteName': name,
              'location': (doc['siteLocation'] ?? doc['location'] ?? '').toString(),
              'status': (doc['status'] ?? doc['projectStatus'] ?? 'Active').toString(),
              'siteId': (doc['siteId'] ?? doc['id'] ?? '').toString(),
            };
          }
        }
      }

      final result = siteMap.values.toList();
      result.sort((a, b) => (a['siteName'] as String).compareTo(b['siteName'] as String));

      if (!controller.isClosed) {
        controller.add(result);
      }
    }

    controller = StreamController<List<Map<String, dynamic>>>(
      onListen: () {
        sub1 = FirebaseFirestore.instance.collection('Site').snapshots().listen((snap) {
          siteDocs = snap.docs.map((d) {
            final data = Map<String, dynamic>.from(d.data());
            data['id'] = d.id;
            return data;
          }).toList();
          emitCombined();
        });

        sub2 = FirebaseFirestore.instance.collection('projects').snapshots().listen((snap) {
          projectDocs = snap.docs.map((d) {
            final data = Map<String, dynamic>.from(d.data());
            data['id'] = d.id;
            return data;
          }).toList();
          emitCombined();
        });
      },
      onCancel: () {
        sub1?.cancel();
        sub2?.cancel();
      },
    );

    return controller.stream;
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
            child: Icon(Icons.arrow_back_ios_new, color: themeColor, size: 20),
          ),
        ),
        const SizedBox(width: 16),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Receptionist Portal',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Site Management',
                style: TextStyle(
                  fontSize: 24,
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
    if (_tabController == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
              child: _buildHeader(context),
            ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.03),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TabBar(
                controller: _tabController,
                indicatorColor: themeColor,
                labelColor: themeColor,
                unselectedLabelColor: Colors.grey[600],
                indicatorWeight: 3,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
                tabs: const [
                  Tab(text: 'New Site'),
                  Tab(text: 'All Sites'),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildNewSiteTab(),
                  _buildAllSiteTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNewSiteTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Site Information'),
            _buildTextField(
              controller: _siteNameController,
              label: 'Site Name',
              hintText: 'Enter site name',
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter site name' : null,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _locationController,
                    label: 'Location',
                    hintText: 'Enter location or get current location',
                    validator: (value) =>
                        value?.isEmpty ?? true ? 'Please enter location' : null,
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.only(top: 25),
                  child: IconButton(
                    iconSize: 28,
                    tooltip: 'Get Current Location',
                    icon: _isGettingLocation
                        ? SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2.5,
                              color: themeColor,
                            ),
                          )
                        : Icon(Icons.gps_fixed, color: themeColor),
                    onPressed: _isGettingLocation ? null : _getCurrentLocation,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildTextField(
                    controller: _latitudeController,
                    label: 'Latitude',
                    hintText: 'Latitude coordinates',
                    keyboardType: TextInputType.number,
                    readOnly: true,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildTextField(
                    controller: _longitudeController,
                    label: 'Longitude',
                    hintText: 'Longitude coordinates',
                    keyboardType: TextInputType.number,
                    readOnly: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 30),
            _buildSectionTitle('Project Details'),
            FutureBuilder<List<String>>(
              future: fetchProjectCategories(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingIndicator();
                }
                final categories = snapshot.data ?? ['Residential', 'Commercial', 'Infrastructure', 'Industrial'];
                if (_projectType != null && !categories.contains(_projectType)) {
                  _projectType = null;
                }
                if (_projectType == null && categories.isNotEmpty) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _projectType = categories.first);
                    }
                  });
                }
                return _buildDropdown(
                  value: _projectType ?? categories.first,
                  items: categories,
                  label: 'Project Category',
                  onChanged: (value) => setState(() => _projectType = value),
                );
              },
            ),
            const SizedBox(height: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDateField(
                  label: 'Start Date',
                  date: _startDate,
                  onTap: () => _selectDate(context, true),
                ),
                const SizedBox(height: 20),
                _buildDateField(
                  label: 'End Date',
                  date: _endDate,
                  onTap: () => _selectDate(context, false),
                ),
              ],
            ),
            const SizedBox(height: 20),
            FutureBuilder<List<String>>(
              future: fetchProjectStatus(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return _buildLoadingIndicator();
                }
                final statusList = snapshot.data ?? ['In-Progress', 'Completed', 'On-Hold'];
                if (!statusList.contains(_status)) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      setState(() => _status = statusList.first);
                    }
                  });
                }
                return _buildDropdown(
                  value: _status,
                  items: statusList,
                  label: 'Project Status',
                  onChanged: (value) => setState(() => _status = value!),
                );
              },
            ),
            const SizedBox(height: 35),
            _buildActionButtons(context),
          ],
        ),
      ),
    );
  }

  Widget _buildAllSiteTab() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search site by name or location...',
              hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
              prefixIcon: Icon(Icons.search, color: themeColor),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: themeColor.withValues(alpha: 0.15)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: themeColor, width: 1.5),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
            onChanged: (value) {
              setState(() {
                _searchText = value.trim().toLowerCase();
              });
            },
          ),
          const SizedBox(height: 16),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _getAllSitesStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Text(
                      'Error loading sites: ${snapshot.error}',
                      style: const TextStyle(color: Colors.red),
                    ),
                  );
                }

                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final sites = snapshot.data ?? [];
                final filteredSites = sites.where((site) {
                  final name = (site['siteName'] ?? '').toString().toLowerCase();
                  final location = (site['location'] ?? '').toString().toLowerCase();
                  return name.contains(_searchText) || location.contains(_searchText);
                }).toList();

                if (filteredSites.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.domain_disabled_rounded, size: 64, color: themeColor.withValues(alpha: 0.3)),
                        const SizedBox(height: 12),
                        Text(
                          'No sites found.',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  physics: const BouncingScrollPhysics(),
                  itemCount: filteredSites.length,
                  itemBuilder: (context, index) {
                    final site = filteredSites[index];
                    final siteName = site['siteName'] as String;
                    final location = site['location'] as String;
                    final status = site['status'] as String;
                    final siteId = site['siteId'] as String;

                    return Container(
                      margin: const EdgeInsets.only(bottom: 12),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: themeColor.withValues(alpha: 0.06),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFBE9E7),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.location_city_rounded,
                              color: themeColor,
                              size: 26,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        siteName,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1E1E2D),
                                        ),
                                      ),
                                    ),
                                    if (siteId.isNotEmpty)
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: themeColor.withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          siteId,
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: themeColor,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                                if (location.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.location_on_outlined,
                                        size: 14,
                                        color: Colors.grey[600],
                                      ),
                                      const SizedBox(width: 4),
                                      Expanded(
                                        child: Text(
                                          location,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: status.toLowerCase().contains('progress') || status.toLowerCase().contains('active')
                                  ? Colors.green.shade50
                                  : Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: status.toLowerCase().contains('progress') || status.toLowerCase().contains('active')
                                    ? Colors.green.shade300
                                    : Colors.orange.shade300,
                              ),
                            ),
                            child: Text(
                              status,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: status.toLowerCase().contains('progress') || status.toLowerCase().contains('active')
                                    ? Colors.green.shade800
                                    : Colors.orange.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: themeColor,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hintText,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    bool readOnly = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 7),
        TextFormField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            filled: true,
            fillColor: readOnly ? Colors.grey.shade100 : Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 18,
              vertical: 16,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: themeColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: themeColor.withValues(alpha: 0.3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: themeColor, width: 2),
            ),
          ),
          validator: validator,
          keyboardType: keyboardType,
          readOnly: readOnly,
          style: TextStyle(
            color: readOnly ? Colors.grey.shade700 : Colors.black87,
            fontWeight: FontWeight.w600,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String value,
    required List<String> items,
    required String label,
    required Function(String?) onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 7),
        CustomDropdown<String>(
          value: value,
          labelText: label,
          mainColor: themeColor,
          items: items
              .map(
                (item) => DropdownMenuItem(
                  value: item,
                  child: Text(
                    item,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              )
              .toList(),
          onChanged: onChanged,
          validator: (value) => value == null ? 'Please select $label' : null,
        ),
      ],
    );
  }

  Widget _buildDateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
        const SizedBox(height: 7),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: InputDecorator(
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 18,
                vertical: 16,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: themeColor.withValues(alpha: 0.6)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: themeColor.withValues(alpha: 0.3)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: themeColor, width: 2),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  date == null
                      ? 'Select $label'
                      : DateFormat('MMM d, yyyy').format(date),
                  style: TextStyle(
                    color: date == null ? Colors.grey.shade600 : Colors.black87,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
                Icon(Icons.calendar_today, color: themeColor, size: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoadingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: themeColor),
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildActionButton(
          context,
          icon: Icons.save_rounded,
          label: _isSaving ? 'Saving...' : 'Save',
          color: themeColor,
          onPressed: _isSaving ? () {} : _saveSiteDetails,
        ),
        _buildActionButton(
          context,
          icon: Icons.refresh_rounded,
          label: 'Reset',
          color: Colors.orange.shade800,
          onPressed: _resetForm,
        ),
        _buildActionButton(
          context,
          icon: Icons.cancel_rounded,
          label: 'Cancel',
          color: Colors.grey.shade700,
          onPressed: () => Navigator.pop(context),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        Material(
          shape: const CircleBorder(),
          color: color.withValues(alpha: 0.15),
          child: IconButton(
            iconSize: 26,
            icon: Icon(icon),
            color: color,
            onPressed: onPressed,
            splashRadius: 24,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ],
    );
  }
}
