"""Fault-injection tests of the static checker; not tests of PLC execution."""
from pathlib import Path
import sys
import tempfile
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from check_sources import check_repository, write_inventory  # noqa: E402


class SourceContractChecks(unittest.TestCase):
    def check_fixture(self, files):
        temporary = tempfile.TemporaryDirectory()
        self.addCleanup(temporary.cleanup)
        root = Path(temporary.name)
        for path, content in files.items():
            target = root / "src" / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_text(content, encoding="utf-8")
        return check_repository(root)

    def assert_finding(self, result, code):
        self.assertFalse(result.ok)
        self.assertIn(code, [finding.code for finding in result.findings])

    def test_valid_dependencies_are_ordered_before_consumers(self):
        result = self.check_fixture({
            "E_MODE.st": "TYPE E_MODE : (Idle := 0, Run := 1) UINT := Idle; END_TYPE",
            "ST_PAYLOAD.st": "TYPE ST_PAYLOAD : STRUCT eMode : E_MODE; END_STRUCT END_TYPE",
            "F_Value.st": "FUNCTION F_Value : UINT VAR_INPUT ui : UINT; END_VAR F_Value := ui; END_FUNCTION",
            "FB_Test.st": "FUNCTION_BLOCK FB_Test VAR st : ST_PAYLOAD; ui : UINT; END_VAR "
                          "st.eMode := E_MODE.Run; ui := F_Value(ui := 1); END_FUNCTION_BLOCK",
            "GVL_Data.st": "VAR_GLOBAL fb : FB_Test; END_VAR",
            "PRG_Test.st": "PROGRAM PRG_Test VAR END_VAR GVL_Data.fb(); END_PROGRAM",
        })
        self.assertTrue(result.ok, result.findings)
        order = [source.name for source in result.import_order]
        for dependency, consumer in [("E_MODE", "ST_PAYLOAD"), ("ST_PAYLOAD", "FB_Test"),
                                     ("F_Value", "FB_Test"), ("FB_Test", "GVL_Data"),
                                     ("GVL_Data", "PRG_Test")]:
            self.assertLess(order.index(dependency), order.index(consumer))

    def test_unknown_enum_member_is_reported(self):
        result = self.check_fixture({
            "E_MODE.st": "TYPE E_MODE : (Idle := 0) := Idle; END_TYPE",
            "FB_Test.st": "FUNCTION_BLOCK FB_Test VAR e : E_MODE; END_VAR e := E_MODE.Missing; END_FUNCTION_BLOCK",
        })
        self.assert_finding(result, "enum-member")

    def test_missing_array_element_type_is_reported(self):
        result = self.check_fixture({
            "ST_A.st": "TYPE ST_A : STRUCT a : ARRAY[1..16] OF ST_Missing; END_STRUCT END_TYPE",
        })
        self.assert_finding(result, "missing-type")

    def test_duplicate_declarations_are_case_insensitive(self):
        result = self.check_fixture({
            "a/ST_A.st": "TYPE ST_A : STRUCT x : BOOL; END_STRUCT END_TYPE",
            "b/st_a.st": "TYPE st_a : STRUCT x : BOOL; END_STRUCT END_TYPE",
        })
        self.assert_finding(result, "duplicate-declaration")

    def test_duplicate_enum_wire_values_include_base_literals(self):
        result = self.check_fixture({
            "E_MODE.st": "TYPE E_MODE : (Idle := 16, Run := UINT#16#10) := Idle; END_TYPE",
        })
        self.assert_finding(result, "duplicate-enum-wirevalue")

    def test_type_dependency_cycle_is_reported(self):
        result = self.check_fixture({
            "ST_A.st": "TYPE ST_A : STRUCT b : ST_B; END_STRUCT END_TYPE",
            "ST_B.st": "TYPE ST_B : STRUCT a : ST_A; END_STRUCT END_TYPE",
        })
        self.assert_finding(result, "dependency-cycle")

    def test_function_dependency_cycle_is_reported(self):
        result = self.check_fixture({
            "F_A.st": "FUNCTION F_A : UINT F_A := F_B(); END_FUNCTION",
            "F_B.st": "FUNCTION F_B : UINT F_B := F_A(); END_FUNCTION",
        })
        self.assert_finding(result, "dependency-cycle")

    def test_comments_strings_and_pragmas_do_not_create_findings(self):
        result = self.check_fixture({
            "FB_Test.st": "{attribute 'IF AT %QX0.0'} FUNCTION_BLOCK FB_Test\n"
                          "VAR s : STRING := 'IF CASE AT %I0.0'; END_VAR\n"
                          "(* IF (* CASE END_FOR *) END_TYPE *)\n"
                          "// E_Missing.Nope and END_VAR\n"
                          "IF TRUE THEN s := 'FOR'; END_IF; END_FUNCTION_BLOCK",
        })
        self.assertTrue(result.ok, result.findings)

    def test_mismatched_nested_delimiters_are_reported(self):
        result = self.check_fixture({
            "FB_Test.st": "FUNCTION_BLOCK FB_Test VAR END_VAR IF TRUE THEN END_FOR; END_FUNCTION_BLOCK",
        })
        self.assert_finding(result, "delimiter")

    def test_physical_io_and_address_binding_are_reported(self):
        result = self.check_fixture({
            "GVL_IO.st": "VAR_GLOBAL x AT %QX0.0 : BOOL; END_VAR",
        })
        self.assert_finding(result, "physical-io")

    def test_filename_mismatch_is_reported(self):
        result = self.check_fixture({
            "FB_Wrong.st": "FUNCTION_BLOCK FB_Test END_FUNCTION_BLOCK",
        })
        self.assert_finding(result, "filename")

    def test_unclosed_comment_is_reported(self):
        result = self.check_fixture({"FB_Test.st": "FUNCTION_BLOCK FB_Test (* IF"})
        self.assert_finding(result, "lexical")

    def test_inventory_refuses_invalid_sources(self):
        result = self.check_fixture({"ST_A.st": "TYPE ST_A : ST_Missing; END_TYPE"})
        with self.assertRaises(ValueError):
            write_inventory(result, result.root / "docs" / "INVENTORY.md")


if __name__ == "__main__":
    unittest.main()
