import { expect, test } from "bun:test";
import { copyFileSync, linkSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const pwsh = Bun.which("pwsh");
const templates = resolve(import.meta.dir, "../home/.chezmoitemplates/PowerShell");

for (const agent of ["claude", "codex", "opencode"]) {
  test.skipIf(!pwsh)(`${agent} preserves native status, arguments, stdin, and editor environment`, () => {
    const temp = mkdtempSync(join(tmpdir(), "agent prompt editor-"));
    try {
      const wrapper = join(templates, "Invoke-AgentWithPromptEditor.ps1");
      mkdirSync(join(temp, "agent-prompt-editors"));
      writeFileSync(join(temp, "agent-prompt-editors", `${agent}.ps1`), readFileSync(wrapper));
      mkdirSync(join(temp, "bin"));
      const nativeCommand = join(temp, "bin", `${agent}${process.platform === "win32" ? ".exe" : ""}`);
      // Real application lookup, without launching another PowerShell for every invocation.
      try {
        linkSync(process.execPath, nativeCommand);
      } catch {
        copyFileSync(process.execPath, nativeCommand);
      }
      writeFileSync(
        join(temp, "native-agent.ts"),
        String.raw`
import { readFileSync } from "node:fs";
console.log(JSON.stringify({
  visual: process.env.VISUAL,
  editor: process.env.EDITOR,
  args: process.argv.slice(2),
  stdin: process.env.AGENT_TEST_READ_STDIN === "1" ? readFileSync(0, "utf8") : null,
  viaShim: process.env.AGENT_TEST_SHIM === "1",
}));
process.exit(Number(process.env.AGENT_TEST_EXIT_CODE));
`,
      );
      const check = join(temp, "check.ps1");
      writeFileSync(
        check,
        String.raw`
param($ProfilePath, $Agent, $NativeCommand)
$PSNativeCommandUseErrorActionPreference = $false
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ProfilePath, [ref]$null, [ref]$null)
$block = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.IfStatementAst] -and
        $node.Clauses[0].Item1.Extent.Text -eq 'Test-Command nvim'
}, $true).Clauses[0].Item2.Extent.Text
$fixtureProfile = Join-Path $PSScriptRoot 'profile.ps1'
Set-Content -LiteralPath $fixtureProfile -Value $block.Substring(1, $block.Length - 2)
. $fixtureProfile
$env:PATH = Join-Path $PSScriptRoot 'bin'
$nativeArgs = @("$PSScriptRoot/native-agent.ts", '--model', 'model name', '-p', 'prompt text', '--debug')
$env:AGENT_TEST_READ_STDIN = '0'
$env:AGENT_TEST_SHIM = '0'
$results = foreach ($code in @(0, 7)) {
    foreach ($unset in @($false, $true)) {
        if ($unset) {
            Remove-Item Env:VISUAL, Env:EDITOR -ErrorAction SilentlyContinue
        } else {
            $env:VISUAL = 'original visual'
            $env:EDITOR = 'original editor'
        }
        $env:AGENT_TEST_EXIT_CODE = $code
        $output = & $Agent @nativeArgs
        $success = $?
        $exitCode = $LASTEXITCODE
        $andRan = $orRan = $false
        $null = & $Agent @nativeArgs && ($andRan = $true) || ($orRan = $true)
        [pscustomobject]@{
            code = $code; unset = $unset; success = $success; exitCode = $exitCode
            andRan = $andRan; orRan = $orRan
            visual = $env:VISUAL; editor = $env:EDITOR
            output = ($output | ConvertFrom-Json)
        }
    }
}
$env:AGENT_TEST_EXIT_CODE = '0'
$env:AGENT_TEST_READ_STDIN = '1'
$direct = 'hello from pipeline', 'second line' | & $NativeCommand @nativeArgs
$piped = 'hello from pipeline', 'second line' | & $Agent @nativeArgs
$env:AGENT_TEST_READ_STDIN = '0'
# PowerShell consumes bare -- for script commands; quote a literal separator.
$separator = & $Agent @nativeArgs '--' '-x'
$env:AGENT_TEST_NATIVE_COMMAND = Join-Path (Split-Path $NativeCommand) ('backend' + [IO.Path]::GetExtension($NativeCommand))
Move-Item -LiteralPath $NativeCommand -Destination $env:AGENT_TEST_NATIVE_COMMAND
Set-Content -LiteralPath (Join-Path (Split-Path $NativeCommand) "$Agent.ps1") -Value @'
$env:AGENT_TEST_SHIM = '1'
& $env:AGENT_TEST_NATIVE_COMMAND @args
exit $LASTEXITCODE
'@
$env:AGENT_TEST_EXIT_CODE = '7'
$shim = & $Agent @nativeArgs 'say "hello" & ^ %AGENT_TEST_EXIT_CODE%' 2>$null
$shimSuccess = $?
$shimExitCode = $LASTEXITCODE
$env:PATH = ''
$global:LASTEXITCODE = 0
$Error.Clear()
$null = & $Agent @nativeArgs 2>$null
$missingSuccess = $?
$missingExitCode = $LASTEXITCODE
$missingErrorCount = $Error.Count
$andRan = $orRan = $false
$global:LASTEXITCODE = 0
$null = & $Agent @nativeArgs 2>$null && ($andRan = $true) || ($orRan = $true)
[pscustomobject]@{
    cases = @($results)
    direct = ($direct | ConvertFrom-Json); piped = ($piped | ConvertFrom-Json)
    separator = ($separator | ConvertFrom-Json)
    shim = @{
        output = ($shim | ConvertFrom-Json); success = $shimSuccess; exitCode = $shimExitCode
    }
    missing = @{
        success = $missingSuccess; exitCode = $missingExitCode; errorCount = $missingErrorCount
        andRan = $andRan; orRan = $orRan; visual = $env:VISUAL; editor = $env:EDITOR
    }
} | ConvertTo-Json -Depth 5 -Compress
`,
      );
      const result = Bun.spawnSync([
        pwsh!, "-NoLogo", "-NoProfile", "-File", check,
        join(templates, "Microsoft.PowerShell_profile.ps1"), agent, nativeCommand,
      ], { stdin: "ignore" });
      expect(result.exitCode).toBe(0);
      expect(result.stderr.toString()).toBe("");
      const { cases, direct, piped, separator, shim, missing } = JSON.parse(result.stdout.toString());
      expect(cases).toHaveLength(4);
      for (const entry of cases) {
        expect(entry.success).toBe(entry.code === 0);
        expect(entry.exitCode).toBe(entry.code);
        expect(entry.andRan).toBe(entry.code === 0);
        expect(entry.orRan).toBe(entry.code !== 0);
        expect(entry.visual).toBe(entry.unset ? null : "original visual");
        expect(entry.editor).toBe(entry.unset ? null : "original editor");
        expect(entry.output).toEqual({
          visual: "nvim --cmd let[g:dotfiles_minimal]=[v:true]",
          editor: "nvim --cmd let[g:dotfiles_minimal]=[v:true]",
          args: ["--model", "model name", "-p", "prompt text", "--debug"],
          stdin: null,
          viaShim: false,
        });
      }
      expect(piped.stdin).toBe(direct.stdin);
      expect(piped.stdin.replace(/\r\n/g, "\n")).toBe("hello from pipeline\nsecond line\n");
      expect(separator.args).toEqual(["--model", "model name", "-p", "prompt text", "--debug", "--", "-x"]);
      expect(shim.success).toBe(false);
      expect(shim.exitCode).toBe(7);
      expect(shim.output.viaShim).toBe(true);
      expect(shim.output.args).toEqual(["--model", "model name", "-p", "prompt text", "--debug", 'say "hello" & ^ %AGENT_TEST_EXIT_CODE%']);
      expect(missing.success).toBe(false);
      expect(missing.exitCode).toBe(127);
      expect(missing.errorCount).toBeGreaterThan(0);
      expect(missing.andRan).toBe(false);
      expect(missing.orRan).toBe(true);
      expect(missing.visual).toBeNull();
      expect(missing.editor).toBeNull();
    } finally {
      rmSync(temp, { recursive: true, force: true });
    }
  }, 30000);
}
