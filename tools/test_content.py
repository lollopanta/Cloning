import contextlib
import importlib.util
import io
from pathlib import Path
import tempfile
import unittest
import xml.etree.ElementTree as ET

from validate import content_pairs, main as validate

spec = importlib.util.spec_from_file_location("repair_content", Path(__file__).with_name("repair-content.py"))
repair_module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(repair_module)


class ContentTests(unittest.TestCase):
    def test_pairs_and_repair(self):
        source = b'''<roblox version="4"><Item class="CharacterMesh" referent="RBX1"><Properties>
<int64 name="MeshId">27111857</int64>
<Content name="MeshContent"><uri>rbxassetid://27111857</uri></Content>
<int64 name="BaseTextureId">123</int64>
<Content name="BaseTextureContent"><uri>rbxassetid://123</uri></Content>
<string name="Name">CharacterMesh</string></Properties></Item></roblox>'''
        with tempfile.TemporaryDirectory() as directory, contextlib.redirect_stdout(io.StringIO()):
            original = Path(directory) / "save.rbxlx"
            original.write_bytes(source)
            self.assertEqual(validate(original), 1)
            output = repair_module.repair(original)
            self.assertEqual(original.read_bytes(), source)
            self.assertEqual(validate(output), 0)
            props = ET.parse(output).find("Item/Properties")
            self.assertEqual(len(props), 3)
            self.assertEqual(props.find("Content/uri").text, "rbxassetid://27111857")
            with self.assertRaises(FileExistsError):
                repair_module.repair(original)

    def test_alias_and_unrelated_property(self):
        props = ET.fromstring('''<Properties>
<ContentId name="SoundId"><url>rbxassetid://1</url></ContentId>
<Content name="AudioContent"><uri>rbxassetid://1</uri></Content>
<string name="Unrelated">keep</string></Properties>''')
        self.assertEqual([(a.get("name"), b.get("name")) for a, b in content_pairs(props)],
                         [("SoundId", "AudioContent")])


if __name__ == "__main__":
    unittest.main()
