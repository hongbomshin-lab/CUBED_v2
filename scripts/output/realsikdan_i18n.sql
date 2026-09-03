-- 리얼식단 전북도청점 대표메뉴/설명 번역 (en/ja/zh)
alter table public.franchise_translations drop constraint if exists franchise_translations_kind_check;
alter table public.franchise_translations add constraint franchise_translations_kind_check
  check (kind in ('menu','brand','size','category','store','store_menu','menu_note'));

insert into public.franchise_translations (kind, source, lang, value, is_reviewed)
values
  ('store_menu','제로 레몬에이드','en','Zero Lemonade',true),
  ('store_menu','제로 레몬에이드','ja','ゼロレモネード',true),
  ('store_menu','제로 레몬에이드','zh','零糖柠檬水',true),
  ('store_menu','제로 초코라떼','en','Zero Choco Latte',true),
  ('store_menu','제로 초코라떼','ja','ゼロチョコラテ',true),
  ('store_menu','제로 초코라떼','zh','零糖巧克力拿铁',true),
  ('store_menu','스파이시투움바 흑현미 리조또','en','Spicy Toowoomba Black Rice Risotto',true),
  ('store_menu','스파이시투움바 흑현미 리조또','ja','スパイシートゥーンバ黒玄米リゾット',true),
  ('store_menu','스파이시투움바 흑현미 리조또','zh','香辣图姆巴黑糙米烩饭',true),
  ('menu_note','대체당 제로 음료','en','Zero-sugar drink made with a sugar substitute',true),
  ('menu_note','대체당 제로 음료','ja','代替糖を使ったゼロシュガードリンク',true),
  ('menu_note','대체당 제로 음료','zh','使用代糖的零糖饮品',true),
  ('menu_note','흑현미 건강식 대표','en','Signature black-rice healthy meal',true),
  ('menu_note','흑현미 건강식 대표','ja','黒玄米ヘルシー料理の看板メニュー',true),
  ('menu_note','흑현미 건강식 대표','zh','黑糙米健康餐招牌菜',true)
on conflict (kind, source, lang) do update
  set value=excluded.value, is_reviewed=excluded.is_reviewed, updated_at=now();
