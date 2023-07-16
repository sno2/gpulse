import type { ExtensionContext } from "vscode";
import { activate as activateLSP } from "./lsp";

export function activate(context: ExtensionContext) {
  activateLSP(context);
}
