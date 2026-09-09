{#
  Explicit project-level override of the built-in `test` materialization.
  Required by Elementary on dbt >= 1.8 so failed-row samples / EDR hooks work
  without PackageMaterializationOverrideDeprecation (do NOT set
  require_explicit_package_overrides_for_builtin_materializations: false).
#}
{% materialization test, default %}
  {{ return(elementary.materialization_test_default()) }}
{% endmaterialization %}

{% materialization test, adapter='snowflake' %}
  {{ return(elementary.materialization_test_snowflake()) }}
{% endmaterialization %}
