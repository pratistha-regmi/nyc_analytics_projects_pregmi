-- Clean DOB NOW job filings
-- One row per job filing number

WITH source AS (
    SELECT *
    FROM {{ source('raw', 'source_nyc_dob_job_apps') }}
),

cleaned AS (
    SELECT
        * EXCEPT (
            job_filing_number,
            filing_status,
            borough,
            zip,
            council_district,
            latitude,
            longitude
        ),

        TRIM(job_filing_number) AS job_filing_number,
        UPPER(TRIM(filing_status)) AS filing_status,

        CASE
            WHEN UPPER(TRIM(borough))
                IN ('1', 'MANHATTAN', 'NEW YORK', 'NEW YORK COUNTY')
                THEN 'Manhattan'
            WHEN UPPER(TRIM(borough))
                IN ('2', 'BRONX', 'THE BRONX')
                THEN 'Bronx'
            WHEN UPPER(TRIM(borough))
                IN ('3', 'BROOKLYN', 'KINGS COUNTY')
                THEN 'Brooklyn'
            WHEN UPPER(TRIM(borough))
                IN ('4', 'QUEENS', 'QUEEN', 'QUEENS COUNTY')
                THEN 'Queens'
            WHEN UPPER(TRIM(borough))
                IN ('5', 'STATEN ISLAND', 'RICHMOND COUNTY')
                THEN 'Staten Island'
            ELSE 'UNKNOWN or CITYWIDE'
        END AS borough,

        CASE
            WHEN REGEXP_CONTAINS(TRIM(zip), r'^\d{5}$')
                THEN TRIM(zip)
            WHEN REGEXP_CONTAINS(TRIM(zip), r'^\d{9}$')
                THEN TRIM(zip)
            WHEN REGEXP_CONTAINS(TRIM(zip), r'^\d{5}-\d{4}$')
                THEN TRIM(zip)
            ELSE NULL
        END AS zip,

        NULLIF(TRIM(council_district), '') AS council_district,

        SAFE_CAST(latitude AS NUMERIC) AS latitude,
        SAFE_CAST(longitude AS NUMERIC) AS longitude,

        CURRENT_TIMESTAMP() AS _stg_loaded_at

    FROM source
    WHERE NULLIF(TRIM(job_filing_number), '') IS NOT NULL

    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY TRIM(job_filing_number)
        ORDER BY current_status_date DESC, filing_date DESC
    ) = 1
)

SELECT *
FROM cleaned