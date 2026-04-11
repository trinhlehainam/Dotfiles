export type PlatformTarget = {
  /** chezmoi source-state directory, relative to `sourceStateRoot` (e.g. `"dot_config/nvim"`). */
  wrapperRoot: string;
  /** relative target path, POSIX-style (e.g. `".config/nvim"`). */
  targetPrefix: string;
};

export type ToolConfig = {
  /** unique tool identifier (e.g. `"nvim"`). */
  name: string;
  /** raw source directory, relative to `sourceStateRoot` (e.g. `".shared-configs/nvim"`). */
  source: string;
  targets: Record<"unix" | "windows", PlatformTarget>;
};

const nvim: ToolConfig = {
  name: "nvim",
  source: ".shared-configs/nvim",
  targets: {
    unix: {
      wrapperRoot: "dot_config/nvim",
      targetPrefix: ".config/nvim",
    },
    windows: {
      wrapperRoot: "AppData/Local/nvim",
      targetPrefix: "AppData/Local/nvim",
    },
  },
};

const yazi: ToolConfig = {
  name: "yazi",
  source: ".shared-configs/yazi",
  targets: {
    unix: {
      wrapperRoot: "dot_config/yazi",
      targetPrefix: ".config/yazi",
    },
    windows: {
      wrapperRoot: "AppData/Roaming/yazi/config",
      targetPrefix: "AppData/Roaming/yazi/config",
    },
  },
};

export const tools: ToolConfig[] = [nvim, yazi];

export function validateToolRegistry(toolList: ToolConfig[]): void {
  const names = new Set<string>();
  const sources = new Set<string>();
  const wrapperRoots = new Set<string>();
  const targetPrefixes = new Set<string>();

  for (const tool of toolList) {
    if (names.has(tool.name)) {
      throw new Error(`duplicate tool name: ${tool.name}`);
    }
    names.add(tool.name);

    if (sources.has(tool.source)) {
      throw new Error(`duplicate tool source: ${tool.source}`);
    }
    sources.add(tool.source);

    for (const [platform, target] of Object.entries(tool.targets)) {
      const wrapperKey = `${platform}:${target.wrapperRoot}`;
      if (wrapperRoots.has(wrapperKey)) {
        throw new Error(`duplicate wrapper root for ${platform}: ${target.wrapperRoot}`);
      }
      wrapperRoots.add(wrapperKey);

      const prefixKey = `${platform}:${target.targetPrefix}`;
      if (targetPrefixes.has(prefixKey)) {
        throw new Error(`duplicate target prefix for ${platform}: ${target.targetPrefix}`);
      }
      targetPrefixes.add(prefixKey);
    }
  }
}