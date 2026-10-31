# Release packaging notes

[Developer guide](developer-guide.md) · [Release notes](ReleaseNotes.md)

## PowerShellGet tags warning

The 4000-character warning concerns the generated NuGet package metadata field `<tags>`, not README length, script size or an LLM token limit. PowerShellGet 2.2.5 adds discovered function names to the script's source tags when generating the nuspec.

The prior offline packaging probe for candidate 3.10.4 measured 4703 characters in generated tags from 71 functions. The source contains 11 tags (65 characters when joined); even removing all of them would leave 4637 characters. Shortening README or removing the few source tags therefore does not resolve this warning.

The warning says some NuGet feeds may not accept the generated tags. Actual PowerShell Gallery rejection was **not tested**; the warning alone is not proof that Gallery will reject the candidate. No source or packaging workaround is implemented by this documentation restructuring.

Keep packaging warnings, offline validation and actual upload results separate. Publication remains a manual maintainer step; do not upload as a diagnostic experiment or disclose API keys, private endpoints or raw provider logs.
