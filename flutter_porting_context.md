---
name: flutter-porting-context
description: "저당맵 Next.js→Flutter 포팅 컨텍스트 — Supabase/지도/제보/핫딜 현황, 실제 DB 스키마, 웹전용 교체 지점"
metadata: 
  node_type: memory
  type: project
  originSessionId: 7e47b867-e901-4dee-810a-18a02b33b944
---

기존 Next.js 저당맵 웹앱([/Users/sangin514/my-nutrition-map](/Users/sangin514/my-nutrition-map))을 Flutter로 포팅 중. 로그인/인증·커뮤니티는 포팅 범위 제외. DB 수정은 별도(새 세션에서 새 스키마 받기로 함) — 아래는 **현재(as-is) 분석**.

**Why:** Flutter 구현 세션의 사전 컨텍스트로 사용. 실제 운영 DB 스키마를 사용자에게 직접 받아 역추적 추정을 교체함.

## Supabase
- 환경변수: `NEXT_PUBLIC_SUPABASE_URL`/`_ANON_KEY`(클라), `SUPABASE_SERVICE_ROLE_KEY`(seed 전용)
- client: lib/supabase.ts (옵션 없는 단일 createClient)
- RPC: `nearby_stores(_lat,_lng,_radius_m,_category)`, `search_stores(_query,_lat,_lng,_radius_m)`, `get_low_sugar_menus(_brand_id,_category)`
- 버킷: store-images, menu-images (public), store-reports
- RLS 주의: store_assets/store_menus는 status='approved'만 public read, hot_deals는 status in(active,unknown_end)만, store_reports는 본인 것만+INSERT시 reported_by=auth.uid()
- 트리거: auth.users INSERT→profiles 자동생성, assets/menus updated_at 자동갱신. **제보 승인→store 자동생성 트리거 없음(admin 수동)**
- PostGIS: stores.geom + nearby_stores 공간쿼리

## 지도 (app/page.tsx, components/cubed/NaverMapCubed.tsx)
- 키: `NEXT_PUBLIC_NAVER_MAP_CLIENT_ID` (layout.tsx에서 maps.js?ncpKeyId=...&submodules=geocoder)
- 2레이어: 컨셉매장=stores 직접 select(naver_place_id LIKE 'manual:low-sugar-20260610:%', is_active) + 클라반경필터 / 프랜차이즈(토글ON)=nearby_stores RPC
- 지도 idle→center(소수3자리)·radius(min 2000m)→react-query 재요청(staleTime 10분)
- 마커 상위 20개만 렌더(MAX_MAP_MARKERS)
- 위치캐시: key=`jodangmap_location`, TTL 24h, lib/location-cache.ts. 유효시 geolocation 재요청 안함
- 필터(클라): 지금영업중/카페/디저트/한식/양식/분식/포장/배달. 정렬: 좋아요순/당낮은순/거리순
- 좋아요/저장=localStorage(`cubed:liked`,`cubed:saved`) — DB store_likes/menu_likes 인프라는 있으나 미사용
- 상세 표시: 사진·이름·카테고리·좋아요/리뷰수·영업상태/시간·메뉴테이블(당g/탄수g)·사진보드·정보·리뷰(DEMO_REVIEWS 하드코딩). 길찾기·전화 버튼은 UI만

## 매장 제보 (components/cubed/StoreReportModal.tsx → store_reports)
- 입력: name*, address*, lat/lng, phone, category, brand_type, naver_place_url, description(≤200), image_urls(≤3), status='pending'
- 주소→좌표: 네이버 maps Geocoder submodule(window.naver.maps.Service.geocode), 디바운스400ms
- 이미지: 버킷 store-reports, 경로 `{reportId}/{Date.now()}_{name}`
- 승인: 자동트리거 없음, admin/reports에서 status·reviewed_*·store_id 수동 처리

## 핫딜
- 프론트=DEMO_DEALS 하드코딩(lib/cubed-hotdeal-data.ts). DB hot_deals 테이블은 완성형이나 미연결(admin만)
- 바코드 기능 전혀 없음

## 실제 DB 스키마 (핵심)
- brands(id,name uniq,logo_url,category,brand_type), stores(id,brand_id,name,address,lat,lng,geom,phone,naver_place_id uniq,place_url,district,is_active,like_count)
- menus(id,brand_id,name,category,raw_name,like_count), nutrition(menu_id uniq, sugar_g/carbs_g/fat_g/sodium_mg/protein_g/calories, sugar_per_100g generated, sugar_level, 당류세부5종, food_weight)
- store_menus(store_id,name,sugar_g,carbs_g,calories,is_signature,confidence,status), store_assets(store_id,kind,bucket,storage_path,source_url,is_primary,sort_order,status)
- store_reports, store_likes/menu_likes(store/menu_id,user_id,device_id), hot_deals(title,channel,category,image_url,original/deal_price,deal_url,end_at,status,like_count)
- profiles(id,nickname,is_admin,created_at) — **username 컬럼 없음(migration과 diverge)**
- (범위외) recipes/recipe_ingredients/ingredients/sugar_estimates(홈쿡 당류추정), posts/comments/board_categories/user_activities(커뮤니티·레벨)

## 디자인 토큰 (styles/theme.css, --cubed-* 만 실사용)
- 색: ink #1f1e1b, bg #f4f2ec, card #fff, lime(oklch 강조), open #2f8a4e, close #c4623f, heart #e2496b
- 폰트: display 'Black Han Sans', ui 'Gothic A1', mono 'DM Mono'
- 레이아웃: header 64 / filterbar 56 / list-w 440px
- 주의: theme.css 하단 SOOGA/shadcn 토큰·components/ui/* 는 레거시 미사용(인라인 style 직접구현) → cubed/* + 토큰만 참고

## Flutter 교체 필요 (웹 전용)
1. 네이버맵 JS SDK→flutter_naver_map(네이티브), HTML마커 재작성
2. Geocoder JS→네이버 Geocoding REST
3. localStorage→shared_preferences(위치캐시·좋아요·저장)
4. react-query→riverpod/dio 캐싱
5. geolocation→geolocator
6. supabase_flutter(RLS approved 필터 동일 적용)
7. File/FileReader→image_picker+Storage upload
8. 폰트 pubspec 번들
9. RPC는 그대로 supabase.rpc 호출 가능

## 관련 메모리
- [[project-cubed-impl]]
