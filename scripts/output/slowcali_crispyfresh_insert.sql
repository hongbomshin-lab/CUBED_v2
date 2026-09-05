-- 슬로우캘리·크리스피프레시 서울 (store_type=restaurant · 저당 전문)
-- 총 78곳 · 이름 중복 시 건너뜀(재실행 안전)

insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 홍대입구역점','서울특별시 서대문구 신촌로 9 1층',37.5585189,126.9280604,'restaurant','서대문구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 홍대입구역점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 서울시청역점','서울특별시 중구 서소문로 134 1층',37.5635723,126.9758925,'restaurant','중구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 서울시청역점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 충무로점','서울특별시 중구 퇴계로27길 16 1층 104호',37.5619522,126.9918449,'restaurant','중구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 충무로점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 광화문','서울특별시 종로구 종로 19 제1층 121-1호',37.5708345,126.9798606,'restaurant','종로구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 광화문');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 종로새문안점','서울특별시 종로구 새문안로 87 2층',37.5703797,126.9744117,'restaurant','종로구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 종로새문안점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 종각역','서울특별시 종로구 우정국로 26 센트로폴리스 1층 Retail 1R-7호',37.5714967,126.983659,'restaurant','종로구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 종각역');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 정동점','서울특별시 종로구 새문안로 58 지하1층 B105-1호, 3호',37.5693106,126.9715861,'restaurant','종로구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 정동점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 경복궁점','서울특별시 종로구 새문안로5가길 32 한국생산성본부 B1층',37.5749172,126.9735672,'restaurant','종로구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 경복궁점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 숭례문점','서울특별시 중구 세종대로 23 창화빌딩 1층',37.5590959,126.9738597,'restaurant','중구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 숭례문점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 을지로점','서울특별시 중구 을지로5길 26 미래에셋센터원 지1층 118호',37.5673385,126.9852223,'restaurant','중구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 을지로점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 을지트윈타워점','서울특별시 중구 을지로 170 1층 120호',37.5661387,126.9973271,'restaurant','중구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 을지트윈타워점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 신용산점','서울특별시 용산구 한강대로 95 지하2층 B238호',37.5290927,126.9668857,'restaurant','용산구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 신용산점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 신촌점','서울특별시 서대문구 연세로12길 10 1층',37.558863,126.9375299,'restaurant','서대문구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 신촌점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 공덕점','서울특별시 마포구 백범로 202 1층 109호',37.5428481,126.9524687,'restaurant','마포구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 공덕점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 뚝섬역점','서울특별시 성동구 상원10길 4-1 1층 슬로우캘리',37.5490822,127.0485403,'restaurant','성동구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 뚝섬역점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 왕십리뉴타운점','서울특별시 성동구 왕십리로 410 센트라스 상가 J동 125호',37.5665507,127.0247864,'restaurant','성동구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 왕십리뉴타운점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 한양대점','서울특별시 성동구 마조로 22 1층',37.5596401,127.0412229,'restaurant','성동구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 한양대점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 종로점','서울특별시 종로구 대학로1길 34-11 1층',37.572334,127.0004466,'restaurant','종로구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 종로점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 압구정점','서울특별시 강남구 논현로171길 15 카로시티1 1층 105호',37.5254936,127.0271419,'restaurant','강남구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 압구정점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 구의역점','서울특별시 광진구 아차산로 375 1층 104호',37.5370792,127.0843905,'restaurant','광진구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 구의역점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 천호점','서울특별시 강동구 천호대로 1006 1층 에프102-1호',37.5380133,127.1237896,'restaurant','강동구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 천호점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 경희대점','서울특별시 동대문구 회기로19길 23 유경빌딩 1층 101호',37.5926859,127.052931,'restaurant','동대문구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 경희대점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 상봉점','서울특별시 중랑구 면목로 490 상봉타워 101호',37.5956441,127.086089,'restaurant','중랑구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 상봉점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 공릉점','서울특별시 노원구 공릉로 208 1층 4호',37.6282799,127.0777856,'restaurant','노원구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 공릉점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 연신내점','서울특별시 은평구 연서로27길 4 1층 101호',37.6178239,126.9190673,'restaurant','은평구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 연신내점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 상암점','서울특별시 마포구 월드컵북로 402 1층 153, 154호',37.5802099,126.8889677,'restaurant','마포구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 상암점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 이대점','서울특별시 서대문구 이화여대길 78 가동 1층',37.5592754,126.9441781,'restaurant','서대문구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 이대점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 서대문점','서울특별시 서대문구 통일로 139 1층',37.5667797,126.9653913,'restaurant','서대문구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 서대문점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 연남본점','서울특별시 마포구 동교로38길 35 2층',37.5613621,126.9258205,'restaurant','마포구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 연남본점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 마포점','서울특별시 마포구 마포대로 156 1층 106호',37.5479194,126.954371,'restaurant','마포구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 마포점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 신도림점','서울특별시 구로구 경인로59길 7 상가동 1층 101호',37.5056493,126.8826529,'restaurant','구로구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 신도림점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 선유도역점','서울특별시 영등포구 양평로 126 신성빌딩 1층 슬로우캘리',37.5382385,126.8939337,'restaurant','영등포구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 선유도역점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 마곡발산점','서울특별시 강서구 공항대로 219 1층 110호',37.5596349,126.8320108,'restaurant','강서구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 마곡발산점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 문래점','서울특별시 영등포구 경인로 775 지하1층 식당가 185호 슬로우캘리 문래점',37.5147686,126.8991302,'restaurant','영등포구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 문래점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 강서우림블루나인점','서울특별시 강서구 양천로 583 124-1호',37.5570451,126.8642592,'restaurant','강서구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 강서우림블루나인점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 마곡나루점','서울특별시 강서구 마곡중앙로 161-11 A-127호',37.5679674,126.826746,'restaurant','강서구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 마곡나루점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 까치산역점','서울특별시 강서구 강서로17길 6 1층 06호',37.5334208,126.8452047,'restaurant','강서구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 까치산역점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 마곡르웨스트점','서울특별시 강서구 마곡중앙로 111 지하2층 B226, B246호',37.5635978,126.8258228,'restaurant','강서구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 마곡르웨스트점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 구로디지털단지점','서울특별시 구로구 디지털로30길 31 지하1층 103호',37.4828775,126.8964891,'restaurant','구로구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 구로디지털단지점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 가산디지털점','서울특별시 금천구 가산디지털1로 181 1층 105호',37.481425,126.8803936,'restaurant','금천구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 가산디지털점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 문래동국메뜨리앙점','서울특별시 영등포구 선유로 76 1층 109호',37.5206365,126.8899118,'restaurant','영등포구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 문래동국메뜨리앙점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 금천시흥점','서울특별시 금천구 시흥대로73길 67 105호',37.4559426,126.8957474,'restaurant','금천구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 금천시흥점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 서울대점','서울특별시 관악구 대학길 22 1층 슬로우캘리',37.4697724,126.9378086,'restaurant','관악구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 서울대점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 보라매공원점','서울특별시 동작구 보라매로5길 43 보라매삼성쉐르빌 1층 110호',37.4914501,126.923264,'restaurant','동작구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 보라매공원점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 여의도신영증권점','서울특별시 영등포구 국제금융로8길 16 신영증권 빌딩 지하1층 B127호',37.5213006,126.9288968,'restaurant','영등포구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 여의도신영증권점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 여의도 KBS 본관점','서울특별시 영등포구 의사당대로 38 여의도더샵아일랜드파크 1층(KBS 본관 정문 앞)',37.5257581,126.9187147,'restaurant','영등포구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 여의도 KBS 본관점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 사당이수점','서울특별시 동작구 사당로 300 1층 슬로우캘리 사당이수점',37.4843925,126.9805811,'restaurant','동작구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 사당이수점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 중앙대점','서울특별시 동작구 흑석로 114 1층',37.5085094,126.9615303,'restaurant','동작구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 중앙대점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 숭실대점','서울특별시 동작구 사당로 12-1 1층, 슬로우캘리 숭실대점',37.4952956,126.955839,'restaurant','동작구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 숭실대점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 서울대입구역점','서울특별시 관악구 관악로 152 1층',37.4787122,126.9525957,'restaurant','관악구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 서울대입구역점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 신림점','서울특별시 관악구 신림로 310 1층 나호',37.4819448,126.9302024,'restaurant','관악구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 신림점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 강남역삼성타운점','서울특별시 서초구 서초대로74길 23 1층 103호',37.4956227,127.0271068,'restaurant','서초구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 강남역삼성타운점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 양재역점','서울특별시 서초구 남부순환로347길 59 슬로우캘리 양재역점',37.4869805,127.0307757,'restaurant','서초구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 양재역점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 남부터미널점','서울특별시 서초구 반포대로14길 58 1층 102호',37.4862003,127.0141489,'restaurant','서초구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 남부터미널점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 교대점','서울특별시 서초구 서초중앙로22길 28 1층',37.4931681,127.015455,'restaurant','서초구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 교대점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 도곡점','서울특별시 강남구 남부순환로 2806 군인공제회관 지하1층',37.4891028,127.0529204,'restaurant','강남구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 도곡점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 강남역점','서울특별시 강남구 강남대로66길 14 강남역 와이즈플레이스 1층 109호',37.4916753,127.0319854,'restaurant','강남구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 강남역점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 삼성점','서울특별시 강남구 삼성로 517 1층 110-1호',37.5079777,127.0555281,'restaurant','강남구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 삼성점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 선릉점','서울특별시 강남구 테헤란로 313 지상1층 103호',37.5038082,127.045287,'restaurant','강남구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 선릉점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 강남구청역점','서울특별시 강남구 학동로 338 강남파라곤 SB103호',37.5165899,127.0402809,'restaurant','강남구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 강남구청역점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 송리단점','서울특별시 송파구 오금로 126 레이크해모로 1층',37.5113819,127.1088352,'restaurant','송파구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 송리단점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 송파문정점','서울특별시 송파구 법원로 96 102호',37.484046,127.12096,'restaurant','송파구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 송파문정점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 잠실삼전역점','서울특별시 송파구 백제고분로 197 1층',37.5043859,127.088784,'restaurant','송파구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 잠실삼전역점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 암사점','서울특별시 강동구 올림픽로 786 JL타워 1층 104호 슬로우캘리 암사점',37.5511474,127.128204,'restaurant','강동구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 암사점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 둔촌점','서울특별시 강동구 양재대로 1360 스테이션5동 지하2층 B217호',37.5274745,127.1370449,'restaurant','강동구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 둔촌점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 강동역점','서울특별시 강동구 천호대로 1089 지상 상가 1층 35호',37.5365922,127.1334296,'restaurant','강동구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 강동역점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '슬로우캘리 고덕비즈밸리점','서울특별시 강동구 고덕비즈밸리로 26 B동 1층 106호',37.5654433,127.1602745,'restaurant','강동구','슬로우캘리',true
where not exists (select 1 from public.stores where name='슬로우캘리 고덕비즈밸리점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '크리스피프레시 파르나스몰점','서울특별시 강남구 테헤란로 521 파르나스몰 B1 F-5, 6호',37.5092611,127.0608196,'restaurant','강남구','크리스피프레시',true
where not exists (select 1 from public.stores where name='크리스피프레시 파르나스몰점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '크리스피프레시 용산아이파크몰점','서울특별시 용산구 한강대로23길 55 용산아이파크몰 4층',37.5297718,126.9647415,'restaurant','용산구','크리스피프레시',true
where not exists (select 1 from public.stores where name='크리스피프레시 용산아이파크몰점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '크리스피프레시 서울스퀘어점','서울특별시 중구 한강대로 416 1층',37.5555057,126.9737678,'restaurant','중구','크리스피프레시',true
where not exists (select 1 from public.stores where name='크리스피프레시 서울스퀘어점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '크리스피프레시 구의이스트폴점','서울특별시 광진구 아차산로 402 지하1층',37.5365957,127.0878481,'restaurant','광진구','크리스피프레시',true
where not exists (select 1 from public.stores where name='크리스피프레시 구의이스트폴점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '크리스피프레시 광화문점','서울특별시 중구 청계천로 24 케이스퀘어시티 1층',37.5685545,126.9801781,'restaurant','중구','크리스피프레시',true
where not exists (select 1 from public.stores where name='크리스피프레시 광화문점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '크리스피프레시 파미에스테이션점','서울특별시 서초구 사평대로 205 GF 19번',37.5044921,127.0078453,'restaurant','서초구','크리스피프레시',true
where not exists (select 1 from public.stores where name='크리스피프레시 파미에스테이션점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '크리스피프레시 합정점','서울특별시 마포구 월드컵로3길 14 딜라이트스퀘어 2차 지하1층',37.5512008,126.9119001,'restaurant','마포구','크리스피프레시',true
where not exists (select 1 from public.stores where name='크리스피프레시 합정점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '크리스피프레시 여의도파크원점','서울특별시 영등포구 여의대로 108 파크원 1층',37.5266691,126.9271941,'restaurant','영등포구','크리스피프레시',true
where not exists (select 1 from public.stores where name='크리스피프레시 여의도파크원점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '크리스피프레시 마곡코엑스점','서울특별시 강서구 마곡중앙로 143 CP1 지하2층 227, 228, 229호',37.5648005,126.8252416,'restaurant','강서구','크리스피프레시',true
where not exists (select 1 from public.stores where name='크리스피프레시 마곡코엑스점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '크리스피프레시 롯데몰 김포공항점','서울특별시 강서구 하늘길 77 롯데몰 김포공항점 MF층',37.5623129,126.8012785,'restaurant','강서구','크리스피프레시',true
where not exists (select 1 from public.stores where name='크리스피프레시 롯데몰 김포공항점');
insert into public.stores (name,address,lat,lng,store_type,district,brand,is_active)
select '크리스피프레시 선릉점','서울특별시 강남구 테헤란로 316 메트라이프타워 B1',37.5031036,127.0455562,'restaurant','강남구','크리스피프레시',true
where not exists (select 1 from public.stores where name='크리스피프레시 선릉점');
