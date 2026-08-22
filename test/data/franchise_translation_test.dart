import 'package:flutter_test/flutter_test.dart';

import 'package:cubed_app/core/i18n/app_lang.dart';
import 'package:cubed_app/data/franchise_repository.dart';
import 'package:cubed_app/data/models/franchise_drink.dart';
import 'package:cubed_app/data/translation_repository.dart';

FranchiseDrink _drink({
  required String brand,
  required String nameClean,
  String? size,
  double? sugarG,
}) {
  final (base, temp) = FranchiseDrink.parseTemp(nameClean);
  return FranchiseDrink(
    id: '$brand-$nameClean-$size',
    brand: brand,
    name: nameClean,
    nameClean: nameClean,
    size: size,
    sugarG: sugarG,
    temperature: temp,
    baseName: base,
  );
}

FranchiseMenu _menu(List<FranchiseDrink> variants) {
  final rep = variants.first;
  return FranchiseMenu(
    brand: rep.brand,
    category: null,
    displayName: variants.length == 1 ? rep.nameClean : rep.baseName,
    representative: rep,
    variants: variants,
  );
}

void main() {
  // 실제 DB에 들어 있는 형태를 그대로 흉내낸 사전.
  final enDict = TranslationDict(AppLang.en, const {
    'menu|아메리카노': 'Americano',
    'menu|페퍼민트티': 'Peppermint Tea',
    'brand|스타벅스': 'Starbucks',
    'brand|빽다방': "PAIK'S COFFEE",
    'size|톨': 'Tall',
  });

  final americano = _menu([
    _drink(brand: '스타벅스', nameClean: '아메리카노', size: '톨', sugarG: 0),
    _drink(brand: '스타벅스', nameClean: '아이스 아메리카노', size: '톨', sugarG: 0),
  ]);
  // 변형이 하나뿐이라 표시명에 '(ICED)' 가 남는 케이스.
  final peppermint = _menu([
    _drink(brand: '빽다방', nameClean: '페퍼민트티(ICED)', sugarG: 0),
  ]);
  final menus = [americano, peppermint];

  group('TranslationDict.menuName', () {
    test('기본명으로 조회해 번역을 찾는다', () {
      expect(enDict.menuName('아메리카노', '아메리카노'), 'Americano');
    });

    test('표시명에 (ICED) 가 남아도 기본명 키로 찾는다', () {
      // 이 폴백이 없으면 '페퍼민트티(ICED)' 가 번역되지 않고 한국어로 남는다.
      expect(peppermint.translationKey, '페퍼민트티');
      expect(
        enDict.menuName(peppermint.displayName, peppermint.translationKey),
        'Peppermint Tea',
      );
    });

    test('사전에 없으면 원문으로 폴백', () {
      expect(enDict.menuName('신메뉴', '신메뉴'), '신메뉴');
    });

    test('한국어는 사전을 타지 않고 원문 그대로', () {
      const ko = TranslationDict(AppLang.ko, {});
      expect(ko.menuName('아메리카노', '아메리카노'), '아메리카노');
      expect(ko.brand('스타벅스'), '스타벅스');
    });
  });

  group('FranchiseRepository.filterByText', () {
    test('번역된 메뉴명으로 검색된다', () {
      final hit = FranchiseRepository.filterByText(menus, 'americano', enDict);
      expect(hit, [americano]);
    });

    test('부분 단어·대소문자 무시', () {
      expect(FranchiseRepository.filterByText(menus, 'AMERI', enDict), [americano]);
      expect(FranchiseRepository.filterByText(menus, 'pepper', enDict), [peppermint]);
    });

    test('외국어 표시 중에도 한국어 원문으로 검색된다', () {
      expect(FranchiseRepository.filterByText(menus, '아메리카노', enDict), [americano]);
    });

    test('번역된 브랜드명으로도 검색된다', () {
      expect(FranchiseRepository.filterByText(menus, 'starbucks', enDict), [americano]);
    });

    test('공백으로 나뉜 토큰은 AND', () {
      expect(
        FranchiseRepository.filterByText(menus, 'starbucks americano', enDict),
        [americano],
      );
      expect(
        FranchiseRepository.filterByText(menus, 'starbucks peppermint', enDict),
        isEmpty,
      );
    });

    test('빈 검색어는 전체를 그대로 돌려준다', () {
      expect(FranchiseRepository.filterByText(menus, '   ', enDict), menus);
    });
  });

  group('FranchiseDrink.parseTemp', () {
    // DB 의 franchise_base_name() 과 같은 규칙이어야 번역 키가 맞는다.
    test('브랜드별 온도 표기를 모두 떼어낸다', () {
      expect(FranchiseDrink.parseTemp('I-아메리카노'), ('아메리카노', 'ICE'));
      expect(FranchiseDrink.parseTemp('H-아메리카노'), ('아메리카노', 'HOT'));
      expect(FranchiseDrink.parseTemp('ICED 아메리카노'), ('아메리카노', 'ICE'));
      expect(FranchiseDrink.parseTemp('HOT 아메리카노'), ('아메리카노', 'HOT'));
      expect(FranchiseDrink.parseTemp('(HOT)아메리카노'), ('아메리카노', 'HOT'));
      expect(FranchiseDrink.parseTemp('아이스 아메리카노'), ('아메리카노', 'ICE'));
      expect(FranchiseDrink.parseTemp('따뜻한 아메리카노'), ('아메리카노', 'HOT'));
      expect(FranchiseDrink.parseTemp('핫 아메리카노'), ('아메리카노', 'HOT'));
      expect(FranchiseDrink.parseTemp('페퍼민트티(ICED)'), ('페퍼민트티', 'ICE'));
    });

    test('온도 표기가 없으면 그대로', () {
      expect(FranchiseDrink.parseTemp('콜드 브루'), ('콜드 브루', null));
    });
  });
}
