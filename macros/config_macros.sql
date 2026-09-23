{% macro curated_config() %}
{{
    config(
        schema="curated",
        materialized="table"
    )
}}
{% endmacro %}


{% macro staging_config() %}
{{
    config(
        schema="staging",
        materialized="view"
    )
}}
{% endmacro %}
