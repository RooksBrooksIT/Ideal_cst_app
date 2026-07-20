import re

with open("lib/screens/add_labour_entry_modal.dart", "r") as f:
    original = f.read()

# Make a backup
with open("lib/screens/add_labour_entry_modal.dart.bak", "w") as f:
    f.write(original)

# We want to replace the `Widget build` method entirely, and add helper methods.
# The start of the build method is: `  @override\n  Widget build(BuildContext context) {`
build_start = original.find("  @override\n  Widget build(BuildContext context) {")

if build_start == -1:
    print("Could not find build method")
    exit(1)

# We can replace everything from build_start to the end of the file.
# The last line of the file should be `}\n` which closes the class.
new_ui = """  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Material(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  _buildToggle(),
                  const SizedBox(height: 16),
                  
                  if (!isAddingNewWorker)
                    _buildSelectWorkerSection()
                  else
                    _buildNewWorkerForm(),
                    
                  const SizedBox(height: 16),
                  _buildAttendanceDetails(),
                  const SizedBox(height: 100), // padding for bottom button
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            offset: const Offset(0, 2),
            blurRadius: 10,
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            widget.initialWorker != null ? 'Edit Labour Entry' : 'Add Labour Entry',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.close, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: _buildToggleButton(
              title: 'Select Existing',
              isActive: !isAddingNewWorker,
              onTap: () => setState(() => isAddingNewWorker = false),
            ),
          ),
          Expanded(
            child: _buildToggleButton(
              title: 'Add New',
              isActive: isAddingNewWorker,
              onTap: () => setState(() => isAddingNewWorker = true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({required String title, required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isActive
              ? [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
              : [],
        ),
        child: Center(
          child: Text(
            title,
            style: TextStyle(
              color: isActive ? primaryColor : Colors.grey.shade600,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectWorkerSection() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: searchController,
              decoration: InputDecoration(
                labelText: 'Search Worker / Contractor',
                prefixIcon: const Icon(Icons.search, color: Colors.grey),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
                filled: true,
                fillColor: Colors.grey.shade50,
              ),
            ),
            const SizedBox(height: 12),
            if (filteredWorkers.isEmpty && filteredContractors.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(16.0), child: Text('No results found')))
            else
              Container(
                constraints: const BoxConstraints(maxHeight: 250),
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (filteredWorkers.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('WORKERS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade600)),
                      ),
                      ...filteredWorkers.map((doc) => _buildWorkerTile(doc, isWorker: true)).toList(),
                    ],
                    if (filteredContractors.isNotEmpty) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
                        child: Text('SUB CONTRACTORS', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey.shade600)),
                      ),
                      ...filteredContractors.map((doc) => _buildWorkerTile(doc, isWorker: false)).toList(),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildWorkerTile(DocumentSnapshot doc, {required bool isWorker}) {
    final data = doc.data() as Map<String, dynamic>;
    final name = isWorker 
        ? (data['workerName'] ?? data['name'] ?? 'Unknown')
        : (data['contractorName'] ?? data['name'] ?? 'Unknown');
        
    final subContractor = isWorker 
        ? (data['contractorName'] ?? data['subContractorName'] ?? data['contractor'] ?? 'None')
        : 'Self';
        
    final category = isWorker 
        ? (data['category'] ?? data['workerType'] ?? 'Uncategorized')
        : 'Sub Contractor';
        
    final isSelected = selectedWorker?.id == doc.id;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: isSelected ? primaryColor.withOpacity(0.05) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isSelected ? primaryColor : Colors.grey.shade200, width: isSelected ? 1.5 : 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        title: Row(
          children: [
            Expanded(child: Text(name, style: TextStyle(fontWeight: FontWeight.bold, color: isSelected ? primaryColor : Colors.black87))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: isWorker ? Colors.blue.shade50 : Colors.orange.shade50,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                isWorker ? 'Worker' : 'Sub',
                style: TextStyle(color: isWorker ? Colors.blue.shade700 : Colors.orange.shade700, fontSize: 10, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        subtitle: Text('$category • Sub: $subContractor', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
        trailing: isSelected ? Icon(Icons.check_circle, color: primaryColor) : const Icon(Icons.radio_button_unchecked, color: Colors.grey),
        onTap: () {
          setState(() {
            selectedWorker = doc;
          });
          _recalculateOtHours();
        },
      ),
    );
  }

  Widget _buildNewWorkerForm() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Worker Details', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildTextField(controller: workerNameController, label: 'Worker Name'),
            const SizedBox(height: 12),
            _buildTextField(controller: mobileController, label: 'Mobile Number', keyboardType: TextInputType.phone),
            const SizedBox(height: 12),
            _buildTextField(controller: aadhaarController, label: 'Aadhaar Number (Optional)'),
            const SizedBox(height: 12),
            _isLoadingLabours
                ? const Center(child: CircularProgressIndicator())
                : _buildDropdown(
                    value: selectedCategory,
                    items: _labours.map((l) => l['designation'].toString()).toList(),
                    label: 'Category',
                    onChanged: (v) {
                      setState(() => selectedCategory = v!);
                      _recalculateOtHours();
                    },
                  ),
            const SizedBox(height: 12),
            _buildDropdown(
              value: (() {
                final names = contractors.map((d) {
                  final data = d.data() as Map<String, dynamic>;
                  return (data['contractorName'] ?? data['name'])?.toString();
                }).whereType<String>().toList();
                return (selectedContractor != null && names.contains(selectedContractor)) ? selectedContractor : null;
              })(),
              items: contractors.map((d) {
                final data = d.data() as Map<String, dynamic>;
                return (data['contractorName'] ?? data['name'] ?? 'Unknown').toString();
              }).toList(),
              label: 'Sub-Contractor',
              onChanged: (v) => setState(() => selectedContractor = v),
            ),
            const SizedBox(height: 12),
            _buildDropdown(
              value: selectedLabourType,
              items: labourTypes,
              label: 'Labour Type',
              onChanged: (v) => setState(() => selectedLabourType = v!),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceDetails() {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16), side: BorderSide(color: Colors.grey.shade200)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Attendance & Time', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            _buildDropdown(
              value: selectedAttendanceType,
              items: attendanceTypes,
              label: 'Attendance Type',
              onChanged: (v) => setState(() => selectedAttendanceType = v!),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _buildTextField(controller: inTimeController, label: 'In Time', icon: Icons.access_time, readOnly: true, onTap: () => _selectTime(context, inTimeController))),
                const SizedBox(width: 12),
                Expanded(child: _buildTextField(controller: outTimeController, label: 'Out Time', icon: Icons.access_time, readOnly: true, onTap: () => _selectTime(context, outTimeController))),
              ],
            ),
            const SizedBox(height: 12),
            _buildTextField(controller: otHoursController, label: 'OT Hours', keyboardType: const TextInputType.numberWithOptions(decimal: true)),
            const SizedBox(height: 12),
            _buildTextField(controller: remarksController, label: 'Remarks (Optional)', maxLines: 2),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    IconData? icon,
    bool readOnly = false,
    VoidCallback? onTap,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return TextField(
      controller: controller,
      readOnly: readOnly,
      onTap: onTap,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        suffixIcon: icon != null ? Icon(icon, color: Colors.grey.shade500, size: 20) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 2)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String label,
    required void Function(String?) onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      items: items.toSet().map((t) => DropdownMenuItem(value: t, child: Text(t, style: const TextStyle(fontSize: 14)))).toList(),
      onChanged: onChanged,
      icon: const Icon(Icons.arrow_drop_down, color: Colors.grey),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: primaryColor, width: 2)),
        filled: true,
        fillColor: Colors.grey.shade50,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }
}
"""

# Now we need to append the sticky bottom button. Wait, in DraggableScrollableSheet, we can wrap the material in a Stack.
# But it's easier to just put it at the bottom.
bottom_button = """
  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Material(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Stack(
          children: [
            Column(
              children: [
                _buildHeader(context),
                Expanded(
                  child: ListView(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    children: [
                      _buildToggle(),
                      const SizedBox(height: 16),
                      
                      if (!isAddingNewWorker)
                        _buildSelectWorkerSection()
                      else
                        _buildNewWorkerForm(),
                        
                      const SizedBox(height: 16),
                      _buildAttendanceDetails(),
                      const SizedBox(height: 100), // padding for bottom button
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                padding: EdgeInsets.only(left: 20, right: 20, bottom: MediaQuery.of(context).padding.bottom + 16, top: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(0, -4), blurRadius: 10)],
                ),
                child: ElevatedButton(
                  onPressed: _isSaving ? null : addWorkerEntry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Save Entry', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
"""

new_ui = new_ui.replace(
"""  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => Material(
        color: Colors.grey.shade50,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: ListView(
                controller: scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                children: [
                  _buildToggle(),
                  const SizedBox(height: 16),
                  
                  if (!isAddingNewWorker)
                    _buildSelectWorkerSection()
                  else
                    _buildNewWorkerForm(),
                    
                  const SizedBox(height: 16),
                  _buildAttendanceDetails(),
                  const SizedBox(height: 100), // padding for bottom button
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }""", bottom_button)

content = original[:build_start] + new_ui

with open("lib/screens/add_labour_entry_modal.dart", "w") as f:
    f.write(content)

