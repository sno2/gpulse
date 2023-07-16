import * as path from "path";
import { ExtensionContext, workspace } from "vscode";

import {
  LanguageClient,
  LanguageClientOptions,
  ServerOptions,
  TransportKind,
} from "vscode-languageclient/node";

/** @type {LanguageClient} */
let client;

/** @param {ExtensionContext} context */
export function activate(context) {
  // The server is implemented in node
  let serverModule = "C:/projects/zig/gpulse/zig-out/bin/gpulse_exe.exe";
  console.log({ serverModule });
  // The debug options for the server
  // --inspect=6009: runs the server in Node's Inspector mode so VS Code can attach to the server for debugging
  let debugOptions = { execArgv: [] };

  // If the extension is launched in debug mode then the debug server options are used
  // Otherwise the run options are used
  /** @type {ServerOptions} */
  let serverOptions = {
    run: { module: serverModule, transport: TransportKind.stdio },
    debug: {
      module: serverModule,
      transport: TransportKind.stdio,
      options: debugOptions,
    },
  };

  // Options to control the language client
  /** @type {LanguageClientOptions} */
  let clientOptions = {
    // Register the server for plain text documents
    documentSelector: [{ scheme: "file", language: "wgsl" }],
    synchronize: {},
  };

  // Create the language client and start the client.
  client = new LanguageClient(
    "gpulse",
    "WGSL Language Server",
    serverOptions,
    clientOptions
  );

  client.start();
}

/** @returns {Thenable<void> | undefined} */
export function deactivate() {
  if (!client) {
    return undefined;
  }
  return client.stop();
}
