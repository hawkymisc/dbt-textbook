-- サロゲートキーを生成するマクロ
-- 複数のカラムを組み合わせてMD5ハッシュを生成します

{% macro generate_surrogate_key(columns) %}
    {%- set column_list = [] -%}
    {%- for column in columns -%}
        {%- set _ = column_list.append("COALESCE(CAST(" ~ column ~ " AS VARCHAR), '')") -%}
    {%- endfor -%}
    MD5({{ column_list | join(" || '-' || ") }})
{% endmacro %}
