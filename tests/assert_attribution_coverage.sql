{#
    Singular test. Fails if any order is missing both a UTM source AND a
    Shopify-native source_name — meaning we have no signal at all for which
    channel produced the sale. A small number of these are normal (legacy
    bookmarks, copy-pasted links); large volumes indicate a tracking regression.
#}

select order_id, utm_source, source_name
from {{ ref('fct_orders') }}
where (utm_source is null or utm_source = '(direct)')
  and (source_name is null or source_name = '')
