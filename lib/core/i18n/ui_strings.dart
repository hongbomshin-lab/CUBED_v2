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
    AppLang.ko: '사이즈',
    AppLang.en: 'sizes',
    AppLang.ja: 'サイズ',
    AppLang.zh: '规格',
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
