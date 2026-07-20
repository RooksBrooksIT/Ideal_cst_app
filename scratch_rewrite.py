import re

with open("lib/screens/daily_labour_entry_screen.dart.bak", "r") as f:
    original = f.read()

# We'll split the file and replace the UI parts.
# Let's find the start of `Widget build(BuildContext context)` in _DailyLabourEntryScreenState.
build_start = original.find("  @override\n  Widget build(BuildContext context) {")
if build_start == -1:
    print("Could not find build method")
    exit(1)

# The first part of the file up to build() remains unchanged
header_part = original[:build_start]

# We want to replace everything from build() down to the end of _DailyLabourEntryScreenState.
# Let's find the end of _DailyLabourEntryScreenState.
# It ends right before `class _MealsBusFareDialog extends StatefulWidget {`
meals_dialog_start = original.find("class _MealsBusFareDialog extends StatefulWidget {")
state_end = original[:meals_dialog_start].rfind("}")

# We will generate a new build method and helper methods.
new_ui_methods = """
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Daily Labour Entry', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: CustomScrollView(
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildHeaderSection(),
                        const SizedBox(height: 24),
                        _buildLabourListSection(),
                        const SizedBox(height: 24),
                        _buildMealsEntrySection(),
                        const SizedBox(height: 24),
                        _buildSummarySection(),
                        const SizedBox(height: 24),
                        _buildQuickActions(),
                        const SizedBox(height: 40),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildHeaderSection() {
    return Card(
      elevation: 2,
      shadowColor: Colors.black12,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on, color: primaryColor, size: 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    (widget.siteName.trim().isEmpty || widget.siteName == 'Unknown Site')
                        ? widget.siteId.split('_').first
                        : widget.siteName,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[900],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.person, color: Colors.grey[600], size: 18),
                const SizedBox(width: 8),
                Text(
                  'Supervisor: ${widget.supervisorName}',
                  style: TextStyle(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, color: Colors.grey[600], size: 18),
                const SizedBox(width: 8),
                Text(
                  'Date: $todayFormatted',
                  style: TextStyle(color: Colors.grey[700], fontSize: 15, fontWeight: FontWeight.w500),
                ),
              ],
            ),
            const Divider(height: 32),
            TextField(
              controller: weatherController,
              focusNode: weatherFocusNode,
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              decoration: InputDecoration(
                labelText: 'Weather (Optional)',
                prefixIcon: const Icon(Icons.wb_sunny_outlined),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: notesController,
              focusNode: notesFocusNode,
              onTapOutside: (_) => FocusManager.instance.primaryFocus?.unfocus(),
              maxLines: 3,
              decoration: InputDecoration(
                labelText: 'Notes',
                alignLabelWithHint: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabourListSection() {
    final subContractors = workersList.where((w) {
      return w['isContractor'] == true ||
          (w['labourType'] == 'Sub Contractor' &&
              (w['contractor'] == null ||
                  w['contractor'].toString().isEmpty ||
                  w['contractor'] == w['workerName']));
    }).toList();

    final directWorkers = workersList.where((w) {
      final isContractor = w['isContractor'] == true ||
          (w['labourType'] == 'Sub Contractor' &&
              (w['contractor'] == null ||
                  w['contractor'].toString().isEmpty ||
                  w['contractor'] == w['workerName']));
      return !isContractor;
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Labour Entries',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            ElevatedButton.icon(
              onPressed: openAddLabourModal,
              icon: const Icon(Icons.add, size: 20, color: Colors.white),
              label: const Text('Add Entry', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (workersList.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.people_outline, size: 48, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No labour entries yet',
                  style: TextStyle(color: Colors.grey[600], fontSize: 16),
                ),
              ],
            ),
          )
        else ...[
          if (directWorkers.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                'Direct Workers (${directWorkers.length})',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
            ),
            ...directWorkers.map((w) {
              final idx = workersList.indexOf(w);
              return _buildLabourEntryCard(idx, w, false);
            }),
            const SizedBox(height: 16),
          ],
          if (subContractors.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(bottom: 12, left: 4),
              child: Text(
                'Sub Contractors (${subContractors.length})',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.grey[700]),
              ),
            ),
            ...subContractors.map((w) {
              final idx = workersList.indexOf(w);
              return _buildLabourEntryCard(idx, w, true);
            }),
          ],
        ]
      ],
    );
  }

  Widget _buildLabourEntryCard(int index, Map<String, dynamic> worker, bool isContractor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => editWorker(index),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isContractor ? Colors.orange.shade50 : Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Icon(
                      isContractor ? Icons.engineering : Icons.person,
                      color: isContractor ? Colors.orange.shade700 : Colors.blue.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              worker['workerName'] ?? 'Unknown',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: worker['attendanceType'] == 'Full Day' ? Colors.green.shade50 : Colors.grey.shade100,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              worker['attendanceType']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: worker['attendanceType'] == 'Full Day' ? Colors.green.shade700 : Colors.grey.shade700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isContractor
                            ? '${worker['category'] ?? worker['workerType'] ?? ''} • Self'
                            : '${worker['category'] ?? worker['workerType'] ?? ''} • Sub: ${worker['contractorName'] ?? worker['contractor'] ?? 'None'}',
                        style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                  onPressed: () => deleteWorker(index),
                  tooltip: 'Delete Entry',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMealsEntrySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Meals & Bus Fare',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        _MealsEntryInlineSection(
          workersList: workersList,
          onUpdate: (updatedWorkers) {
            setState(() {
              workersList = updatedWorkers;
            });
            calculateSummary();
            _saveMealsBusFare(updatedWorkers);
          },
        ),
      ],
    );
  }

  Widget _buildSummarySection() {
    return Card(
      elevation: 0,
      color: primaryColor.withOpacity(0.04),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: primaryColor.withOpacity(0.1)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics_outlined, color: primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'Daily Summary',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _buildSummaryRow('Effective Labour', summary['effectiveLabour'].toString(), primaryColor, isBold: true, isLarge: true),
            const Divider(height: 32),
            _buildSummaryRow('Full Day', summary['fullDay'].toString(), Colors.green),
            _buildSummaryRow('Half Day', summary['halfDay'].toString(), Colors.orange),
            _buildSummaryRow('Early Out', summary['earlyOut'].toString(), Colors.purple),
            _buildSummaryRow('Absent', summary['absent'].toString(), Colors.red),
            _buildSummaryRow('Leave', summary['leave'].toString(), Colors.grey),
            _buildSummaryRow('Total OT Hours', summary['totalOT'].toString(), Colors.teal),
            const Divider(height: 32),
            _buildSummaryRow('Total Additional Expense', '₹${summary['totalAdditionalExpense'].toStringAsFixed(2)}', Colors.red, isBold: true, isLarge: true),
            const SizedBox(height: 12),
            _buildSummaryRow('Meals (Count)', summary['totalMealsCount'].toString(), Colors.orange),
            _buildSummaryRow('Meals (Expense)', '₹${summary['totalMealsExpense'].toStringAsFixed(2)}', Colors.orange),
            _buildSummaryRow('Bus Fare (Trips)', summary['totalBusCount'].toString(), Colors.blue),
            _buildSummaryRow('Bus Fare (Expense)', '₹${summary['totalBusExpense'].toStringAsFixed(2)}', Colors.blue),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, Color color, {bool isBold = false, bool isLarge = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isLarge ? 16 : 14,
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              color: isBold ? Colors.black87 : Colors.grey[700],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              value,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: isLarge ? 18 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick Actions',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _buildActionCard(
                icon: Icons.bar_chart,
                label: 'Site Progress',
                color: Colors.teal,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SiteProgressScreen(
                        supervisorId: widget.supervisorId,
                        supervisorName: widget.supervisorName,
                        siteId: widget.siteId,
                        siteName: widget.siteName,
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildActionCard(
                icon: Icons.shopping_cart,
                label: 'Material Request',
                color: Colors.purple,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => MaterialRequestForm(
                        supervisorId: widget.supervisorId,
                        supervisorName: widget.supervisorName,
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildActionCard({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
"""

inline_meals_class = """
class _MealsEntryInlineSection extends StatefulWidget {
  final List<Map<String, dynamic>> workersList;
  final Function(List<Map<String, dynamic>>) onUpdate;

  const _MealsEntryInlineSection({
    required this.workersList,
    required this.onUpdate,
  });

  @override
  __MealsEntryInlineSectionState createState() => __MealsEntryInlineSectionState();
}

class __MealsEntryInlineSectionState extends State<_MealsEntryInlineSection> {
  late List<Map<String, dynamic>> _updatedWorkers;
  final Color _primaryColor = const Color(0xFF0b3470);
  String? _selectedSubContractorName;
  String? _selectedWorkerId;
  late TextEditingController _mealsCountController;
  late TextEditingController _mealsAmountController;
  late TextEditingController _busCountController;
  late TextEditingController _busAmountController;
  bool _isSaving = false;

  Map<String, dynamic>? get _selectedWorker {
    if (_selectedWorkerId == null) return null;
    return _updatedWorkers.firstWhere(
      (w) => w['workerId'] == _selectedWorkerId,
      orElse: () => {},
    );
  }

  @override
  void initState() {
    super.initState();
    _mealsCountController = TextEditingController();
    _mealsAmountController = TextEditingController();
    _busCountController = TextEditingController();
    _busAmountController = TextEditingController();
    _syncWorkers();
  }

  @override
  void didUpdateWidget(_MealsEntryInlineSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.workersList != oldWidget.workersList) {
      _syncWorkers();
    }
  }

  void _syncWorkers() {
    _updatedWorkers = widget.workersList.map((worker) {
      final mealsCountRaw = worker['mealsCount'] ?? 0;
      final mealsCount = mealsCountRaw is num ? mealsCountRaw.toInt() : 0;
      final busCountRaw = worker['busCount'] ?? 0;
      final busCount = busCountRaw is num ? busCountRaw.toInt() : 0;

      final mealsAmountRaw = worker['mealsAmount'] ?? 0;
      final mealsAmount = mealsAmountRaw is num ? mealsAmountRaw.toDouble() : 0.0;
      final busAmountRaw = worker['busAmount'] ?? 0;
      final busAmount = busAmountRaw is num ? busAmountRaw.toDouble() : 0.0;

      return {
        ...worker,
        'mealsCount': mealsCount,
        'mealsAmount': mealsAmount,
        'busCount': busCount,
        'busAmount': busAmount,
      };
    }).toList();
  }

  @override
  void dispose() {
    _mealsCountController.dispose();
    _mealsAmountController.dispose();
    _busCountController.dispose();
    _busAmountController.dispose();
    super.dispose();
  }

  List<String> _getSubContractors() {
    final contractors = <String>{};
    for (final worker in _updatedWorkers) {
      final isContractor = worker['isContractor'] == true ||
          (worker['labourType'] == 'Sub Contractor' &&
              (worker['contractor'] == null ||
                  worker['contractor'].toString().isEmpty ||
                  worker['contractor'] == worker['workerName']));

      String contractorName = isContractor 
          ? (worker['workerName'] ?? 'Unknown Contractor') 
          : (worker['contractorName'] ?? worker['contractor'] ?? 'General');
      contractors.add(contractorName);
    }
    return contractors.toList()..sort();
  }

  List<Map<String, dynamic>> _getWorkersForSelectedSubContractor() {
    if (_selectedSubContractorName == null) return [];
    final workers = <Map<String, dynamic>>[];
    final contractors = <Map<String, dynamic>>[];
    for (final worker in _updatedWorkers) {
      final isContractor = worker['isContractor'] == true ||
          (worker['labourType'] == 'Sub Contractor' &&
              (worker['contractor'] == null ||
                  worker['contractor'].toString().isEmpty ||
                  worker['contractor'] == worker['workerName']));

      String contractorName = isContractor 
          ? (worker['workerName'] ?? 'Unknown Contractor') 
          : (worker['contractorName'] ?? worker['contractor'] ?? 'General');

      if (contractorName == _selectedSubContractorName) {
        if (isContractor) contractors.add(worker);
        else workers.add(worker);
      }
    }
    return [...contractors, ...workers];
  }

  void _loadWorkerData() {
    final worker = _selectedWorker;
    if (worker != null && worker.isNotEmpty) {
      _mealsCountController.text = worker['mealsCount'].toString();
      _mealsAmountController.text = worker['mealsAmount'].toString();
      _busCountController.text = worker['busCount'].toString();
      _busAmountController.text = worker['busAmount'].toString();
    } else {
      _mealsCountController.clear();
      _mealsAmountController.clear();
      _busCountController.clear();
      _busAmountController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_updatedWorkers.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: const Center(
          child: Text(
            'Add labour entries first to assign meals and bus fare.',
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    final subContractors = _getSubContractors();
    if (_selectedSubContractorName != null && !subContractors.contains(_selectedSubContractorName)) {
        _selectedSubContractorName = null;
        _selectedWorkerId = null;
    }

    final workersForSubContractor = _getWorkersForSelectedSubContractor();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<String>(
            value: _selectedSubContractorName,
            decoration: InputDecoration(
              labelText: 'Select Sub Contractor',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              filled: true,
              fillColor: Colors.grey[50],
            ),
            items: subContractors.map((name) => DropdownMenuItem(value: name, child: Text(name))).toList(),
            onChanged: (value) {
              setState(() {
                _selectedSubContractorName = value;
                _selectedWorkerId = null;
                _loadWorkerData();
              });
            },
          ),
          const SizedBox(height: 16),
          if (_selectedSubContractorName != null)
            DropdownButtonFormField<String>(
              value: _selectedWorkerId,
              decoration: InputDecoration(
                labelText: 'Select Worker',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey[50],
              ),
              items: workersForSubContractor.map<DropdownMenuItem<String>>((worker) {
                final isContractor = worker['isContractor'] == true ||
                    (worker['labourType'] == 'Sub Contractor' &&
                        (worker['contractor'] == null ||
                            worker['contractor'].toString().isEmpty ||
                            worker['contractor'] == worker['workerName']));
                final label = isContractor ? '${worker['workerName']} (Sub Contractor)' : worker['workerName'] ?? 'Unknown Worker';
                return DropdownMenuItem(value: worker['workerId'], child: Text(label));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedWorkerId = value;
                  _loadWorkerData();
                });
              },
            ),
          const SizedBox(height: 16),
          if (_selectedWorkerId != null) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.restaurant, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text('Meals', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _mealsCountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'No of Meals',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _mealsAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            prefixText: '₹',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      const Icon(Icons.directions_bus, color: Colors.blue, size: 20),
                      const SizedBox(width: 8),
                      Text('Bus Fare', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[800])),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _busCountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'No of Trips',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _busAmountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Amount',
                            prefixText: '₹',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : () async {
                        if (_selectedWorkerId != null) {
                          setState(() => _isSaving = true);
                          final index = _updatedWorkers.indexWhere((w) => w['workerId'] == _selectedWorkerId);
                          if (index != -1) {
                            _updatedWorkers[index] = {
                              ..._updatedWorkers[index],
                              'mealsCount': int.tryParse(_mealsCountController.text) ?? 0,
                              'mealsAmount': double.tryParse(_mealsAmountController.text) ?? 0,
                              'busCount': int.tryParse(_busCountController.text) ?? 0,
                              'busAmount': double.tryParse(_busAmountController.text) ?? 0,
                            };
                            widget.onUpdate(_updatedWorkers);
                            _selectedWorkerId = null;
                            _loadWorkerData();
                          }
                          setState(() => _isSaving = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: _isSaving
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Save Worker Expenses', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
"""

with open("lib/screens/daily_labour_entry_screen.dart", "w") as f:
    f.write(header_part)
    f.write(new_ui_methods)
    f.write(inline_meals_class)

