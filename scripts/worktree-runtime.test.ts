import { describe, expect, test } from "bun:test";

import { buildChezmoiArgs, type ChezmoiRuntime } from "./worktree-runtime.ts";

const runtime: ChezmoiRuntime = {
  cacheDir: "/session/cache",
  configFile: "/session/config.toml",
  destinationDir: "/home/tester",
  persistentStateFile: "/session/state.boltdb",
  sourceDir: "/repo/home",
  worktreeRoot: "/repo",
};

describe("buildChezmoiArgs", () => {
  test("uses explicit long-form isolation flags before command arguments", () => {
    expect(buildChezmoiArgs(runtime, ["status", "--path-style", "absolute"])).toEqual([
      "--source",
      "/repo/home",
      "--working-tree",
      "/repo",
      "--config",
      "/session/config.toml",
      "--cache",
      "/session/cache",
      "--persistent-state",
      "/session/state.boltdb",
      "--destination",
      "/home/tester",
      "status",
      "--path-style",
      "absolute",
    ]);
  });

  test("never adds --init", () => {
    expect(buildChezmoiArgs(runtime, ["apply"])).not.toContain("--init");
  });
});

import { promises as fs } from "node:fs";
import os from "node:os";
import path from "node:path";

import { createEphemeralRuntime, removeEphemeralRuntime } from "./worktree-runtime.ts";

test("creates and removes a hookless isolated runtime", async () => {
  const parent = await fs.mkdtemp(path.join(os.tmpdir(), "worktree-runtime-test-"));
  const runtime = await createEphemeralRuntime({
    destinationDir: path.join(parent, "home"),
    sourceDir: "/repo/home",
    tempParent: parent,
    worktreeRoot: "/repo",
  });

  expect(await fs.readFile(runtime.configFile, "utf8")).toBe("");
  expect(runtime.cacheDir.startsWith(parent)).toBe(true);

  await removeEphemeralRuntime(runtime);
  await expect(fs.stat(path.dirname(runtime.configFile))).rejects.toMatchObject({ code: "ENOENT" });
});
