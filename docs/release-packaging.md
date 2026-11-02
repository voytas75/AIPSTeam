# Release packaging notes

[Developer guide](developer-guide.md) · [Release notes](ReleaseNotes.md)

## Published 3.10.4 artifact

[3.10.4 is published on PowerShell Gallery](https://www.powershellgallery.com/packages/AIPSTeam/3.10.4). The inspected public nupkg has five entries (script, nuspec and three NuGet infrastructure entries), identity `AIPSTeam`/`3.10.4`, and **5148** nuspec tag characters. Its SHA256 is `446d6ed2a8c7dbb7f4196864605558c47a2a463f161c7b73d045759bdf3468e3`.

The packaged 5048-line script has raw SHA256 `f8243db119587a03320687b05bd49ac389ee3fc002fae01cf40feb8d2cc344f7`. Normalizing only CRLF to LF gives SHA256 `0053dfb1ef4183a9dde4019454c82b704b1297ef71bbf57e8c177e4d86d2a100`, matching the repository's UTF-8 BOM/LF product byte-for-byte. Raw artifact identity and canonical source equivalence are distinct checks; do not compare a CRLF package against an LF raw hash as though they were identical bytes. Publication does not establish fresh provider inference or current CI qualification.

The sections below preserve the **historical earlier-source packaging route and receipts**, not current function/tag counts, payload hashes or instructions to republish 3.10.4. Earlier 404 preflight snapshots and then-pending upload checks are closed historical gates; the exact version now exists. Do not retry an upload of this version.

## Historical PowerShellGet tags warning and published precedent

The 4000-character warning concerns the generated NuGet metadata `<tags>`, not README length, script size or an LLM token limit. PowerShellGet 2.2.5 adds both `PSFunction_` and `PSCommand_` names. The earlier 3.10.4 source snapshot had 71 functions and 11 source tags (65 characters joined); its generated tags measure 4703 characters. Removing all source tags would still leave 4637 characters.

A previously published package downloaded from the official Gallery package endpoint was inspected on 2026-10-31: its actual nuspec confirmed the package identity and version and contained **4703** tag characters. This is a published historical precedent, not merely an HTTP 200. The helper warning says some feeds may reject these tags; it is not an absolute demonstrated Gallery limit. The precedent supports conditional manual readiness without function refactoring, product changes, module patches or an alternative packager. It does not guarantee future Gallery acceptance of 3.10.4.

## Historical selected manual route and exact bytes

Use the existing official **PowerShellGet 2.2.5 `Publish-Script`** with isolated, signed NuGet **6.14.0.116**, already qualified on native Windows PowerShell 5.1 and 7. No installation, restore, trust/security changes or diagnostic upload is required. Publication and API credentials remain exclusively with the maintainer; the assistant does not upload. Repository documentation and offline qualification do not establish Gallery publication; verify the exact package after manual upload.

The approved UTF-8 BOM/LF `AIPSTeam.ps1` has raw SHA256 `4A48A7F06E566FF0D0C6555635FC5B2560A8EC58FCD07D55E13112232D22CE84`. A checkout converted to CRLF has different raw bytes and must not silently replace this payload. Validate metadata version 3.10.4, `#Requires` PSAOAI >= 0.7.0, and whole-source parsing in both native runtimes without executing the product. The public PSAOAI 0.7.0 baseline already meets the selected minimum; no dependency release is needed.

The offline diagnostic package was produced using the installed official metadata helper and NuGet pack, with publisher-typed Tags and ReleaseNotes. Its actual five entries are the script, nuspec and three NuGet infrastructure entries; the packed script hash matches the approved source. External module names are metadata, not generated NuGet dependencies; the versioned PSAOAI minimum remains `#Requires`. Offline packing is not an upload test. `Publish-Script` regenerates its own package rather than uploading this diagnostic nupkg; package hashes may change, and acceptance cannot be guaranteed.

## Historical immediate preflight and post-upload verification

Then-current instruction (closed for 3.10.4): in a fresh owner console, dot-source the validated handoff helper to retain its process-only tooling configuration. Immediately before manual upload, request `https://www.powershellgallery.com/api/v2/Packages(Id='AIPSTeam',Version='3.10.4')`: only a confirmed HTTP 404 permits continuing. HTTP 200 requires reconciling the existing exact-version record and package; network/authentication errors or ambiguous responses mean stop. Any earlier 404 is a snapshot, not a reservation or future guarantee.

Read the API key with hidden `Read-Host -AsSecureString`, convert only transiently for the official publisher, and clean up in `finally`. Do not use transcripts, literal keys in command history, chat, verbose/debug output or credential files. Plaintext String copies in memory and the publisher's NuGet process argument exposure cannot be eliminated by hidden input.

Then-current verification instruction: after manual upload, read back the exact version endpoint and download `https://www.powershellgallery.com/api/v2/package/AIPSTeam/3.10.4`. Inspect actual nuspec id/version, metadata and entry allowlist; extract the script, compare its **raw** SHA256 above, and parse it in both native runtimes without running it. HTTP 200 alone or a successful upload command is not publication verification. With rejection or an ambiguous result, stop and reconcile Gallery state before any retry; do not automatically alter metadata or change the product. Keep private logs, credentials and tooling binaries outside the product package and handoff ZIP.
