{% macro exasol__type_string() %}
    VARCHAR(2000000)
{% endmacro %}

{% macro exasol__hash(field) -%}
    hash_md5(cast({{ field }} as VARCHAR(2000000)))
{%- endmacro %}
