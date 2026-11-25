# Governance Notes

The project uses public data. It does not intentionally store names, addresses, card details or other personal customer information.

## Access

- Only project maintainers should have Member or Admin access to the Fabric workspace.
- Report users can use Viewer access.
- Connection details and API keys must not be committed to Git.
- Fabric connections should be reviewed when ownership of the project changes.

RLS was not added because the report contains public, aggregated data and there are no user-specific data rules.

## OpenAQ secret

The OpenAQ API key is stored in Azure Key Vault under `openaq-api-key`. The OpenAQ pipeline reads it at runtime. The key is not written in the Dataflow, notebook or repository.

If the key is changed, the Key Vault secret should be updated without changing the pipeline code.

## Data quality rules

- Taxi records with invalid dates, IDs, amounts, distances or durations are removed.
- Duplicate Taxi rows are removed in Silver.
- OpenAQ rows with missing values or negative measurements are removed.
- Pollutant units are kept in the Air Quality fact key so different units are not mixed.
- Pipeline validation checks empty tables, duplicate keys, date coverage and OpenAQ freshness.

## Refresh policy

- OpenAQ runs every day because new measurements are available frequently.
- Taxi runs from the monthly master pipeline because TLC publishes files monthly and with a delay.
- The separate Taxi schedule is disabled to avoid starting the same work twice.
- World Bank and ECB are refreshed by the monthly master pipeline.
- Bronze data is kept so that Silver and Gold can be rebuilt if needed.

## How results should be used

The Taxi and Air Quality overlay is a time comparison. It should not be presented as proof that Taxi traffic caused a pollution change. OpenAQ locations and Taxi Zones are also different location systems.

GDP covers a longer period than Taxi and OpenAQ, so the report gives economic context but does not prove a long-term relationship between all three domains.

## Optional items

Purview and Power BI RLS were optional in the task. I did not add them to the current public-data version. They would be useful if the project were extended with private data or more users.

## Changes to the project

Before committing a larger change:

1. Run the affected pipeline.
2. Check row counts and minimum/maximum dates.
3. Confirm that validation activities succeed.
4. Commit the related Fabric items together.

