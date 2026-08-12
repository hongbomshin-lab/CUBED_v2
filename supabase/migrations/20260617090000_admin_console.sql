-- 제보 → 승격된 제품 추적
alter table public.user_submissions
  add column if not exists promoted_product_id text references public.products(product_id);

-- 승격: products insert + product_sweeteners + sweetener_review + 제보 상태전이를 한 트랜잭션으로.
-- product_id / image_file 은 Edge Function(service_role)이 생성해 넘긴다(이미지 복사 선행 때문).
create or replace function public.promote_submission(
  p_submission_id bigint,
  p_product_id text,
  p_image_file text
) returns text
language plpgsql
security definer
set search_path = public
as $$
declare
  v_sub   public.user_submissions%rowtype;
  v_p     jsonb;
  v_sw    jsonb;
  v_i     int := 0;
  v_raw   text;
begin
  select * into v_sub from public.user_submissions where id = p_submission_id for update;
  if not found then raise exception 'submission % not found', p_submission_id; end if;
  if v_sub.status = 'approved' then raise exception 'submission % already approved', p_submission_id; end if;

  v_p := coalesce(v_sub.parsed, '{}'::jsonb);

  if v_sub.barcode is not null
     and exists (select 1 from public.products where barcode = v_sub.barcode) then
    raise exception 'barcode % already exists in products', v_sub.barcode;
  end if;
  if exists (select 1 from public.products where product_id = p_product_id) then
    raise exception 'product_id % already exists', p_product_id;
  end if;

  insert into public.products (
    product_id, name, brand, category, serving_size, unit,
    kcal, carb, sugar, protein, fat, sodium_mg, fiber, sugar_alcohol, rare_sugar_g,
    ingredients_raw, sweetener_count, barcode, image_file, source_type, verified, notes
  ) values (
    p_product_id,
    coalesce(nullif(v_p->>'name',''), '이름 미상'),
    v_p->>'brand',
    v_p->>'category',
    nullif(v_p->>'serving_size','')::numeric,
    coalesce(nullif(v_p->>'unit',''), 'g'),
    nullif(v_p->>'kcal','')::numeric,
    nullif(v_p->>'carb','')::numeric,
    nullif(v_p->>'sugar','')::numeric,
    nullif(v_p->>'protein','')::numeric,
    nullif(v_p->>'fat','')::numeric,
    nullif(v_p->>'sodium_mg','')::numeric,
    nullif(v_p->>'fiber','')::numeric,
    nullif(v_p->>'sugar_alcohol','')::numeric,
    nullif(v_p->>'rare_sugar_g','')::numeric,
    v_p->>'ingredients_raw',
    coalesce(jsonb_array_length(v_p->'sweeteners'), 0),
    v_sub.barcode,
    p_image_file,
    'OCR제보',
    true,
    v_p->>'notes'
  );

  for v_sw in select * from jsonb_array_elements(coalesce(v_p->'sweeteners', '[]'::jsonb)) loop
    if coalesce(v_sw->>'slug','') <> '' then
      insert into public.product_sweeteners (product_id, slug, amount_g, sort_order)
      values (p_product_id, v_sw->>'slug', nullif(v_sw->>'amount_g','')::numeric, v_i);
      v_i := v_i + 1;
    end if;
  end loop;

  for v_raw in select jsonb_array_elements_text(coalesce(v_p->'unknown_sweeteners', '[]'::jsonb)) loop
    if coalesce(v_raw,'') <> '' then
      insert into public.sweetener_review (raw_name, product_id, resolved) values (v_raw, p_product_id, false);
    end if;
  end loop;

  update public.user_submissions
     set status = 'approved', promoted_product_id = p_product_id
   where id = p_submission_id;

  return p_product_id;
end;
$$;

revoke all on function public.promote_submission(bigint, text, text) from public, anon, authenticated;
