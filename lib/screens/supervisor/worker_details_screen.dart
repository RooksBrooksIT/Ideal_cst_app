import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:ideal_cst/models/worker.dart';
import 'package:ideal_cst/services/workforce_service.dart';
import 'package:ideal_cst/models/worker_transfer.dart';

final WorkforceService _workforceService = WorkforceService();
const Color primaryColor = Color(0xFF4527A0);
const Color backgroundColor = Color.fromARGB(255, 213, 207, 232);

class WorkerDetailsScreen extends StatefulWidget {
  final Worker worker;
  final String supervisorId;
  final String supervisorName;

  const WorkerDetailsScreen({
    super.key,
    required this.worker,
    required this.supervisorId,
    required this.supervisorName,
  });

  @override
  _WorkerDetailsScreenState createState() => _WorkerDetailsScreenState();
}

class _WorkerDetailsScreenState extends State<WorkerDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text(
          "Worker Details",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
        ),
        backgroundColor: primaryColor,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Assigned Sites'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _OverviewTab(worker: widget.worker),
          _AssignedSitesTab(worker: widget.worker),
          _HistoryTab(worker: widget.worker),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
}

class _OverviewTab extends StatelessWidget {
  final Worker worker;

  const _OverviewTab({required this.worker});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Profile Header Card
          Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: primaryColor.withValues(alpha: 0.1),
                    child: worker.photoUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(50),
                            child: Image.network(worker.photoUrl!, width: 100, height: 100, fit: BoxFit.cover),
                          )
                        : const Icon(
                            Icons.person,
                            size: 50,
                            color: primaryColor,
                          ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    worker.name,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E1E2D),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'ID: ${worker.workerId}',
                      style: const TextStyle(fontSize: 14, color: primaryColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Contact Information Card
          _buildInfoCard(
            title: 'Contact Details',
            icon: Icons.contact_phone,
            children: [
              _InfoRow(label: 'Mobile Number', value: worker.mobileNumber),
              _InfoRow(label: 'Emergency Contact', value: worker.emergencyContact ?? 'N/A'),
              _InfoRow(label: 'Aadhar Number', value: worker.aadharNumber ?? 'N/A'),
            ],
          ),
          const SizedBox(height: 16),
          // Employment Information Card
          _buildInfoCard(
            title: 'Employment Information',
            icon: Icons.work,
            children: [
              _InfoRow(label: 'Category', value: worker.workerType),
              _InfoRow(label: 'Sub Contractor', value: worker.subContractorName ?? 'N/A'),
              _InfoRow(label: 'Labour Type', value: worker.labourType),
              _InfoRow(label: 'Joining Date', value: '${worker.joiningDate.day}/${worker.joiningDate.month}/${worker.joiningDate.year}'),
              _InfoRow(
                label: 'Status',
                value: worker.isActive ? 'Active' : 'Inactive',
                valueColor: worker.isActive ? Colors.green : Colors.red,
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Financial Details Card
          _buildInfoCard(
            title: 'Financial Details',
            icon: Icons.account_balance_wallet,
            children: [
              _InfoRow(label: 'Basic Salary', value: '₹${worker.basicSalary}'),
              _InfoRow(label: 'Overtime Rate', value: '₹${worker.overtimeRate}'),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildInfoCard({required String title, required IconData icon, required List<Widget> children}) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
                ),
              ],
            ),
            const Divider(height: 24),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final Color? valueColor;

  const _InfoRow({required this.label, required this.value, this.valueColor});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(color: Colors.grey.shade700, fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value, 
              style: TextStyle(
                color: valueColor ?? const Color(0xFF1E1E2D), 
                fontWeight: FontWeight.bold
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _AssignedSitesTab extends StatelessWidget {
  final Worker worker;

  const _AssignedSitesTab({required this.worker});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.location_on, color: primaryColor, size: 24),
                  SizedBox(width: 8),
                  Text(
                    'Assigned Sites',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF1E1E2D)),
                  ),
                ],
              ),
              const Divider(height: 32),
              if (worker.assignedSiteIds.isEmpty)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        Icon(Icons.location_off, size: 64, color: Colors.grey.shade300),
                        const SizedBox(height: 16),
                        Text('No sites assigned yet', style: TextStyle(color: Colors.grey.shade500, fontSize: 16)),
                      ],
                    ),
                  ),
                )
              else
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: worker.assignedSiteIds.map((siteId) {
                    return Chip(
                      label: Text(siteId, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      side: BorderSide.none,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    );
                  }).toList(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryTab extends StatelessWidget {
  final Worker worker;

  const _HistoryTab({required this.worker});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WorkerTransfer>>(
      stream: _workforceService.getWorkerTransfersBySupervisor(
        worker.supervisorId ?? '',
      ),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: primaryColor));
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading site history: ${snapshot.error}',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          );
        }
        
        final transfers = snapshot.data?.where((t) => t.workerId == worker.workerId).toList() ?? [];
        
        if (transfers.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.history, size: 64, color: Colors.grey.shade400),
                const SizedBox(height: 16),
                Text(
                  'No site assignment history',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 16),
                ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: transfers.length,
          itemBuilder: (context, index) {
            final transfer = transfers[index];
            final dateStr = DateFormat('EEE, dd MMM yyyy').format(transfer.transferDate);
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.swap_horiz, color: primaryColor),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(dateStr, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Color(0xFF1E1E2D))),
                          const SizedBox(height: 8),
                          _buildTransferRow('From', '${transfer.fromSubContractorName ?? 'N/A'} (${transfer.fromSiteName})'),
                          const SizedBox(height: 4),
                          _buildTransferRow('To', '${transfer.toSubContractorName ?? 'N/A'} (${transfer.toSiteName})'),
                          if (transfer.reason.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            _buildTransferRow('Reason', transfer.reason),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildTransferRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 50,
          child: Text('$label:', style: TextStyle(color: Colors.grey.shade600, fontWeight: FontWeight.bold, fontSize: 13)),
        ),
        Expanded(
          child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E1E2D), fontSize: 13)),
        ),
      ],
    );
  }
}
