-- 매장 대표 메뉴 (저당 + 시그니처)
-- 생성: build_store_menus.py · 45행
-- 출처·신뢰도는 각 행의 source_url/confidence 참고. 당류 미공개는 null.

-- 테이블이 초안 스키마로 먼저 만들어진 환경을 위해 칼럼을 먼저 맞춘다.
alter table public.store_menus add column if not exists serving text;
alter table public.store_menus add column if not exists updated_at timestamptz default now();

insert into public.store_menus
  (store_id, name, kind, sugar_g, calories, price_won, serving, note, source_url, confidence, sort_order)
values
  ('85cfa37c-6d3a-40a0-8c75-397177542fd1', '콥 샐러디', 'low_sugar', 3.4, 219.1, null, '215g', '전 샐러디 메뉴 중 당류 최저', 'https://salady.com/pdf/220908_nutrition.pdf', 'official', 0),
  ('85cfa37c-6d3a-40a0-8c75-397177542fd1', '고추장머쉬룸 웜볼', 'low_sugar', 3.8, 433.9, null, '365g', null, 'https://salady.com/pdf/220908_nutrition.pdf', 'official', 1),
  ('85cfa37c-6d3a-40a0-8c75-397177542fd1', '우삼겹 웜볼', 'low_sugar', 5.1, 409.9, null, '285g', null, 'https://salady.com/pdf/220908_nutrition.pdf', 'official', 2),
  ('85cfa37c-6d3a-40a0-8c75-397177542fd1', '우삼겹메밀면 샐러디', 'low_sugar', 5.2, 307.4, null, '305g', null, 'https://salady.com/pdf/220908_nutrition.pdf', 'official', 3),
  ('85cfa37c-6d3a-40a0-8c75-397177542fd1', '시저치킨 샐러디', 'signature', 8.5, 116.4, null, '160g', '전 메뉴 중 최저 칼로리', 'https://salady.com/pdf/220908_nutrition.pdf', 'official', 4),
  ('482518e2-f68f-4ed9-9225-5648939c1ab7', '콥 샐러디', 'low_sugar', 3.4, 219.1, null, '215g', '전 샐러디 메뉴 중 당류 최저', 'https://salady.com/pdf/220908_nutrition.pdf', 'official', 0),
  ('482518e2-f68f-4ed9-9225-5648939c1ab7', '고추장머쉬룸 웜볼', 'low_sugar', 3.8, 433.9, null, '365g', null, 'https://salady.com/pdf/220908_nutrition.pdf', 'official', 1),
  ('482518e2-f68f-4ed9-9225-5648939c1ab7', '우삼겹 웜볼', 'low_sugar', 5.1, 409.9, null, '285g', null, 'https://salady.com/pdf/220908_nutrition.pdf', 'official', 2),
  ('482518e2-f68f-4ed9-9225-5648939c1ab7', '우삼겹메밀면 샐러디', 'low_sugar', 5.2, 307.4, null, '305g', null, 'https://salady.com/pdf/220908_nutrition.pdf', 'official', 3),
  ('482518e2-f68f-4ed9-9225-5648939c1ab7', '시저치킨 샐러디', 'signature', 8.5, 116.4, null, '160g', '전 메뉴 중 최저 칼로리', 'https://salady.com/pdf/220908_nutrition.pdf', 'official', 4),
  ('0a0e1e96-60e5-4041-8db5-84850a086845', '애사비 에이드', 'low_sugar', 0, 0, null, null, '당류·열량 0', 'https://www.slowcali.co.kr/bbs/content.php?co_id=menu', 'official', 0),
  ('0a0e1e96-60e5-4041-8db5-84850a086845', '연어 포케 (메밀면&샐러드)', 'low_sugar', 3.0, 536.3, null, null, null, 'https://www.slowcali.co.kr/bbs/content.php?co_id=menu', 'official', 1),
  ('0a0e1e96-60e5-4041-8db5-84850a086845', '크런치 시저 샐러드', 'low_sugar', 3.1, 189.9, null, '151g', null, 'https://www.slowcali.co.kr/bbs/content.php?co_id=menu', 'official', 2),
  ('0a0e1e96-60e5-4041-8db5-84850a086845', '문어 포케 (현미밥&샐러드)', 'low_sugar', 3.4, 398.2, null, '336g', null, 'https://www.slowcali.co.kr/bbs/content.php?co_id=menu', 'official', 3),
  ('0a0e1e96-60e5-4041-8db5-84850a086845', '올인원 포케 (현미밥&샐러드)', 'signature', 3.4, 453.2, null, '405g', '브랜드 대표 포케', 'https://www.slowcali.co.kr/bbs/content.php?co_id=menu', 'official', 4),
  ('b8d48155-a0d1-4946-bb76-2aba138c0eef', '무설탕 수비드 안심 김치 덮밥', 'low_sugar', 1, 330, null, null, null, 'https://xn--2o2b2xt4yeqi6sah0v.com/', 'estimated', 0),
  ('b8d48155-a0d1-4946-bb76-2aba138c0eef', '저당 갈비 포케', 'low_sugar', 2, 500, null, null, '메뉴명에 ''저당'' 표기', 'https://xn--2o2b2xt4yeqi6sah0v.com/', 'estimated', 1),
  ('b8d48155-a0d1-4946-bb76-2aba138c0eef', '저당 갈비 덮밥', 'low_sugar', 3, 300, null, null, '메뉴명에 ''저당'' 표기', 'https://xn--2o2b2xt4yeqi6sah0v.com/', 'estimated', 2),
  ('b8d48155-a0d1-4946-bb76-2aba138c0eef', '부채살 포케', 'signature', 2, 325, null, null, null, 'https://xn--2o2b2xt4yeqi6sah0v.com/', 'estimated', 3),
  ('b8d48155-a0d1-4946-bb76-2aba138c0eef', '연어 포케', 'signature', 4, 400, null, null, null, 'https://xn--2o2b2xt4yeqi6sah0v.com/', 'estimated', 4),
  ('bcac8deb-cc86-47c4-a0e1-3d7cca9df01c', '0칼로리 복숭아 아이스티', 'low_sugar', null, 0, 2300, null, '공식 메뉴판 ''제로·저칼로리'' 분류', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 0),
  ('bcac8deb-cc86-47c4-a0e1-3d7cca9df01c', '착한 콜드브루', 'signature', null, null, 1900, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 1),
  ('bcac8deb-cc86-47c4-a0e1-3d7cca9df01c', '아메리카노', 'signature', null, null, 3900, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 2),
  ('bcac8deb-cc86-47c4-a0e1-3d7cca9df01c', '착한 바닐라라떼', 'signature', null, null, 2800, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 3),
  ('bcac8deb-cc86-47c4-a0e1-3d7cca9df01c', '자바칩 프라페', 'signature', null, null, 5500, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 4),
  ('bbaf7e7f-f349-441d-9baf-ef0f0c3bb030', '0칼로리 복숭아 아이스티', 'low_sugar', null, 0, 2300, null, '공식 메뉴판 ''제로·저칼로리'' 분류', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 0),
  ('bbaf7e7f-f349-441d-9baf-ef0f0c3bb030', '착한 콜드브루', 'signature', null, null, 1900, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 1),
  ('bbaf7e7f-f349-441d-9baf-ef0f0c3bb030', '아메리카노', 'signature', null, null, 3900, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 2),
  ('bbaf7e7f-f349-441d-9baf-ef0f0c3bb030', '착한 바닐라라떼', 'signature', null, null, 2800, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 3),
  ('bbaf7e7f-f349-441d-9baf-ef0f0c3bb030', '자바칩 프라페', 'signature', null, null, 5500, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 4),
  ('26a006d8-39fa-4407-9321-445f0996c129', '0칼로리 복숭아 아이스티', 'low_sugar', null, 0, 2300, null, '공식 메뉴판 ''제로·저칼로리'' 분류', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 0),
  ('26a006d8-39fa-4407-9321-445f0996c129', '착한 콜드브루', 'signature', null, null, 1900, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 1),
  ('26a006d8-39fa-4407-9321-445f0996c129', '아메리카노', 'signature', null, null, 3900, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 2),
  ('26a006d8-39fa-4407-9321-445f0996c129', '착한 바닐라라떼', 'signature', null, null, 2800, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 3),
  ('26a006d8-39fa-4407-9321-445f0996c129', '자바칩 프라페', 'signature', null, null, 5500, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 4),
  ('49be3410-b2ff-4b5f-a6dd-fe9c5a3eb2a1', '0칼로리 복숭아 아이스티', 'low_sugar', null, 0, 2300, null, '공식 메뉴판 ''제로·저칼로리'' 분류', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 0),
  ('49be3410-b2ff-4b5f-a6dd-fe9c5a3eb2a1', '착한 콜드브루', 'signature', null, null, 1900, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 1),
  ('49be3410-b2ff-4b5f-a6dd-fe9c5a3eb2a1', '아메리카노', 'signature', null, null, 3900, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 2),
  ('49be3410-b2ff-4b5f-a6dd-fe9c5a3eb2a1', '착한 바닐라라떼', 'signature', null, null, 2800, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 3),
  ('49be3410-b2ff-4b5f-a6dd-fe9c5a3eb2a1', '자바칩 프라페', 'signature', null, null, 5500, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 4),
  ('b57b279c-8697-4fdf-b1b0-18d284f3baeb', '0칼로리 복숭아 아이스티', 'low_sugar', null, 0, 2300, null, '공식 메뉴판 ''제로·저칼로리'' 분류', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 0),
  ('b57b279c-8697-4fdf-b1b0-18d284f3baeb', '착한 콜드브루', 'signature', null, null, 1900, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 1),
  ('b57b279c-8697-4fdf-b1b0-18d284f3baeb', '아메리카노', 'signature', null, null, 3900, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 2),
  ('b57b279c-8697-4fdf-b1b0-18d284f3baeb', '착한 바닐라라떼', 'signature', null, null, 2800, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 3),
  ('b57b279c-8697-4fdf-b1b0-18d284f3baeb', '자바칩 프라페', 'signature', null, null, 5500, null, '공식 메뉴판 ''베스트 인기 메뉴''', 'https://www.dessert39.com/html/pages/menu_beverage.php', 'official', 4)
on conflict (store_id, name) do update set
  kind = excluded.kind,
  sugar_g = excluded.sugar_g,
  calories = excluded.calories,
  price_won = excluded.price_won,
  serving = excluded.serving,
  note = excluded.note,
  source_url = excluded.source_url,
  confidence = excluded.confidence,
  sort_order = excluded.sort_order,
  updated_at = now();
