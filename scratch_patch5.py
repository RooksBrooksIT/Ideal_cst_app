import re

with open("lib/screens/add_labour_entry_modal.dart", "r") as f:
    content = f.read()

# Replace title
content = content.replace(
    "Text('Add Labour Entry', style:",
    "Text(widget.initialWorker != null ? 'Edit Labour Entry' : 'Add Labour Entry', style:"
)

with open("lib/screens/add_labour_entry_modal.dart", "w") as f:
    f.write(content)

