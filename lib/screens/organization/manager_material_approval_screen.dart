import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ManagerMaterialApprovalScreen extends StatefulWidget {
  const ManagerMaterialApprovalScreen({super.key});

  @override
  State<ManagerMaterialApprovalScreen> createState() =>
      _ManagerMaterialApprovalScreenState();
}

class _ManagerMaterialApprovalScreenState
    extends State<ManagerMaterialApprovalScreen>
    with SingleTickerProviderStateMixin {
  final Color mainColor = const Color(0xFF003768);

  late TabController _tabController;

  final TextEditingController _processingSearchController =
      TextEditingController();
  final TextEditingController _approvedSearchController =
      TextEditingController();
  String _processingSearchQuery = '';
  String _approvedSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _processingSearchController.dispose();
    _approvedSearchController.dispose();
    super.dispose();
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
                  'Material Request',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Approval',
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

  Widget buildSearchBar(
    TextEditingController controller,
    Function(String) onChanged,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: "Search material requests...",
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        prefixIcon: Icon(Icons.search, color: mainColor),
        filled: true,
        fillColor: const Color.fromARGB(255, 245, 247, 250),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mainColor.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mainColor.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mainColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      ),
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      onChanged: onChanged,
    );
  }

  Widget buildRequestCard(Map<String, dynamic> data, String docId) {
    final List materials = data['materials'] ?? [];
    final bool isApproved = data['status'] == 'Approved';
    return GestureDetector(
      onTap: () => _showRequestDetailsModal(context, data, docId),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.inventory_2, color: mainColor, size: 24),
                    const SizedBox(width: 10),
                    Text(
                      data['matReqId'] ?? '',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: mainColor,
                      ),
                    ),
                  ],
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isApproved
                        ? Colors.green.shade100
                        : Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    data['status'] ?? '',
                    style: TextStyle(
                      color: isApproved
                          ? Colors.green.shade800
                          : Colors.orange.shade900,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _infoRow(Icons.location_on, "Site ID", data['siteId']),
            const SizedBox(height: 4),
            _infoRow(Icons.business, "Project", data['projectName']),
            const SizedBox(height: 4),
            _infoRow(Icons.person, "Supervisor", data['supervisorName']),
            const SizedBox(height: 4),
            _infoRow(Icons.calendar_today, "Date", data['date']),
            const SizedBox(height: 12),
            const Divider(),
            Row(
              children: [
                Icon(Icons.category_outlined, color: mainColor, size: 20),
                const SizedBox(width: 6),
                Text(
                  "${materials.length} Requested Items",
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: Color(0xFF1E1E2D),
                  ),
                ),
                const Spacer(),
                Icon(
                  isApproved ? Icons.verified : Icons.pending_actions,
                  size: 18,
                  color: isApproved ? Colors.green[700] : Colors.orange[800],
                ),
                const SizedBox(width: 4),
                Text(
                  isApproved ? "Approved" : "Pending Approval",
                  style: TextStyle(
                    color: isApproved ? Colors.green[700] : Colors.orange[800],
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showRequestDetailsModal(
    BuildContext context,
    Map<String, dynamic> data,
    String docId,
  ) {
    final List materials = data['materials'] ?? [];
    final bool isProcessing = data['status'] == 'Processing';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            minChildSize: 0.4,
            maxChildSize: 0.95,
            builder: (context, scrollController) {
              return SingleChildScrollView(
                controller: scrollController,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          data['matReqId'] ?? '',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: mainColor,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: data['status'] == 'Approved'
                                ? Colors.green.shade100
                                : Colors.orange.shade100,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            data['status'] ?? '',
                            style: TextStyle(
                              color: data['status'] == 'Approved'
                                  ? Colors.green.shade800
                                  : Colors.orange.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 10),

                    Text(
                      "Project Details",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: mainColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color.fromARGB(255, 245, 247, 250),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        children: [
                          _infoRow(Icons.location_on, "Site ID", data['siteId']),
                          const SizedBox(height: 6),
                          _infoRow(Icons.business, "Project", data['projectName']),
                          const SizedBox(height: 6),
                          _infoRow(Icons.person, "Supervisor", data['supervisorName']),
                          const SizedBox(height: 6),
                          _infoRow(Icons.calendar_today, "Date", data['date']),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    Text(
                      "Materials Requested",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: mainColor,
                      ),
                    ),
                    const SizedBox(height: 10),
                    ...materials.map<Widget>((mat) => _materialTile(mat)),
                    const SizedBox(height: 20),

                    Row(
                      children: [
                        if (isProcessing)
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                              label: const Text(
                                "APPROVE REQUEST",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green[700],
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              onPressed: () async {
                                try {
                                  await FirebaseFirestore.instance
                                      .collection('siteMaterialsRequest')
                                      .doc(docId)
                                      .update({'status': 'Approved'});
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                  }
                                } catch (e) {
                                  if (context.mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text('Failed to approve: $e'),
                                      ),
                                    );
                                  }
                                }
                              },
                            ),
                          ),
                        if (isProcessing) const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(color: mainColor, width: 1.5),
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => Navigator.pop(context),
                            child: Text(
                              "CLOSE",
                              style: TextStyle(
                                color: mainColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _infoRow(IconData icon, String label, String? value) {
    return Row(
      children: [
        Icon(icon, color: mainColor, size: 18),
        const SizedBox(width: 8),
        Text(
          "$label: ",
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 13,
            color: Color(0xFF1E1E2D),
          ),
        ),
        Expanded(
          child: Text(
            value ?? '',
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 13, color: Colors.grey[800]),
          ),
        ),
      ],
    );
  }

  Widget _materialTile(Map<String, dynamic> mat) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mainColor.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: mainColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.inventory, color: mainColor, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mat['materialName'] ?? 'Unknown Material',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: Color(0xFF1E1E2D),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        'Qty: ${mat['materialQty']} ${mat['materialUnit'] ?? ''}  |  ',
                        style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                      ),
                      Text(
                        'Priority: ${mat['priority'] ?? 'Normal'}',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: (mat['priority']?.toString().toLowerCase() == 'high')
                              ? Colors.red[700]
                              : mainColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
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
              const SizedBox(height: 16),
              Container(
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
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    TabBar(
                      controller: _tabController,
                      labelColor: mainColor,
                      unselectedLabelColor: Colors.grey[500],
                      indicatorColor: mainColor,
                      indicatorWeight: 3,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                      tabs: const [
                        Tab(text: "Processing Requests"),
                        Tab(text: "Approved Requests"),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // Processing Requests Tab with search
                    Column(
                      children: [
                        buildSearchBar(_processingSearchController, (query) {
                          setState(
                            () => _processingSearchQuery =
                                query.trim().toLowerCase(),
                          );
                        }),
                        const SizedBox(height: 10),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('siteMaterialsRequest')
                                .where('status', isEqualTo: 'Processing')
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                  child: CircularProgressIndicator(
                                    color: mainColor,
                                  ),
                                );
                              }
                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No processing requests found.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                );
                              }
                              final docs = snapshot.data!.docs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final query = _processingSearchQuery;
                                if (query.isEmpty) return true;
                                return (data['matReqId'] ?? '')
                                        .toString()
                                        .toLowerCase()
                                        .contains(query) ||
                                    (data['siteId'] ?? '')
                                        .toString()
                                        .toLowerCase()
                                        .contains(query) ||
                                    (data['projectName'] ?? '')
                                        .toString()
                                        .toLowerCase()
                                        .contains(query) ||
                                    (data['supervisorName'] ?? '')
                                        .toString()
                                        .toLowerCase()
                                        .contains(query);
                              }).toList();
                              return ListView.builder(
                                padding: const EdgeInsets.only(bottom: 20),
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  final data =
                                      docs[index].data() as Map<String, dynamic>;
                                  final docId = docs[index].id;
                                  return buildRequestCard(data, docId);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                    // Approved Requests Tab with search
                    Column(
                      children: [
                        buildSearchBar(_approvedSearchController, (query) {
                          setState(
                            () => _approvedSearchQuery =
                                query.trim().toLowerCase(),
                          );
                        }),
                        const SizedBox(height: 10),
                        Expanded(
                          child: StreamBuilder<QuerySnapshot>(
                            stream: FirebaseFirestore.instance
                                .collection('siteMaterialsRequest')
                                .where('status', isEqualTo: 'Approved')
                                .snapshots(),
                            builder: (context, snapshot) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return Center(
                                  child: CircularProgressIndicator(
                                    color: mainColor,
                                  ),
                                );
                              }
                              if (!snapshot.hasData ||
                                  snapshot.data!.docs.isEmpty) {
                                return Center(
                                  child: Text(
                                    'No approved requests found.',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                );
                              }
                              final docs = snapshot.data!.docs.where((doc) {
                                final data = doc.data() as Map<String, dynamic>;
                                final query = _approvedSearchQuery;
                                if (query.isEmpty) return true;
                                return (data['matReqId'] ?? '')
                                        .toString()
                                        .toLowerCase()
                                        .contains(query) ||
                                    (data['siteId'] ?? '')
                                        .toString()
                                        .toLowerCase()
                                        .contains(query) ||
                                    (data['projectName'] ?? '')
                                        .toString()
                                        .toLowerCase()
                                        .contains(query) ||
                                    (data['supervisorName'] ?? '')
                                        .toString()
                                        .toLowerCase()
                                        .contains(query);
                              }).toList();
                              return ListView.builder(
                                padding: const EdgeInsets.only(bottom: 20),
                                itemCount: docs.length,
                                itemBuilder: (context, index) {
                                  final data =
                                      docs[index].data() as Map<String, dynamic>;
                                  final docId = docs[index].id;
                                  return buildRequestCard(data, docId);
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
