import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

EdgeInsets getSymmetricPadding(BuildContext context, {double fraction = 0.06}) {
  double width = MediaQuery.of(context).size.width;
  return EdgeInsets.symmetric(horizontal: width * fraction);
}

class ManagerApprovalScreen extends StatefulWidget {
  const ManagerApprovalScreen({super.key});

  @override
  State<ManagerApprovalScreen> createState() => _ManagerApprovalScreenState();
}

class _ManagerApprovalScreenState extends State<ManagerApprovalScreen>
    with SingleTickerProviderStateMixin {
  final Color mainColor = const Color(0xFF003768);

  late TabController _tabController;
  List<Map<String, dynamic>> allRequests = [];
  List<Map<String, dynamic>> pendingRequests = [];
  List<Map<String, dynamic>> approvedRequests = [];
  String _searchText = '';
  final TextEditingController _searchController = TextEditingController();
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    setState(() {
      isLoading = true;
    });
    try {
      List<Map<String, dynamic>> fetchedData = await fetchAllSchedules();
      if (!mounted) return;
      setState(() {
        allRequests = fetchedData;
        pendingRequests = allRequests
            .where((req) => req["approvalStatus"] == "Pending")
            .toList();
        approvedRequests = allRequests
            .where((req) => req["approvalStatus"] == "Approved")
            .toList();
        isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching schedules: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> fetchAllSchedules() async {
    final QuerySnapshot snapshot = await FirebaseFirestore.instance
        .collection('siteSupervisorProjectStageSchedule')
        .get();
    return snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
  }

  Future<List<Map<String, dynamic>>> fetchAllLabours() async {
    final QuerySnapshot snapshot =
        await FirebaseFirestore.instance.collection('labours').get();
    return snapshot.docs
        .map((doc) => doc.data() as Map<String, dynamic>)
        .toList();
  }

  void _showRequestDetails(Map<String, dynamic> request) async {
    TextEditingController dateController =
        TextEditingController(text: request['reqDays'].toString());
    TextEditingController paymentController =
        TextEditingController(text: request['estimatedPayment'].toString());
    List<Map<String, dynamic>> labours =
        List<Map<String, dynamic>>.from(request['reqLabours'] ?? []);
    List<TextEditingController> labourCountControllers = labours
        .map((labour) => TextEditingController(
            text: labour['labourCount']?.toString() ?? ''))
        .toList();
    List<TextEditingController> labourDesignationControllers = labours
        .map((labour) =>
            TextEditingController(text: labour['labourDesignation'] ?? ''))
        .toList();

    List<Map<String, dynamic>> allLabours = await fetchAllLabours();

    String? approvedDaysError;

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: StatefulBuilder(
          builder: (context, setModalState) {
            int calculateLabourTotal() {
              int total = 0;
              for (int i = 0; i < labours.length; i++) {
                final designation = labourDesignationControllers[i].text;
                final matched = allLabours.firstWhere(
                  (l) => l['designation'] == designation,
                  orElse: () => {},
                );
                final salary =
                    int.tryParse(matched['salary']?.toString() ?? '0') ?? 0;
                final count = int.tryParse(labourCountControllers[i].text) ?? 0;
                total += count * salary;
              }
              return total;
            }

            int getApprovedDays() {
              return int.tryParse(dateController.text) ?? 0;
            }

            int getEstimatedDays() {
              return request['reqDays'] ?? 0;
            }

            void recalculate() {
              setModalState(() {});
            }

            void validateApprovedDays(String value) {
              final approvedDays = int.tryParse(value) ?? 0;
              final estimatedDays = getEstimatedDays();
              if (approvedDays > estimatedDays) {
                setModalState(() {
                  approvedDaysError =
                      "Approved Days ($approvedDays) cannot exceed Estimated ($estimatedDays).";
                });
              } else {
                setModalState(() {
                  approvedDaysError = null;
                });
              }
            }

            return DraggableScrollableSheet(
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
                            "Req ID: ${request['wsReqId'] ?? ''}",
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: mainColor,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: request['approvalStatus'] == 'Approved'
                                  ? Colors.green.shade100
                                  : Colors.orange.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              request['approvalStatus'] ?? '',
                              style: TextStyle(
                                color: request['approvalStatus'] == 'Approved'
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

                      // Project Info Section
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
                            _RowInfo(label: "Project Name", value: request['projectName'] ?? '', icon: Icons.business, mainColor: mainColor),
                            const SizedBox(height: 6),
                            _RowInfo(label: "Site ID", value: request['siteId'] ?? '', icon: Icons.location_on, mainColor: mainColor),
                            const SizedBox(height: 6),
                            _RowInfo(label: "Supervisor", value: request['supervisorName'] ?? '', icon: Icons.person, mainColor: mainColor),
                            const SizedBox(height: 6),
                            _RowInfo(label: "Project Stage", value: request['projectStage'] ?? '', icon: Icons.account_tree, mainColor: mainColor),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Labour Requirements Section
                      Text(
                        "Requested Labour Requirements",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: mainColor,
                        ),
                      ),
                      const SizedBox(height: 10),
                      ...List.generate(request['reqLabours']?.length ?? 0, (index) {
                        final labour = request['reqLabours'][index];
                        final designation = labour['labourDesignation'] ?? '';
                        final matched = allLabours.firstWhere(
                          (l) => l['designation'] == designation,
                          orElse: () => {},
                        );
                        final labourId = matched['labourId']?.toString() ?? '';
                        final salary = int.tryParse(matched['salary']?.toString() ?? '0') ?? 0;
                        final count = int.tryParse(labour['labourCount']?.toString() ?? '0') ?? 0;
                        final totalSalary = count * salary;
                        return _LabourRequirementCard(
                          designation: designation,
                          labourId: labourId,
                          salary: salary,
                          count: count,
                          total: totalSalary,
                          color: mainColor,
                        );
                      }),
                      const SizedBox(height: 20),

                      // Edit Details Section
                      Text(
                        "Edit Approval Details",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: mainColor,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          const Text("Requested Days: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                          Text(request['reqDays'].toString(), style: TextStyle(fontSize: 16, color: mainColor, fontWeight: FontWeight.bold)),
                          const Spacer(),
                          const Text("Requested Amount: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueGrey)),
                          Text('₹${paymentController.text}', style: TextStyle(fontSize: 16, color: Colors.green[800], fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Editable Days field
                      TextFormField(
                        controller: dateController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Approved Days *',
                          isDense: true,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          errorText: approvedDaysError,
                          fillColor: Colors.orange.shade50,
                          filled: true,
                        ),
                        onChanged: (val) {
                          recalculate();
                          validateApprovedDays(val);
                        },
                      ),
                      const SizedBox(height: 14),

                      ...List.generate(labours.length, (index) {
                        final designation = labourDesignationControllers[index].text;
                        final matched = allLabours.firstWhere(
                          (l) => l['designation'] == designation,
                          orElse: () => {},
                        );
                        final labourId = matched['labourId']?.toString() ?? '';
                        final salary = int.tryParse(matched['salary']?.toString() ?? '0') ?? 0;
                        final count = int.tryParse(labourCountControllers[index].text) ?? 0;
                        final totalSalary = count * salary;
                        return _LabourRequirementCard(
                          designation: designation,
                          labourId: labourId,
                          salary: salary,
                          count: count,
                          total: totalSalary,
                          color: mainColor,
                          editable: true,
                          countController: labourCountControllers[index],
                          designationController: labourDesignationControllers[index],
                          onChanged: recalculate,
                        );
                      }),
                      const SizedBox(height: 16),

                      // Calculated Total Amount
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade300),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.payments, color: Colors.green[800]),
                                const SizedBox(width: 8),
                                Text(
                                  "Approved Total Payment: ",
                                  style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800], fontSize: 15),
                                ),
                              ],
                            ),
                            Text(
                              '₹${getApprovedDays() * calculateLabourTotal()}',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.green[800]),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      if (request['approvalStatus'] == "Pending")
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.check_circle_outline, color: Colors.white),
                                label: const Text("APPROVE", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.green[700],
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: (approvedDaysError != null)
                                    ? null
                                    : () async {
                                        final wsReqId = request['wsReqId'];
                                        final approvedDays = int.tryParse(dateController.text) ?? request['reqDays'];
                                        final estimatedDays = request['reqDays'] ?? 0;
                                        if (approvedDays > estimatedDays) {
                                          setModalState(() {
                                            approvedDaysError = "Approved Days ($approvedDays) cannot exceed Estimated ($estimatedDays).";
                                          });
                                          return;
                                        }
                                        final docSnapshot = await FirebaseFirestore.instance
                                            .collection('siteSupervisorProjectStageSchedule')
                                            .where('wsReqId', isEqualTo: wsReqId)
                                            .limit(1)
                                            .get();
                                        if (docSnapshot.docs.isNotEmpty) {
                                          final docRef = docSnapshot.docs.first.reference;
                                          final approvedPayment = getApprovedDays() * calculateLabourTotal();
                                          final approvedLabours = List.generate(
                                            labours.length,
                                            (i) => {
                                              'labourCount': int.tryParse(labourCountControllers[i].text) ?? 0,
                                              'labourDesignation': labourDesignationControllers[i].text,
                                            },
                                          );
                                          await docRef.update({
                                            'appDays': approvedDays,
                                            'appLabours': approvedLabours,
                                            'approvedPayment': approvedPayment,
                                            'approvalStatus': 'Approved',
                                          });
                                          request['appDays'] = approvedDays;
                                          request['appLabours'] = approvedLabours;
                                          request['approvedPayment'] = approvedPayment;
                                        }
                                        setState(() {
                                          request['approvalStatus'] = 'Approved';
                                          pendingRequests = allRequests.where((req) => req["approvalStatus"] == "Pending").toList();
                                          approvedRequests = allRequests.where((req) => req["approvalStatus"] == "Approved").toList();
                                        });
                                        if (mounted) Navigator.pop(context);
                                      },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.cancel_outlined, color: Colors.red),
                                label: const Text("REJECT", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                                style: OutlinedButton.styleFrom(
                                  side: const BorderSide(color: Colors.red, width: 1.5),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _updateRequestStatus(request['wsReqId'], "Rejected"),
                              ),
                            ),
                          ],
                        ),
                      const SizedBox(height: 16),
                    ],
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  void _showApprovedRequestDetails(Map<String, dynamic> request) async {
    List<Map<String, dynamic>> allLabours = await fetchAllLabours();
    List<Map<String, dynamic>> approvedLabours = List<Map<String, dynamic>>.from(request['appLabours'] ?? []);
    int approvedDays = request['appDays'] ?? request['reqDays'];
    int approvedPayment = request['approvedPayment'] ?? request['estimatedPayment'];

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
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
          builder: (context, scrollController) => SingleChildScrollView(
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
                      "Req ID: ${request['wsReqId'] ?? ''}",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: mainColor,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "Approved",
                        style: TextStyle(
                          color: Colors.green.shade800,
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

                // Project Info
                Text("Project Details", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: mainColor)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color.fromARGB(255, 245, 247, 250),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _RowInfo(label: "Project Name", value: request['projectName'] ?? '', icon: Icons.business, mainColor: mainColor),
                      const SizedBox(height: 6),
                      _RowInfo(label: "Site ID", value: request['siteId'] ?? '', icon: Icons.location_on, mainColor: mainColor),
                      const SizedBox(height: 6),
                      _RowInfo(label: "Supervisor", value: request['supervisorName'] ?? '', icon: Icons.person, mainColor: mainColor),
                      const SizedBox(height: 6),
                      _RowInfo(label: "Project Stage", value: request['projectStage'] ?? '', icon: Icons.account_tree, mainColor: mainColor),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Approved Labour Requirements
                Text("Approved Labour Requirements", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: mainColor)),
                const SizedBox(height: 10),
                ...List.generate(approvedLabours.length, (index) {
                  final labour = approvedLabours[index];
                  final designation = labour['labourDesignation'] ?? '';
                  final matched = allLabours.firstWhere(
                    (l) => l['designation'] == designation,
                    orElse: () => {},
                  );
                  final labourId = matched['labourId']?.toString() ?? '';
                  final salary = int.tryParse(matched['salary']?.toString() ?? '0') ?? 0;
                  final count = int.tryParse(labour['labourCount']?.toString() ?? '0') ?? 0;
                  final totalSalary = count * salary;
                  return _LabourRequirementCard(
                    designation: designation,
                    labourId: labourId,
                    salary: salary,
                    count: count,
                    total: totalSalary,
                    color: mainColor,
                    editable: false,
                  );
                }),
                const SizedBox(height: 20),

                // Approved Details
                Text("Approval Summary", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: mainColor)),
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Approved Days:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          Text("$approvedDays Days", style: TextStyle(fontWeight: FontWeight.bold, color: mainColor, fontSize: 16)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text("Approved Total Payment:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                          Text("₹$approvedPayment", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green[800], fontSize: 18)),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _updateRequestStatus(String wsReqId, String status) async {
    try {
      final docSnapshot = await FirebaseFirestore.instance
          .collection('siteSupervisorProjectStageSchedule')
          .where('wsReqId', isEqualTo: wsReqId)
          .limit(1)
          .get();
      if (docSnapshot.docs.isNotEmpty) {
        await docSnapshot.docs.first.reference.update({'approvalStatus': status});
      }
    } catch (e) {
      debugPrint('Error updating status: $e');
    }

    setState(() {
      final match = allRequests.firstWhere((req) => req['wsReqId'] == wsReqId, orElse: () => {});
      if (match.isNotEmpty) {
        match['approvalStatus'] = status;
      }
      pendingRequests = allRequests.where((req) => req["approvalStatus"] == "Pending").toList();
      approvedRequests = allRequests.where((req) => req["approvalStatus"] == "Approved").toList();
    });

    if (mounted) Navigator.pop(context);
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
                  'Work Schedule',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Request Approval',
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

  Widget _buildRequestList(List<Map<String, dynamic>> requests, {bool isApprovedTab = false}) {
    List<Map<String, dynamic>> filteredRequests = List.from(requests);
    if (_searchText.isNotEmpty) {
      filteredRequests = filteredRequests
          .where((req) => (req['wsReqId'] ?? '').toString().toLowerCase().contains(_searchText.toLowerCase()) ||
              (req['siteId'] ?? '').toString().toLowerCase().contains(_searchText.toLowerCase()) ||
              (req['supervisorName'] ?? '').toString().toLowerCase().contains(_searchText.toLowerCase()))
          .toList();
    }

    if (filteredRequests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 60, color: mainColor.withValues(alpha: 0.4)),
            const SizedBox(height: 12),
            Text(
              "No requests found",
              style: TextStyle(color: Colors.grey[600], fontSize: 16, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 12),
      itemCount: filteredRequests.length,
      itemBuilder: (context, index) {
        final request = filteredRequests[index];
        return GestureDetector(
          onTap: () => isApprovedTab ? _showApprovedRequestDetails(request) : _showRequestDetails(request),
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
                        Icon(Icons.assignment, color: mainColor, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          request['wsReqId'] ?? "",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: mainColor,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: isApprovedTab ? Colors.green.shade100 : Colors.orange.shade100,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        request['approvalStatus'] ?? '',
                        style: TextStyle(
                          color: isApprovedTab ? Colors.green.shade800 : Colors.orange.shade900,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _RowInfo(label: "Project", value: request['projectName'] ?? '', icon: Icons.business, mainColor: mainColor),
                const SizedBox(height: 4),
                _RowInfo(label: "Site ID", value: request['siteId'] ?? '', icon: Icons.location_on, mainColor: mainColor),
                const SizedBox(height: 4),
                _RowInfo(label: "Supervisor", value: request['supervisorName'] ?? '', icon: Icons.person, mainColor: mainColor),
                const SizedBox(height: 4),
                _RowInfo(label: "Stage", value: request['projectStage'] ?? '', icon: Icons.account_tree, mainColor: mainColor),
                const SizedBox(height: 12),
                const Divider(),
                Row(
                  children: [
                    Icon(Icons.people_outline, color: mainColor, size: 20),
                    const SizedBox(width: 6),
                    Text(
                      "${(request['reqLabours'] ?? []).length} Labour Types",
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E1E2D)),
                    ),
                    const Spacer(),
                    Icon(
                      isApprovedTab ? Icons.verified : Icons.pending_actions,
                      size: 18,
                      color: isApprovedTab ? Colors.green[700] : Colors.orange[800],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isApprovedTab ? "Approved" : "Pending Approval",
                      style: TextStyle(
                        color: isApprovedTab ? Colors.green[700] : Colors.orange[800],
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
      },
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
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                      tabs: const [
                        Tab(text: "Pending Requests"),
                        Tab(text: "Approved Requests"),
                      ],
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by Request ID, Site, Supervisor...',
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
                      onChanged: (value) {
                        setState(() {
                          _searchText = value.trim();
                        });
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildRequestList(pendingRequests, isApprovedTab: false),
                          _buildRequestList(approvedRequests, isApprovedTab: true),
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

class _RowInfo extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color mainColor;
  const _RowInfo({
    required this.label,
    required this.value,
    required this.icon,
    required this.mainColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: mainColor, size: 18),
        const SizedBox(width: 8),
        Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF1E1E2D))),
        Expanded(child: Text(value, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13, color: Colors.grey[800]))),
      ],
    );
  }
}

class _LabourRequirementCard extends StatelessWidget {
  final String designation;
  final String labourId;
  final int salary;
  final int count;
  final int total;
  final Color color;
  final bool editable;
  final TextEditingController? countController;
  final TextEditingController? designationController;
  final VoidCallback? onChanged;

  const _LabourRequirementCard({
    required this.designation,
    required this.labourId,
    required this.salary,
    required this.count,
    required this.total,
    required this.color,
    this.editable = false,
    this.countController,
    this.designationController,
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.people, color: color, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: editable
                  ? Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: TextFormField(
                            controller: countController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Count',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              fillColor: Colors.orange.shade50,
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (val) => onChanged?.call(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 3,
                          child: TextFormField(
                            controller: designationController,
                            decoration: InputDecoration(
                              labelText: 'Designation',
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                              fillColor: Colors.orange.shade50,
                              filled: true,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            ),
                            onChanged: (val) => onChanged?.call(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ID: $labourId', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                              Text('Salary: ₹$salary', style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                              Text('Total: ₹$total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green[800])),
                            ],
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          designation,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: Color(0xFF1E1E2D)),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text('Count: $count  |  ', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                            Text('Salary: ₹$salary  |  ', style: TextStyle(fontSize: 12, color: Colors.grey[700])),
                            Text('Total: ₹$total', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green[800])),
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
}
