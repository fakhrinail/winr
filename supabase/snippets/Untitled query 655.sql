select
  wins.text,
  wins.occurred_at,
  categories.name as category
from public.wins
left join public.categories
  on categories.id = wins.category_id;