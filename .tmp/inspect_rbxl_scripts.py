import sys
import xml.etree.ElementTree as ET


path = sys.argv[1]
needles = sys.argv[2:]
root = ET.parse(path).getroot()
for item in root.iter("Item"):
    props = item.find("Properties")
    if props is None:
        continue
    source = props.find("ProtectedString[@name='Source']")
    if source is None or not source.text:
        continue
    if not any(needle in source.text for needle in needles):
        continue
    name = props.find("string[@name='Name']")
    print(item.get("class"), name.text if name is not None else "?", len(source.text))
    print(source.text[:240].replace("\n", " "))
