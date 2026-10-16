import { expect, test } from "bun:test";
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";

const pwsh = Bun.which("pwsh");
const templates = resolve(import.meta.dir, "../home/.chezmoitemplates/PowerShell");

for (const agent of ["claude", "codex", "opencode"]) {
  test.skipIf(!pwsh)(`${agent} preserves native status, arguments, and editor environment`, () => {
    const temp = mkdtempSync(join(tmpdir(), "agent-prompt-editor-"));
    try {
      const wrapper = join(templates, "Invoke-AgentWithPromptEditor.ps1");
      mkdirSync(join(temp, "agent-prompt-editors"));
      writeFileSync(join(temp, "agent-prompt-editors", `${agent}.ps1`), readFileSync(wrapper));
      writeFileSync(
        join(temp, "native-agent.ps1"),
        String.raw`
[Console]::WriteLine((@{ visual = $env:VISUAL; editor = $env:EDITOR; args = @($args) } | ConvertTo-Json -Compress))
exit [int]$env:AGENT_TEST_EXIT_CODE
`,
      );
      const check = join(temp, "check.ps1");
      writeFileSync(
        check,
        String.raw`
param($ProfilePath, $Agent)
$PSNativeCommandUseErrorActionPreference = $false
$nativeCommand = (Get-Process -Id $PID).Path
function Get-Command { param($Name, $CommandType) [pscustomobject]@{ Source = $nativeCommand } }
$ast = [System.Management.Automation.Language.Parser]::ParseFile($ProfilePath, [ref]$null, [ref]$null)
$block = $ast.Find({
    param($node)
    $node -is [System.Management.Automation.Language.IfStatementAst] -and
        $node.Clauses[0].Item1.Extent.Text -eq 'Test-Command nvim'
}, $true).Clauses[0].Item2.Extent.Text
$fixtureProfile = Join-Path $PSScriptRoot 'profile.ps1'
Set-Content -LiteralPath $fixtureProfile -Value $block.Substring(1, $block.Length - 2)
. $fixtureProfile
$nativeArgs = @('-NoLogo', '-NoProfile', '-File', "$PSScriptRoot/native-agent.ps1", '--model', 'model name', '-p', 'prompt text', '--debug')
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
$results | ConvertTo-Json -Depth 5 -Compress
`,
      );
      const result = Bun.spawnSync([
        pwsh!, "-NoLogo", "-NoProfile", "-File", check,
        join(templates, "Microsoft.PowerShell_profile.ps1"), agent,
      ]);
      expect(result.exitCode).toBe(0);
      expect(result.stderr.toString()).toBe("");
      const cases = JSON.parse(result.stdout.toString());
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
        });
      }
    } finally {
      rmSync(temp, { recursive: true, force: true });
    }
  }, 30000);
}
