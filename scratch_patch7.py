import re

with open("lib/screens/add_labour_entry_modal.dart", "r") as f:
    content = f.read()

# Replace batch.set to include SetOptions(merge: true)
content = content.replace(
    "batch.set(attendanceDocRef.collection('workers').doc(workerId), entry);",
    "batch.set(attendanceDocRef.collection('workers').doc(workerId), entry, SetOptions(merge: true));"
)
content = content.replace(
    """      batch.set(
        FirebaseFirestore.instance
            .collection('daily_labour_entries')
            .doc(flatDocId),
        entry,
      );""",
    """      batch.set(
        FirebaseFirestore.instance
            .collection('daily_labour_entries')
            .doc(flatDocId),
        entry,
        SetOptions(merge: true),
      );"""
)

with open("lib/screens/add_labour_entry_modal.dart", "w") as f:
    f.write(content)

