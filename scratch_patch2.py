import re

with open("lib/screens/add_labour_entry_modal.dart", "r") as f:
    content = f.read()

# 1. Add initialWorker to AddLabourEntryModal signature
content = content.replace(
    "final Function(Map<String, dynamic>) onWorkerAdded;",
    "final Function(Map<String, dynamic>) onWorkerAdded;\n  final Map<String, dynamic>? initialWorker;"
)
content = content.replace(
    "required this.onWorkerAdded,",
    "required this.onWorkerAdded,\n    this.initialWorker,"
)

# 2. Add filter logic to loadContractors
contractor_filter = """          if (name.isEmpty || seenNames.contains(name)) return false;
          if (!_isVisibleForCurrentSite(data)) return false;
          if (_isBlockedOnAnotherSiteToday(doc.id)) return false;
          // Filter out if already in existingEntries, unless it's the one we're editing
          if (widget.initialWorker == null || widget.initialWorker!['workerId'] != doc.id) {
            if (widget.existingEntries.any((w) => w['workerId'] == doc.id)) return false;
          }"""
content = content.replace(
    """          if (name.isEmpty || seenNames.contains(name)) return false;
          if (!_isVisibleForCurrentSite(data)) return false;
          if (_isBlockedOnAnotherSiteToday(doc.id)) return false;""",
    contractor_filter
)

# 3. Add filter logic to loadWorkers
worker_filter = """          if (!_isVisibleForCurrentSite(data)) return false;
          if (_isBlockedOnAnotherSiteToday(doc.id)) return false;
          // Filter out if already in existingEntries, unless it's the one we're editing
          if (widget.initialWorker == null || widget.initialWorker!['workerId'] != doc.id) {
            if (widget.existingEntries.any((w) => w['workerId'] == doc.id)) return false;
          }"""
content = content.replace(
    """          if (!_isVisibleForCurrentSite(data)) return false;
          if (_isBlockedOnAnotherSiteToday(doc.id)) return false;""",
    worker_filter
)

# 4. In initState of _AddLabourEntryModalState, pre-fill if initialWorker is not null
init_state_start = content.find("  void initState() {")
init_state_end = content.find("super.initState();", init_state_start) + len("super.initState();")

prefill_logic = """
    if (widget.initialWorker != null) {
      final w = widget.initialWorker!;
      selectedAttendanceType = w['attendanceType'] ?? 'Full Day';
      inTimeController.text = w['inTime'] ?? '';
      outTimeController.text = w['outTime'] ?? '';
      otHoursController.text = (w['otHours'] ?? '').toString();
      remarksController.text = w['remarks'] ?? '';
      
      final isContractor = w['isContractor'] == true ||
          (w['labourType'] == 'Sub Contractor' &&
              (w['contractor'] == null ||
                  w['contractor'].toString().isEmpty ||
                  w['contractor'] == w['workerName']));
                  
      if (isContractor) {
        selectedContractor = w['workerName'] ?? w['contractorName'];
      } else {
        selectedWorkerId = w['workerId'];
      }
      _isNewWorker = false;
    }
"""

content = content[:init_state_end] + "\n" + prefill_logic + content[init_state_end:]

with open("lib/screens/add_labour_entry_modal.dart", "w") as f:
    f.write(content)

