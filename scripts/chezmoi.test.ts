import { expect, test } from "bun:test";
import { parseApplyInvocation } from "./chezmoi.ts";

test("recognizes apply without confusing option values or target names with flags", () => {
  expect(parseApplyInvocation(["-c", "apply", "diff"])).toBeUndefined();
  expect(parseApplyInvocation(["--format=json", "data"])).toBeUndefined();
  expect(parseApplyInvocation(["-vn", "apply", "--", "--dry-run=false"])?.dryRun).toBeTrue();
  expect(parseApplyInvocation(["apply", "--output", "-n"])?.dryRun).toBeFalse();
  expect(parseApplyInvocation(["apply", "--dry-run=false"])?.dryRun).toBeFalse();
  expect(parseApplyInvocation(["apply", "-n=false"])?.dryRun).toBeFalse();
  expect(parseApplyInvocation(["apply", "--dry-run", "--dry-run=0"])?.dryRun).toBeFalse();
  expect(parseApplyInvocation(["apply", "--help"])?.help).toBeTrue();
  expect(parseApplyInvocation(["apply", "--help", "--version=false"])?.help).toBeTrue();
});

test("preserves configuration arguments and paths containing spaces", () => {
  expect(parseApplyInvocation(["-S/main path", "apply", "-D", "/home path", "--config=x y", "/home path/file"])
    ?.configArgs).toEqual(["--source", "/main path", "--destination", "/home path", "--config", "x y"]);
});

test("rejects unknown apply options before suspending a session", () => {
  expect(() => parseApplyInvocation(["apply", "--unknown", "-n"])).toThrow("unsupported option");
  expect(() => parseApplyInvocation(["apply", "--destination"])).toThrow("requires a value");
});
