# Optional web retrieval (RAG)

[Start here](../README.md) · [Provider setup](provider-configuration.md)

Start with `-NORAG`. Remove it only after model calls work and you have configured search services. RAG retrieves web context to include in model requests; retrieved material can be incomplete, misleading or contain instructions that should not be trusted. Retrieval does not guarantee a more accurate draft.

## Search providers

The implementation tries [SerpApi](https://serpapi.com/) first, then [EXA](https://exa.ai/), then [Serper](https://serper.com/) on errors or empty results. If all fail, no successful retrieval is available and the workflow continues without it. Bing search is historical, commented-out code, not an active fallback.

Configuration names:

- `SERPAPI_API_KEY`
- `EXA_API_KEY`
- `SERPER_API_KEY`

The RAG setup path reads User-scoped values and can prompt for missing keys, persisting them to User configuration. Process-only settings are not a substitute for these particular reads. Do not assume `-NOInteraction` prevents all search setup prompts. Avoid putting keys in source, examples or logs; follow each service's credential guidance. Check current service pricing and quotas with the provider instead of relying on historical free-tier numbers.

Search queries and retrieved text may leave your machine through search and LLM requests. Review whether your project description or code contains sensitive information before enabling retrieval. `-NORAG` disables search but still allows calls to the chosen model provider.
