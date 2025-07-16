{# ============================================================================ #
  Macro name      :  dbt_assertions__is_max_stg_orders
  Helper key      :  __is_max_stg_orders__
  Semantics       :  <column> must equal the MAX(<column>) from {{ ref('stg_orders') }}
# ============================================================================ #}

{% macro dbt_assertions__is_max_stg_orders(columns) %}
    {%- set base_relation = ref('stg_orders') -%}      {# resolves to the full relation name #}
    {%- set out = {} -%}

    {%- for col in columns %}
        {%- do out.update({
            (col ~ '__is_max_stg_orders'): {
                'description': col ~ ' must equal MAX(' ~ col ~ ') in ' ~ base_relation,
                'expression'  : col ~ ' = (SELECT MAX(' ~ col ~ ') FROM ' ~ base_relation ~ ')'
            }
        }) %}
    {%- endfor %}

    {{ return(out) }}
{% endmacro %}
