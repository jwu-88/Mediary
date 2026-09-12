# Live medication catalog

Mediary keeps the public catalog read-only and queries it on demand through
`MedicationCatalogClient`:

- RxNorm Prescribable `/REST/Prescribe/drugs.json` supplies up to 20 current,
  prescribable concepts per normalized search.
- RxNorm properties provide the source/version and stable RxCUI join key.
- openFDA `/drug/label.json?search=openfda.rxcui:<rxcui>` enriches a selected
  concept with dosage form, route, active-label warnings, indications, and a
  DailyMed label URL.

The Flutter client is keyless, debounces searches by 300 ms, ignores stale
responses, deduplicates RxCUIs, and caches recent searches/details in memory.
It never sends profile data, notes, schedules, or dose logs to either API.
openFDA detail requests are made only when a result is opened or confirmed and
are cached because unauthenticated traffic is limited per IP.

The library and add-medication picker show the NLM RxNorm attribution,
openFDA/DailyMed label source, source version, loading/empty/offline/rate-limit
states, and a reminder to verify medication information with a pharmacist or
care team. User selections are copied into private Firestore medication
documents with `catalogId`, `catalogSource`, and `catalogVersion`; the public
response is never written wholesale to Firestore.

## Web integration check

Before enabling the web build in production, exercise both endpoints from the
deployed origin and record the CORS result. If either government endpoint
rejects browser requests, add a Firebase Hosting rewrite for only these API
paths and keep the app-facing `MedicationCatalogClient` interface unchanged.
Native builds continue to call NLM and FDA directly.
