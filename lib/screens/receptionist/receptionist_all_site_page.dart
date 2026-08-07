import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ReceptionistAllSitePage extends StatefulWidget {
  const ReceptionistAllSitePage({super.key});

  @override
  State<ReceptionistAllSitePage> createState() => _ReceptionistAllSitePageState();
}

class _ReceptionistAllSitePageState extends State<ReceptionistAllSitePage> {
  final Color themeColor = const Color(0xFFD84315);
  final TextEditingController _searchController = TextEditingController();
  String _searchText = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
                'All Site List',
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
    return Scaffold(
      backgroundColor: const Color(0xFFFFF3E0), // Light Orange Background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),

              // Search bar
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

              // Read-only Sites List
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

                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFFD84315).withValues(alpha: 0.06),
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
                                    Text(
                                      siteName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF1E1E2D),
                                      ),
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
        ),
      ),
    );
  }
}
