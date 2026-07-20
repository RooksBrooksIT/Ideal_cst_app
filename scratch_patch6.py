import re

with open("lib/screens/add_labour_entry_modal.dart", "r") as f:
    content = f.read()

# Replace hardcoded 0 with widget.initialWorker values
content = content.replace(
    "'mealsCount': 0,",
    "'mealsCount': widget.initialWorker?['mealsCount'] ?? 0,"
)
content = content.replace(
    "'mealsAmount': 0,",
    "'mealsAmount': widget.initialWorker?['mealsAmount'] ?? 0,"
)
content = content.replace(
    "'busCount': 0,",
    "'busCount': widget.initialWorker?['busCount'] ?? 0,"
)
content = content.replace(
    "'busAmount': 0,",
    "'busAmount': widget.initialWorker?['busAmount'] ?? 0,"
)

with open("lib/screens/add_labour_entry_modal.dart", "w") as f:
    f.write(content)

