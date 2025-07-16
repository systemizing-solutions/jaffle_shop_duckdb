{# =============================================================================
  Helper family :  __exists_in__
  Purpose       :  Row‑level test – every key combo in the current model must
                   exist in a chosen target relation.
============================================================================= #}
{% macro dbt_assertions__exists_in(configs) %}
    {%- set out = {} -%}
    {%- set model_name = this.name -%}

    {%- for cfg in configs %}
        {# ─── pull fields ---------------------------------------------------- #}
        {%- set target_raw = cfg.get('target_table') %}
        {%- set keys_raw   = cfg.get('keys') %}

        {%- if not target_raw or not keys_raw %}
            {{ exceptions.raise_compiler_error(
                "__exists_in__ needs 'target_table' and 'keys'"
            ) }}
        {%- endif %}

        {%- set target_raw_str = target_raw | string | trim %}

        {# ─── resolve target relation (string) -------------------------------- #}
        {%- if target_raw_str.startswith("ref(") %}
            {# ref('model') → model relation string #}
            {%- set inner       = target_raw_str[4:-1] | trim %}
            {%- set model_name_only = inner
                  | replace("'", "")
                  | replace('"', "") %}
            {%- set target_rel = ref(model_name_only) %}
        {%- elif target_raw_str.startswith("source(") %}
            {# source('src','table') → source relation string #}
            {%- set inner = target_raw_str[7:-1] %}
            {%- set parts = inner.split(',', 1) %}
            {%- if parts | length != 2 %}
                {{ exceptions.raise_compiler_error(
                    "__exists_in__ source() needs two args: source('src','table')"
                ) }}
            {%- endif %}
            {%- set src_name  = parts[0]
                  | trim
                  | replace("'", "")
                  | replace('"', "") %}
            {%- set tbl_name  = parts[1]
                  | trim
                  | replace("'", "")
                  | replace('"', "") %}
            {%- set target_rel = source(src_name, tbl_name) %}
        {%- else %}
            {# literal relation #}
            {%- set target_rel = target_raw_str %}
        {%- endif %}

        {# ─── build key predicates ------------------------------------------- #}
        {%- if not (keys_raw is iterable) %}
            {{ exceptions.raise_compiler_error(
                "__exists_in__ 'keys' must be a list of mappings"
            ) }}
        {%- endif %}

        {%- set predicates = [] %}
        {%- for pair in keys_raw %}
            {%- if pair is mapping %}
                {%- set src_col = pair.get('source') or pair.get('src') %}
                {%- set tgt_col = pair.get('target') or pair.get('tgt') %}
                {%- if not src_col or not tgt_col %}
                    {{ exceptions.raise_compiler_error(
                        "__exists_in__ each key mapping needs 'source'/'target'"
                    ) }}
                {%- endif %}
                {%- do predicates.append("tgt." ~ tgt_col ~ " = " ~ src_col) %}
            {%- else %}
                {{ exceptions.raise_compiler_error(
                    "__exists_in__ 'keys' entries must be mappings"
                ) }}
            {%- endif %}
        {%- endfor %}
        {%- set join_predicate = predicates | join(' AND ') %}

        {%- set expression = (
              "NOT EXISTS (SELECT 1 FROM " ~ target_rel ~
              " tgt WHERE " ~ join_predicate ~ ")"
        ) %}

        {# ─── let dbt register the dependency via 'depends_on' --------------- #}
        {%- set depends_on = [] %}
        {%- if target_raw_str.startswith("ref(") or target_raw_str.startswith("source(") %}
            {%- do depends_on.append(target_raw_str) %}
        {%- endif %}

        {# ─── stable rule name ----------------------------------------------- #}
        {%- set safe_target = target_raw_str
              | replace('.', '_')
              | replace('(', '_')
              | replace(')', '_')
              | replace("'", '')
              | replace('"', '') %}
        {%- set assertion_name = model_name ~ '_in_' ~ safe_target ~ '__exists' %}

        {# ─── accumulate dict ------------------------------------------------ #}
        {%- do out.update({
            assertion_name: {
                'description': model_name ~ " keys must exist in " ~ target_raw_str,
                'expression':  expression,
                'depends_on':  depends_on
            }
        }) %}
    {%- endfor %}

    {{ return(out) }}
{% endmacro %}
