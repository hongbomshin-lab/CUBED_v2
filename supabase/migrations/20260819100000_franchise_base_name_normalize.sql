-- ============================================================
-- franchise_base_name(): 온도 표기 접두어 정규화 확장
--
-- 문제: 이디야 "I-"/"H-", "ICED "/"HOT ", "(HOT)" 접두어가 제거되지 않아
--   · 같은 메뉴가 온도별로 다른 그룹이 됨 (I-흑당 라떼 ≠ 흑당 라떼)
--   · 번역도 중복 발생 (1071 → 954 로 줄어듦, 351건 절약)
-- ⚠️ 앱의 FranchiseDrink.parseTemp 도 동일 규칙으로 맞춰야 한다.
--    (키가 어긋나면 앱에서 번역을 찾지 못함)
-- ============================================================

create or replace function public.franchise_base_name(p_name_clean text)
returns text
language sql
immutable
as $$
  with normalized as (
    select btrim(
      regexp_replace(
        regexp_replace(
          regexp_replace(
            btrim(p_name_clean),
            -- 앞머리 온도 표기: I- / H- / (HOT) / (ICED) / ICED / HOT / 아이스 / 따뜻한 / 핫
            '^([IH]-|\((HOT|ICE|ICED|아이스|핫)\)|(ICED|ICE|HOT)\s|아이스\s*|따뜻한\s*|핫\s*)',
            '', 'i'
          ),
          '\s*\(ICED\)', '', 'gi'      -- 뒤에 붙는 (ICED)
        ),
        '\s{2,}', ' ', 'g'             -- 중복 공백 정리
      )
    ) as v
  )
  select coalesce(nullif(v, ''), btrim(p_name_clean)) from normalized;
$$;

-- 뷰들은 이 함수를 참조하므로 자동으로 새 규칙을 따른다.
-- 구 규칙으로 저장된 번역(예: 'I-흑당 라떼')은 그대로 남지만 조회되지 않는다.
-- 정리하려면(선택):
--   delete from public.franchise_translations t
--   where t.kind = 'menu'
--     and not exists (select 1 from public.franchise_menu_names n where n.source = t.source);
