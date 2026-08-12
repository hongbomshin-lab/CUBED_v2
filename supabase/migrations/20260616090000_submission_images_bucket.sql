-- 사용자 제보 원본 사진(전체샷/원재료/영양성분) 비공개 버킷.
-- 정책 없음 → service_role(Edge Function)만 읽기/쓰기. 의도된 동작.
insert into storage.buckets (id, name, public)
values ('submission-images', 'submission-images', false)
on conflict (id) do nothing;
