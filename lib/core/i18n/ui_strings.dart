import 'app_lang.dart';

/// 메뉴 정보 화면의 고정 UI 문구. (메뉴명·브랜드·사이즈·카테고리는 DB 번역을 쓴다)
/// 키는 화면에서 읽기 쉬운 영문 슬러그.
const Map<String, Map<AppLang, String>> _strings = {
  // 목록
  'searchHint': {
    AppLang.ko: '메뉴 이름 검색 (예: 아메)',
    AppLang.en: 'Search menu (e.g. Ame)',
    AppLang.ja: 'メニュー検索（例：アメ）',
    AppLang.zh: '搜索菜单（例：美式）',
  },
  'all': {
    AppLang.ko: '전체',
    AppLang.en: 'All',
    AppLang.ja: 'すべて',
    AppLang.zh: '全部',
  },
  'loadFailed': {
    AppLang.ko: '메뉴를 불러오지 못했어요',
    AppLang.en: "Couldn't load the menu",
    AppLang.ja: 'メニューを読み込めませんでした',
    AppLang.zh: '无法加载菜单',
  },
  'noResult': {
    AppLang.ko: '검색 결과가 없어요',
    AppLang.en: 'No results',
    AppLang.ja: '検索結果がありません',
    AppLang.zh: '没有搜索结果',
  },
  'countSuffix': {
    AppLang.ko: '개',
    AppLang.en: ' items',
    AppLang.ja: '件',
    AppLang.zh: '项',
  },
  // 정렬
  'sortSugarAsc': {
    AppLang.ko: '당 낮은순',
    AppLang.en: 'Lowest sugar',
    AppLang.ja: '糖質が低い順',
    AppLang.zh: '含糖量低到高',
  },
  'sortSugarDesc': {
    AppLang.ko: '당 높은순',
    AppLang.en: 'Highest sugar',
    AppLang.ja: '糖質が高い順',
    AppLang.zh: '含糖量高到低',
  },
  'sortCalories': {
    AppLang.ko: '칼로리순',
    AppLang.en: 'By calories',
    AppLang.ja: 'カロリー順',
    AppLang.zh: '按热量',
  },
  // 온도·사이즈
  'iced': {
    AppLang.ko: '아이스',
    AppLang.en: 'Iced',
    AppLang.ja: 'アイス',
    AppLang.zh: '冰',
  },
  'hot': {
    AppLang.ko: '핫',
    AppLang.en: 'Hot',
    AppLang.ja: 'ホット',
    AppLang.zh: '热',
  },
  'sizeCount': {
    AppLang.ko: '사이즈 {n}',
    AppLang.en: '{n} sizes',
    AppLang.ja: 'サイズ{n}種',
    AppLang.zh: '{n} 种规格',
  },
  // 상세
  'sugar': {
    AppLang.ko: '당류',
    AppLang.en: 'Sugar',
    AppLang.ja: '糖類',
    AppLang.zh: '糖类',
  },
  'sugarCubes': {
    AppLang.ko: '각설탕 약 {n}개',
    AppLang.en: 'about {n} sugar cubes',
    AppLang.ja: '角砂糖 約{n}個',
    AppLang.zh: '约 {n} 块方糖',
  },
  'calories': {
    AppLang.ko: '칼로리',
    AppLang.en: 'Calories',
    AppLang.ja: 'カロリー',
    AppLang.zh: '热量',
  },
  'zeroOption': {
    AppLang.ko: '제로 옵션',
    AppLang.en: 'Zero option',
    AppLang.ja: 'ゼロオプション',
    AppLang.zh: '零糖选项',
  },
  'available': {
    AppLang.ko: '있음',
    AppLang.en: 'Available',
    AppLang.ja: 'あり',
    AppLang.zh: '有',
  },
  'altSweetener': {
    AppLang.ko: '대체 감미료',
    AppLang.en: 'Alt. sweetener',
    AppLang.ja: '代替甘味料',
    AppLang.zh: '代糖',
  },
  'nutritionAll': {
    AppLang.ko: '영양성분 전체',
    AppLang.en: 'All nutrition facts',
    AppLang.ja: '栄養成分すべて',
    AppLang.zh: '全部营养成分',
  },
  'carbs': {
    AppLang.ko: '탄수화물',
    AppLang.en: 'Carbs',
    AppLang.ja: '炭水化物',
    AppLang.zh: '碳水化合物',
  },
  'protein': {
    AppLang.ko: '단백질',
    AppLang.en: 'Protein',
    AppLang.ja: 'たんぱく質',
    AppLang.zh: '蛋白质',
  },
  'fat': {
    AppLang.ko: '지방',
    AppLang.en: 'Fat',
    AppLang.ja: '脂質',
    AppLang.zh: '脂肪',
  },
  'sodium': {
    AppLang.ko: '나트륨',
    AppLang.en: 'Sodium',
    AppLang.ja: 'ナトリウム',
    AppLang.zh: '钠',
  },
  'caffeine': {
    AppLang.ko: '카페인',
    AppLang.en: 'Caffeine',
    AppLang.ja: 'カフェイン',
    AppLang.zh: '咖啡因',
  },
  // 저당맵 (매장 지도)
  'storeSearchHint': {
    AppLang.ko: '저당 매장 이름 검색',
    AppLang.en: 'Search store name',
    AppLang.ja: '店舗名を検索',
    AppLang.zh: '搜索门店名称',
  },
  'typeCafe': {
    AppLang.ko: '카페·베이커리',
    AppLang.en: 'Cafe & Bakery',
    AppLang.ja: 'カフェ・ベーカリー',
    AppLang.zh: '咖啡·烘焙',
  },
  'typeRestaurant': {
    AppLang.ko: '음식점',
    AppLang.en: 'Restaurant',
    AppLang.ja: 'レストラン',
    AppLang.zh: '餐厅',
  },
  'typeZeroStore': {
    AppLang.ko: '제로스토어',
    AppLang.en: 'Zero Store',
    AppLang.ja: 'ゼロストア',
    AppLang.zh: '零糖商店',
  },
  'typeDelivery': {
    AppLang.ko: '배달',
    AppLang.en: 'Delivery',
    AppLang.ja: 'デリバリー',
    AppLang.zh: '外送',
  },
  'noSearchResult': {
    AppLang.ko: '검색 결과가 없어요',
    AppLang.en: 'No stores found',
    AppLang.ja: '検索結果がありません',
    AppLang.zh: '没有搜索结果',
  },
  // 매장 상세 — 대표 메뉴
  'featuredMenu': {
    AppLang.ko: '대표 메뉴',
    AppLang.en: 'Featured menu',
    AppLang.ja: 'おすすめメニュー',
    AppLang.zh: '招牌菜单',
  },
  'lowSugarMenu': {
    AppLang.ko: '저당 메뉴',
    AppLang.en: 'Low sugar',
    AppLang.ja: '低糖メニュー',
    AppLang.zh: '低糖菜单',
  },
  'signatureMenu': {
    AppLang.ko: '시그니처',
    AppLang.en: 'Signature',
    AppLang.ja: 'シグネチャー',
    AppLang.zh: '招牌',
  },
  'sugarUnknown': {
    AppLang.ko: '정보 준비 중',
    AppLang.en: 'Data pending',
    AppLang.ja: '準備中',
    AppLang.zh: '信息准备中',
  },
  'estimated': {
    AppLang.ko: '추정',
    AppLang.en: 'Est.',
    AppLang.ja: '推定',
    AppLang.zh: '估算',
  },
  'noReview': {
    AppLang.ko: '리뷰 없음',
    AppLang.en: 'No reviews',
    AppLang.ja: 'レビューなし',
    AppLang.zh: '暂无评价',
  },
  'reviewSummary': {
    AppLang.ko: '추천 {rate}%  ·  리뷰 {n}개',
    AppLang.en: '{rate}% recommend  ·  {n} reviews',
    AppLang.ja: 'おすすめ {rate}%  ·  レビュー {n}件',
    AppLang.zh: '{rate}% 推荐  ·  {n} 条评价',
  },
  'reportStore': {
    AppLang.ko: '매장 제보',
    AppLang.en: 'Add a store',
    AppLang.ja: '店舗を提報',
    AppLang.zh: '提报门店',
  },
  'franchiseToggle': {
    AppLang.ko: '프랜차이즈',
    AppLang.en: 'Chains',
    AppLang.ja: 'チェーン店',
    AppLang.zh: '连锁店',
  },
  'franchiseNearby': {
    AppLang.ko: '내 주변 {n}m',
    AppLang.en: 'within {n}m',
    AppLang.ja: '半径{n}m',
    AppLang.zh: '{n}m 以内',
  },
  'brandLowSugar': {
    AppLang.ko: '이 브랜드 저당 메뉴',
    AppLang.en: 'Low-sugar picks here',
    AppLang.ja: 'このブランドの低糖メニュー',
    AppLang.zh: '该品牌低糖菜单',
  },
  'seeAllMenus': {
    AppLang.ko: '메뉴 전체 보기',
    AppLang.en: 'See all menus',
    AppLang.ja: 'メニューをすべて見る',
    AppLang.zh: '查看全部菜单',
  },
  // 모드 토글
  'modeMap': {
    AppLang.ko: '매장 지도',
    AppLang.en: 'Store map',
    AppLang.ja: '店舗マップ',
    AppLang.zh: '门店地图',
  },
  'modeMenu': {
    AppLang.ko: '메뉴 정보',
    AppLang.en: 'Menu info',
    AppLang.ja: 'メニュー情報',
    AppLang.zh: '菜单信息',
  },
};

/// UI 고정 문구 조회. 없으면 한국어로 폴백.
String uiText(String key, AppLang lang) {
  final m = _strings[key];
  if (m == null) return key;
  return m[lang] ?? m[AppLang.ko] ?? key;
}
