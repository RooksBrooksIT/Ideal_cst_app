import re

with open("lib/screens/add_labour_entry_modal.dart", "r") as f:
    content = f.read()

# Fix mounted in loadContractors
content = content.replace("      setState(() {\n        // Step 1: Merge by document ID", "      if (!mounted) return;\n      setState(() {\n        // Step 1: Merge by document ID")
# Fix duplicate filter in loadContractors
dup_filter = """          // Filter out if already in existingEntries, unless it's the one we're editing
          if (widget.initialWorker == null || widget.initialWorker!['workerId'] != doc.id) {
            if (widget.existingEntries.any((w) => w['workerId'] == doc.id)) return false;
          }
          // Filter out if already in existingEntries, unless it's the one we're editing
          if (widget.initialWorker == null || widget.initialWorker!['workerId'] != doc.id) {
            if (widget.existingEntries.any((w) => w['workerId'] == doc.id)) return false;
          }"""
single_filter = """          // Filter out if already in existingEntries, unless it's the one we're editing
          if (widget.initialWorker == null || widget.initialWorker!['workerId'] != doc.id) {
            if (widget.existingEntries.any((w) => w['workerId'] == doc.id)) return false;
          }"""
content = content.replace(dup_filter, single_filter)

# Fix mounted in loadWorkers
content = content.replace("      setState(() {\n        workers = querySnapshot.docs.where((doc) {", "      if (!mounted) return;\n      setState(() {\n        workers = querySnapshot.docs.where((doc) {")

# Fix mounted in _loadLabours
content = content.replace("      setState(() {\n        _labours = uniqueLabours;\n        _isLoadingLabours = false;\n      });", "      if (!mounted) return;\n      setState(() {\n        _labours = uniqueLabours;\n        _isLoadingLabours = false;\n      });")
content = content.replace("      setState(() {\n        _isLoadingLabours = false;\n      });", "      if (mounted) {\n        setState(() {\n          _isLoadingLabours = false;\n        });\n      }")

# Fix mounted in _loadWorkersOnOtherSitesToday
content = content.replace("      setState(() {\n        _workerIdsOnOtherSitesToday = blocked;\n      });\n      filterWorkers();", "      if (!mounted) return;\n      setState(() {\n        _workerIdsOnOtherSitesToday = blocked;\n      });\n      filterWorkers();")

# Fix mounted in _addEntry (actually it already has `setState(() => _isSaving = true);` synchronously, but at the end of `try` it has `setState(() => _isSaving = false);`)
# In _addEntry, `setState(() => _isSaving = true);` is safe because it's sync on button press.
# But `setState(() => _isSaving = false);` in success and catch blocks needs mounted check.
content = content.replace("      setState(() => _isSaving = false);\n\n      if (!mounted) return;", "      if (mounted) setState(() => _isSaving = false);\n\n      if (!mounted) return;")
content = content.replace("      debugPrint('Error saving labour entry: $e');\n      setState(() => _isSaving = false);", "      debugPrint('Error saving labour entry: $e');\n      if (mounted) setState(() => _isSaving = false);")

with open("lib/screens/add_labour_entry_modal.dart", "w") as f:
    f.write(content)

